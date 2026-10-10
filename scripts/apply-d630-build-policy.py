#!/usr/bin/env python3
"""Apply a D630-specific policy to Debian's native amd64 image target."""

from difflib import unified_diff
from pathlib import Path
import re
import sys

if len(sys.argv) != 4:
    raise SystemExit("usage: apply-d630-build-policy.py SOURCE_DIR AUDIT_DIR OVERLAY_CONFIG")

source = Path(sys.argv[1]).resolve()
audit = Path(sys.argv[2]).resolve()
overlay = Path(sys.argv[3]).resolve()
audit.mkdir(parents=True, exist_ok=True)

makefile = source / "Makefile"
rules = source / "debian/rules.gen"
target_config = source / "debian/config/d630-core2.config"
baseline_config = source / "debian/build/build_amd64_none_amd64/.config"
if not makefile.is_file() or not rules.is_file():
    raise SystemExit("Debian source tree lacks Makefile or debian/rules.gen")
if not overlay.is_file():
    raise SystemExit("Missing committed D630 config overlay: " + str(overlay))
if not baseline_config.is_file():
    raise SystemExit("Debian-generated baseline config missing: " + str(baseline_config))

make_before = makefile.read_text()
rules_before = rules.read_text()
(audit / "kernel-Makefile-before.txt").write_text(make_before)
(audit / "rules.gen-before.txt").write_text(rules_before)

# The D630 uses Intel ICH8 HD Audio with a Sigmatel/IDT codec.
# Keep the ALSA core and this one driver/codec; explicitly turn off every
# other sound Kconfig option present in Debian's generated baseline.
sound_keep = {
    "SND", "SND_TIMER", "SND_PCM", "SND_HWDEP", "SND_HDA", "SND_HDA_INTEL",
    "SND_HDA_CODEC", "SND_HDA_CODEC_IDT", "SND_HDA_CORE", "SND_HDA_COMPONENT",
    "SND_INTEL_DSP_CONFIG", "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE",
    "SND_JACK", "SND_CTL_LED",
}
config_symbols = set()
for raw in baseline_config.read_text(errors="replace").splitlines():
    match = re.match(r"^(?:CONFIG_([A-Z0-9_]+)=|# CONFIG_([A-Z0-9_]+) is not set$)", raw)
    if match:
        config_symbols.add(match.group(1) or match.group(2))
sound_disabled = sorted(
    symbol for symbol in config_symbols
    if symbol.startswith("SND_") and symbol not in sound_keep
)
# Keep only the filesystems requested for this laptop and essential kernel pseudo-filesystems.
filesystem_keep = {
    "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "FAT_FS", "MSDOS_FS", "VFAT_FS",
    "UDF_FS", "ISO9660_FS", "PROC_FS", "DEVPTS_FS",
}
filesystem_disabled = sorted(
    symbol for symbol in config_symbols
    if (symbol.endswith("_FS") and symbol not in filesystem_keep)
    or symbol in {
        "SQUASHFS", "CRAMFS", "ROMFS",
        # Network/distributed filesystems whose symbols do not end in _FS.
        "CIFS", "CIFS_UPCALL", "CIFS_XATTR", "CIFS_POSIX",
        "NFS_V2", "NFS_V3", "NFS_V4", "NFS_SWAP",
        "NFSD", "NFSD_V2", "NFSD_V3", "NFSD_V4",
        "SMB_SERVER", "SMB_SERVER_SMBDIRECT",
    }
)
# Disable unrelated discrete/vendor GPU drivers. Keep Intel i915 and shared DRM helpers.
gpu_prefixes = (
    "DRM_AMDGPU", "DRM_RADEON", "DRM_NOUVEAU", "DRM_NVIDIA",
    "DRM_VMWGFX", "DRM_VIRTIO_GPU", "DRM_QXL", "DRM_GMA500",
    "DRM_AST", "DRM_BOCHS", "DRM_CIRRUS_QEMU", "DRM_MGAG200",
    "DRM_TEGRA", "DRM_ROCKCHIP", "DRM_MESON", "DRM_EXYNOS",
    "DRM_OMAP", "DRM_ETNAVIV", "DRM_LIMA", "DRM_PANFROST",
    "DRM_PANTHOR", "DRM_V3D", "DRM_VC4", "DRM_IMX",
    "DRM_PL111", "DRM_SUN4I", "DRM_FSL_DCU", "DRM_ARMADA",
    "DRM_MEDIATEK", "DRM_SPRD", "DRM_STI", "DRM_RCAR_DU",
    "DRM_XEN", "DRM_POWERVR", "DRM_LOONGSON", "DRM_SSD130X",
    # Legacy framebuffer GPU drivers unrelated to the D630's Intel i915.
    "FB_AMDGPU", "FB_NVIDIA", "FB_RADEON", "FB_ATY", "FB_SIS", "FB_VIA",
    "FB_MATROX", "FB_CYBER2000", "FB_TRIDENT", "FB_S3", "FB_I810",
    "FB_3DFX", "FB_VOODOO", "FB_PM2", "FB_PM3", "FB_NEOMAGIC",
    "FB_TG3", "FB_RIVA", "FB_CIRRUS", "FB_SAVAGE", "FB_BROADSHEET",
    "FB_SM", "FB_ARK", "FB_KYRO", "FB_VIRTUAL",
)
gpu_disabled = sorted(
    symbol for symbol in config_symbols
    if any(symbol.startswith(prefix) for prefix in gpu_prefixes)
)
sound_policy = (
    "\n# D630 audio: Intel ICH8 HD Audio plus the Sigmatel/IDT codec only.\n"
    "# All other Debian sound drivers/codecs are explicitly disabled by the build policy.\n"
    "CONFIG_SND=m\nCONFIG_SND_HDA_INTEL=m\nCONFIG_SND_HDA_CODEC_IDT=m\n"
    + "".join("# CONFIG_" + symbol + " is not set\n" for symbol in sound_disabled)
    + "\n# D630 filesystems: only requested disk filesystems; pseudo-filesystems remain independently configured.\n"
    + "".join("# CONFIG_" + symbol + " is not set\n" for symbol in filesystem_disabled)
    + "\n# D630 graphics: Intel i915 only; disable unrelated GPU drivers.\n"
    + "".join("# CONFIG_" + symbol + " is not set\n" for symbol in gpu_disabled)
)
target_config.parent.mkdir(parents=True, exist_ok=True)
target_config.write_text(overlay.read_text().rstrip() + sound_policy)
(audit / "sound-policy-disabled-symbols.txt").write_text(
    "Allowed D630 sound stack: ALSA core, Intel HDA, IDT/Sigmatel codec and required dependencies.\n"
    + "".join("CONFIG_" + symbol + "=n\n" for symbol in sound_disabled)
)
(audit / "filesystem-policy-disabled-symbols.txt").write_text(
    "Allowed disk filesystems: ext4, Btrfs, NTFS3, FAT/MS-DOS/VFAT, UDF and ISO9660.\n"
    + "Essential proc and devpts pseudo-filesystems are retained; tmpfs/sysfs/devtmpfs are unaffected.\n"
    + "".join("CONFIG_" + symbol + "=n\n" for symbol in filesystem_disabled)
)
(audit / "gpu-policy-disabled-symbols.txt").write_text(
    "Intel i915 retained. Unrelated GPU driver families disabled.\n"
    + "".join("CONFIG_" + symbol + "=n\n" for symbol in gpu_disabled)
)

