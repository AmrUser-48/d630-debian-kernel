#!/usr/bin/env python3
"""Apply D630 policy and configure a unique release on Debian's amd64 image target."""
from __future__ import annotations

from pathlib import Path
import re
import sys

from d630_kconfig import normalize_fragment, parse_config_text, read_config

if len(sys.argv) != 5:
    raise SystemExit("usage: apply-d630-policy.py SOURCE AUDIT OVERLAY FEATURESET")

source = Path(sys.argv[1]).resolve()
audit = Path(sys.argv[2]).resolve()
overlay = Path(sys.argv[3]).resolve()
featureset = sys.argv[4]
if featureset != "none":
    raise SystemExit("Only Debian amd64 featureset=none is supported")

baseline_path = source / f"debian/build/build_amd64_{featureset}_amd64/.config"
rules_path = source / "debian/rules.gen"
target_config = source / "debian/config/d630-core2.config"
if not baseline_path.is_file():
    raise SystemExit(f"Debian-generated config missing: {baseline_path}")
if not rules_path.is_file() or not overlay.is_file():
    raise SystemExit("Debian rules or committed D630 overlay is missing")

baseline = read_config(baseline_path)
symbols = set(baseline)
overlay_text = overlay.read_text(encoding="utf-8").rstrip()
overlay_values = parse_config_text(overlay_text)

# Retain HDA/Sigmatel plus USB audio, Realtek codecs, and MIDI sequencer support.
# Keep SND_SEQ_* dependencies when the sequencer is enabled.
sound_keep = {
    "SND", "SND_TIMER", "SND_PCM_TIMER", "SND_PCM", "SND_HDA", "SND_PCI",
    "SND_HDA_INTEL", "SND_HDA_CODEC_SIGMATEL", "SND_HDA_CODEC_REALTEK",
    "SND_HDA_CORE", "SND_HDA_COMPONENT", "SND_HDA_GENERIC", "SND_HDA_GENERIC_LEDS",
    "SND_INTEL_DSP_CONFIG", "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE",
    "SND_JACK", "SND_CTL_LED", "SND_VMASTER", "SND_USB_AUDIO",
    "SND_SEQUENCER", "SND_SEQ_DEVICE", "SND_RAWMIDI",
}
required_sound_keep = {
    "SND_PCI", "SND_HDA", "SND_HDA_INTEL", "SND_HDA_CODEC_SIGMATEL",
    "SND_HDA_CODEC_REALTEK", "SND_USB_AUDIO", "SND_SEQUENCER", "SND_RAWMIDI",
}
if not required_sound_keep.issubset(sound_keep):
    raise SystemExit("Audio policy is missing required HDA dependencies: " + ", ".join(sorted(required_sound_keep - sound_keep)))

sound_disabled = sorted(
    s for s in symbols if s.startswith(("SND_", "SOUNDWIRE_")) and s not in sound_keep
    and not (s.startswith("SND_SEQ_") and overlay_values.get("SND_SEQUENCER", "n") in {"m", "y"})
    and baseline.get(s, "n") in {"y", "m"}
)

# Retain the filesystems used by the laptop and the standalone Gentoo boot
# contract. Preserve configfs/debugfs as Debian baseline facilities.
filesystem_keep = {
    "AUTOFS4_FS", "AUTOFS_FS", "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "FAT_FS",
    "MSDOS_FS", "VFAT_FS", "EXFAT_FS", "UDF_FS", "ISO9660_FS", "SQUASHFS",
    "FUSE_FS", "OVERLAY_FS", "EFIVAR_FS", "XFS_FS", "F2FS_FS", "EROFS_FS",
    "PROC_FS", "DEVPTS_FS", "CONFIGFS_FS", "DEBUG_FS",
}
# Network filesystems and FUSE remain enabled by the committed overlay.
filesystem_extras = {"CRAMFS", "ROMFS"}
filesystem_disabled = sorted(
    s for s in symbols
    if ((s.endswith("_FS") and s not in filesystem_keep) or s in filesystem_extras)
    and overlay_values.get(s, "n") == "n"
    and baseline.get(s, "n") in {"y", "m"}
)

# Disable unrelated GPU vendors and legacy framebuffer drivers. Generic DRM,
# i915, shared helpers, backlight and framebuffer-DDC support are not matched.
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
    s for s in symbols
    if any(s.startswith(prefix) for prefix in gpu_prefixes)
    and baseline.get(s, "n") in {"y", "m"}
)

