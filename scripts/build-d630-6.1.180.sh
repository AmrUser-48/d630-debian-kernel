#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_VARIANT="${BUILD_VARIANT:-amd64}"
SOURCE_VERSION="${SOURCE_VERSION:-6.1.180-1}"
BUILD_JOBS="${BUILD_JOBS:-2}"
case "$BUILD_VARIANT" in
  amd64)
    FEATURESET=none
    EXPECTED_RELEASE=6.1.0-52-amd64
    EXPECTED_PACKAGE=linux-image-6.1.0-52-amd64
    SETUP_TARGET=setup_amd64_none_amd64_real_image
    BUILD_TARGET=binary-arch_amd64_none_amd64_real_image
    ;;
  amd64-rt)
    FEATURESET=rt
    EXPECTED_RELEASE=6.1.0-52-rt-amd64
    EXPECTED_PACKAGE=linux-image-6.1.0-52-rt-amd64
    SETUP_TARGET=setup_amd64_rt_amd64_real_image
    BUILD_TARGET=binary-arch_amd64_rt_amd64_real_image
    ;;
  *)
    echo "Unsupported BUILD_VARIANT=$BUILD_VARIANT (expected amd64 or amd64-rt)" >&2
    exit 2
    ;;
esac
[[ "$SOURCE_VERSION" == "6.1.180-1" ]] || {
  echo "This workflow is pinned to linux source 6.1.180-1." >&2
  exit 2
}

WORK="$ROOT/build-work/$BUILD_VARIANT"
AUDIT="$ROOT/audit/$BUILD_VARIANT"
DIST="$ROOT/dist/$BUILD_VARIANT"
INPUTS="$WORK/inputs"
SOURCE="$WORK/linux-source"
BUILD="$SOURCE/debian/build/build_amd64_${FEATURESET}_amd64"
IMAGE_VERSION="${SOURCE_VERSION}+d6301"
SOURCE_BASE="https://security.debian.org/debian-security/pool/updates/main/l/linux"

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C

rm -rf "$WORK" "$AUDIT" "$DIST"
mkdir -p "$WORK" "$AUDIT" "$DIST" "$INPUTS/source"

echo "=== Build contract ==="
printf 'Variant: %s\nFeatureset: %s\nSource: linux=%s\nExpected kernel release: %s\n' \
  "$BUILD_VARIANT" "$FEATURESET" "$SOURCE_VERSION" "$EXPECTED_RELEASE"
echo "Build target: $BUILD_TARGET"

echo "=== Configure signed Debian Bookworm repositories ==="
rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources
cat > /etc/apt/sources.list.d/d630-bookworm.list <<'SOURCES'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
SOURCES
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl dpkg-dev xz-utils zstd lz4 iucode-tool
sed -i 's#http://#https://#g' /etc/apt/sources.list.d/d630-bookworm.list
apt-get update

echo "=== Install kernel build dependencies from current Bookworm metadata ==="
# The exact historical source archive is fetched below. Current Bookworm
# build-dependencies provide the toolchain and libraries for the pinned 6.1 source.
apt-get build-dep -y linux
apt-get install -y --no-install-recommends \
  build-essential gcc-12 g++-12 bc bison flex libelf-dev libssl-dev \
  rsync kmod cpio pahole fakeroot quilt debhelper python3 python3-dev \
  python3-ply python3-setuptools perl file zstd lz4 xz-utils \
  ca-certificates curl dpkg-dev iucode-tool
apt-get clean

echo "=== Download the exact Debian linux 6.1.180-1 source archives ==="
for file in linux_6.1.180-1.dsc linux_6.1.180.orig.tar.xz linux_6.1.180-1.debian.tar.xz; do
  curl --fail --location --retry 3 --retry-delay 2 "$SOURCE_BASE/$file" -o "$INPUTS/source/$file"
  test -s "$INPUTS/source/$file"
done
dpkg-source -x "$INPUTS/source/linux_6.1.180-1.dsc" "$SOURCE" \
  > "$AUDIT/source-extraction.log" 2>&1