make_after = make_before
for key, value in (("VERSION", "6"), ("PATCHLEVEL", "1"), ("SUBLEVEL", "187"), ("EXTRAVERSION", "")):
    pattern = re.compile(r"(?m)^" + re.escape(key) + r"\s*=.*$")
    make_after, count = pattern.subn(key + " = " + value, make_after, count=1)
    if count != 1:
        raise SystemExit("Could not set exactly one top-level Makefile variable: " + key)
makefile.write_text(make_after)

lines = rules_before.splitlines(keepends=True)
target_indices = [i for i, line in enumerate(lines) if line.startswith("binary-arch_amd64_none_amd64_real_image:")]
if len(target_indices) != 1:
    raise SystemExit("Expected exactly one binary-arch_amd64_none_amd64_real_image target; got " + str(len(target_indices)))
index = target_indices[0]
recipe_index = None
for i in range(index + 1, min(index + 8, len(lines))):
    if lines[i].startswith("\t") and "binary_image" in lines[i]:
        recipe_index = i
        break
    if lines[i].strip() and not lines[i].startswith("\t"):
        break
if recipe_index is None:
    raise SystemExit("Could not locate Debian image build recipe immediately below the target")
recipe = lines[recipe_index]
kconfig_match = re.search(r"KCONFIG='([^']*)'", recipe)
if not kconfig_match:
    raise SystemExit("Cannot safely parse KCONFIG in Debian image recipe")
kconfig_parts = kconfig_match.group(1).split()
if "debian/config/d630-core2.config" not in kconfig_parts:
    kconfig_parts.append("debian/config/d630-core2.config")
recipe = recipe[:kconfig_match.start(1)] + " ".join(kconfig_parts) + recipe[kconfig_match.end(1):]
for pattern, replacement in (
    (r"\bABINAME='[^']*'", "ABINAME='6.1.187'"),
    (r"\bLOCALVERSION='[^']*'", "LOCALVERSION='-d630-core2'"),
    (r"\bLOCALVERSION_IMAGE='[^']*'", "LOCALVERSION_IMAGE='-d630-core2'"),
):
    recipe, count = re.subn(pattern, replacement, recipe, count=1)
    if count != 1:
        raise SystemExit("Could not safely set Debian image recipe variable: " + pattern)
lines[recipe_index] = recipe
rules_after = "".join(lines)
rules.write_text(rules_after)

(audit / "kernel-Makefile.diff").write_text(
    "".join(unified_diff(make_before.splitlines(keepends=True), make_after.splitlines(keepends=True),
                         fromfile="Debian-Makefile.before", tofile="Debian-Makefile.after"))
)
(audit / "rules.gen.diff").write_text(
    "".join(unified_diff(rules_before.splitlines(keepends=True), rules_after.splitlines(keepends=True),
                         fromfile="Debian-rules.gen.before", tofile="Debian-rules.gen.after"))
)
(audit / "build-policy-applied.txt").write_text(
    "Debian source package: linux 6.1.187-1\n"
    "Native build target: binary-arch_amd64_none_amd64_real_image\n"
    "Source Makefile: VERSION=6 PATCHLEVEL=1 SUBLEVEL=187 EXTRAVERSION empty\n"
    "Debian ABI name passed to image target: 6.1.187\n"
    "Debian LOCALVERSION and LOCALVERSION_IMAGE: -d630-core2\n"
    "The image target KCONFIG chain includes debian/config/d630-core2.config last\n"
    "Sound policy: Intel HDA + IDT/Sigmatel codec only; unrelated sound drivers disabled\n"
    "Filesystem policy: only requested disk filesystems; unrelated filesystem drivers disabled\n"
    "GPU policy: Intel i915 retained; unrelated AMD/NVIDIA and other vendor drivers disabled\n"
    "The generated config diff is checked by audit-d630-config.py\n"
)
print("Applied D630 policy, including the single-device sound policy.")
