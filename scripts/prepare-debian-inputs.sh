#!/bin/bash
set -Eeuo pipefail

# Fetch and validate Debian 12 kernel build inputs only. Never compile a kernel here.
SOURCE_VERSION="${SOURCE_VERSION:-6.1.187-1}"
IMAGE_PACKAGE="${IMAGE_PACKAGE:-linux-image-6.1.0-53-amd64}"
IMAGE_VERSION="${IMAGE_VERSION:-6.1.187-1}"
CONFIG_PACKAGE="${CONFIG_PACKAGE:-linux-config-6.1}"
CONFIG_VERSION="${CONFIG_VERSION:-6.1.187-1}"

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/prepared-inputs"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
export LANG=C

rm -rf "$OUT"
mkdir -p "$OUT/source" "$OUT/reference" "$OUT/config" "$OUT/metadata"

# Use only Debian 12 Bookworm and Bookworm security. The minimal container may
# have no CA certificates, so bootstrap over HTTP while still verifying Debian's
# signed Release/InRelease metadata with APT. Install the CA bundle, then switch
# all final package access to HTTPS.
rm -f /etc/apt/sources.list
mkdir -p /etc/apt/sources.list.d
rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources
cat > /etc/apt/sources.list.d/d630-bookworm.list <<'SOURCES'
deb http://deb.debian.org/debian bookworm main
deb http://deb.debian.org/debian bookworm-updates main
deb http://security.debian.org/debian-security bookworm-security main
deb-src http://deb.debian.org/debian bookworm main
deb-src http://deb.debian.org/debian bookworm-updates main
deb-src http://security.debian.org/debian-security bookworm-security main
SOURCES

apt-get update
apt-get install -y --no-install-recommends ca-certificates dpkg-dev xz-utils
sed -i 's#http://#https://#g' /etc/apt/sources.list.d/d630-bookworm.list
apt-get update

{
  echo "Target Debian source package: linux=$SOURCE_VERSION"
  echo "Target reference image: $IMAGE_PACKAGE=$IMAGE_VERSION"
  echo "Target config package: $CONFIG_PACKAGE=$CONFIG_VERSION"
  echo
  echo "=== APT package candidates ==="
  apt-cache policy linux "$IMAGE_PACKAGE" "$CONFIG_PACKAGE"
} > "$OUT/metadata/apt-policy.txt"

# Download authentic source-package files from the signed Debian repository metadata.
mkdir -p "$WORK/source-download"
(
  cd "$WORK/source-download"
  apt-get source --download-only "linux=$SOURCE_VERSION"
)
for file in \
  "linux_${SOURCE_VERSION}.dsc" \
  "linux_${SOURCE_VERSION%%-*}.orig.tar.xz" \
  "linux_${SOURCE_VERSION}.debian.tar.xz"; do
  test -s "$WORK/source-download/$file" || {
    echo "Expected Debian source file missing: $file" >&2
    find "$WORK/source-download" -maxdepth 1 -type f -printf '%f\n' >&2
    exit 1
  }
  cp "$WORK/source-download/$file" "$OUT/source/"
done

# Extract once to verify .dsc checksums, patch series, and Debian source layout.
SOURCE_TREE="$WORK/linux-source"
dpkg-source -x "$OUT/source/linux_${SOURCE_VERSION}.dsc" "$SOURCE_TREE" \
  > "$OUT/metadata/dpkg-source-extract.log" 2>&1
test "$(dpkg-parsechangelog -l "$SOURCE_TREE/debian/changelog" -S Version)" = "$SOURCE_VERSION"
{
  echo "Extracted source package: $(dpkg-parsechangelog -l "$SOURCE_TREE/debian/changelog" -S Source) $(dpkg-parsechangelog -l "$SOURCE_TREE/debian/changelog" -S Version)"
  echo "Source directory: $SOURCE_TREE (temporary; not uploaded as a duplicate tree)"
  echo
  echo "=== Debian packaging entry points ==="
  for f in debian/rules debian/rules.gen debian/bin/gencontrol.py debian/config/defines; do
    if test -f "$SOURCE_TREE/$f"; then printf '%s\n' "$f"; fi
  done
  echo
  echo "=== AMD64 flavour configuration files ==="
  find "$SOURCE_TREE/debian/config/amd64" -maxdepth 3 -type f -printf '%P\n' 2>/dev/null | sort || true
} > "$OUT/metadata/debian-packaging-layout.txt"

# Download the matching official signed kernel image and Debian config package.
(
  cd "$WORK"
  apt-get download "$IMAGE_PACKAGE=$IMAGE_VERSION" "$CONFIG_PACKAGE=$CONFIG_VERSION"
)
IMAGE_DEB="$(find "$WORK" -maxdepth 1 -type f -name "${IMAGE_PACKAGE}_${IMAGE_VERSION}_amd64.deb" -print -quit)"
CONFIG_DEB="$(find "$WORK" -maxdepth 1 -type f -name "${CONFIG_PACKAGE}_${CONFIG_VERSION}_*.deb" -print -quit)"
test -n "$IMAGE_DEB" && test -s "$IMAGE_DEB"
test -n "$CONFIG_DEB" && test -s "$CONFIG_DEB"

