#!/usr/bin/env bash
# Verify the installable package and audited effective configuration before release.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VARIANT="${1:-${BUILD_VARIANT:-}}"
case "$VARIANT" in
  amd64)
    EXPECTED_PACKAGE=linux-image-6.1.0-52-amd64
    EXPECTED_RELEASE=6.1.0-52-amd64
    EXPECTED_RT=n
    ;;
  amd64-rt)
    EXPECTED_PACKAGE=linux-image-6.1.0-52-rt-amd64
    EXPECTED_RELEASE=6.1.0-52-rt-amd64
    EXPECTED_RT=y
    ;;
  *)
    echo "Usage: $0 {amd64|amd64-rt}" >&2
    exit 2
    ;;
esac

DIST="$ROOT/dist/$VARIANT"
AUDIT="$ROOT/audit/$VARIANT"
PACKAGE="$DIST/${EXPECTED_PACKAGE}_6.1.180-1+d6301_amd64.deb"
FINAL_CONFIG="$AUDIT/d630-final.config"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}
require_file() {
  [[ -s "$1" ]] || fail "required file is missing or empty: $1"
}
require_config() {
  local symbol="$1" expected="$2" actual
  actual="$(awk -v key="CONFIG_$symbol" '
    $0 ~ ("^" key "=") { sub("^[^=]*=", ""); print; found=1; exit }
    $0 == "# " key " is not set" { print "n"; found=1; exit }
    END { if (!found) print "n" }
  ' "$FINAL_CONFIG")"
  [[ "$actual" == "$expected" ]] || fail "CONFIG_$symbol: expected $expected, got $actual"
}

echo "=== Verify required release files ==="
for file in \
  "$PACKAGE" \
  "$DIST/firmware-iwlwifi_"*"_all.deb" \
  "$DIST/intel-microcode_"*"_amd64.deb" \
  "$DIST/D630-FINAL-CONFIG" \
  "$DIST/D630-CONFIG-DIFF.txt" \
  "$DIST/D630-CONFIG-AUDIT.tsv" \
  "$DIST/CONFIG-AUDIT-SUMMARY.txt" \
  "$DIST/CONFIG-AUDIT-ERRORS.txt" \
  "$DIST/UNCLASSIFIED-MODULE-DROPS.txt" \
  "$DIST/POLICY-DISABLED-SYMBOLS.tsv" \
  "$DIST/MICROCODE-VALIDATION.txt" \
  "$DIST/KERNEL-PACKAGE-METADATA.txt" \
  "$DIST/D630-FIRMWARE-REQUIREMENTS.txt" \
  "$DIST/RELEASE-NOTES.md" \
  "$DIST/BUILD-REPORT.txt" \
  "$DIST/SHA256SUMS"; do
  require_file "$file"
done
require_file "$FINAL_CONFIG"
require_file "$AUDIT/d630-config-symbol-audit.tsv"
require_file "$AUDIT/kconfig-fragment-normalization.txt"
require_file "$AUDIT/config-audit-summary.txt"
require_file "$AUDIT/config-audit-errors.txt"
grep -Fqx "PASS" "$AUDIT/config-audit-errors.txt" || fail "configuration audit recorded errors"
require_file "$AUDIT/kconfig-olddefconfig.log"
require_file "$AUDIT/native-image-build.log"

echo "=== Verify Debian package identity ==="
[[ "$(dpkg-deb -f "$PACKAGE" Package)" == "$EXPECTED_PACKAGE" ]] || fail "unexpected package name"
[[ "$(dpkg-deb -f "$PACKAGE" Version)" == "6.1.180-1+d6301" ]] || fail "unexpected package version"
[[ "$(dpkg-deb -f "$PACKAGE" Architecture)" == "amd64" ]] || fail "unexpected package architecture"
grep -Fqx "Kernel release: $EXPECTED_RELEASE" "$DIST/BUILD-REPORT.txt" || fail "build report has the wrong kernel release"

echo "=== Verify effective D630 configuration ==="
require_config MCORE2 y
require_config GENERIC_CPU n
require_config SOUND y
require_config SND y
require_config SND_PCI y
require_config SND_HDA y
require_config SND_HDA_INTEL m
require_config SND_HDA_CODEC_SIGMATEL m
require_config ZRAM y
require_config ZSMALLOC y
require_config ZRAM_DEF_COMP_LZ4 y
require_config ZRAM_DEF_COMP_LZORLE n
require_config ZRAM_DEF_COMP_ZSTD n
require_config ZRAM_DEF_COMP_LZO n
require_config ZRAM_DEF_COMP_LZ4HC n
require_config ZRAM_DEF_COMP_842 n
require_config SQUASHFS y
require_config IWL3945 m
require_config MODULES y
require_config MODULE_UNLOAD y
require_config PREEMPT_RT "$EXPECTED_RT"

if grep -Eiq 'warning: override:|changes choice state' \
  "$AUDIT/kconfig-olddefconfig.log" "$AUDIT/native-image-build.log"; then
  fail "Kconfig override/choice warnings remain in configuration or build logs"
fi
grep -Fqx 'CONFIG_SND_HDA=y' "$FINAL_CONFIG" || fail "HDA core is not built in"
grep -Fqx 'CONFIG_SND_PCI=y' "$FINAL_CONFIG" || fail "ALSA PCI core is not built in"
grep -Fqx 'CONFIG_SND_HDA_INTEL=m' "$FINAL_CONFIG" || fail "Intel HDA driver is not modular"
grep -Fqx 'CONFIG_SND_HDA_CODEC_SIGMATEL=m' "$FINAL_CONFIG" || fail "Sigmatel codec is not modular"

echo "=== Verify module payload and checksums ==="
dpkg-deb -c "$PACKAGE" | grep -F "/lib/modules/$EXPECTED_RELEASE/" >/dev/null || fail "kernel modules for $EXPECTED_RELEASE are absent"
(cd "$DIST" && sha256sum --check SHA256SUMS)

echo "PASS: package metadata, firmware, effective config, kernel modules, and checksums validated for $VARIANT."