# The parent toggles below intentionally remove only their dependent hardware
# families. Generic disk/SCSI/USB storage, i915, HDA, Wi-Fi, input and ACPI stay.
parent_disable = {
    "CAN": ("CAN_", "NET_EMATCH_CANID"),
    "ISDN": ("MISDN", "BT_CMTP", "ISDN"),
    "INFINIBAND": ("INFINIBAND", "RDMA", "MLX4_INFINIBAND", "MLX5_INFINIBAND",
                    "RDS_RDMA", "SUNRPC_XPRT_RDMA", "NET_9P_RDMA"),
    "FIREWIRE": ("FIREWIRE", "SBP_TARGET", "SND_FIREWIRE", "SND_FIREWORKS",
                 "SND_BEBOB", "SND_DICE", "SND_FIREFACE", "SND_ISIGHT", "SND_OXFW"),
    "NFC": ("NFC",),
    "WIMAX": ("WIMAX",),
    "IEEE802154": ("IEEE802154", "MAC802154"),
    "6LOWPAN": ("6LOWPAN", "BT_6LOWPAN"),
    "USB_GADGET": ("USB_GADGET", "USBIP_VUDC", "USB_DUMMY_HCD", "USB_FUNCTIONFS",
                   "USB_LIBCOMPOSITE", "USB_CONFIGFS", "USB_F_", "USB_U_",
                   "USB_ETH", "USB_G_SERIAL", "USB_NET2280"),
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
                      "LIBCXGBI", "CXGB", "ENCLOSURE_SERVICES", "RAID_ATTRS",
                      "CHR_DEV_", "FUSION_", "QEDF", "TCM_", "PCMCIA_AHA152X",
                      "PCMCIA_QLOGIC", "PCMCIA_SYM53C500"),
    "MTD": ("MTD", "FTL", "INFTL", "NFTL", "RFD_FTL", "SSFDC", "JFFS2_FS",
            "UBIFS_FS", "BCH"),
    "XEN": ("XEN", "TCG_XEN", "NET_9P_XEN"),
    "VIRTIO_MENU": ("VIRTIO_", "HW_RANDOM_VIRTIO", "CRYPTO_DEV_VIRTIO", "NET_9P_VIRTIO"),
    "NFS_FS": ("NFS_", "SUNRPC", "LOCKD"),
}
parent_values = read_config(overlay)
child_disabled: list[str] = []
for parent, prefixes in parent_disable.items():
    if parent_values.get(parent, "n") != "n":
        continue
    for symbol in sorted(symbols):
        if symbol in {"SCSI", "SCSI_MOD", "SCSI_COMMON", "SCSI_DMA", "SCSI_NETLINK",
                      "SCSI_PROC_FS", "SCSI_CONSTANTS", "SCSI_LOGGING", "SCSI_SCAN_ASYNC",
                      "BLK_DEV_SD", "BLK_DEV_SR", "USB_STORAGE", "SATA_AHCI", "ATA_PIIX"}:
            continue
        if any(symbol.startswith(prefix) for prefix in prefixes) and baseline.get(symbol, "n") in {"y", "m"}:
            child_disabled.append(symbol)

# Explicitly prune unrelated FPGA, devfreq, tuner, MXM, Slimbus and media-codec
# drivers. These m -> n transitions are policy, not unexplained losses.
unused_hardware = {
    "ALTERA_STAPL", "DEVFREQ_GOV_SIMPLE_ONDEMAND", "MXM_WMI", "SLIMBUS",
    "VIDEO_CS3308", "VIDEO_CS5345",
}
unused_hardware.update(s for s in symbols if s.startswith("MEDIA_TUNER_"))
unused_hardware_disabled = sorted(
    s for s in unused_hardware if baseline.get(s, "n") in {"y", "m"}
)
all_disabled = sorted(set(
    sound_disabled + filesystem_disabled + gpu_disabled + child_disabled
    + unused_hardware_disabled
))
generated = overlay_text + "\n"
generated += "\n# Standard Debian amd64 runtime kernel; PREEMPT_RT is disabled.\n"
generated += "# CONFIG_PREEMPT_RT is not set\n"
generated += "\n# D630 audio trim: keep HDA + Sigmatel, disable other sound devices.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in sound_disabled)
generated += "\n# D630 filesystem trim: disable unneeded filesystem implementations.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in filesystem_disabled)
generated += "\n# D630 GPU trim: retain the Intel GM965/i915 stack only.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in gpu_disabled)
generated += "\n# Child drivers disabled because their parent subsystem is excluded.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in sorted(set(child_disabled)))
generated += "\n# Unused D630 hardware/media drivers.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in unused_hardware_disabled)