check_field() {
  local deb="$1" field="$2" expected="$3" actual
  actual="$(dpkg-deb -f "$deb" "$field")"
  test "$actual" = "$expected" || {
    echo "$deb: expected $field '$expected', got '$actual'" >&2
    exit 1
  }
}
check_field "$IMAGE_DEB" Package "$IMAGE_PACKAGE"
check_field "$IMAGE_DEB" Version "$IMAGE_VERSION"
check_field "$IMAGE_DEB" Architecture amd64
check_field "$CONFIG_DEB" Package "$CONFIG_PACKAGE"
check_field "$CONFIG_DEB" Version "$CONFIG_VERSION"
CONFIG_ARCH="$(dpkg-deb -f "$CONFIG_DEB" Architecture)"
case "$CONFIG_ARCH" in
  all|amd64) ;;
  *) echo "Unexpected $CONFIG_PACKAGE architecture: $CONFIG_ARCH" >&2; exit 1 ;;
esac

cp "$IMAGE_DEB" "$OUT/reference/"
cp "$CONFIG_DEB" "$OUT/reference/"

mkdir -p "$WORK/image-root" "$WORK/config-root"
dpkg-deb -x "$IMAGE_DEB" "$WORK/image-root"
dpkg-deb -x "$CONFIG_DEB" "$WORK/config-root"

IMAGE_CONFIG="$WORK/image-root/boot/config-6.1.0-53-amd64"
if ! test -s "$IMAGE_CONFIG"; then
  IMAGE_CONFIG="$(find "$WORK/image-root" -type f -name 'config-6.1.0-53-amd64' -print -quit)"
fi
test -n "$IMAGE_CONFIG" && test -s "$IMAGE_CONFIG"
cp "$IMAGE_CONFIG" "$OUT/config/debian-image-config-6.1.0-53-amd64"

DIST_CONFIG_XZ="$WORK/config-root/usr/src/linux-config-6.1/config.amd64_none_amd64.xz"
if ! test -s "$DIST_CONFIG_XZ"; then
  DIST_CONFIG_XZ="$(find "$WORK/config-root" -type f -name 'config.amd64_none_amd64.xz' -print -quit)"
fi
test -n "$DIST_CONFIG_XZ" && test -s "$DIST_CONFIG_XZ"
xz -dc "$DIST_CONFIG_XZ" > "$OUT/config/debian-config-package-amd64_none_amd64"
test -s "$OUT/config/debian-config-package-amd64_none_amd64"

# Copy a small set of the exact Debian packaging/config rule files for quick review.
mkdir -p "$OUT/reference/debian-packaging"
for f in debian/rules debian/rules.gen debian/bin/gencontrol.py debian/config/defines; do
  if test -f "$SOURCE_TREE/$f"; then
    mkdir -p "$OUT/reference/debian-packaging/$(dirname "$f")"
    cp "$SOURCE_TREE/$f" "$OUT/reference/debian-packaging/$f"
  fi
done
if test -d "$SOURCE_TREE/debian/config/amd64/none"; then
  mkdir -p "$OUT/reference/debian-packaging/debian/config/amd64"
  cp -a "$SOURCE_TREE/debian/config/amd64/none" "$OUT/reference/debian-packaging/debian/config/amd64/"
fi

{
  echo "=== Official reference image package ==="
  dpkg-deb -f "$IMAGE_DEB" Package Version Architecture Section Source
  echo
  echo "=== Official Debian config package ==="
  dpkg-deb -f "$CONFIG_DEB" Package Version Architecture Section Source
  echo
  echo "=== Relevant settings in the exact reference image config ==="
  for symbol in \
    MODULES MODULE_UNLOAD MODULE_SIG MODVERSIONS \
    DRM DRM_I915 AGP_INTEL \
    MOUSE_PS2 MOUSE_PS2_ALPS MOUSE_PS2_SYNAPTICS MOUSE_PS2_TRACKPOINT MOUSEDEV MOUSEDEV_PSAUX \
    ISO9660_FS EXT4_FS BTRFS_FS NTFS3_FS FAT_FS MSDOS_FS VFAT_FS UDF_FS \
    ZRAM ZSMALLOC NETFILTER NF_TABLES NETFILTER_NETLINK NF_CONNTRACK NF_NAT \
    NFT_CT NFT_FIB_IPV4 NFT_FIB_IPV6 NFT_FIB_INET NFT_MASQ; do
    if grep -q "^CONFIG_$symbol=" "$OUT/config/debian-image-config-6.1.0-53-amd64"; then
      grep "^CONFIG_$symbol=" "$OUT/config/debian-image-config-6.1.0-53-amd64"
    elif grep -q "^# CONFIG_$symbol is not set$" "$OUT/config/debian-image-config-6.1.0-53-amd64"; then
      echo "# CONFIG_$symbol is not set"
    else
      echo "CONFIG_$symbol=<not present in config>"
    fi
  done
} > "$OUT/metadata/package-and-config-report.txt"

{
  echo "Prepared at UTC: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "Source package version: $SOURCE_VERSION"
  echo "Image package: $IMAGE_PACKAGE=$IMAGE_VERSION"
  echo "Config package: $CONFIG_PACKAGE=$CONFIG_VERSION"
  echo "Source package extracted and checked by dpkg-source: PASS"
  echo "No kernel compile, no custom package build, no install, no release."
} > "$OUT/metadata/INPUTS-READY.txt"

(
  cd "$OUT"
  find source reference config -type f -print0 | sort -z | xargs -0 sha256sum > metadata/SHA256SUMS
)

echo "Prepared Debian source and reference inputs:"
find "$OUT" -type f -printf '%P (%s bytes)\n' | sort
echo "No custom kernel was built."
