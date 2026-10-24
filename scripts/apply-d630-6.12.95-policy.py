#!/usr/bin/env python3
"""Apply a D630 policy directly to Debian's generated .config, before olddefconfig."""
from __future__ import annotations

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

build_dir = source / f"debian/build/build_amd64_{featureset}_amd64"
config_path = build_dir / ".config"
baseline_path = audit / "debian-baseline.config"
if not config_path.is_file() or not baseline_path.is_file():
    raise SystemExit("Debian's native .config and saved baseline must exist before policy application")
if not overlay.is_file():
    raise SystemExit(f"D630 policy fragment not found: {overlay}")

audit.mkdir(parents=True, exist_ok=True)

def parse_config(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        match = re.match(r"^CONFIG_([A-Z0-9_]+)=(.*)$", line)
        if match:
            values[match.group(1)] = match.group(2)
            continue
        match = re.match(r"^# CONFIG_([A-Z0-9_]+) is not set$", line)
        if match:
            values[match.group(1)] = "n"
    return values

def read_config(path: Path) -> dict[str, str]:
    return parse_config(path.read_text(encoding="utf-8", errors="replace"))

def config_line(symbol: str, value: str) -> str:
    return f"# CONFIG_{symbol} is not set" if value == "n" else f"CONFIG_{symbol}={value}"

baseline = read_config(baseline_path)
current_text = config_path.read_text(encoding="utf-8", errors="replace")
current = parse_config(current_text)
requested = parse_config(overlay.read_text(encoding="utf-8", errors="replace"))

# D630 hardware profile: keep the complete Intel HDA PCI dependency chain and
# the exact Kconfig symbol used by SigmaTel/IDT in this kernel series.
requested.update({
    "SND": "y",
    "SND_PCI": "y",
    "SND_HDA": "y",
    "SND_HDA_INTEL": "m",
    "SND_HDA_CODEC_SIGMATEL": "m",
    "WLAN": "y",
    "CFG80211": "m",
    "MAC80211": "m",
    "RFKILL": "y",
    "IWLEGACY": "m",
    "IWL3945": "m",
    "MOUSE_PS2": "m",
    "INPUT_MOUSEDEV": "y",
    "INPUT_MOUSEDEV_PSAUX": "y",
    "EXT4_FS": "y",
    "BTRFS_FS": "y",
    "NTFS3_FS": "y",
    "FAT_FS": "y",
    "MSDOS_FS": "y",
    "VFAT_FS": "y",
    "EXFAT_FS": "y",
    "UDF_FS": "y",
    "SQUASHFS": "y",
    "OVERLAY_FS": "y",
    "ZSMALLOC": "y",
    "ZRAM": "y",
    "ZRAM_BACKEND_LZO": "y",
    "ZRAM_BACKEND_ZSTD": "y",
    "ZRAM_BACKEND_LZ4": "y",
    "ZRAM_BACKEND_LZ4HC": "y",
    "ZRAM_BACKEND_DEFLATE": "y",
    "ZRAM_BACKEND_842": "y",
    "ZRAM_DEF_COMP_LZ4": "y",
    "MCORE2": "y",
    "GENERIC_CPU": "n",
    "X86_MSR": "y",
    "X86_CPUID": "y",
    "MICROCODE": "y",
    "MICROCODE_INTEL": "y",
    "FW_LOADER": "y",
    "EXTRA_FIRMWARE": '"intel-ucode/06-0f-0d iwlwifi-3945-2.ucode"',
    "EXTRA_FIRMWARE_DIR": '"/lib/firmware"',
    "KERNEL_XZ": "y",
    "DEBUG_INFO_NONE": "y",
    "DEBUG_INFO": "n",
    "DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT": "n",
    "DEBUG_INFO_DWARF4": "n",
    "DEBUG_INFO_DWARF5": "n",
    "DEBUG_INFO_BTF": "n",
    "DEBUG_INFO_BTF_MODULES": "n",
    "GDB_SCRIPTS": "n",
    "MODULES": "y",
    "MODULE_UNLOAD": "y",
    "DVB_CORE": "n",
    "MEDIA_DIGITAL_TV_SUPPORT": "n",
    "MEDIA_RADIO_SUPPORT": "n",
    "MEDIA_SDR_SUPPORT": "n",
    "MEDIA_TEST_SUPPORT": "n",
    "CAN": "n",
    "ISDN": "n",
    "INFINIBAND": "n",
    "FIREWIRE": "n",
    "NFC": "n",
    "WIMAX": "n",
    "IEEE802154": "n",
    "6LOWPAN": "n",
    "USB_GADGET": "n",
    "MTD": "n",
    "BLK_DEV_NVME": "n",
    "SCSI_LOWLEVEL": "n",
})
if featureset == "rt":
    requested["EXPERT"] = "y"
    requested["PREEMPT_RT"] = "y"
else:
    requested["PREEMPT_RT"] = "n"

# Kconfig represents the default compressor as a choice. Clear all entries in
# that choice before setting LZ4 so the staged .config never contains two y's.
for symbol in current:
    if symbol.startswith("ZRAM_DEF_COMP_"):
        requested[symbol] = "n"
requested["ZRAM_DEF_COMP_LZ4"] = "y"

# Normalize all relevant Kconfig choices before olddefconfig.
# CPU family: every available x86 CPU choice except Merom/Core 2 is disabled.
cpu_choice = {
    "M386", "M486", "M486SX", "M586", "M586TSC", "M586MMX", "M686",
    "MPENTIUMII", "MPENTIUMIII", "MPENTIUMM", "MPENTIUM4", "MK6", "MK7",
    "MK8", "MK8SSE3", "MCRUSOE", "MEFFICEON", "MATOM", "MCORE2", "MGEODEGX1",
    "MGEODE_LX", "MPSC", "X86_GENERIC", "GENERIC_CPU", "MVIAC3_2", "MVIAC7",
    "MWINCHIP3D", "MWINCHIPC6", "MCYRIXIII", "MELAN",
}
for symbol in cpu_choice:
    if symbol in current or symbol in requested:
        requested[symbol] = "n"
requested["MCORE2"] = "y"
requested["GENERIC_CPU"] = "n"

# Exactly one kernel image compressor and one debug-info mode are selected.
kernel_compression_choice = {
    "KERNEL_GZIP", "KERNEL_BZIP2", "KERNEL_LZMA", "KERNEL_XZ",
    "KERNEL_LZO", "KERNEL_LZ4", "KERNEL_ZSTD",
}
for symbol in kernel_compression_choice:
    if symbol in current or symbol in requested:
        requested[symbol] = "n"
requested["KERNEL_XZ"] = "y"

debug_info_choice = {
    "DEBUG_INFO_NONE", "DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT",
    "DEBUG_INFO_DWARF4", "DEBUG_INFO_DWARF5",
}
for symbol in debug_info_choice:
    if symbol in current or symbol in requested:
        requested[symbol] = "n"
requested["DEBUG_INFO_NONE"] = "y"

# The RT flavour replaces the normal preemption choice. Keep Debian's native
# normal choice unchanged for amd64, but select RT exclusively for amd64-rt.
if featureset == "rt":
    for symbol in ("PREEMPT_NONE", "PREEMPT_VOLUNTARY", "PREEMPT"):
        if symbol in current or symbol in requested:
            requested[symbol] = "n"
    requested["PREEMPT_RT"] = "y"
else:
    requested["PREEMPT_RT"] = "n"

sound_keep = {
    "SND", "SND_PCI", "SND_TIMER", "SND_PCM", "SND_HWDEP", "SND_HDA",
    "SND_HDA_INTEL", "SND_HDA_CODEC_SIGMATEL", "SND_HDA_CORE",
    "SND_HDA_COMPONENT", "SND_HDA_GENERIC", "SND_HDA_GENERIC_LEDS",
    "SND_INTEL_DSP_CONFIG", "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE",
    "SND_JACK", "SND_CTL_LED", "SND_VMASTER",
}
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

disable_reasons: dict[str, str] = {}
for symbol, value in requested.items():
    if value == "n":
        disable_reasons[symbol] = "explicit D630 policy"

for symbol in baseline:
    if symbol.startswith("SND_") and symbol not in sound_keep and baseline[symbol] in {"y", "m"}:
        requested[symbol] = "n"
        disable_reasons[symbol] = "unused sound device/codec"
    if ((symbol.endswith("_FS") and symbol not in filesystem_keep) or symbol in filesystem_extras) and baseline[symbol] in {"y", "m"}:
        requested[symbol] = "n"
        disable_reasons[symbol] = "unused filesystem/network filesystem"
    if any(symbol.startswith(prefix) for prefix in gpu_prefixes) and baseline[symbol] in {"y", "m"}:
        requested[symbol] = "n"
        disable_reasons[symbol] = "GPU vendor absent from D630"

# Critical settings must not be silently overwritten by trimming rules.
critical = {
    "MCORE2", "X86_MSR", "X86_CPUID", "MICROCODE", "MICROCODE_INTEL",
    "EXTRA_FIRMWARE", "EXTRA_FIRMWARE_DIR", "ZRAM", "ZRAM_DEF_COMP_LZ4",
    "ZRAM_BACKEND_LZO", "ZRAM_BACKEND_ZSTD", "ZRAM_BACKEND_LZ4",
    "ZRAM_BACKEND_LZ4HC", "ZRAM_BACKEND_DEFLATE", "ZRAM_BACKEND_842",
    "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "SQUASHFS", "SND", "SND_PCI",
    "SND_HDA", "SND_HDA_INTEL", "SND_HDA_CODEC_SIGMATEL", "IWL3945",
    "IWLEGACY", "CFG80211", "MAC80211", "MOUSE_PS2",
}
if critical.intersection(disable_reasons):
    bad = sorted(critical.intersection(disable_reasons))
    raise SystemExit("Internal policy contradiction: critical symbols marked disabled: " + ", ".join(bad))

# Enforce single-value choices before invoking Kconfig.
zram_choices = [s for s, v in requested.items() if s.startswith("ZRAM_DEF_COMP_") and v == "y"]
if zram_choices != ["ZRAM_DEF_COMP_LZ4"]:
    raise SystemExit(f"Expected exactly the LZ4 zram default choice before Kconfig; got {zram_choices}")
cpu_choices = sorted(s for s in cpu_choice if requested.get(s) == "y")
if cpu_choices != ["MCORE2"]:
    raise SystemExit(f"Expected only MCORE2 in the CPU choice; got {cpu_choices}")
kernel_choices = sorted(s for s in kernel_compression_choice if requested.get(s) == "y")
if kernel_choices != ["KERNEL_XZ"]:
    raise SystemExit(f"Expected only KERNEL_XZ in the image compression choice; got {kernel_choices}")
debug_choices = sorted(s for s in debug_info_choice if requested.get(s) == "y")
if debug_choices != ["DEBUG_INFO_NONE"]:
    raise SystemExit(f"Expected only DEBUG_INFO_NONE in the debug info choice; got {debug_choices}")
if featureset == "rt":
    rt_choices = sorted(s for s in ("PREEMPT_NONE", "PREEMPT_VOLUNTARY", "PREEMPT", "PREEMPT_RT") if requested.get(s) == "y")
    if rt_choices != ["PREEMPT_RT"]:
        raise SystemExit(f"Expected only PREEMPT_RT in the RT preemption choice; got {rt_choices}")

# Apply values by rewriting the existing generated config. Unlike merge_config,
# this does not produce a cascade of override warnings; olddefconfig then
# resolves dependencies and the separate audit validates its output.
lines = current_text.splitlines()
written: set[str] = set()
output: list[str] = []
for line in lines:
    match = re.match(r"^(?:CONFIG_([A-Z0-9_]+)=.*|# CONFIG_([A-Z0-9_]+) is not set)$", line)
    if not match:
        output.append(line)
        continue
    symbol = match.group(1) or match.group(2)
    if symbol not in requested:
        output.append(line)
        continue
    if symbol not in written:
        output.append(config_line(symbol, requested[symbol]))
        written.add(symbol)
# Existing generated .config should contain every Kconfig symbol. Add only
# requested names absent from the baseline so olddefconfig/audit can catch it.
for symbol in sorted(set(requested) - written):
    output.append(config_line(symbol, requested[symbol]))
config_path.write_text("\n".join(output) + "\n", encoding="utf-8")

with (audit / "policy-disabled-symbols.tsv").open("w", encoding="utf-8") as out:
    out.write("symbol\tpolicy\n")
    for symbol, reason in sorted(disable_reasons.items()):
        out.write(f"{symbol}\t{reason}\n")
with (audit / "policy-application.txt").open("w", encoding="utf-8") as out:
    out.write(f"Source: Debian Bookworm-backports linux 6.12.95-1~bpo12+1\n")
    out.write(f"Feature set: {featureset}\n")
    out.write(f"Native config: {config_path}\n")
    out.write("Method: direct .config edit followed by Kconfig olddefconfig; no merge_config/fragment override cascade.\n")
    out.write("zram default: exactly CONFIG_ZRAM_DEF_COMP_LZ4=y before olddefconfig.\n")
    out.write("SND_PCI and SigmaTel HDA dependencies are explicitly preserved.\n")
    out.write(f"Explicitly disabled symbols recorded: {len(disable_reasons)}\n")
print(f"Applied {len(requested)} D630 policy requests directly to {config_path}.")
print("No Debian rules/ABI/Makefile/localversion values were modified.")
