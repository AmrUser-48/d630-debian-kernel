#!/usr/bin/env python3
"""Audit the effective Debian 6.1.180 D630 kernel config and report all deltas."""
from __future__ import annotations

from pathlib import Path
import difflib
import re
import sys

if len(sys.argv) != 6:
    raise SystemExit(
        "usage: audit-d630-6.1.180.py BASELINE FINAL OVERLAY AUDIT_DIR VARIANT"
    )
baseline_path, final_path, overlay_path, audit_path = map(Path, sys.argv[1:5])
variant = sys.argv[5]
if variant not in {"amd64", "amd64-rt"}:
    raise SystemExit("variant must be amd64 or amd64-rt")
audit_path.mkdir(parents=True, exist_ok=True)
baseline_path, final_path = baseline_path.resolve(), final_path.resolve()
overlay_path = overlay_path.resolve()

def read_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(errors="replace").splitlines():
        match = re.match(r"^CONFIG_([A-Z0-9_]+)=(.*)$", line)
        if match:
            values[match.group(1)] = match.group(2)
            continue
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
    "MCORE2": "y", "GENERIC_CPU": "n", "X86_MSR": "y", "X86_CPUID": "y",
    "MICROCODE": "y", "MICROCODE_INTEL": "y", "FW_LOADER": "y",
    "EXTRA_FIRMWARE": '"intel-ucode/06-0f-0d iwlwifi-3945-2.ucode"',
    "EXTRA_FIRMWARE_DIR": '"/lib/firmware"',
    "MODULES": "y", "MODULE_UNLOAD": "y", "DEBUG_INFO_NONE": "y", "DEBUG_INFO": "n",
    "KERNEL_XZ": "y",
    "EXT4_FS": "y", "BTRFS_FS": "y", "NTFS3_FS": "y", "NTFS3_LZX_XPRESS": "y",
    "FAT_FS": "y", "MSDOS_FS": "y", "VFAT_FS": "y", "EXFAT_FS": "y", "UDF_FS": "y",
    "SQUASHFS": "y", "SQUASHFS_ZLIB": "y", "SQUASHFS_LZ4": "y",
    "SQUASHFS_LZO": "y", "SQUASHFS_XZ": "y", "SQUASHFS_ZSTD": "y",
    "ZSMALLOC": "y", "ZRAM": "y", "ZRAM_DEF_COMP_LZ4": "y",
    "CRYPTO_LZO": "y", "CRYPTO_ZSTD": "y", "CRYPTO_LZ4": "y",
    "CRYPTO_LZ4HC": "y", "CRYPTO_842": "y",
    "LZO_COMPRESS": "y", "LZO_DECOMPRESS": "y",
    "LZ4_COMPRESS": "y", "LZ4_DECOMPRESS": "y", "LZ4HC_COMPRESS": "y",
    "ZSTD_COMPRESS": "y", "ZSTD_DECOMPRESS": "y",
    "NLS": "y", "NLS_UTF8": "y", "NLS_CODEPAGE_437": "y",
    "WLAN": "y", "CFG80211": "m", "MAC80211": "m", "RFKILL": "y",
    "IWLEGACY": "m", "IWL3945": "m",
    "SOUND": "y", "SND": "y", "SND_HDA": "y",
    "SND_HDA_INTEL": "m", "SND_HDA_CODEC_SIGMATEL": "m",
    "DVB_CORE": "n", "MEDIA_DIGITAL_TV_SUPPORT": "n",
    "MEDIA_RADIO_SUPPORT": "n", "MEDIA_SDR_SUPPORT": "n", "MEDIA_TEST_SUPPORT": "n",
    "CAN": "n", "ISDN": "n", "INFINIBAND": "n", "FIREWIRE": "n",
    "NFC": "n", "WIMAX": "n", "IEEE802154": "n", "6LOWPAN": "n",
    "USB_GADGET": "n", "MTD": "n", "BLK_DEV_NVME": "n", "SCSI_LOWLEVEL": "n",
}
required["PREEMPT_RT"] = "y" if variant == "amd64-rt" else "n"
for symbol, expected in required.items():
    actual = val(final, symbol)
    if actual != expected:
        errors.append(f"CONFIG_{symbol}: expected {expected}, got {actual}")

# These must stay at Debian's generated values. This specifically protects
# Intel i915/AGP, normal disk and USB storage, and firewall/netfilter support.
preserve = (
    "DRM", "DRM_I915", "AGP_INTEL", "SND_PCI", "SCSI", "SCSI_MOD", "SCSI_COMMON",
    "BLK_DEV_SD", "BLK_DEV_SR", "USB_STORAGE", "ATA", "SATA_AHCI", "ATA_PIIX",
    "NF_TABLES", "NETFILTER", "NFT_FIB_INET", "NFT_FIB_IPV4", "NFT_FIB_IPV6",
    "INPUT_MOUSEDEV", "INPUT_MOUSEDEV_PSAUX",
)
for symbol in preserve:
    old, new = val(base, symbol), val(final, symbol)
    if old in {"y", "m"} and old != new:
        errors.append(f"CONFIG_{symbol} changed from Debian baseline {old} to {new}")