ACTUAL_SOURCE_VERSION="$(dpkg-parsechangelog -l "$SOURCE/debian/changelog" -S Version)"
test "$ACTUAL_SOURCE_VERSION" = "$SOURCE_VERSION" || {
  echo "Expected source version $SOURCE_VERSION, got $ACTUAL_SOURCE_VERSION" >&2
  exit 1
}
printf 'Verified Debian source version: %s\n' "$ACTUAL_SOURCE_VERSION" | tee "$AUDIT/source-version.txt"

echo "=== Download Intel CPU microcode and Intel 3945ABG firmware ==="
(
  cd "$INPUTS"
  apt-get download intel-microcode firmware-iwlwifi
)
MICROCODE_DEB="$(find "$INPUTS" -maxdepth 1 -type f -name 'intel-microcode_*_amd64.deb' -print -quit)"
WIFI_DEB="$(find "$INPUTS" -maxdepth 1 -type f -name 'firmware-iwlwifi_*_all.deb' -print -quit)"
test -s "$MICROCODE_DEB"
test -s "$WIFI_DEB"
mkdir -p "$INPUTS/microcode-root" "$INPUTS/wifi-root"
dpkg-deb -x "$MICROCODE_DEB" "$INPUTS/microcode-root"
dpkg-deb -x "$WIFI_DEB" "$INPUTS/wifi-root"
MICROCODE_FILE="$(find "$INPUTS/microcode-root" -type f -path '*/intel-ucode/06-0f-0d' -print -quit)"
WIFI_FIRMWARE_FILE="$(find "$INPUTS/wifi-root" -type f -name 'iwlwifi-3945-2.ucode' -print -quit)"
test -s "$MICROCODE_FILE" || { echo "Intel T7250 microcode 06-0f-0d missing" >&2; exit 1; }
test -s "$WIFI_FIRMWARE_FILE" || { echo "Intel 3945ABG firmware iwlwifi-3945-2.ucode missing" >&2; exit 1; }
iucode_tool -l "$MICROCODE_FILE" > "$AUDIT/core2-microcode-validation.txt" 2>&1
grep -qiE '0x0*6fd' "$AUDIT/core2-microcode-validation.txt" || {
  cat "$AUDIT/core2-microcode-validation.txt" >&2
  echo "Microcode does not contain T7250 CPUID signature 0x000006fd" >&2
  exit 1
}
mkdir -p /lib/firmware/intel-ucode
install -m 0644 "$MICROCODE_FILE" /lib/firmware/intel-ucode/06-0f-0d
install -m 0644 "$WIFI_FIRMWARE_FILE" /lib/firmware/iwlwifi-3945-2.ucode
cp "$MICROCODE_FILE" "$INPUTS/06-0f-0d"
cp "$WIFI_FIRMWARE_FILE" "$INPUTS/iwlwifi-3945-2.ucode"
cp "$MICROCODE_DEB" "$DIST/"
cp "$WIFI_DEB" "$DIST/"
MICROCODE_DOCS="$INPUTS/microcode-root/usr/share/doc/intel-microcode"
MICROCODE_COPYRIGHT="$(find "$MICROCODE_DOCS" -maxdepth 1 -type f -iname copyright -print -quit)"
MICROCODE_LICENSE="$(find "$MICROCODE_DOCS" -maxdepth 1 -type f -iname license -print -quit)"
test -s "$MICROCODE_COPYRIGHT" || { echo "Intel microcode copyright notice missing" >&2; exit 1; }
cp "$MICROCODE_COPYRIGHT" "$DIST/INTEL-MICROCODE-COPYRIGHT.txt"
if [[ -n "$MICROCODE_LICENSE" && -s "$MICROCODE_LICENSE" ]]; then
  cp "$MICROCODE_LICENSE" "$DIST/INTEL-MICROCODE-LICENSE.txt"
fi

