#!/usr/bin/env python3
"""Compare Debian's generated config to the final D630 config and detect silent module loss."""

from pathlib import Path
import re
import sys

if len(sys.argv) != 6:
    raise SystemExit("usage: audit-d630-config.py BASELINE FINAL OVERLAY OFFICIAL_CONFIG AUDIT_DIR")

baseline_path, final_path, overlay_path, official_path, audit_path = map(Path, sys.argv[1:])
audit_path.mkdir(parents=True, exist_ok=True)

CONFIG_SET = re.compile(r"^CONFIG_([A-Z0-9_]+)=(.*)$")
CONFIG_UNSET = re.compile(r"^# CONFIG_([A-Z0-9_]+) is not set$")

def read_config(path):
    result = {}
    for raw in path.read_text(errors="replace").splitlines():
        match = CONFIG_SET.match(raw)
        if match:
            result[match.group(1)] = match.group(2)
            continue
        match = CONFIG_UNSET.match(raw)
        if match:
            result[match.group(1)] = "n"
    return result

baseline = read_config(baseline_path)
final = read_config(final_path)
overlay = read_config(overlay_path)
official = read_config(official_path)
errors = []

def value(config, symbol):
    return config.get(symbol, "n")

required = {
    "MCORE2": "y",
    "GENERIC_CPU": "n",
    "DEBUG_INFO_NONE": "y",
    "DEBUG_INFO": "n",
    "DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT": "n",
    "DEBUG_INFO_BTF": "n",
    "DEBUG_INFO_BTF_MODULES": "n",
    "GDB_SCRIPTS": "n",
    "NVME_CORE": "n",
    "NVME_FABRICS": "n",
    "NVME_TARGET": "n",
    "NVME_FC": "n",
    "NVME_TCP": "n",
    "NVME_RDMA": "n",
    "NVME_TARGET_FC": "n",
    "NVME_TARGET_TCP": "n",
    "NVME_TARGET_RDMA": "n",
    "MEDIA_SUPPORT_FILTER": "y",
    "MEDIA_CAMERA_SUPPORT": "y",
    "MEDIA_ANALOG_TV_SUPPORT": "y",
    "MEDIA_DIGITAL_TV_SUPPORT": "n",
    "MEDIA_RADIO_SUPPORT": "n",
    "MEDIA_SDR_SUPPORT": "n",
    "MEDIA_PLATFORM_SUPPORT": "y",
    "MEDIA_TEST_SUPPORT": "n",
    "MICROCODE": "y",
    "MICROCODE_INTEL": "y",
    "FW_LOADER": "y",
    "EXTRA_FIRMWARE": '"intel-ucode/06-0f-0d"',
    "EXTRA_FIRMWARE_DIR": '"/lib/firmware"',
    "MODULES": "y",
    "MODULE_UNLOAD": "y",
    "MOUSE_PS2": "m",
    "INPUT_MOUSEDEV": "y",
    "INPUT_MOUSEDEV_PSAUX": "y",
    "ISO9660_FS": "m",
    "EXT4_FS": "y",
    "BTRFS_FS": "y",
    "NTFS3_FS": "y",
    "FAT_FS": "y",
    "MSDOS_FS": "y",
    "VFAT_FS": "y",
    "UDF_FS": "y",
    "ZRAM": "y",
    "ZSMALLOC": "y",
    "ZRAM_DEF_COMP_LZORLE": "y",
    "CRYPTO_LZO": "y",
    "ZRAM_DEF_COMP": '"lzo-rle"',
    "LZO_COMPRESS": "y",
    "LZO_DECOMPRESS": "y",
    "ZSTD_COMPRESS": "y",
    "ZSTD_DECOMPRESS": "y",
    "NFT_FIB_INET": "m",
    "NFT_FIB_IPV4": "m",
    "NFT_FIB_IPV6": "m",
    "CAN": "n",
    "ISDN": "n",
    "INFINIBAND": "n",
    "FIREWIRE": "n",
    "NFC": "n",
    "WIMAX": "n",
    "IEEE802154": "n",
    "USB_GADGET": "n",
    "BLK_DEV_NVME": "n",
    "DVB_CORE": "n",
    "RADIO_ADAPTERS": "n",
    "MTD": "n",
    "SND": "m",
    "SND_HDA_INTEL": "m",
    "SND_HDA_CODEC_IDT": "m",
}
for symbol, expected in required.items():
    actual = value(final, symbol)
    if actual != expected:
        errors.append("CONFIG_" + symbol + ": expected " + expected + ", got " + actual)

for symbol in ("DRM", "DRM_I915", "AGP_INTEL"):
    expected = value(official, symbol)
    actual = value(final, symbol)
    if actual != expected:
        errors.append("CONFIG_" + symbol + " changed from official Debian value " + expected + " to " + actual)

