#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_VARIANT="${BUILD_VARIANT:-amd64}"
SOURCE_VERSION="${SOURCE_VERSION:-6.12.95-1~bpo12+1}"
BUILD_JOBS="${BUILD_JOBS:-2}"

case "$BUILD_VARIANT" in
  amd64)
    FEATURESET=none
    EXPECTED_RELEASE="6.12.95+deb12-amd64"
    EXPECTED_PACKAGE="linux-image-6.12.95+deb12-amd64"
    SETUP_TARGET=setup_amd64_none_amd64
    BUILD_TARGET=binary-arch_amd64_none_amd64_image
    ;;
  amd64-rt)
    FEATURESET=rt
    EXPECTED_RELEASE="6.12.95+deb12-rt-amd64"
    EXPECTED_PACKAGE="linux-image-6.12.95+deb12-rt-amd64"
    SETUP_TARGET=setup_amd64_rt_amd64
    BUILD_TARGET=binary-arch_amd64_rt_amd64_image
    ;;
  *)
    echo "Unsupported BUILD_VARIANT=$BUILD_VARIANT (use amd64 or amd64-rt)." >&2
    exit 2
    ;;
esac

[[ "$SOURCE_VERSION" == "6.12.95-1~bpo12+1" ]] || {
  echo "This workflow is pinned to Debian 12 Bookworm-backports linux $SOURCE_VERSION." >&2
  exit 2
}

WORK="$ROOT/build-work/$BUILD_VARIANT"
AUDIT="$ROOT/audit/$BUILD_VARIANT"
DIST="$ROOT/dist/$BUILD_VARIANT"
INPUTS="$WORK/inputs"
SOURCE="$WORK/linux-source"
BUILD="$SOURCE/debian/build/build_amd64_${FEATURESET}_amd64"
IMAGE_VERSION="${SOURCE_VERSION}+d6301"

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C

rm -rf "$WORK" "$AUDIT" "$DIST"
mkdir -p "$WORK" "$AUDIT" "$DIST" "$INPUTS/source"

echo "=== Build contract ==="
printf 'Variant: %s\nFeatureset: %s\nSource package: linux=%s\nExpected release: %s\n' \
  "$BUILD_VARIANT" "$FEATURESET" "$SOURCE_VERSION" "$EXPECTED_RELEASE"
printf 'Native setup target: %s\nNative image target: %s\n' "$SETUP_TARGET" "$BUILD_TARGET"
printf 'Custom binary version: %s\n' "$IMAGE_VERSION"

echo "=== Configure Debian Bookworm and Bookworm-backports repositories ==="
rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources
cat > /etc/apt/sources.list.d/d630-bookworm.list <<'SOURCES'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware
deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
SOURCES

# Bootstrap only the CA bundle over HTTP. APT still authenticates Debian's
# InRelease metadata using its trusted archive keyring. All later traffic uses HTTPS.
apt-get update
apt-get install -y --no-install-recommends ca-certificates
sed -i 's#http://#https://#g' /etc/apt/sources.list.d/d630-bookworm.list
apt-get update
apt-get install -y --no-install-recommends curl dpkg-dev xz-utils zstd lz4 iucode-tool
apt-get update
echo "=== Install build dependencies for the exact backported source version ==="
apt-get build-dep -y -t bookworm-backports "linux=$SOURCE_VERSION"
apt-get install -y --no-install-recommends \
  build-essential gcc-12 g++-12 bc bison flex libelf-dev libssl-dev \
  rsync kmod cpio pahole fakeroot quilt debhelper python3 python3-dev \
  python3-ply python3-setuptools perl file zstd lz4 xz-utils \
  ca-certificates curl dpkg-dev iucode-tool
apt-get clean

