#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_VERSION="$(printenv SOURCE_VERSION 2>/dev/null || true)"
BUILD_JOBS="$(printenv BUILD_JOBS 2>/dev/null || true)"
if test -z "$SOURCE_VERSION"; then SOURCE_VERSION="6.1.187-1"; fi
if test -z "$BUILD_JOBS"; then BUILD_JOBS="2"; fi
EXPECTED_RELEASE="6.1.187-d630-core2"
WORK="$ROOT/work"
AUDIT="$ROOT/audit"
DIST="$ROOT/dist"
INPUTS="$ROOT/prepared-inputs"
SOURCE="$WORK/linux-source"
BUILD="$SOURCE/debian/build/build_amd64_none_amd64"

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
export LANG=C

rm -rf "$WORK" "$AUDIT" "$DIST"
mkdir -p "$WORK" "$AUDIT" "$DIST"

echo "=== Stage 1: fetch and verify pinned Debian inputs ==="
bash "$ROOT/scripts/prepare-debian-inputs.sh" 2>&1 | tee "$AUDIT/input-preparation.log"

echo "=== Stage 2: install Debian source-package build dependencies ==="
apt-get build-dep -y "linux=$SOURCE_VERSION"
apt-get install -y --no-install-recommends \
  build-essential gcc-12 g++-12 bc bison flex libelf-dev libssl-dev \
  rsync kmod cpio xz-utils zstd lz4 pahole fakeroot quilt debhelper \
  python3 python3-dev python3-ply python3-setuptools perl file
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "=== Stage 3: extract the exact source package ==="
DSC_FILE="$(find "$INPUTS/source" -maxdepth 1 -type f -name '*.dsc' -print -quit)"
test -n "$DSC_FILE" && test -s "$DSC_FILE"
dpkg-source -x "$DSC_FILE" "$SOURCE" > "$AUDIT/source-extraction.log" 2>&1
ACTUAL_SOURCE_VERSION="$(dpkg-parsechangelog -l "$SOURCE/debian/changelog" -S Version)"
test "$ACTUAL_SOURCE_VERSION" = "$SOURCE_VERSION"
printf 'Source package version: %s\n' "$ACTUAL_SOURCE_VERSION" | tee "$AUDIT/source-version.txt"

echo "=== Stage 4: stage the verified early-microcode input ==="
mkdir -p /lib/firmware/intel-ucode
install -m 0644 "$INPUTS/microcode/intel-ucode/06-0f-0d" /lib/firmware/intel-ucode/06-0f-0d
cp "$INPUTS/config/debian-image-config-6.1.0-53-amd64" "$AUDIT/official-reference-config"
cp "$INPUTS/config/debian-config-package-amd64_none_amd64" "$AUDIT/debian-config-package-amd64"
cp "$ROOT/config/d630-core2.config" "$AUDIT/d630-core2.config"

if ! id builder >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash builder
fi
chown -R builder:builder "$WORK" "$AUDIT" "$SOURCE"

echo "=== Stage 5: generate Debian's stock amd64 config first ==="
runuser -u builder -- env DEB_RULES_REQUIRES_ROOT=no \
  make -C "$SOURCE" -f debian/rules.gen setup_amd64_none_amd64
if ! test -s "$BUILD/.config"; then
  find "$SOURCE/debian/build" -maxdepth 5 -type f -name .config -print >&2 || true
  echo "Debian setup target did not create $BUILD/.config" >&2
  exit 1
fi
cp "$BUILD/.config" "$AUDIT/debian-baseline.config"
chown builder:builder "$AUDIT/debian-baseline.config"

echo "=== Stage 6: apply the narrowly scoped Debian build policy ==="
runuser -u builder -- python3 "$ROOT/scripts/apply-d630-build-policy.py" \
  "$SOURCE" "$AUDIT" "$ROOT/config/d630-core2.config"

echo "=== Stage 7: preflight the merged config and exact kernel release ==="
runuser -u builder -- "$SOURCE/scripts/kconfig/merge_config.sh" -m -O "$BUILD" \
  "$AUDIT/debian-baseline.config" "$SOURCE/debian/config/d630-core2.config" \
  > "$AUDIT/kconfig-merge.log" 2>&1
runuser -u builder -- make -C "$SOURCE" O="$BUILD" ARCH=x86 olddefconfig
PREVIEW_RELEASE="$(runuser -u builder -- make --no-print-directory -s -C "$SOURCE" \
  O="$BUILD" ARCH=x86 LOCALVERSION=-d630-core2 kernelrelease)"
