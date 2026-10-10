#!/bin/bash
set -Eeuo pipefail

# Fetch and validate Debian 13 Trixie backports source and microcode inputs only.
SOURCE_VERSION="${SOURCE_VERSION:-6.18.15-1~bpo13+1}"

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/prepared-inputs"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
export LANG=C

rm -rf "$OUT"
mkdir -p "$OUT/source" "$OUT/reference" "$OUT/config" "$OUT/microcode/intel-ucode" "$OUT/metadata"

# Use Debian 13 Trixie plus the official Trixie backports suite. APT verifies
# signed Release metadata; bootstrap CA certificates before switching to HTTPS.
rm -f /etc/apt/sources.list
mkdir -p /etc/apt/sources.list.d
rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources
cat > /etc/apt/sources.list.d/d630-trixie.list <<'SOURCES'
deb http://deb.debian.org/debian trixie main non-free-firmware
deb http://deb.debian.org/debian trixie-updates main non-free-firmware
deb http://security.debian.org/debian-security trixie-security main non-free-firmware
deb http://deb.debian.org/debian trixie-backports main non-free-firmware
deb-src http://deb.debian.org/debian trixie main non-free-firmware
deb-src http://deb.debian.org/debian trixie-updates main non-free-firmware
deb-src http://security.debian.org/debian-security trixie-security main non-free-firmware
deb-src http://deb.debian.org/debian trixie-backports main non-free-firmware
SOURCES

apt-get update
apt-get install -y --no-install-recommends ca-certificates dpkg-dev xz-utils iucode-tool
sed -i 's#http://#https://#g' /etc/apt/sources.list.d/d630-trixie.list
apt-get update

{
  echo "Target Debian source package: linux=$SOURCE_VERSION"
    echo
  echo "=== APT package candidates ==="
  apt-cache policy linux intel-microcode
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

# Download microcode separately; Debian's native setup target generates the baseline config.
(
  cd "$WORK"
  apt-get download intel-microcode
)
MICROCODE_DEB="$(find "$WORK" -maxdepth 1 -type f -name "intel-microcode_*_amd64.deb" -print -quit)"
test -n "$MICROCODE_DEB" && test -s "$MICROCODE_DEB"
check_field "$MICROCODE_DEB" Package intel-microcode
check_field "$MICROCODE_DEB" Architecture amd64
MICROCODE_VERSION="$(dpkg-deb -f "$MICROCODE_DEB" Version)"

cp "$MICROCODE_DEB" "$OUT/reference/"

mkdir -p "$WORK/microcode-root"
dpkg-deb -x "$MICROCODE_DEB" "$WORK/microcode-root"

# T7250 is CPUID signature 06fd; the matching Linux firmware filename is 06-0f-0d.
MICROCODE_BLOB="$WORK/microcode-root/lib/firmware/intel-ucode/06-0f-0d"
if ! test -s "$MICROCODE_BLOB"; then
  MICROCODE_BLOB="$WORK/microcode-root/usr/lib/firmware/intel-ucode/06-0f-0d"
fi
test -s "$MICROCODE_BLOB" || { echo "Debian intel-microcode package lacks CPUID 06-0f-0d" >&2; exit 1; }
iucode_tool -l "$MICROCODE_BLOB" > "$OUT/metadata/core2-microcode-validation.txt" 2>&1
if ! grep -qiE "0x0*6fd" "$OUT/metadata/core2-microcode-validation.txt"; then
  cat "$OUT/metadata/core2-microcode-validation.txt" >&2
  echo "Microcode blob does not report T7250 CPUID signature 0x06fd" >&2
  exit 1
fi
cp "$MICROCODE_BLOB" "$OUT/microcode/intel-ucode/06-0f-0d"
MICROCODE_DOCS="$WORK/microcode-root/usr/share/doc/intel-microcode"
test -s "$MICROCODE_DOCS/license" || { echo "Intel microcode license file missing" >&2; exit 1; }
cp "$MICROCODE_DOCS/license" "$OUT/microcode/INTEL-MICROCODE-LICENSE.txt"
if test -s "$MICROCODE_DOCS/copyright"; then cp "$MICROCODE_DOCS/copyright" "$OUT/microcode/INTEL-MICROCODE-COPYRIGHT.txt"; fi
{
  echo "Package: intel-microcode=$MICROCODE_VERSION"
  echo "Firmware path: intel-ucode/06-0f-0d"
  echo "Target CPUID signature: 0x000006fd (Intel Core 2 Duo T7250 / Merom M0)"
  echo "Built-in config: CONFIG_EXTRA_FIRMWARE=\"intel-ucode/06-0f-0d\""
  echo "Built-in directory: CONFIG_EXTRA_FIRMWARE_DIR=\"/lib/firmware\""
  sha256sum "$OUT/microcode/intel-ucode/06-0f-0d"
} > "$OUT/microcode/MICROCODE-METADATA.txt"


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
  echo "=== Intel microcode package ==="
  dpkg-deb -f "$MICROCODE_DEB" Package Version Architecture Section Source
  echo "Embedded microcode target file: intel-ucode/06-0f-0d"
  cat "$OUT/microcode/MICROCODE-METADATA.txt"
} > "$OUT/metadata/package-and-config-report.txt"

{
  echo "Prepared at UTC: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "Source package version: $SOURCE_VERSION"
  echo "Intel microcode package: intel-microcode=$MICROCODE_VERSION"
  echo "Intel Core 2 T7250 microcode CPUID 0x06fd: PASS"
  echo "Source package extracted and checked by dpkg-source: PASS"
  echo "No kernel compile, no custom package build, no install, no release."
} > "$OUT/metadata/INPUTS-READY.txt"

(
  cd "$OUT"
  find source reference config microcode -type f -print0 | sort -z | xargs -0 sha256sum > metadata/SHA256SUMS
)

echo "Prepared Debian source and reference inputs:"
find "$OUT" -type f -printf '%P (%s bytes)\n' | sort
echo "No custom kernel was built."