echo "=== Download and validate exact Debian Bookworm-backports source ==="
(
  cd "$INPUTS/source"
  apt-get source --download-only -t bookworm-backports "linux=$SOURCE_VERSION"
)
DSC="$INPUTS/source/linux_6.12.95-1~bpo12+1.dsc"
test -s "$DSC" || {
  find "$INPUTS/source" -maxdepth 1 -type f -printf '%f\n' >&2
  echo "Debian source descriptor was not downloaded." >&2
  exit 1
}
dpkg-source -x "$DSC" "$SOURCE" > "$AUDIT/source-extraction.log" 2>&1
ACTUAL_SOURCE_VERSION="$(dpkg-parsechangelog -l "$SOURCE/debian/changelog" -S Version)"
test "$ACTUAL_SOURCE_VERSION" = "$SOURCE_VERSION" || {
  echo "Source version mismatch: expected $SOURCE_VERSION, got $ACTUAL_SOURCE_VERSION" >&2
  exit 1
}
{
  echo "Source package: linux"
  echo "Source version: $ACTUAL_SOURCE_VERSION"
  echo "Source descriptor: $DSC"
  echo "Source descriptor checksums: validated by dpkg-source -x"
  echo "Suite: Debian 12 Bookworm-backports"
} | tee "$AUDIT/source-version.txt"

echo "=== Download target firmware and Intel microcode ==="
(
  cd "$INPUTS"
  apt-get download intel-microcode firmware-iwlwifi
)
MICROCODE_DEB="$(find "$INPUTS" -maxdepth 1 -type f -name 'intel-microcode_*_amd64.deb' -print -quit)"
WIFI_DEB="$(find "$INPUTS" -maxdepth 1 -type f -name 'firmware-iwlwifi_*_all.deb' -print -quit)"
test -s "$MICROCODE_DEB" || { echo "intel-microcode .deb is missing." >&2; exit 1; }
test -s "$WIFI_DEB" || { echo "firmware-iwlwifi .deb is missing." >&2; exit 1; }

mkdir -p "$INPUTS/microcode-root" "$INPUTS/wifi-root"
dpkg-deb -x "$MICROCODE_DEB" "$INPUTS/microcode-root"
dpkg-deb -x "$WIFI_DEB" "$INPUTS/wifi-root"
MICROCODE_FILE="$(find "$INPUTS/microcode-root" -type f -path '*/intel-ucode/06-0f-0d' -print -quit)"
WIFI_FIRMWARE_FILE="$(find "$INPUTS/wifi-root" -type f -name 'iwlwifi-3945-2.ucode' -print -quit)"
test -s "$MICROCODE_FILE" || { echo "T7250 microcode intel-ucode/06-0f-0d is missing." >&2; exit 1; }
test -s "$WIFI_FIRMWARE_FILE" || { echo "Intel 3945ABG firmware iwlwifi-3945-2.ucode is missing." >&2; exit 1; }

iucode_tool -l "$MICROCODE_FILE" > "$AUDIT/core2-microcode-validation.txt" 2>&1
if ! grep -qiE '0x0*6fd' "$AUDIT/core2-microcode-validation.txt"; then
  cat "$AUDIT/core2-microcode-validation.txt" >&2
  echo "The microcode blob does not list T7250 CPUID signature 0x000006fd." >&2
  exit 1
fi

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
test -s "$MICROCODE_COPYRIGHT" || { echo "Microcode copyright notice missing." >&2; exit 1; }
cp "$MICROCODE_COPYRIGHT" "$DIST/INTEL-MICROCODE-COPYRIGHT.txt"
if [[ -n "$MICROCODE_LICENSE" && -s "$MICROCODE_LICENSE" ]]; then
  cp "$MICROCODE_LICENSE" "$DIST/INTEL-MICROCODE-LICENSE.txt"
fi

echo "=== Generate Debian's native configuration for the selected feature set ==="
if ! id builder >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash builder
fi
chown -R builder:builder "$WORK" "$AUDIT"
runuser -u builder -- env DEB_RULES_REQUIRES_ROOT=no \
  make -C "$SOURCE" -f debian/rules.gen "$SETUP_TARGET"
