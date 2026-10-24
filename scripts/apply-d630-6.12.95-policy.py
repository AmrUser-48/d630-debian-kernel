#!/usr/bin/env python3
"""Apply the D630 overlay to one native Debian Bookworm-backports image target."""
from __future__ import annotations

from difflib import unified_diff
from pathlib import Path
import re
import sys

if len(sys.argv) != 5:
    raise SystemExit("usage: apply-d630-6.12.95-policy.py SOURCE AUDIT OVERLAY FEATURESET")

source = Path(sys.argv[1]).resolve()
audit = Path(sys.argv[2]).resolve()
overlay = Path(sys.argv[3]).resolve()
featureset = sys.argv[4]
if featureset not in {"none", "rt"}:
    raise SystemExit("FEATURESET must be none or rt")

baseline = source / f"debian/build/build_amd64_{featureset}_amd64/.config"
rules = source / "debian/rules.gen"
target_config = source / "debian/config/d630-core2-6.12.95.config"
if not baseline.is_file():
    raise SystemExit(f"Debian-generated {featureset} config not found: {baseline}")
if not rules.is_file() or not overlay.is_file():
    raise SystemExit("Debian rules.gen or the committed D630 overlay is missing")

audit.mkdir(parents=True, exist_ok=True)

def read_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(errors="replace").splitlines():
        match = re.match(r"^CONFIG_([A-Z0-9_]+)=(.*)$", line)
        if match:
            values[match.group(1)] = match.group(2)
        else:
            match = re.match(r"^# CONFIG_([A-Z0-9_]+) is not set$", line)
            if match:
                values[match.group(1)] = "n"
    return values

base = read_config(baseline)
symbols = set(base)
overlay_text = overlay.read_text(encoding="utf-8").rstrip()

# These are intentional policy trims on the Debian-generated config. Preserve
# the actual D630 audio core and SigmaTel codec, not every sound device.
sound_keep = {
    "SND", "SND_PCI", "SND_TIMER", "SND_PCM", "SND_HWDEP", "SND_HDA", "SND_HDA_INTEL",
    "SND_HDA_CODEC_SIGMATEL", "SND_HDA_CORE", "SND_HDA_COMPONENT",
    "SND_HDA_GENERIC", "SND_HDA_GENERIC_LEDS", "SND_INTEL_DSP_CONFIG",
    "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE", "SND_JACK", "SND_CTL_LED",
    "SND_VMASTER",
}
sound_disabled = sorted(
    symbol for symbol in symbols
    if symbol.startswith("SND_") and symbol not in sound_keep and base.get(symbol) in {"y", "m"}
)

# Keep the D630's disk filesystems, boot/live-image filesystems, virtual
# filesystems, and FUSE. Do not remove configfs/debugfs from the Debian baseline.
filesystem_keep = {
    "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "FAT_FS", "MSDOS_FS", "VFAT_FS",
    "EXFAT_FS", "UDF_FS", "ISO9660_FS", "SQUASHFS", "OVERLAY_FS", "FUSE_FS",
    "PROC_FS", "DEVPTS_FS", "CONFIGFS_FS", "DEBUG_FS",
}
filesystem_extras = {
    "CRAMFS", "ROMFS", "CIFS", "CIFS_UPCALL", "CIFS_XATTR", "CIFS_POSIX",
    "NFS_V2", "NFS_V3", "NFS_V4", "NFS_SWAP", "NFSD", "NFSD_V2", "NFSD_V3",
    "NFSD_V4", "SMB_SERVER", "SMB_SERVER_SMBDIRECT",
}
filesystem_disabled = sorted(
    symbol for symbol in symbols
    if ((symbol.endswith("_FS") and symbol not in filesystem_keep) or symbol in filesystem_extras)
    and base.get(symbol) in {"y", "m"}
)

# Prune unrelated GPU drivers while preserving the generic DRM framework,
# Intel i915, Intel AGP, framebuffer console and their shared dependencies.
gpu_prefixes = (
    "DRM_AMDGPU", "DRM_RADEON", "DRM_NOUVEAU", "DRM_NVIDIA", "DRM_VMWGFX",
    "DRM_VIRTIO_GPU", "DRM_QXL", "DRM_GMA500", "DRM_AST", "DRM_BOCHS",
    "DRM_CIRRUS_QEMU", "DRM_MGAG200", "DRM_TEGRA", "DRM_ROCKCHIP",
    "DRM_MESON", "DRM_EXYNOS", "DRM_OMAP", "DRM_ETNAVIV", "DRM_LIMA",
    "DRM_PANFROST", "DRM_PANTHOR", "DRM_V3D", "DRM_VC4", "DRM_IMX",
    "DRM_PL111", "DRM_SUN4I", "DRM_FSL_DCU", "DRM_ARMADA", "DRM_MEDIATEK",
    "DRM_SPRD", "DRM_STI", "DRM_RCAR_DU", "DRM_XEN", "DRM_POWERVR",
    "DRM_LOONGSON", "DRM_SSD130X", "FB_AMDGPU", "FB_NVIDIA", "FB_RADEON",
    "FB_ATY", "FB_SIS", "FB_VIA", "FB_MATROX", "FB_CYBER2000", "FB_TRIDENT",
    "FB_S3", "FB_3DFX", "FB_VOODOO", "FB_PM2", "FB_PM3", "FB_NEOMAGIC",
    "FB_TG3", "FB_RIVA", "FB_CIRRUS", "FB_SAVAGE", "FB_BROADSHEET", "FB_SM",
    "FB_ARK", "FB_KYRO",
)
gpu_disabled = sorted(
    symbol for symbol in symbols
    if any(symbol.startswith(prefix) for prefix in gpu_prefixes)
    and base.get(symbol) in {"y", "m"}
)