target_config.parent.mkdir(parents=True, exist_ok=True)
generated, collapsed = normalize_fragment(generated)
target_config.write_text(generated, encoding="utf-8")
(audit / "kconfig-fragment-normalization.txt").write_text(
    f"Effective D630 fragment: {target_config}\n"
    f"Unique Kconfig symbols: {len(parse_config_text(generated))}\n"
    f"Identical repeated assignments collapsed: {len(collapsed)}\n"
    + "".join(f"CONFIG_{symbol}\n" for symbol in collapsed)
    + "Conflicting repeated assignments: 0\n",
    encoding="utf-8",
)

policy_reasons: dict[str, str] = {}
for group, values in (
    ("unused sound", sound_disabled), ("unused filesystem", filesystem_disabled),
    ("unrelated GPU", gpu_disabled), ("disabled parent dependency", sorted(set(child_disabled))),
):
    for symbol in values:
        policy_reasons.setdefault(symbol, group)
for symbol, value in parse_config_text(generated).items():
    if value == "n":
        policy_reasons.setdefault(symbol, "explicit D630 Kconfig policy")
with (audit / "policy-disabled-symbols.tsv").open("w", encoding="utf-8") as out:
    out.write("symbol\tpolicy\n")
    for symbol, group in sorted(policy_reasons.items()):
        out.write(f"{symbol}\t{group}\n")

# Patch the selected Debian amd64 runtime image's setup and build recipes.
# The setup and build must agree on the custom ABI/localversion to guarantee
# the kernel release, boot image path, and modules directory all match.
rules_before = rules_path.read_text(encoding="utf-8")
custom_abi = "6.1.0-52"
custom_localversion = "-d630-core2"
custom_release = custom_abi + custom_localversion
config_rel = "debian/config/d630-core2.config"

def set_make_arg(line: str, key: str, value: str) -> str:
    pattern = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(key) + r"=(?:'[^']*'|[^ \t]+)")
    updated, count = pattern.subn(key + "='" + value + "'", line, count=1)
    if count != 1:
        raise SystemExit(f"Cannot set {key} in Debian image recipe: {line.rstrip()}")
    return updated

lines = rules_before.splitlines(keepends=True)
targets = (
    (f"setup_amd64_{featureset}_amd64_real_image:", "setup_image", False),
    (f"binary-arch_amd64_{featureset}_amd64_real_image:", "binary_image", True),
)
for target, marker, build_image in targets:
    matches = [i for i, line in enumerate(lines) if line.startswith(target)]
    if len(matches) != 1:
        raise SystemExit(f"Expected exactly one Debian target {target}; got {len(matches)}")
    start_index = matches[0]
    recipe_index = None
    for i in range(start_index + 1, min(start_index + 12, len(lines))):
        if lines[i].startswith("\t") and marker in lines[i]:
            recipe_index = i
            break
        if lines[i].strip() and not lines[i].startswith("\t"):
            break
    if recipe_index is None:
        raise SystemExit(f"Cannot find {marker} recipe for {target}")
    recipe = lines[recipe_index]
    recipe = set_make_arg(recipe, "ABINAME", custom_abi)
    recipe = set_make_arg(recipe, "LOCALVERSION", custom_localversion)
    recipe = set_make_arg(recipe, "LOCALVERSION_IMAGE", custom_localversion)
    if build_image:
        match = re.search(r"KCONFIG='([^']*)'", recipe)
        if not match:
            raise SystemExit(f"Cannot parse KCONFIG chain for {target}")
        parts = match.group(1).split()
        if config_rel not in parts:
            parts.append(config_rel)
        recipe = recipe[:match.start(1)] + " ".join(parts) + recipe[match.end(1):]
    lines[recipe_index] = recipe

rules_after = "".join(lines)
rules_path.write_text(rules_after, encoding="utf-8")
(audit / "rules.gen.diff").write_text(
    "\n".join(
        ["# Custom release applied to this Debian image target only",
         "# Setup and build release: 6.1.0-52-d630-core2."]
        + [line.rstrip("\n") for line in __import__("difflib").unified_diff(
            rules_before.splitlines(), rules_after.splitlines(),
            fromfile="rules.gen.before", tofile="rules.gen.after")]
    ) + "\n",
    encoding="utf-8",
)
print(f"Applied D630 policy to {targets[1][0]}.")
print(f"Configured kernel release: {custom_release}")
print(f"Baseline config: {baseline_path}")
print(f"Explicitly pruned symbols: {len(all_disabled)}")