test -s "$BUILD/.config" || {
  find "$SOURCE/debian/build" -maxdepth 5 -type f -name .config -print >&2 || true
  echo "Debian setup target did not create $BUILD/.config." >&2
  exit 1
}
cp "$BUILD/.config" "$AUDIT/debian-baseline.config"
chown builder:builder "$AUDIT/debian-baseline.config"

echo "=== Apply the D630 policy to only the selected native image target ==="
runuser -u builder -- python3 "$ROOT/scripts/apply-d630-6.12.95-policy.py" \
  "$SOURCE" "$AUDIT" "$ROOT/config/d630-core2-6.12.95.config" "$FEATURESET"

echo "=== Resolve Kconfig dependencies and validate the final .config ==="
runuser -u builder -- make -C "$SOURCE" O="$BUILD" ARCH=x86 olddefconfig \
  2>&1 | tee "$AUDIT/olddefconfig.log"
if grep -Eiq 'warning:|changes choice state|reassigning to symbol|trying to assign nonexistent symbol' "$AUDIT/olddefconfig.log"; then
  echo "Unexpected Kconfig override/choice warning; refuse to compile." >&2
  cat "$AUDIT/olddefconfig.log" >&2
  exit 1
fi
cp "$BUILD/.config" "$AUDIT/preflight-final.config"
python3 "$ROOT/scripts/audit-d630-6.12.95.py" \
  "$AUDIT/debian-baseline.config" "$BUILD/.config" \
  "$ROOT/config/d630-core2-6.12.95.config" "$AUDIT" "$BUILD_VARIANT"

echo "=== Build only the native Debian runtime image target ==="
runuser -u builder -- env \
  DEB_RULES_REQUIRES_ROOT=no \
  DEB_BUILD_OPTIONS="parallel=$BUILD_JOBS noautodbgsym" \
  MAKEFLAGS="-j$BUILD_JOBS" \
  make -C "$SOURCE" -f debian/rules.gen "$BUILD_TARGET" \
  2>&1 | tee "$AUDIT/native-image-build.log"

echo "=== Re-audit the final config and verify firmware was built into vmlinux ==="
test -s "$BUILD/.config"
cp "$BUILD/.config" "$AUDIT/d630-final.config"
python3 "$ROOT/scripts/audit-d630-6.12.95.py" \
  "$AUDIT/debian-baseline.config" "$BUILD/.config" \
  "$ROOT/config/d630-core2-6.12.95.config" "$AUDIT" "$BUILD_VARIANT"