# Fail if unrelated optional disk filesystems or non-Intel GPU drivers survive.
FILESYSTEM_KEEP = {
    "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "FAT_FS", "MSDOS_FS", "VFAT_FS",
    "UDF_FS", "ISO9660_FS", "PROC_FS", "DEVPTS_FS",
}
unexpected_filesystems = sorted(
    symbol for symbol, setting in final.items()
    if ((symbol.endswith("_FS") and symbol not in FILESYSTEM_KEEP) or symbol in {"SQUASHFS", "CRAMFS", "ROMFS"})
    and setting in ("y", "m")
)
if unexpected_filesystems:
    errors.append("Unwanted filesystem drivers remain enabled: " + ", ".join("CONFIG_" + s for s in unexpected_filesystems))

UNWANTED_GPU_PREFIXES = (
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
unexpected_gpu = sorted(
    symbol for symbol, setting in final.items()
    if any(symbol.startswith(prefix) for prefix in UNWANTED_GPU_PREFIXES) and setting in ("y", "m")
)
if unexpected_gpu:
    errors.append("Unwanted GPU drivers remain enabled: " + ", ".join("CONFIG_" + s for s in unexpected_gpu))

for symbol in ("CGROUPS", "NAMESPACES", "BPF_SYSCALL", "SECCOMP", "SECURITY_APPARMOR", "NETFILTER", "NF_TABLES"):
    expected = value(baseline, symbol)
    actual = value(final, symbol)
    if expected in ("y", "m") and actual != expected:
        errors.append("CONFIG_" + symbol + " changed from Debian baseline " + expected + " to " + actual)

# These are explicit child symbols whose Kconfig dependencies become unavailable
# only because the matching top-level exclusion in config/d630-core2.config is off.
# This is a narrow allow-list; all other Debian m -> n changes remain fatal.
DISABLED_CHILDREN = {
    "CAN": ("CAN_", "NET_EMATCH_CANID"),
    "ISDN": ("MISDN", "BT_CMTP"),
    "INFINIBAND": (
        "INFINIBAND", "MLX4_INFINIBAND", "MLX5_INFINIBAND",
        "NET_9P_RDMA", "RDS_RDMA", "SUNRPC_XPRT_RDMA",
        "RDMA", "NVME_RDMA", "NVME_TARGET_RDMA", "SMC",
    ),
    "FIREWIRE": (
        "FIREWIRE", "DVB_FIREDTV", "SBP_TARGET",
        "SND_FIREWIRE", "SND_FIREWORKS", "SND_BEBOB",
        "SND_DICE", "SND_FIREFACE", "SND_ISIGHT", "SND_OXFW",
    ),
    "NFC": ("NFC",),
    "IEEE802154": ("IEEE802154", "MAC802154"),
    "6LOWPAN": ("6LOWPAN", "BT_6LOWPAN"),
    "USB_GADGET": (
        "USB_GADGET", "USBIP_VUDC", "USB_DUMMY_HCD", "USB_EG20T",
        "USB_ETH", "USB_FUNCTIONFS", "USB_G_SERIAL", "USB_LIBCOMPOSITE",
        "USB_NET2280", "USB_U_AUDIO", "USB_U_ETHER", "USB_U_SERIAL",
        "USB_CONFIGFS", "USB_F_",
    ),
    "MTD": (
        "MTD", "FTL", "INFTL", "NFTL", "RFD_FTL", "SSFDC",
        "JFFS2_FS", "UBIFS_FS", "BCH", "PTP_1588_CLOCK_OCP",
    ),
    "BLK_DEV_NVME": ("NVME", "BLK_DEV_NVME"),
    "MEDIA_DIGITAL_TV_SUPPORT": (
        "DVB", "MEDIA_TUNER_", "CYPRESS_FIRMWARE", "MANTIS_CORE", "MEDIA_ALTERA_CI",
        "SMS_SDIO_DRV", "SMS_SIANO_MDTV", "SMS_USB_DRV", "TTPCI_EEPROM",
        "VIDEO_AU0828", "VIDEO_BT848", "VIDEO_CX18", "VIDEO_CX23885",
        "VIDEO_CX88_VP3054", "VIDEO_PVRUSB2", "VIDEO_SAA7164",
        "VIDEO_CS3308", "VIDEO_CS5345",
        "VIDEOBUF_DMA_SG", "VIDEOBUF_GEN", "VIDEOBUF_VMALLOC",
    ),
    "MEDIA_RADIO_SUPPORT": (
        "RADIO_", "RADIO_ADAPTERS",
        "USB_DSBR", "USB_KEENE", "USB_MA901", "USB_MR800", "USB_RAREMONO", "USB_SI470X",
    ),
    "MEDIA_SDR_SUPPORT": ("USB_AIRSPY", "USB_HACKRF", "USB_MSI2500"),
    "MEDIA_TEST_SUPPORT": ("VIDEO_VIM2M", "VIDEO_VICODEC", "VIDEO_VIMC", "VIDEO_VIVID", "VIDEO_V4L2_TPG", "DVB_VIDTV"),
}

SOUND_KEEP = {
    "SND", "SND_TIMER", "SND_PCM", "SND_HWDEP", "SND_HDA", "SND_HDA_INTEL",
    "SND_HDA_CODEC", "SND_HDA_CODEC_IDT", "SND_HDA_CORE", "SND_HDA_COMPONENT",
    "SND_INTEL_DSP_CONFIG", "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE",
    "SND_JACK", "SND_CTL_LED",
}
unexpected_sound = sorted(
    symbol for symbol, setting in final.items()
    if symbol.startswith("SND_") and setting in ("y", "m") and symbol not in SOUND_KEEP
)
if unexpected_sound:
    errors.append("Unwanted sound drivers/codecs remain enabled: " + ", ".join("CONFIG_" + s for s in unexpected_sound))

def disabled_by_parent(symbol):
    # The build script explicitly disables non-allowlisted SND_* symbols.
    if symbol.startswith("SND_") and symbol not in SOUND_KEEP:
        return True
    if ((symbol.endswith("_FS") and symbol not in FILESYSTEM_KEEP) or symbol in {
        "SQUASHFS", "CRAMFS", "ROMFS", "CIFS", "CIFS_UPCALL", "CIFS_XATTR",
        "CIFS_POSIX", "NFS_V2", "NFS_V3", "NFS_V4", "NFS_SWAP",
        "NFSD", "NFSD_V2", "NFSD_V3", "NFSD_V4", "SMB_SERVER", "SMB_SERVER_SMBDIRECT",
    }):
        return True
    if any(symbol.startswith(prefix) for prefix in UNWANTED_GPU_PREFIXES):
        return True
    for parent, prefixes in DISABLED_CHILDREN.items():
        if value(overlay, parent) != "n":
            continue
        if any(symbol.startswith(p) for p in prefixes):
            return True
        # A small number of digital-TV integrations are named *_DVB rather
        # than DVB_*; they disappear when the digital-TV API is disabled.
        if parent == "MEDIA_DIGITAL_TV_SUPPORT" and symbol.endswith("_DVB"):
            return True
    return False

for symbol in sorted(set(baseline) | set(final)):
    old = value(baseline, symbol)
    new = value(final, symbol)
    if old == new or old != "m" or new != "n":
        continue
    if symbol in overlay and overlay[symbol] == "n":
        continue
    if disabled_by_parent(symbol):
        continue
    errors.append("Retained Debian module silently changed m -> n: CONFIG_" + symbol)

changes = ["symbol\tdebian_baseline\tfinal\tclassification\n"]
diff_lines = ["# CONFIG DIFF: Debian-generated baseline -> final D630 config\n"]
for symbol in sorted(set(baseline) | set(final)):
    old = value(baseline, symbol)
    new = value(final, symbol)
    if old == new:
        continue
    requested = overlay.get(symbol)
    if requested == "n":
        classification = "explicitly disabled"
    elif requested == "y" and new == "y":
        classification = "promoted/required built-in"
    elif requested == "m" and new == "m":
        classification = "explicitly retained as module"
    elif old == "m" and new == "n" and disabled_by_parent(symbol):
        classification = "disabled by documented parent subsystem exclusion"
    elif old == "m" and new == "y":
        classification = "promoted by Kconfig dependency"
    elif old == "n" and new == "m":
        classification = "enabled as module by policy/dependency"
    elif old == "n" and new == "y":
        classification = "enabled built-in by policy/dependency"
    elif symbol in overlay:
        classification = "explicit policy setting"
    else:
        classification = "Kconfig dependency/default adjustment"
    changes.append("CONFIG_" + symbol + "\t" + old + "\t" + new + "\t" + classification + "\n")
    diff_lines.append("CONFIG_" + symbol + ": " + old + " -> " + new + "\n")

(audit_path / "config-change-classification.tsv").write_text("".join(changes))
(audit_path / "config-diff.txt").write_text("".join(diff_lines))
(audit_path.joinpath("config-audit-errors.txt")).write_text("\n".join(errors) + ("\n" if errors else "PASS\n"))

if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)

(audit_path / "config-audit-report.txt").write_text(
    "PASS: Core 2 CPU optimization and required D630 configuration values validated.\n"
    "PASS: debug information is disabled for the stripped runtime kernel.\n"
    "PASS: only Intel HDA plus the IDT/Sigmatel codec and required ALSA core remain enabled.\n"
    "PASS: unrelated optional filesystem drivers are disabled; proc/devpts remain.\n"
    "PASS: Intel i915 is retained and unrelated GPU drivers are disabled.\n"
    "PASS: NVMe, digital-TV and radio support are disabled as requested.\n"
    "PASS: DRM, i915 and Intel AGP match the official Debian reference config.\n"
    "PASS: cgroups, namespaces, eBPF, seccomp, AppArmor and nftables retain Debian baseline values.\n"
    "PASS: no unexplained Debian module m -> n conversion.\n"
    "See config-diff.txt and config-change-classification.tsv for every effective change.\n"
)
print("D630 config audit passed.")
print("Changed config symbols: " + str(len(changes) - 1))
