#!/usr/bin/env python3
"""Audit Debian's generated D630 config and record all deltas for Linux 6.12.95."""
from __future__ import annotations

from difflib import unified_diff
from pathlib import Path
import re
import sys

if len(sys.argv) != 6:
    raise SystemExit(
        "usage: audit-d630-6.12.95.py BASELINE FINAL OVERLAY AUDIT_DIR VARIANT"
    )
baseline_path, final_path, overlay_path, audit_path = map(Path, sys.argv[1:5])
variant = sys.argv[5]
if variant not in {"amd64", "amd64-rt"}:
    raise SystemExit("VARIANT must be amd64 or amd64-rt")
audit_path.mkdir(parents=True, exist_ok=True)

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

base = read_config(baseline_path)
final = read_config(final_path)
overlay = read_config(overlay_path)
errors: list[str] = []

def val(config: dict[str, str], symbol: str) -> str:
    return config.get(symbol, "n")

required = {
    "KERNEL_XZ": "y",
    "KERNEL_XZ": "y",
    "MCORE2": "y",
    "GENERIC_CPU": "n",
    "X86_MSR": "y",
    "X86_CPUID": "y",
    "MICROCODE": "y",
    "MICROCODE_INTEL": "y",
    "FW_LOADER": "y",
    "EXTRA_FIRMWARE": '"intel-ucode/06-0f-0d iwlwifi-3945-2.ucode"',
    "EXTRA_FIRMWARE_DIR": '"/lib/firmware"',
    "DEBUG_INFO_NONE": "y",
    "DEBUG_INFO": "n",
    "MODULES": "y",
    "MODULE_UNLOAD": "y",
    "MOUSE_PS2": "m",
    "INPUT_MOUSEDEV": "y",
    "INPUT_MOUSEDEV_PSAUX": "y",
    "EXT4_FS": "y",
    "BTRFS_FS": "y",
    "NTFS3_FS": "y",
    "NTFS3_LZX_XPRESS": "y",
    "FAT_FS": "y",
    "MSDOS_FS": "y",
    "VFAT_FS": "y",
    "EXFAT_FS": "y",
    "UDF_FS": "y",
    "ISO9660_FS": "m",
    "OVERLAY_FS": "y",
    "SQUASHFS": "y",
    "SQUASHFS_ZLIB": "y",
    "SQUASHFS_LZ4": "y",
    "SQUASHFS_LZO": "y",
    "SQUASHFS_XZ": "y",
    "SQUASHFS_ZSTD": "y",
    "NLS": "y",
    "NLS_UTF8": "y",
    "NLS_CODEPAGE_437": "y",
    "ZSMALLOC": "y",
    "ZRAM": "y",
    "ZRAM_DEF_COMP_LZ4": "y",
    "ZRAM_BACKEND_LZO": "y",
    "ZRAM_BACKEND_ZSTD": "y",
    "ZRAM_BACKEND_LZ4": "y",
    "ZRAM_BACKEND_LZ4HC": "y",
    "ZRAM_BACKEND_DEFLATE": "y",
    "ZRAM_BACKEND_842": "y",
    "WLAN": "y",
    "CFG80211": "m",
    "MAC80211": "m",
    "RFKILL": "y",
    "IWLEGACY": "m",
    "IWL3945": "m",
    "SOUND": "y",
    "SND": "y",
    "SND_PCI": "y",
    "SND_HDA": "y",
    "SND_HDA_INTEL": "m",
    "SND_HDA_CODEC_SIGMATEL": "m",
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
}
required["PREEMPT_RT"] = "y" if variant == "amd64-rt" else "n"
for symbol, expected in required.items():
    actual = val(final, symbol)
    if actual != expected:
        errors.append(f"CONFIG_{symbol}: expected {expected}, got {actual}")

# The compression default is a Kconfig choice: exactly one backend must be selected.
zram_choice = sorted(s for s, value in final.items() if s.startswith("ZRAM_DEF_COMP_") and value == "y")
if zram_choice != ["ZRAM_DEF_COMP_LZ4"]:
    errors.append(f"zram default choice must be only ZRAM_DEF_COMP_LZ4, got {zram_choice}")