test -s "$BUILD/vmlinux" || {
  find "$SOURCE/debian/build" -maxdepth 6 -type f -name vmlinux -print >&2 || true
  echo "Uncompressed vmlinux was not found after the image build." >&2
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
        raise SystemExit(f"FAIL: {firmware.name} is not embedded in vmlinux")
    print(f"PASS: embedded {firmware.name}; sha256={hashlib.sha256(blob).hexdigest()}")
PY

echo "=== Find the exact unsigned kernel image package emitted by Debian ==="
mapfile -t CANDIDATES < <(
  find "$WORK" -type f -name "linux-image-$EXPECTED_RELEASE-unsigned_*.deb" -print | sort
)
if (( ${#CANDIDATES[@]} != 1 )); then
  echo "Expected exactly one unsigned package for $EXPECTED_RELEASE; found ${#CANDIDATES[@]}." >&2
  find "$WORK" -type f -name 'linux-image*.deb' -printf '%p\n' >&2 || true
  exit 1
fi
PACKAGE="${CANDIDATES[0]}"
OLD_PACKAGE="$(dpkg-deb -f "$PACKAGE" Package)"
PACKAGE_VERSION="$(dpkg-deb -f "$PACKAGE" Version)"
PACKAGE_ARCH="$(dpkg-deb -f "$PACKAGE" Architecture)"
test "$OLD_PACKAGE" = "linux-image-$EXPECTED_RELEASE-unsigned" || {
  echo "Unexpected image package name: $OLD_PACKAGE" >&2
  exit 1
}
test "$PACKAGE_VERSION" = "$SOURCE_VERSION" || {
  echo "Expected source binary version $SOURCE_VERSION; got $PACKAGE_VERSION." >&2
  exit 1
}
test "$PACKAGE_ARCH" = amd64

echo "=== Repackage the runtime image with an identifiable version ==="
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
        raise SystemExit(f"Could not update package control field {name}")

set_field("Package", new)
set_field("Version", version)
set_field(
    "Description",
    f"Stripped Debian 12 Bookworm-backports kernel for Dell Latitude D630 / Intel Core 2 ({variant}); Linux 6.12.95.",
)

# Avoid self-conflicts after replacing Debian's unsigned binary package name
# with the installable package name. Keep unrelated package constraints intact.
for field in ("Conflicts", "Breaks", "Replaces"):
    pattern = re.compile(r"(?ms)^" + re.escape(field) + r":([^\n]*(?:\n[ \t][^\n]*)*)\n?")
    match = pattern.search(text)
    if not match:
        continue
    raw_value = match.group(1).replace("\n", " ")
    kept = []
    for clause in raw_value.split(","):
        clause = clause.strip()
        if not clause:
            continue
        package = re.split(r"[\s(]", clause, maxsplit=1)[0]
        if package in {old, new}:
            continue
        kept.append(clause)
    replacement = field + ": " + ", ".join(kept) + "\n" if kept else ""
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
  echo "Package does not contain /boot/vmlinuz-$EXPECTED_RELEASE." >&2
  find "$REPACK/boot" -maxdepth 1 -type f -printf '%f\n' >&2 || true
  exit 1
}
test -d "$REPACK/lib/modules/$EXPECTED_RELEASE" || {
  echo "Package does not contain /lib/modules/$EXPECTED_RELEASE." >&2
  find "$REPACK/lib/modules" -maxdepth 2 -type d -print >&2 || true
  exit 1
}

require_module() {
  local module="$1" symbol="$2"
  if grep -qx "CONFIG_$symbol=m" "$BUILD/.config"; then
    find "$REPACK/lib/modules/$EXPECTED_RELEASE" -type f -name "$module.ko*" -print -quit | grep -q . || {
      echo "Required module $module.ko* missing while CONFIG_$symbol=m." >&2
      exit 1
    }
  fi
}
require_module cfg80211 CFG80211
require_module mac80211 MAC80211
require_module iwlegacy IWLEGACY
require_module iwl3945 IWL3945
require_module snd-hda-intel SND_HDA_INTEL
require_module snd-hda-codec-idt SND_HDA_CODEC_SIGMATEL
require_module psmouse MOUSE_PS2
if [[ "$(grep -E '^CONFIG_DRM_I915=m$' "$BUILD/.config" || true)" ]]; then
  require_module i915 DRM_I915
fi

DEB_NAME="${NEW_PACKAGE}_${IMAGE_VERSION}_amd64.deb"
DEB_OUTPUT="$DIST/$DEB_NAME"
dpkg-deb --build --root-owner-group "$REPACK" "$DEB_OUTPUT"
test "$(dpkg-deb -f "$DEB_OUTPUT" Package)" = "$NEW_PACKAGE"
test "$(dpkg-deb -f "$DEB_OUTPUT" Version)" = "$IMAGE_VERSION"
test "$(dpkg-deb -f "$DEB_OUTPUT" Architecture)" = amd64
dpkg-deb -I "$DEB_OUTPUT" control >/dev/null
dpkg-deb -c "$DEB_OUTPUT" >/dev/null

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
Intel PRO/Wireless 3945ABG: iwlwifi-3945-2.ucode is embedded in the kernel. The official firmware-iwlwifi Debian package accompanies the image for future updates.
CPU microcode: Intel CPUID 0x000006fd blob intel-ucode/06-0f-0d is embedded in the kernel.
Graphics: GM965/GMA X3100 uses the legacy i915 driver; no separate DMC/GuC/HuC firmware is required for this GPU generation on Linux 6.12.
Audio: Intel ICH8 HD Audio/SigmaTel codec uses the Linux HDA driver; no separate firmware file is needed for this codec.
Kernel release: $EXPECTED_RELEASE
Package version: $IMAGE_VERSION
The image package is custom and unsigned by Debian's kernel signing keys.
EOF

cat > "$DIST/RELEASE-NOTES.md" <<EOF
# D630 stripped Debian 12 Bookworm-backports kernel — $BUILD_VARIANT

- Source: Debian Bookworm-backports \`linux=6.12.95-1~bpo12+1\`, verified by \`dpkg-source\`.
- Kernel release: \`$EXPECTED_RELEASE\`.
- Binary package: \`$NEW_PACKAGE\`, version \`$IMAGE_VERSION\`, architecture amd64.
- CPU: Core 2 Duo T7250; \`CONFIG_MCORE2=y\`, MSR and CPUID enabled. No runner-native ISA flags.
- Filesystems: built-in ext4, Btrfs, NTFS3, FAT/MS-DOS/VFAT, exFAT, UDF and SquashFS; ISO9660 remains a module. SquashFS supports zlib, LZ4, LZO, XZ and Zstd.
- zram: built in, LZ4 default, with LZO-RLE/LZO, Zstd, LZ4, LZ4HC, DEFLATE and 842 compressors enabled.
- Embedded firmware: Intel T7250 microcode and the exact Intel PRO/Wireless 3945ABG firmware. Official \`intel-microcode\` and \`firmware-iwlwifi\` packages are also included.
- Retained hardware: Intel i915/AGP at Debian's native baseline values; Intel 3945ABG Wi-Fi, Intel HDA/SigmaTel audio and PS/2 touchpad modules verified where configured as modules; SATA/ATAPI and USB mass storage retained.
- RT variant is built using Debian's native \`rt\` feature set and must pass the \`CONFIG_PREEMPT_RT=y\` audit.
- Custom image is unsigned by Debian's kernel signing keys. Keep a known-good kernel and initramfs boot entry until this package has been tested on the physical D630.
- Hosted CI verifies the source, build, package contents, config and checksums. It cannot prove hardware boot or behavior.
EOF

{
  echo "Build status: PASS"
  echo "Debian source package: linux=$SOURCE_VERSION (Bookworm-backports)"
  echo "Variant: $BUILD_VARIANT (featureset $FEATURESET)"
  echo "Kernel release: $EXPECTED_RELEASE"
  echo "Package: $(dpkg-deb -f "$DEB_OUTPUT" Package)"
  echo "Package version: $(dpkg-deb -f "$DEB_OUTPUT" Version)"
  echo "Architecture: $(dpkg-deb -f "$DEB_OUTPUT" Architecture)"
  echo "zram default compressor: LZ4; all Linux 6.12 compressors enabled"
  echo "Filesystems: ext4, Btrfs, NTFS3, FAT/VFAT/exFAT, UDF and SquashFS (zlib/LZ4/LZO/XZ/Zstd)"
  echo "Embedded firmware: Intel Core 2 microcode and Intel 3945ABG firmware"
  echo "Graphics/audio: Debian i915 baseline and HDA/SigmaTel stack verified; no separate firmware needed for GM965/HDA codec"
  echo "Custom image is unsigned by Debian's kernel signing keys."
  echo "Kernel package SHA256: $(sha256sum "$DEB_OUTPUT" | awk '{print $1}')"
} > "$DIST/BUILD-REPORT.txt"

(
  cd "$DIST"
  find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z \
    | xargs -0 -r sha256sum > SHA256SUMS
  sha256sum -c SHA256SUMS
)

echo "=== Build and package validation complete ==="
cat "$DIST/BUILD-REPORT.txt"
printf '\nFinal artifact files for %s:\n' "$BUILD_VARIANT"
find "$DIST" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