echo "=== Generate the matching Debian native image configuration ==="
if ! id builder >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash builder
fi
chown -R builder:builder "$WORK" "$AUDIT"
runuser -u builder -- env DEB_RULES_REQUIRES_ROOT=no \
  make -C "$SOURCE" -f debian/rules.gen "$SETUP_TARGET"
test -s "$BUILD/.config" || {
  find "$SOURCE/debian/build" -maxdepth 5 -type f -name .config -print >&2 || true
  echo "Debian setup target did not create $BUILD/.config" >&2
  exit 1
}
cp "$BUILD/.config" "$AUDIT/debian-baseline.config"
chown builder:builder "$AUDIT/debian-baseline.config"

echo "=== Apply the audited D630 overlay to only the requested image target ==="
runuser -u builder -- python3 "$ROOT/scripts/apply-d630-6.1.180-policy.py" \
  "$SOURCE" "$AUDIT" "$ROOT/config/d630-core2-6.1.180.config" "$FEATURESET"
(
  cd "$SOURCE"
  runuser -u builder -- "$SOURCE/scripts/kconfig/merge_config.sh" -m -O "$BUILD" \
    "$AUDIT/debian-baseline.config" "$SOURCE/debian/config/d630-core2-6.1.180.config"
) > "$AUDIT/kconfig-merge.log" 2>&1
runuser -u builder -- make -C "$SOURCE" O="$BUILD" ARCH=x86 olddefconfig 2>&1 | tee "$AUDIT/kconfig-olddefconfig.log"
if grep -Ein 'warning: override:' "$AUDIT/kconfig-olddefconfig.log"; then
  echo "FAIL: Kconfig emitted override warnings during olddefconfig; refusing to compile." >&2
  exit 1
fi
cp "$BUILD/.config" "$AUDIT/preflight-final.config"
python3 "$ROOT/scripts/audit-d630-6.1.180.py" \
  "$AUDIT/debian-baseline.config" "$BUILD/.config" \
  "$SOURCE/debian/config/d630-core2-6.1.180.config" "$AUDIT" "$BUILD_VARIANT"

echo "=== Build only Debian's native runtime image target ==="
runuser -u builder -- env \
  DEB_RULES_REQUIRES_ROOT=no \
  DEB_BUILD_OPTIONS="parallel=$BUILD_JOBS noautodbgsym" \
  MAKEFLAGS="-j$BUILD_JOBS" \
  KCFLAGS="-mtune=core2" \
  make -C "$SOURCE" -f debian/rules.gen "$BUILD_TARGET" \
  2>&1 | tee "$AUDIT/native-image-build.log"
if grep -Ein 'warning: override:' "$AUDIT/native-image-build.log"; then
  echo "FAIL: Kconfig emitted override warnings during the native build; refusing to package." >&2
  exit 1
fi

echo "=== Audit the actual post-build config and both embedded firmware blobs ==="
test -s "$BUILD/.config"
cp "$BUILD/.config" "$AUDIT/d630-final.config"
python3 "$ROOT/scripts/audit-d630-6.1.180.py" \
  "$AUDIT/debian-baseline.config" "$BUILD/.config" \
  "$SOURCE/debian/config/d630-core2-6.1.180.config" "$AUDIT" "$BUILD_VARIANT"
test -s "$BUILD/vmlinux" || {
  find "$SOURCE/debian/build" -maxdepth 5 -type f -name vmlinux -print >&2 || true
  echo "Uncompressed vmlinux missing after native build" >&2
  exit 1
}
python3 - "$BUILD/vmlinux" "$INPUTS/06-0f-0d" "$INPUTS/iwlwifi-3945-2.ucode" <<'PY'
from pathlib import Path
import hashlib
import sys

image = Path(sys.argv[1]).read_bytes()
for firmware in map(Path, sys.argv[2:]):
    blob = firmware.read_bytes()
    if image.find(blob) < 0:
        raise SystemExit(f"FAIL: firmware {firmware.name} is not embedded in vmlinux")
    print(f"PASS: embedded {firmware.name}; sha256={hashlib.sha256(blob).hexdigest()}")