# Validate the effective Kconfig choices after Kconfig has resolved dependencies.
cpu_choice = {
    "M386", "M486", "M486SX", "M586", "M586TSC", "M586MMX", "M686",
    "MPENTIUMII", "MPENTIUMIII", "MPENTIUMM", "MPENTIUM4", "MK6", "MK7",
    "MK8", "MK8SSE3", "MCRUSOE", "MEFFICEON", "MATOM", "MCORE2", "MGEODEGX1",
    "MGEODE_LX", "MPSC", "X86_GENERIC", "GENERIC_CPU", "MVIAC3_2", "MVIAC7",
    "MWINCHIP3D", "MWINCHIPC6", "MCYRIXIII", "MELAN",
}
chosen_cpu = sorted(s for s in cpu_choice if val(final, s) == "y")
if chosen_cpu != ["MCORE2"]:
    errors.append(f"CPU choice must be only MCORE2, got {chosen_cpu}")

kernel_compression_choice = {
    "KERNEL_GZIP", "KERNEL_BZIP2", "KERNEL_LZMA", "KERNEL_XZ",
    "KERNEL_LZO", "KERNEL_LZ4", "KERNEL_ZSTD",
}
chosen_kernel_compression = sorted(s for s in kernel_compression_choice if val(final, s) == "y")
if chosen_kernel_compression != ["KERNEL_XZ"]:
    errors.append(f"kernel image compression choice must be only KERNEL_XZ, got {chosen_kernel_compression}")

debug_info_choice = {
    "DEBUG_INFO_NONE", "DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT",
    "DEBUG_INFO_DWARF4", "DEBUG_INFO_DWARF5",
}
chosen_debug_info = sorted(s for s in debug_info_choice if val(final, s) == "y")
if chosen_debug_info != ["DEBUG_INFO_NONE"]:
    errors.append(f"debug information choice must be only DEBUG_INFO_NONE, got {chosen_debug_info}")

preemption_choice = ("PREEMPT_NONE", "PREEMPT_VOLUNTARY", "PREEMPT", "PREEMPT_RT")
chosen_preemption = sorted(s for s in preemption_choice if val(final, s) == "y")
if variant == "amd64-rt":
    if chosen_preemption != ["PREEMPT_RT"]:
        errors.append(f"RT preemption choice must be only PREEMPT_RT, got {chosen_preemption}")
else:
    base_preemption = sorted(s for s in preemption_choice if val(base, s) == "y")
    if val(final, "PREEMPT_RT") != "n":
        errors.append(f"normal kernel must have PREEMPT_RT=n, got {val(final, 'PREEMPT_RT')}")
    if chosen_preemption != base_preemption:
        errors.append(f"normal preemption choice changed from Debian baseline {base_preemption} to {chosen_preemption}")

# Confirm Debian's generated hardware and firewall infrastructure wasn't
# accidentally lost or changed while trimming unrelated D630-absent drivers.
preserve = (
    "DRM", "DRM_I915", "AGP_INTEL", "SCSI", "SCSI_MOD", "SCSI_COMMON",
    "BLK_DEV_SD", "BLK_DEV_SR", "USB_STORAGE", "ATA", "SATA_AHCI", "ATA_PIIX",
    "NF_TABLES", "NETFILTER", "NFT_FIB_INET", "NFT_FIB_IPV4", "NFT_FIB_IPV6",
)
for symbol in preserve:
    old, new = val(base, symbol), val(final, symbol)
    if old in {"y", "m"} and old != new:
        errors.append(f"CONFIG_{symbol} changed from Debian baseline {old} to {new}")

policy_file = audit_path / "policy-disabled-symbols.tsv"
policy_symbols: set[str] = set()
if policy_file.is_file():
    for line in policy_file.read_text(encoding="utf-8").splitlines()[1:]:
        if line.strip():
            policy_symbols.add(line.split("\t", 1)[0])