# Any Debian module change is recorded. Changes produced by the explicitly
# documented sound, filesystem, GPU, and excluded-parent policies are classified
# as intentional; other m -> n changes are highlighted for review, not silently
# accepted as a successful core-hardware check.
policy_symbols: set[str] = set()
policy_file = audit_path / "policy-disabled-symbols.tsv"
if policy_file.is_file():
    for line in policy_file.read_text().splitlines()[1:]:
        if line.strip():
            policy_symbols.add(line.split("\t", 1)[0])

sound_keep = {
    "SND", "SND_TIMER", "SND_PCM", "SND_HWDEP", "SND_HDA", "SND_HDA_INTEL",
    "SND_PCI", "SND_HDA_CODEC_SIGMATEL", "SND_HDA_CORE", "SND_HDA_COMPONENT",
    "SND_HDA_GENERIC", "SND_HDA_GENERIC_LEDS", "SND_INTEL_DSP_CONFIG",
    "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE", "SND_JACK", "SND_CTL_LED", "SND_VMASTER",
}
fs_keep = {
    "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "FAT_FS", "MSDOS_FS", "VFAT_FS",
    "EXFAT_FS", "UDF_FS", "ISO9660_FS", "SQUASHFS", "PROC_FS", "DEVPTS_FS",
    "CONFIGFS_FS", "DEBUG_FS",
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
    "ISDN": ("MISDN", "BT_CMTP", "ISDN"),
    "INFINIBAND": ("INFINIBAND", "RDMA", "MLX4_INFINIBAND", "MLX5_INFINIBAND"),
    "FIREWIRE": ("FIREWIRE", "SBP_TARGET", "SND_FIREWIRE", "SND_FIREWORKS",
                 "SND_BEBOB", "SND_DICE", "SND_FIREFACE", "SND_ISIGHT", "SND_OXFW"),
    "NFC": ("NFC",), "WIMAX": ("WIMAX",),
    "IEEE802154": ("IEEE802154", "MAC802154"), "6LOWPAN": ("6LOWPAN", "BT_6LOWPAN"),
    "USB_GADGET": ("USB_GADGET", "USBIP_VUDC", "USB_DUMMY_HCD", "USB_FUNCTIONFS",
                   "USB_LIBCOMPOSITE", "USB_CONFIGFS", "USB_F_", "USB_U_"),
    "BLK_DEV_NVME": ("NVME", "BLK_DEV_NVME"),
    "MEDIA_DIGITAL_TV_SUPPORT": ("DVB", "MANTIS_CORE", "MEDIA_ALTERA_CI",
                                 "SMS_SDIO_DRV", "SMS_SIANO_MDTV", "SMS_USB_DRV",
                                 "TTPCI_EEPROM", "VIDEO_AU0828", "VIDEO_BT848",
                                 "VIDEO_CX18", "VIDEO_CX23885", "VIDEO_CX88_VP3054",
                                 "VIDEO_PVRUSB2", "VIDEO_SAA7164", "VIDEOBUF_DMA_SG",
                                 "VIDEOBUF_GEN", "VIDEOBUF_VMALLOC"),
    "MEDIA_RADIO_SUPPORT": ("RADIO_", "RADIO_ADAPTERS", "USB_DSBR", "USB_KEENE",
                            "USB_MA901", "USB_MR800", "USB_RAREMONO", "USB_SI470X"),
    "MEDIA_SDR_SUPPORT": ("USB_AIRSPY", "USB_HACKRF", "USB_MSI2500"),
    "MEDIA_TEST_SUPPORT": ("VIDEO_VIM2M", "VIDEO_VICODEC", "VIDEO_VIMC",
                           "VIDEO_VIVID", "VIDEO_V4L2_TPG", "DVB_VIDTV"),
    "SCSI_LOWLEVEL": ("SCSI_", "ISCSI_", "SGIWD93_SCSI", "BLK_DEV_3W_",
                      "VMWARE_PVSCSI", "XEN_SCSI_FRONTEND", "HYPERV_STORAGE",
                      "LIBFC", "LIBFCOE", "FCOE", "ZFCP", "53C700_", "A3000_SCSI",
                      "A2091_SCSI", "GVP11_SCSI", "ATARI_SCSI", "MAC_SCSI",
                      "MVME147_SCSI", "MVME16", "BVME6000_SCSI", "SUN3_SCSI",
                      "SUN3X_ESP", "JAZZ_ESP", "QEDI", "BE2ISCSI", "MEGARAID_",
                      "LIBCXGBI", "CXGB"),
    "MTD": ("MTD", "FTL", "INFTL", "NFTL", "RFD_FTL", "SSFDC", "JFFS2_FS", "UBIFS_FS", "BCH"),
    "XEN": ("XEN",), "VIRTIO": ("VIRTIO_",),
}
core_scsi = {
    "SCSI", "SCSI_MOD", "SCSI_COMMON", "SCSI_DMA", "SCSI_NETLINK", "SCSI_PROC_FS",
    "SCSI_CONSTANTS", "SCSI_LOGGING", "SCSI_SCAN_ASYNC", "BLK_DEV_SD", "BLK_DEV_SR",
    "USB_STORAGE", "SATA_AHCI", "ATA_PIIX",
}

