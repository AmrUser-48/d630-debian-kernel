#!/usr/bin/env python3
"""Apply the D630 overlay without rewriting Debian's native ABI or Makefile."""
from __future__ import annotations

from pathlib import Path
import re
import sys

from d630_kconfig import normalize_fragment, parse_config_text, read_config

if len(sys.argv) != 5:
    raise SystemExit("usage: apply-d630-6.1.180-policy.py SOURCE AUDIT OVERLAY FEATURESET")

source = Path(sys.argv[1]).resolve()
audit = Path(sys.argv[2]).resolve()
overlay = Path(sys.argv[3]).resolve()
featureset = sys.argv[4]
if featureset not in {"none", "rt"}:
    raise SystemExit("FEATURESET must be none or rt")

baseline_path = source / f"debian/build/build_amd64_{featureset}_amd64/.config"
rules_path = source / "debian/rules.gen"
target_config = source / "debian/config/d630-core2-6.1.180.config"
if not baseline_path.is_file():
    raise SystemExit(f"Debian-generated config missing: {baseline_path}")
if not rules_path.is_file() or not overlay.is_file():
    raise SystemExit("Debian rules or committed D630 overlay is missing")

baseline = read_config(baseline_path)
symbols = set(baseline)
overlay_text = overlay.read_text(encoding="utf-8").rstrip()

# Retain only the D630's Intel HDA/Sigmatel path. SND_HDA is an invisible
# tristate selected by SND_HDA_INTEL; a modular controller resolves the core
# to m. SND_PCM_TIMER is explicitly retained for normal ALSA PCM timing.
sound_keep = {
    "SND", "SND_TIMER", "SND_PCM_TIMER", "SND_PCM", "SND_HDA",
    # SND_PCI gates the PCI sound-driver Kconfig menu, including Intel HDA, in Linux 6.1.
    "SND_PCI", "SND_HDA_INTEL", "SND_HDA_CODEC_SIGMATEL", "SND_HDA_CORE",
    "SND_HDA_COMPONENT", "SND_HDA_GENERIC", "SND_HDA_GENERIC_LEDS",
    "SND_INTEL_DSP_CONFIG", "SND_DMAENGINE_PCM", "SND_PCM_DMAENGINE",
    "SND_JACK", "SND_CTL_LED", "SND_VMASTER",
}
required_sound_keep = {"SND_PCI", "SND_HDA", "SND_HDA_INTEL", "SND_HDA_CODEC_SIGMATEL"}
if not required_sound_keep.issubset(sound_keep):
    raise SystemExit("Audio policy is missing required HDA dependencies: " + ", ".join(sorted(required_sound_keep - sound_keep)))

sound_disabled = sorted(
    s for s in symbols if s.startswith(("SND_", "SOUNDWIRE_")) and s not in sound_keep
    and baseline.get(s, "n") in {"y", "m"}
)

# Retain the filesystems used by the laptop and the standalone Gentoo boot
# contract. Preserve configfs/debugfs as Debian baseline facilities.
filesystem_keep = {
    "EXT4_FS", "BTRFS_FS", "NTFS3_FS", "FAT_FS", "MSDOS_FS", "VFAT_FS",
    "EXFAT_FS", "UDF_FS", "ISO9660_FS", "SQUASHFS", "PROC_FS", "DEVPTS_FS",
    "CONFIGFS_FS", "DEBUG_FS",
}
filesystem_extras = {
    "CRAMFS", "ROMFS", "CIFS", "CIFS_UPCALL", "CIFS_XATTR", "CIFS_POSIX",
    "NFS_V2", "NFS_V3", "NFS_V4", "NFS_SWAP", "NFSD", "NFSD_V2",
    "NFSD_V3", "NFSD_V4", "SMB_SERVER", "SMB_SERVER_SMBDIRECT",
}
filesystem_disabled = sorted(
    s for s in symbols
    if ((s.endswith("_FS") and s not in filesystem_keep) or s in filesystem_extras)
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
    "VIRTIO": ("VIRTIO_", "HW_RANDOM_VIRTIO", "CRYPTO_DEV_VIRTIO", "NET_9P_VIRTIO"),
    "EFI": ("EFI_",),
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

# Explicit per-symbol disable list; Kconfig will resolve dependent symbols on
# olddefconfig. A TSV audit artifact documents every deliberate change.
all_disabled = sorted(set(sound_disabled + filesystem_disabled + gpu_disabled + child_disabled))
generated = overlay_text + "\n"
generated += f"\n# Variant-specific scheduling policy: Debian RT featureset={featureset}.\n"
generated += "CONFIG_EXPERT=y\nCONFIG_PREEMPT_RT=y\n" if featureset == "rt" else "# CONFIG_PREEMPT_RT is not set\n"
generated += "\n# D630 audio trim: keep HDA + Sigmatel, disable other sound devices.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in sound_disabled)
generated += "\n# D630 filesystem trim: disable unneeded filesystem implementations.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in filesystem_disabled)
generated += "\n# D630 GPU trim: retain the Intel GM965/i915 stack only.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in gpu_disabled)
generated += "\n# Child drivers disabled because their parent subsystem is excluded.\n"
generated += "".join(f"# CONFIG_{s} is not set\n" for s in sorted(set(child_disabled)))

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

# Patch only the selected Debian native image target's KCONFIG chain. Do not
# alter the upstream version, ABI name, LOCALVERSION, or Makefile: Debian itself
# must generate 6.1.0-52-amd64 / 6.1.0-52-rt-amd64.
rules_before = rules_path.read_text(encoding="utf-8")
target = f"binary-arch_amd64_{featureset}_amd64_real_image:"
lines = rules_before.splitlines(keepends=True)
matches = [i for i, line in enumerate(lines) if line.startswith(target)]
if len(matches) != 1:
    raise SystemExit(f"Expected exactly one Debian target {target}; got {len(matches)}")
start = matches[0]
recipe_index = None
for i in range(start + 1, min(start + 12, len(lines))):
    if lines[i].startswith("\t") and "binary_image" in lines[i]:
        recipe_index = i
        break
    if lines[i].strip() and not lines[i].startswith("\t"):
        break
if recipe_index is None:
    raise SystemExit(f"Cannot find binary_image recipe for {target}")
recipe = lines[recipe_index]
match = re.search(r"KCONFIG='([^']*)'", recipe)
if not match:
    raise SystemExit(f"Cannot parse KCONFIG chain for {target}")
parts = match.group(1).split()
config_rel = "debian/config/d630-core2-6.1.180.config"
if config_rel not in parts:
    parts.append(config_rel)
lines[recipe_index] = recipe[:match.start(1)] + " ".join(parts) + recipe[match.end(1):]
rules_after = "".join(lines)
rules_path.write_text(rules_after, encoding="utf-8")

(audit / "rules.gen.diff").write_text(
    "\n".join(
        ["# Debian rules.gen change: append the D630 overlay to only " + target,
         "# No Makefile version, ABI name, or LOCALVERSION mutation performed."]
        + [line.rstrip("\n") for line in __import__("difflib").unified_diff(
            rules_before.splitlines(), rules_after.splitlines(),
            fromfile="rules.gen.before", tofile="rules.gen.after")]
    ) + "\n",
    encoding="utf-8",
)
print(f"Applied D630 policy to {target}.")
print(f"Baseline config: {baseline_path}")
print(f"Explicitly pruned symbols: {len(all_disabled)}")