printf '%s\n' "$PREVIEW_RELEASE" | tee "$AUDIT/preflight-kernelrelease.txt"
test "$PREVIEW_RELEASE" = "$EXPECTED_RELEASE" || {
  echo "Expected kernel release $EXPECTED_RELEASE; config/Makefile produced $PREVIEW_RELEASE" >&2
  exit 1
}
cp "$BUILD/.config" "$AUDIT/preflight-final.config"
runuser -u builder -- python3 "$ROOT/scripts/audit-d630-config.py" \
  "$AUDIT/debian-baseline.config" "$BUILD/.config" "$ROOT/config/d630-core2.config" \
  "$AUDIT/official-reference-config" "$AUDIT"

echo "=== Stage 8: build only the amd64 runtime image binary target ==="
runuser -u builder -- env \
  DEB_RULES_REQUIRES_ROOT=no \
  DEB_BUILD_OPTIONS="parallel=$BUILD_JOBS" \
  MAKEFLAGS="-j$BUILD_JOBS" \
  make -C "$SOURCE" -f debian/rules.gen binary-arch_amd64_none_amd64_image

echo "=== Stage 9: validate the built config and embedded microcode ==="
test -s "$BUILD/.config"
cp "$BUILD/.config" "$AUDIT/d630-final.config"
python3 "$ROOT/scripts/audit-d630-config.py" \
  "$AUDIT/debian-baseline.config" "$BUILD/.config" "$ROOT/config/d630-core2.config" \
  "$AUDIT/official-reference-config" "$AUDIT"
test -s "$BUILD/vmlinux" || { echo "Uncompressed vmlinux missing after build" >&2; exit 1; }
python3 - "$BUILD/vmlinux" "$INPUTS/microcode/intel-ucode/06-0f-0d" <<'PY'
from pathlib import Path
import hashlib
import sys

image = Path(sys.argv[1]).read_bytes()
blob = Path(sys.argv[2]).read_bytes()
if image.find(blob) < 0:
    raise SystemExit("FAIL: verified T7250 microcode blob is not present in vmlinux")
print("PASS: the exact Intel Core 2 microcode blob is embedded in vmlinux")
print("Microcode SHA-256: " + hashlib.sha256(blob).hexdigest())
PY

echo "=== Stage 10: repackage only the runtime image under a distinct package name ==="
PACKAGE=""
while IFS= read -r candidate; do
  package_name="$(dpkg-deb -f "$candidate" Package 2>/dev/null || true)"
  case "$package_name" in
    linux-image-*)
      case "$package_name" in
        *-dbg|*-dev|linux-image-amd64|linux-image-cloud-amd64) continue ;;
      esac
      PACKAGE="$candidate"
      break
      ;;
  esac
done < <(find "$WORK" -maxdepth 4 -type f -name '*.deb' -print | sort)

test -n "$PACKAGE" && test -s "$PACKAGE" || {
  echo "Could not find an installable runtime linux-image package from the Debian image target" >&2
  find "$WORK" -maxdepth 4 -type f -name '*.deb' -print >&2
  exit 1
}
OLD_PACKAGE="$(dpkg-deb -f "$PACKAGE" Package)"
PACKAGE_VERSION="$(dpkg-deb -f "$PACKAGE" Version)"
PACKAGE_ARCH="$(dpkg-deb -f "$PACKAGE" Architecture)"
printf 'Original package: %s\nVersion: %s\nArchitecture: %s\n' \
  "$OLD_PACKAGE" "$PACKAGE_VERSION" "$PACKAGE_ARCH" > "$AUDIT/original-image-package.txt"
dpkg-deb -I "$PACKAGE" control > "$AUDIT/original-image-control.txt"

REPACK="$WORK/repack"
rm -rf "$REPACK"
mkdir -p "$REPACK"
dpkg-deb -R "$PACKAGE" "$REPACK"
NEW_PACKAGE="linux-image-6.1.187-d630-core2"
python3 - "$REPACK/DEBIAN/control" "$OLD_PACKAGE" "$NEW_PACKAGE" "$EXPECTED_RELEASE" <<'PY'
from pathlib import Path
import re
import sys

control_path = Path(sys.argv[1])
old_package, new_package, release = sys.argv[2:]
text = control_path.read_text()
text, count = re.subn(r"(?m)^Package:.*$", "Package: " + new_package, text, count=1)
if count != 1:
    raise SystemExit("Could not rename the Debian image control stanza")
text, count = re.subn(
    r"(?m)^Description:.*$",
    "Description: Custom Debian kernel image for Dell Latitude D630, release " + release,
    text,
    count=1,
)
if count != 1:
    raise SystemExit("Could not set the custom image description")