# Start from the native Debian baseline and then apply the D630 overlay last.
generated = overlay_text + "\n"
if featureset == "rt":
    # PREEMPT_RT depends on EXPERT and ARCH_SUPPORTS_RT in this kernel series.
    generated += "\n# Debian Bookworm backports RT variant requirements.\nCONFIG_EXPERT=y\nCONFIG_PREEMPT_RT=y\n"
else:
    generated += "\n# Normal amd64 image: do not enable PREEMPT_RT.\n# CONFIG_PREEMPT_RT is not set\n"

generated += "\n# Disable unused audio-card and codec families; retain HDA/SigmaTel.\n"
generated += "".join(f"# CONFIG_{symbol} is not set\n" for symbol in sound_disabled)
generated += "\n# Disable unrelated filesystems; preserve configfs/debugfs and live boot filesystems.\n"
generated += "".join(f"# CONFIG_{symbol} is not set\n" for symbol in filesystem_disabled)
generated += "\n# Disable unrelated vendor GPU drivers; retain Intel i915.\n"
generated += "".join(f"# CONFIG_{symbol} is not set\n" for symbol in gpu_disabled)

# Explicitly document and enforce selected parent-family exclusions. Kconfig
# handles dependent children; we do not hand-edit every child symbol.
target_config.parent.mkdir(parents=True, exist_ok=True)
target_config.write_text(generated, encoding="utf-8")

with (audit / "policy-disabled-symbols.tsv").open("w", encoding="utf-8") as out:
    out.write("symbol\tpolicy\n")
    for policy, values in (
        ("unused sound", sound_disabled),
        ("unused filesystem", filesystem_disabled),
        ("unrelated GPU", gpu_disabled),
    ):
        for symbol in values:
            out.write(f"{symbol}\t{policy}\n")

# Patch only the selected Debian image target's KCONFIG list. Do not change the
# Debian version, ABI, localversion, target name, or any generated package rule.
before = rules.read_text(encoding="utf-8")
target = f"binary-arch_amd64_{featureset}_amd64_real_image:"
lines = before.splitlines(keepends=True)
indices = [i for i, line in enumerate(lines) if line.startswith(target)]
if len(indices) != 1:
    raise SystemExit(f"Expected exactly one {target}, found {len(indices)}")
start = indices[0]
recipe_index = None
for i in range(start + 1, min(start + 12, len(lines))):
    if lines[i].startswith("\t") and "binary_image" in lines[i]:
        recipe_index = i
        break
    if lines[i].strip() and not lines[i].startswith("\t"):
        break
if recipe_index is None:
    raise SystemExit(f"Could not locate the image recipe following {target}")
recipe = lines[recipe_index]
match = re.search(r"KCONFIG='([^']*)'", recipe)
if not match:
    raise SystemExit(f"Could not parse KCONFIG chain in {target}")
parts = match.group(1).split()
config_rel = "debian/config/d630-core2-6.12.95.config"
if config_rel not in parts:
    parts.append(config_rel)
lines[recipe_index] = recipe[:match.start(1)] + " ".join(parts) + recipe[match.end(1):]
after = "".join(lines)
rules.write_text(after, encoding="utf-8")

(audit / "rules.gen.diff").write_text(
    "\n".join(unified_diff(
        before.splitlines(), after.splitlines(),
        fromfile="debian/rules.gen.before", tofile="debian/rules.gen.after",
        lineterm="",
    )) + "\n",
    encoding="utf-8",
)
(audit / "policy-application.txt").write_text(
    f"Source package: linux 6.12.95-1~bpo12+1\n"
    f"Feature set: {featureset}\n"
    f"Native image target: {target}\n"
    f"Debian ABI/version/localversion values are not patched.\n"
    f"D630 config fragment appended last to the target KCONFIG chain.\n"
    f"Explicit unused sound symbols disabled: {len(sound_disabled)}\n"
    f"Explicit unused filesystem symbols disabled: {len(filesystem_disabled)}\n"
    f"Unrelated GPU symbols disabled: {len(gpu_disabled)}\n"
)
print(f"Applied D630 overlay to {target}; native Debian ABI rules left intact.")
