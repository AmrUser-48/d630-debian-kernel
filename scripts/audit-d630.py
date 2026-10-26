#!/usr/bin/env python3
"""Audit the effective Debian 6.1.180 D630 kernel config and report all deltas."""
from __future__ import annotations

from pathlib import Path
import difflib
import re
import sys

from d630_kconfig import read_config

if len(sys.argv) != 6:
    raise SystemExit(
        "usage: audit-d630.py BASELINE FINAL OVERLAY AUDIT_DIR VARIANT"
    )
baseline_path, final_path, overlay_path, audit_path = map(Path, sys.argv[1:5])
variant = sys.argv[5]
if variant != "amd64":
    raise SystemExit("only variant amd64 is supported")
audit_path.mkdir(parents=True, exist_ok=True)
baseline_path, final_path = baseline_path.resolve(), final_path.resolve()
overlay_path = overlay_path.resolve()

base = read_config(baseline_path)
final = read_config(final_path)
overlay = read_config(overlay_path)
errors: list[str] = []

def val(config: dict[str, str], symbol: str) -> str:
    return config.get(symbol, "n")

required = {
    "MCORE2": "y", "GENERIC_CPU": "n", "X86_MSR": "y", "X86_CPUID": "y",
    "CPU_FREQ": "y", "CPU_FREQ_GOV_USERSPACE": "y", "X86_ACPI_CPUFREQ": "m",
    "MICROCODE": "y", "MICROCODE_INTEL": "y", "FW_LOADER": "y",
    "EXTRA_FIRMWARE": '"intel-ucode/06-0f-0d iwlwifi-3945-2.ucode"',
    "EXTRA_FIRMWARE_DIR": '"/lib/firmware"',
    "MODULES": "y", "MODULE_UNLOAD": "y", "DEBUG_INFO_NONE": "y", "DEBUG_INFO": "n",
    "KERNEL_XZ": "y",
    "MODULE_COMPRESS_NONE": "n", "MODULE_COMPRESS_GZIP": "n",
    "MODULE_COMPRESS_XZ": "n", "MODULE_COMPRESS_ZSTD": "y", "SND_USB": "y",
    "AUTOFS4_FS": "y", "AUTOFS_FS": "y", "FUSE_FS": "m", "CUSE": "m",
    "OVERLAY_FS": "m", "EFI": "y", "EFIVAR_FS": "m",
    "XFS_FS": "m", "F2FS_FS": "m", "EROFS_FS": "m",
    "NETWORK_FILESYSTEMS": "y", "NFS_FS": "m", "NFS_V2": "n",
    "NFS_V3": "m", "NFS_V4": "m", "NFSD": "m", "NFSD_V4": "n",
    "CIFS": "m", "SMB_SERVER": "m",
    "EXT4_FS": "y", "BTRFS_FS": "y", "NTFS3_FS": "y", "NTFS3_LZX_XPRESS": "y",
    "FAT_FS": "y", "MSDOS_FS": "y", "VFAT_FS": "y", "EXFAT_FS": "y", "UDF_FS": "y",
    "SQUASHFS": "y", "SQUASHFS_ZLIB": "y", "SQUASHFS_LZ4": "y",
    "SQUASHFS_LZO": "y", "SQUASHFS_XZ": "y", "SQUASHFS_ZSTD": "y",
    "ZSMALLOC": "y", "ZRAM": "y", "ZRAM_DEF_COMP_LZ4": "y",
    "ZRAM_DEF_COMP_LZORLE": "n", "ZRAM_DEF_COMP_ZSTD": "n",
    "ZRAM_DEF_COMP_LZO": "n", "ZRAM_DEF_COMP_LZ4HC": "n", "ZRAM_DEF_COMP_842": "n",
    "CRYPTO_LZO": "y", "CRYPTO_ZSTD": "y", "CRYPTO_LZ4": "y",
    "CRYPTO_LZ4HC": "y", "CRYPTO_842": "y",
    "LZO_COMPRESS": "y", "LZO_DECOMPRESS": "y",
    "LZ4_COMPRESS": "y", "LZ4_DECOMPRESS": "y", "LZ4HC_COMPRESS": "y",
    "ZSTD_COMPRESS": "y", "ZSTD_DECOMPRESS": "y",
    "NLS": "y", "NLS_UTF8": "y", "NLS_CODEPAGE_437": "y",
    "WLAN": "y", "CFG80211": "m", "MAC80211": "m", "RFKILL": "y",
    "IWLEGACY": "m", "IWL3945": "m", "IWL4965": "m",
    "IWLWIFI": "m", "IWLDVM": "m", "IWLMVM": "m",
    "SOUND": "y", "SND": "y", "SND_DRIVERS": "y", "SND_PCI": "y", "SND_HDA": "m",
    "SND_PCM_TIMER": "y", "SND_TIMER": "m", "SND_HDA_CORE": "m",
    "SND_HDA_GENERIC": "m", "SND_PCM": "m",
    "SND_HDA_INTEL": "m", "SND_HDA_CODEC_SIGMATEL": "m",
    "SND_HDA_CODEC_REALTEK": "m", "SND_USB": "y", "SND_USB_AUDIO": "m",
    "SND_SEQUENCER": "m", "SND_RAWMIDI": "m", "SND_VIRMIDI": "m",
    "SND_HWDEP": "m", "SND_HRTIMER": "m", "SND_SEQ_HRTIMER_DEFAULT": "y",
    "SND_OPL3_LIB": "m", "SND_OPL3_LIB_SEQ": "m",
    "SND_SEQ_DEVICE": "m", "SND_SEQ_DUMMY": "m", "SND_SEQ_MIDI": "m",
    "SND_SEQ_MIDI_EVENT": "m", "SND_SEQ_VIRMIDI": "m", "SND_SEQ_MIDI_EMUL": "m",
    "SCSI_LOWLEVEL": "y", "SCSI_DH": "y",
    "SCSI_DH_ALUA": "m", "SCSI_DH_EMC": "m", "SCSI_DH_HP_SW": "m",
    "SCSI_DH_RDAC": "m", "ISCSI_TCP": "m",
    "MEGARAID_SAS": "m", "SCSI_MPT2SAS": "m", "SCSI_MPT3SAS": "m",
    "SCSI_SMARTPQI": "m", "SCSI_HPSA": "m", "SCSI_AACRAID": "m",
    "SCSI_AIC7XXX": "m", "SCSI_AIC79XX": "m",
    "VIRTIO_MENU": "y", "VIRTIO_PCI": "m", "VIRTIO_BLK": "m",
    "VIRTIO_NET": "m", "VIRTIO_CONSOLE": "m", "VIRTIO_BALLOON": "m",
    "VIRTIO_INPUT": "m", "VIRTIO_MMIO": "m", "DRM_VIRTIO_GPU": "m",
    "VIRTIO_FS": "m", "XEN": "y", "XEN_PVHVM_GUEST": "y",
    "XEN_PVH": "y", "XEN_BLKDEV_FRONTEND": "m",
    "XEN_NETDEV_FRONTEND": "m", "XEN_SCSI_FRONTEND": "m", "HVC_XEN": "y",
    "DVB_CORE": "n", "MEDIA_DIGITAL_TV_SUPPORT": "n",
    "MEDIA_RADIO_SUPPORT": "n", "MEDIA_SDR_SUPPORT": "n", "MEDIA_TEST_SUPPORT": "n",
    "CAN": "n", "ISDN": "n", "INFINIBAND": "n", "FIREWIRE": "n",
    "NFC": "n", "WIMAX": "n", "IEEE802154": "n", "6LOWPAN": "n",
    "USB_GADGET": "n", "MTD": "n", "BLK_DEV_NVME": "n",
}
required["PREEMPT_RT"] = "n"
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
    "EFI", "EFI_STUB", "EFI_MIXED", "LOCK_DOWN_IN_EFI_SECURE_BOOT",
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
    "SND", "SND_DRIVERS", "SND_TIMER", "SND_PCM_TIMER", "SND_PCM", "SND_HDA", "SND_HDA_INTEL",
    "SND_PCI", "SND_HDA_CODEC_SIGMATEL", "SND_HDA_CODEC_REALTEK", "SND_USB", "SND_USB_AUDIO",
    "SND_SEQ_DUMMY", "SND_SEQ_MIDI", "SND_SEQ_MIDI_EMUL", "SND_SEQ_MIDI_EVENT",
    "SND_VIRMIDI", "SND_SEQ_VIRMIDI", "SND_SEQUENCER", "SND_SEQ_DEVICE", "SND_RAWMIDI",
    "SND_HWDEP", "SND_HRTIMER", "SND_SEQ_HRTIMER_DEFAULT",
    "SND_OPL3_LIB", "SND_OPL3_LIB_SEQ", "SND_HDA_CORE", "SND_HDA_COMPONENT",
    "SND_HDA_GENERIC", "SND_HDA_GENERIC_LEDS", "SND_INTEL_DSP_CONFIG",
    "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE", "SND_JACK", "SND_CTL_LED", "SND_VMASTER",
}
fs_keep = {
    "AUTOFS4_FS", "AUTOFS_FS", "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "FAT_FS",
    "MSDOS_FS", "VFAT_FS", "EXFAT_FS", "UDF_FS", "ISO9660_FS", "SQUASHFS",
    "FUSE_FS", "OVERLAY_FS", "EFIVAR_FS", "XFS_FS", "F2FS_FS", "EROFS_FS",
    "PROC_FS", "DEVPTS_FS", "CONFIGFS_FS", "DEBUG_FS",
}
gpu_prefixes = (
    "DRM_AMDGPU", "DRM_RADEON", "DRM_NOUVEAU", "DRM_NVIDIA", "DRM_VMWGFX",
    "DRM_QXL", "DRM_GMA500", "DRM_AST", "DRM_BOCHS",
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
    "XEN": ("XEN",), "VIRTIO_MENU": ("VIRTIO_",),
}
core_scsi = {
    "SCSI", "SCSI_MOD", "SCSI_COMMON", "SCSI_DMA", "SCSI_NETLINK", "SCSI_PROC_FS",
    "SCSI_CONSTANTS", "SCSI_LOGGING", "SCSI_SCAN_ASYNC", "BLK_DEV_SD", "BLK_DEV_SR",
    "USB_STORAGE", "SATA_AHCI", "ATA_PIIX",
}