# The custom module path is unique; remove exact references that forbid side-by-side install.
for field in ("Conflicts", "Breaks", "Replaces"):
    pattern = re.compile(r"(?ms)^" + field + r":([^\n]*(?:\n[ \t][^\n]*)*)")
    match = pattern.search(text)
    if not match:
        continue
    value = match.group(1).replace("\n", " ")
    clauses = [clause.strip() for clause in value.split(",") if clause.strip()]
    kept = []
    for clause in clauses:
        alternatives = [
            item.strip() for item in clause.split("|")
            if not re.match(r"^" + re.escape(old_package) + r"(?:\s|\(|$)", item.strip())
        ]
        if alternatives:
            kept.append(" | ".join(alternatives))
    replacement = field + ": " + ", ".join(kept) if kept else ""
    text = text[:match.start()] + replacement + text[match.end():]

control_path.write_text(text.rstrip() + "\n")
PY

OLD_DOC="$REPACK/usr/share/doc/$OLD_PACKAGE"
NEW_DOC="$REPACK/usr/share/doc/$NEW_PACKAGE"
if test -L "$OLD_DOC"; then
  rm -f "$OLD_DOC"
elif test -d "$OLD_DOC"; then
  mv "$OLD_DOC" "$NEW_DOC"
fi
mkdir -p "$NEW_DOC"
cp "$INPUTS/microcode/INTEL-MICROCODE-LICENSE.txt" "$NEW_DOC/INTEL-MICROCODE-LICENSE.txt"
cp "$INPUTS/microcode/INTEL-MICROCODE-COPYRIGHT.txt" "$NEW_DOC/INTEL-MICROCODE-COPYRIGHT.txt"
(cd "$REPACK" && find . -type f ! -path './DEBIAN/*' -print0 | sort -z | xargs -0 md5sum) \
  > "$REPACK/DEBIAN/md5sums"

test -s "$REPACK/boot/vmlinuz-$EXPECTED_RELEASE" || {
  find "$REPACK/boot" -maxdepth 1 -type f -printf '%f\n' >&2
  echo "Packaged kernel image filename does not match $EXPECTED_RELEASE" >&2
  exit 1
}
test -d "$REPACK/lib/modules/$EXPECTED_RELEASE" || {
  find "$REPACK/lib/modules" -maxdepth 2 -type d -print >&2
  echo "Packaged module directory does not match $EXPECTED_RELEASE" >&2
  exit 1
}

DEB_NAME="$(printf '%s_%s_%s.deb' "$NEW_PACKAGE" "$PACKAGE_VERSION" "$PACKAGE_ARCH")"
DEB_OUTPUT="$DIST/$DEB_NAME"
dpkg-deb --build --root-owner-group "$REPACK" "$DEB_OUTPUT"
test "$(dpkg-deb -f "$DEB_OUTPUT" Package)" = "$NEW_PACKAGE"
test "$(dpkg-deb -f "$DEB_OUTPUT" Architecture)" = "amd64"

cp "$INPUTS/microcode/INTEL-MICROCODE-LICENSE.txt" "$DIST/"
cp "$INPUTS/microcode/INTEL-MICROCODE-COPYRIGHT.txt" "$DIST/"
cp "$INPUTS/microcode/MICROCODE-METADATA.txt" "$DIST/"
dpkg-deb -I "$DEB_OUTPUT" control > "$AUDIT/final-image-control.txt"
dpkg-deb -c "$DEB_OUTPUT" > "$AUDIT/final-image-file-list.txt"

{
  echo "Build status: PASS"
  echo "Source package: linux=$SOURCE_VERSION"
  echo "Kernel release: $EXPECTED_RELEASE"
  echo "Binary package: $(dpkg-deb -f "$DEB_OUTPUT" Package)"
  echo "Binary package version: $(dpkg-deb -f "$DEB_OUTPUT" Version)"
  echo "Architecture: $(dpkg-deb -f "$DEB_OUTPUT" Architecture)"
  echo "Build target: binary-arch_amd64_none_amd64_image (Debian native rules)"
  echo "Configuration: Debian-generated amd64 baseline + config/d630-core2.config"
  echo "Embedded microcode: Intel Core 2 T7250, CPUID 0x000006fd"
  echo "Microcode SHA-256: $(sha256sum "$INPUTS/microcode/intel-ucode/06-0f-0d" | awk '{print $1}')"
  echo "Package SHA-256: $(sha256sum "$DEB_OUTPUT" | awk '{print $1}')"
  echo "Debug/development packages: not built or published"
  echo "Hardware boot test: not performed in GitHub Actions; test on the target D630 remains required."
} > "$DIST/BUILD-REPORT.txt"

(
  cd "$DIST"
  sha256sum *.deb INTEL-MICROCODE-LICENSE.txt INTEL-MICROCODE-COPYRIGHT.txt MICROCODE-METADATA.txt BUILD-REPORT.txt > SHA256SUMS
)

echo "=== Build and package verification complete ==="
cat "$DIST/BUILD-REPORT.txt"
printf '\nOutput files:\n'
find "$DIST" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