PY

echo "=== Find and repackage the unsigned runtime image with a distinct upgrade version ==="
mapfile -t CANDIDATES < <(
  find "$WORK" -type f -name "linux-image-$EXPECTED_RELEASE-unsigned_*.deb" -print | sort
)
if (( ${#CANDIDATES[@]} != 1 )); then
  echo "Expected exactly one Debian unsigned runtime package for $EXPECTED_RELEASE; found ${#CANDIDATES[@]}." >&2
  find "$WORK" -type f -name 'linux-image*.deb' -printf '%p\n' >&2 || true
  exit 1
fi
PACKAGE="${CANDIDATES[0]}"
OLD_PACKAGE="$(dpkg-deb -f "$PACKAGE" Package)"
PACKAGE_VERSION="$(dpkg-deb -f "$PACKAGE" Version)"
PACKAGE_ARCH="$(dpkg-deb -f "$PACKAGE" Architecture)"
test "$OLD_PACKAGE" = "linux-image-$EXPECTED_RELEASE-unsigned"
test "$PACKAGE_VERSION" = "$SOURCE_VERSION" || {
  echo "Expected source binary version $SOURCE_VERSION; got $PACKAGE_VERSION" >&2
  exit 1
}
test "$PACKAGE_ARCH" = amd64
REPACK="$WORK/repack"
rm -rf "$REPACK"
mkdir -p "$REPACK"
dpkg-deb -R "$PACKAGE" "$REPACK"
NEW_PACKAGE="$EXPECTED_PACKAGE"
python3 - "$REPACK/DEBIAN/control" "$OLD_PACKAGE" "$NEW_PACKAGE" "$IMAGE_VERSION" "$BUILD_VARIANT" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
old, new, version, variant = sys.argv[2:]
text = path.read_text(encoding="utf-8")
def set_field(name: str, value: str) -> None:
    global text
    pattern = re.compile(r"(?m)^" + re.escape(name) + r":[^\n]*(?:\n[ \t][^\n]*)*")
    text, count = pattern.subn(name + ": " + value, text, count=1)
    if count != 1:
        raise SystemExit(f"Could not update control field {name}")
set_field("Package", new)
set_field("Version", version)
set_field(
    "Description",
    f"Stripped Debian 12 Linux kernel image for Dell Latitude D630 / Intel Core 2 ({variant}); custom unsigned build from linux 6.1.180-1.",
)
# Remove self-conflicting clauses from the Debian unsigned/signed transition.
for field in ("Conflicts", "Breaks", "Replaces"):
    pattern = re.compile(r"(?ms)^" + re.escape(field) + r":([^\n]*(?:\n[ \t][^\n]*)*)\n?")
    match = pattern.search(text)
    if not match:
        continue
    value = match.group(1).replace("\n", " ")
    kept = []
    for clause in value.split(","):
        clause = clause.strip()
        if not clause:
            continue
        package = re.split(r"[\s(]", clause, maxsplit=1)[0]
        if package in {old, new}:
            continue
        kept.append(clause)
    replacement = (field + ": " + ", ".join(kept) + "\n") if kept else ""
    text = text[:match.start()] + replacement + text[match.end():]
path.write_text(text.rstrip() + "\n", encoding="utf-8")
PY

OLD_DOC="$REPACK/usr/share/doc/$OLD_PACKAGE"
NEW_DOC="$REPACK/usr/share/doc/$NEW_PACKAGE"
if [[ -L "$OLD_DOC" ]]; then
  rm -f "$OLD_DOC"
elif [[ -d "$OLD_DOC" ]]; then
  mv "$OLD_DOC" "$NEW_DOC"
fi
mkdir -p "$NEW_DOC"
cp "$MICROCODE_COPYRIGHT" "$NEW_DOC/INTEL-MICROCODE-COPYRIGHT.txt"
if [[ -n "$MICROCODE_LICENSE" && -s "$MICROCODE_LICENSE" ]]; then
  cp "$MICROCODE_LICENSE" "$NEW_DOC/INTEL-MICROCODE-LICENSE.txt"
fi
for file in "$REPACK"/DEBIAN/*; do
  [[ -f "$file" && "$file" != "$REPACK/DEBIAN/control" && "$file" != "$REPACK/DEBIAN/md5sums" ]] || continue
  sed -i "s/$OLD_PACKAGE/$NEW_PACKAGE/g" "$file"
done
(
  cd "$REPACK"
  find . -type f ! -path './DEBIAN/*' -print0 | sort -z \
    | xargs -0 -r md5sum | sed 's#  \./#  #' > DEBIAN/md5sums
)
test -s "$REPACK/boot/vmlinuz-$EXPECTED_RELEASE" || {
  echo "Package lacks /boot/vmlinuz-$EXPECTED_RELEASE" >&2
  find "$REPACK/boot" -maxdepth 1 -type f -printf '%f\n' >&2 || true
  exit 1
}
test -d "$REPACK/lib/modules/$EXPECTED_RELEASE" || {
  echo "Package lacks /lib/modules/$EXPECTED_RELEASE" >&2
  find "$REPACK/lib/modules" -maxdepth 2 -type d -print >&2 || true
  exit 1
}

require_module() {
  local module="$1" symbol="$2"
  if [[ "$(grep -E "^CONFIG_$symbol=m$" "$BUILD/.config" || true)" ]]; then
    find "$REPACK/lib/modules/$EXPECTED_RELEASE" -type f -name "$module.ko*" -print -quit | grep -q . || {
      echo "Required module $module.ko* missing although CONFIG_$symbol=m" >&2
      exit 1
    }
  fi
}
require_module iwl3945 IWL3945
require_module snd-hda-intel SND_HDA_INTEL
require_module snd-hda-codec-idt SND_HDA_CODEC_SIGMATEL
require_module psmouse MOUSE_PS2
require_module i915 DRM_I915

DEB_NAME="$NEW_PACKAGE"_"$IMAGE_VERSION"_amd64.deb
DEB_OUTPUT="$DIST/$DEB_NAME"
dpkg-deb --build --root-owner-group "$REPACK" "$DEB_OUTPUT"
test "$(dpkg-deb -f "$DEB_OUTPUT" Package)" = "$NEW_PACKAGE"
test "$(dpkg-deb -f "$DEB_OUTPUT" Version)" = "$IMAGE_VERSION"
test "$(dpkg-deb -f "$DEB_OUTPUT" Architecture)" = amd64

cp "$AUDIT/d630-final.config" "$DIST/D630-FINAL-CONFIG"
cp "$AUDIT/d630-config.diff" "$DIST/D630-CONFIG-DIFF.txt"
cp "$AUDIT/d630-config-symbol-audit.tsv" "$DIST/D630-CONFIG-AUDIT.tsv"
cp "$AUDIT/config-audit-summary.txt" "$DIST/CONFIG-AUDIT-SUMMARY.txt"
cp "$AUDIT/unclassified-module-drops.txt" "$DIST/UNCLASSIFIED-MODULE-DROPS.txt"
cp "$AUDIT/policy-disabled-symbols.tsv" "$DIST/POLICY-DISABLED-SYMBOLS.tsv"
cp "$INPUTS/06-0f-0d" "$DIST/INTEL-CORE2-MICROCODE-06-0F-0D"
cp "$INPUTS/iwlwifi-3945-2.ucode" "$DIST/IWLWIFI-3945-2.UCODE"
cp "$AUDIT/core2-microcode-validation.txt" "$DIST/MICROCODE-VALIDATION.txt"
dpkg-deb -f "$DEB_OUTPUT" Package Version Architecture Depends > "$DIST/KERNEL-PACKAGE-METADATA.txt"

cat > "$DIST/D630-FIRMWARE-REQUIREMENTS.txt" <<EOF
Target: Dell Latitude D630 / Intel Core 2 Duo T7250 / Intel GM965 GMA X3100.
Intel PRO/Wireless 3945ABG: iwlwifi-3945-2.ucode is embedded in the kernel and the official firmware-iwlwifi Debian package is included alongside it.
CPU microcode: Intel CPUID 0x000006fd blob intel-ucode/06-0f-0d is embedded in the kernel.
Graphics: Intel GM965/GMA X3100 uses the legacy i915 driver; this generation does not require separate i915 DMC/GuC/HuC firmware on this kernel.
Audio: Intel ICH8 HD Audio with Sigmatel/IDT codec uses the Linux HDA driver; no separate codec firmware is required by this configuration.
Package version: $IMAGE_VERSION
Kernel release: $EXPECTED_RELEASE
Kernel package is a custom unsigned rebuild; it is not signed by Debian's kernel signing keys.
EOF

cat > "$DIST/RELEASE-NOTES.md" <<EOF
# D630 stripped Debian 12 kernel — $BUILD_VARIANT

- Debian Linux source package: $SOURCE_VERSION, fetched from the official Debian security source pool and verified by dpkg-source checksums.
- Kernel release: $EXPECTED_RELEASE.
- Binary package: $NEW_PACKAGE, version $IMAGE_VERSION, amd64.
- CPU target: Intel Core 2 Duo T7250, selected through CONFIG_MCORE2.
- Built-in: zram (default LZ4, with LZO-RLE, Zstd, LZ4, LZO, LZ4HC and 842 compressors enabled); ext4, Btrfs, NTFS3, FAT/VFAT/exFAT, UDF and SquashFS with zlib/LZ4/LZO/XZ/Zstd support; MSR and CPUID; early Intel CPU microcode and Intel 3945ABG firmware.
- Loadable D630 drivers retained: Intel i915 where Debian's baseline selects it as a module, Intel 3945ABG Wi-Fi, Intel HDA/Sigmatel audio and PS/2 touchpad.
- The RT flavour is built using Debian's native RT featureset and is audited for PREEMPT_RT.
- The official firmware-iwlwifi and intel-microcode .debs plus the final config and audit reports accompany the image.
- The kernel image package is custom and unsigned by Debian. On this legacy-BIOS D630, keep a known-good boot entry before installing.
- Hosted CI validates build/package/configuration only; boot and hardware behaviour still require testing on the actual D630.
EOF

{
  echo "Build status: PASS"
  echo "Debian source package: linux=$SOURCE_VERSION"
  echo "Variant: $BUILD_VARIANT (featureset $FEATURESET)"
  echo "Kernel release: $EXPECTED_RELEASE"
  echo "Package: $(dpkg-deb -f "$DEB_OUTPUT" Package)"
  echo "Version: $(dpkg-deb -f "$DEB_OUTPUT" Version)"
  echo "Architecture: $(dpkg-deb -f "$DEB_OUTPUT" Architecture)"
  echo "Default zram compressor: LZ4; all Linux 6.1 zram compressors enabled"
  echo "Filesystems: ext4, Btrfs, NTFS3, FAT/VFAT/exFAT, UDF and SquashFS with zlib/LZ4/LZO/XZ/Zstd"
  echo "Embedded firmware: Intel T7250 microcode and Intel 3945ABG firmware"
  echo "GPU/audio firmware: not required for GM965/i915 + ICH8/Sigmatel on this target"
  echo "Package is custom unsigned; Debian's signed kernel package was not modified."
  echo "Kernel package SHA256: $(sha256sum "$DEB_OUTPUT" | awk '{print $1}')"
} > "$DIST/BUILD-REPORT.txt"
(
  cd "$DIST"
  find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 -r sha256sum > SHA256SUMS
  sha256sum -c SHA256SUMS
)

echo "=== Build and package validation complete ==="
cat "$DIST/BUILD-REPORT.txt"
printf '\nRelease payloads for %s:\n' "$BUILD_VARIANT"
find "$DIST" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