def intentional_drop(symbol: str) -> bool:
    if symbol in policy_symbols:
        return True
    if symbol.startswith("SND_") and symbol not in sound_keep:
        return True
    if (symbol.endswith("_FS") and symbol not in fs_keep) or symbol in {
        "CIFS", "CIFS_UPCALL", "CIFS_XATTR", "CIFS_POSIX", "NFS_V2", "NFS_V3",
        "NFS_V4", "NFS_SWAP", "NFSD", "NFSD_V2", "NFSD_V3", "NFSD_V4",
        "SMB_SERVER", "SMB_SERVER_SMBDIRECT", "SMBFS", "LOCKD", "SUNRPC",
        "SUNRPC_GSS", "RPCSEC_GSS_KRB5", "PNFS_BLOCK", "PNFS_FILE_LAYOUT",
        "PNFS_FLEXFILE_LAYOUT", "OCFS2_FS_O2CB", "OCFS2_FS_USERSPACE_CLUSTER",
        "CUSE", "FUSE_FS",
    }:
        return True
    if any(symbol.startswith(prefix) for prefix in gpu_prefixes):
        return True
    if symbol in {"AC97_BUS", "CS_DSP", "REGMAP_SOUNDWIRE", "REGMAP_SOUNDWIRE_MBQ",
                  "HDMI_LPE_AUDIO", "GRACE_PERIOD", "VIRTIO_DMA_SHARED_BUFFER",
                  "XEN_FRONT_PGDIR_SHBUF"}:
        return True
    if symbol.startswith("SCSI_") and symbol not in core_scsi and val(final, "SCSI_LOWLEVEL") == "n":
        return True
    for parent, prefixes in parent_prefixes.items():
        if val(final, parent) == "n" and any(symbol.startswith(p) for p in prefixes):
            return True
    if symbol.endswith("_DVB") and val(final, "MEDIA_DIGITAL_TV_SUPPORT") == "n":
        return True
    return False

changes = []
unexpected_drops = []
diff = list(difflib.unified_diff(
    baseline_path.read_text(errors="replace").splitlines(),
    final_path.read_text(errors="replace").splitlines(),
    fromfile="Debian-generated baseline", tofile="final D630 config", lineterm="",
))
(audit_path / "d630-config.diff").write_text("\n".join(diff) + "\n", encoding="utf-8")

for symbol in sorted(set(base) | set(final)):
    old, new = val(base, symbol), val(final, symbol)
    if old == new:
        continue
    if new == "n" and old == "m":
        classification = "intentional policy/dependency" if intentional_drop(symbol) else "unclassified module drop — review"
        if not intentional_drop(symbol):
            unexpected_drops.append(symbol)
    elif old == "m" and new == "y":
        classification = "promoted to built-in"
    elif new == "n":
        classification = "disabled by config policy/Kconfig"
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
    "\n".join("CONFIG_" + s for s in unexpected_drops) + ("\n" if unexpected_drops else ""),
    encoding="utf-8",
)

report = [
    f"Variant: {variant}",
    f"Baseline config: {baseline_path}",
    f"Final config: {final_path}",
    f"Symbols changed: {len(changes)}",
    f"Unclassified Debian m -> n transitions: {len(unexpected_drops)}",
    "Unclassified transitions are included in the TSV and are not allowed to hide any of the explicitly asserted critical hardware symbols.",
    "Critical checks: Core 2 target, embedded CPU+Wi-Fi firmware, zram compressors, filesystem support, audio, Wi-Fi, PREEMPT_RT flavour, i915 baseline, storage, and nftables baseline.",
]
(audit_path / "config-audit-summary.txt").write_text("\n".join(report) + "\n", encoding="utf-8")

if errors:
    print("\n".join("FAIL: " + e for e in errors), file=sys.stderr)
    print(f"See {audit_path / 'd630-config-symbol-audit.tsv'}", file=sys.stderr)
    raise SystemExit(1)

print("\n".join(report))
if unexpected_drops:
    print("WARNING: review unclassified m -> n changes in unclassified-module-drops.txt")
print("PASS: required D630 kernel config settings verified.")