sound_keep = {
    "SND", "SND_PCI", "SND_TIMER", "SND_PCM", "SND_HWDEP", "SND_HDA", "SND_HDA_INTEL",
    "SND_HDA_CODEC_SIGMATEL", "SND_HDA_CORE", "SND_HDA_COMPONENT",
    "SND_HDA_GENERIC", "SND_HDA_GENERIC_LEDS", "SND_INTEL_DSP_CONFIG",
    "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE", "SND_JACK", "SND_CTL_LED", "SND_VMASTER",
}
fs_keep = {
    "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "FAT_FS", "MSDOS_FS", "VFAT_FS",
    "EXFAT_FS", "UDF_FS", "ISO9660_FS", "SQUASHFS", "OVERLAY_FS", "FUSE_FS",
    "PROC_FS", "DEVPTS_FS", "CONFIGFS_FS", "DEBUG_FS",
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
parent_prefixes = {
    "CAN": ("CAN_", "NET_EMATCH_CANID"),
    "ISDN": ("ISDN", "MISDN", "BT_CMTP"),
    "INFINIBAND": ("INFINIBAND", "RDMA", "MLX4_INFINIBAND", "MLX5_INFINIBAND"),
    "FIREWIRE": ("FIREWIRE", "SBP_TARGET", "SND_FIREWIRE", "SND_FIREWORKS",
                 "SND_BEBOB", "SND_DICE", "SND_FIREFACE", "SND_ISIGHT", "SND_OXFW"),
    "NFC": ("NFC",),
    "WIMAX": ("WIMAX",),
    "IEEE802154": ("IEEE802154", "MAC802154"),
    "6LOWPAN": ("6LOWPAN", "BT_6LOWPAN"),
    "USB_GADGET": ("USB_GADGET", "USBIP_VUDC", "USB_DUMMY_HCD", "USB_FUNCTIONFS",
                   "USB_LIBCOMPOSITE", "USB_CONFIGFS", "USB_F_", "USB_U_"),
    "BLK_DEV_NVME": ("NVME", "BLK_DEV_NVME"),
    "MEDIA_DIGITAL_TV_SUPPORT": ("DVB", "MANTIS_CORE", "MEDIA_ALTERA_CI",
        "SMS_SDIO_DRV", "SMS_SIANO_MDTV", "SMS_USB_DRV", "TTPCI_EEPROM",
        "VIDEO_AU0828", "VIDEO_BT848", "VIDEO_CX18", "VIDEO_CX23885",
        "VIDEO_CX88_VP3054", "VIDEO_PVRUSB2", "VIDEO_SAA7164", "VIDEOBUF_DMA_SG",
        "VIDEOBUF_GEN", "VIDEOBUF_VMALLOC"),
    "MEDIA_RADIO_SUPPORT": ("RADIO_", "RADIO_ADAPTERS", "USB_DSBR", "USB_KEENE",
        "USB_MA901", "USB_MR800", "USB_RAREMONO", "USB_SI470X"),
    "MEDIA_SDR_SUPPORT": ("USB_AIRSPY", "USB_HACKRF", "USB_MSI2500"),
    "MEDIA_TEST_SUPPORT": ("VIDEO_VIM2M", "VIDEO_VICODEC", "VIDEO_VIMC",
        "VIDEO_VIVID", "VIDEO_V4L2_TPG", "DVB_VIDTV"),
    "SCSI_LOWLEVEL": ("SCSI_", "ISCSI_", "SGIWD93_SCSI", "BLK_DEV_3W_",
        "VMWARE_PVSCSI", "XEN_SCSI_FRONTEND", "HYPERV_STORAGE", "LIBFC", "LIBFCOE",
        "FCOE", "ZFCP", "53C700_", "A3000_SCSI", "A2091_SCSI", "GVP11_SCSI",
        "ATARI_SCSI", "MAC_SCSI", "MVME147_SCSI", "MVME16", "BVME6000_SCSI",
        "SUN3_SCSI", "SUN3X_ESP", "JAZZ_ESP", "QEDI", "BE2ISCSI", "MEGARAID_",
        "LIBCXGBI", "CXGB"),
    "MTD": ("MTD", "FTL", "INFTL", "NFTL", "RFD_FTL", "SSFDC", "JFFS2_FS", "UBIFS_FS"),
    "XEN": ("XEN",),
    "VIRTIO": ("VIRTIO_",),
    "EFI": ("EFI_",),
}
scsi_core = {
    "SCSI", "SCSI_MOD", "SCSI_COMMON", "SCSI_DMA", "SCSI_NETLINK", "SCSI_PROC_FS",
    "SCSI_CONSTANTS", "SCSI_LOGGING", "SCSI_SCAN_ASYNC", "BLK_DEV_SD", "BLK_DEV_SR",
    "USB_STORAGE", "SATA_AHCI", "ATA_PIIX",
}

def parent_disabled(symbol: str) -> bool:
    if symbol in policy_symbols:
        return True
    if symbol.startswith("SND_") and symbol not in sound_keep:
        return True
    if (symbol.endswith("_FS") and symbol not in fs_keep) or symbol in {
        "CIFS", "CIFS_UPCALL", "CIFS_XATTR", "CIFS_POSIX", "NFS_V2", "NFS_V3",
        "NFS_V4", "NFS_SWAP", "NFSD", "NFSD_V2", "NFSD_V3", "NFSD_V4",
        "SMB_SERVER", "SMB_SERVER_SMBDIRECT",
    }:
        return True
    if any(symbol.startswith(prefix) for prefix in gpu_prefixes):
        return True
    if symbol.startswith("SCSI_") and symbol not in scsi_core and val(final, "SCSI_LOWLEVEL") == "n":
        return True
    for parent, prefixes in parent_prefixes.items():
        if val(final, parent) == "n" and any(symbol.startswith(p) for p in prefixes):
            return True
    if symbol.endswith("_DVB") and val(final, "MEDIA_DIGITAL_TV_SUPPORT") == "n":
        return True
    if symbol in {
        "AC97_BUS", "CS_DSP", "HDMI_LPE_AUDIO", "GRACE_PERIOD", "SMBFS", "LOCKD",
        "SUNRPC", "SUNRPC_GSS", "RPCSEC_GSS_KRB5", "PNFS_BLOCK", "PNFS_FILE_LAYOUT",
        "PNFS_FLEXFILE_LAYOUT", "OCFS2_FS_O2CB", "OCFS2_FS_USERSPACE_CLUSTER", "CUSE",
        "FUSE_FS",
    }:
        return True
    return False

diff = list(unified_diff(
    baseline_path.read_text(errors="replace").splitlines(),
    final_path.read_text(errors="replace").splitlines(),
    fromfile="Debian-generated baseline", tofile="final D630 config", lineterm="",
))
(audit_path / "d630-config.diff").write_text("\n".join(diff) + "\n", encoding="utf-8")

changes: list[str] = []
unclassified: list[str] = []
for symbol in sorted(set(base) | set(final)):
    old, new = val(base, symbol), val(final, symbol)
    if old == new:
        continue
    if old == "m" and new == "n":
        classified = parent_disabled(symbol)
        classification = "intentional trim/dependency" if classified else "unclassified m-to-n change; review"
        if not classified:
            unclassified.append(symbol)
    elif old == "m" and new == "y":
        classification = "promoted to built-in"
    elif new == "n":
        classification = "disabled by explicit policy/Kconfig"
    elif new == "m":
        classification = "enabled as module"
    elif new == "y":
        classification = "enabled as built-in"
    else:
        classification = "value changed"
    changes.append(f"{symbol}\t{old}\t{new}\t{classification}")

(audit_path / "d630-config-symbol-audit.tsv").write_text(
    "symbol\tdebian_baseline\tfinal\tclassification\n" + "\n".join(changes) + "\n",
    encoding="utf-8",
)
(audit_path / "unclassified-module-drops.txt").write_text(
    "\n".join("CONFIG_" + s for s in unclassified) + ("\n" if unclassified else ""),
    encoding="utf-8",
)

summary = [
    "Source: Debian Bookworm backports linux 6.12.95-1~bpo12+1",
    f"Variant: {variant}",
    f"Baseline: {baseline_path}",
    f"Final config: {final_path}",
    f"Changed symbols: {len(changes)}",
    f"Unclassified Debian module m-to-n changes: {len(unclassified)} (reported for review)",
    "Core CPU, embedded firmware, zram compressors, filesystems, Wi-Fi/audio modules, i915/storage/nftables and RT flavour are hard-asserted.",
]
(audit_path / "config-audit-summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")

if errors:
    print("\n".join("FAIL: " + error for error in errors), file=sys.stderr)
    print(f"See {audit_path / 'd630-config-symbol-audit.tsv'}", file=sys.stderr)
    raise SystemExit(1)

print("\n".join(summary))
if unclassified:
    print("FAIL: unclassified Debian m-to-n transitions remain:", file=sys.stderr)
    print("\n".join("CONFIG_" + symbol for symbol in unclassified), file=sys.stderr)
    print("Review unclassified-module-drops.txt and classify or preserve these symbols before compiling.", file=sys.stderr)
    raise SystemExit(1)
print("PASS: required D630 kernel configuration verified; no unexplained module removals.")