def intentional_drop(symbol: str) -> bool:
    if symbol in policy_symbols:
        return True
    # The exact D630 fragment is audited too: if it explicitly disables a
    # symbol, an m -> n transition is documented policy. Dependency-only drops
    # still need one of the narrowly defined family/dependency rules below.
    if overlay.get(symbol) == "n":
        return True
    if symbol.startswith("SND_") and symbol not in sound_keep:
        return True
    if (symbol.endswith("_FS") and symbol not in fs_keep and val(final, symbol) == "n") or symbol in {
        "SMB_SERVER_SMBDIRECT", "SMBFS", "PNFS_BLOCK", "PNFS_FILE_LAYOUT",
        "PNFS_FLEXFILE_LAYOUT", "OCFS2_FS_O2CB", "OCFS2_FS_USERSPACE_CLUSTER",
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
    ("\n".join("CONFIG_" + s for s in unexpected_drops) + "\n")
    if unexpected_drops
    else "None: all Debian m -> n transitions are classified.\n",
    encoding="utf-8",
)

if unexpected_drops:
    errors.append(
        "Unclassified Debian m -> n transitions are fatal: "
        + ", ".join("CONFIG_" + s for s in unexpected_drops)
    )

report = [
    f"Variant: {variant}",
    f"Baseline config: {baseline_path}",
    f"Final config: {final_path}",
    f"Symbols changed: {len(changes)}",
    f"Unclassified Debian m -> n transitions: {len(unexpected_drops)}",
    "Every unclassified Debian m -> n transition is fatal; classify intentional policy changes explicitly.",
    "Critical checks: Core 2 target, embedded CPU+Wi-Fi firmware, zram compressors, filesystem support, audio, Wi-Fi, CPU-frequency scaling, i915 baseline, storage, and nftables baseline.",
]
(audit_path / "config-audit-summary.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
(audit_path / "config-audit-errors.txt").write_text(
    ("\n".join("FAIL: " + error for error in errors) + "\n") if errors else "PASS\n",
    encoding="utf-8",
)

if errors:
    print("\n".join("FAIL: " + e for e in errors), file=sys.stderr)
    print(f"See {audit_path / 'd630-config-symbol-audit.tsv'}", file=sys.stderr)
    raise SystemExit(1)

print("\n".join(report))
if unexpected_drops:
    print("WARNING: review unclassified m -> n changes in unclassified-module-drops.txt")
print("PASS: required D630 kernel config settings verified.")
