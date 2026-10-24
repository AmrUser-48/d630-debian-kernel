# Dell Latitude D630 — Debian 12 stripped kernel workbench

This repository builds two compact kernels from the **exact Debian Bookworm Linux source package 6.1.180-1** that corresponds to the previously working stock image ABI:

- Normal: `linux-image-6.1.0-52-amd64`, kernel release `6.1.0-52-amd64`.
- PREEMPT_RT: `linux-image-6.1.0-52-rt-amd64`, kernel release `6.1.0-52-rt-amd64`.

The custom binary package version is `6.1.180-1+d6301`. The package name and `/lib/modules` release match Debian's respective ABI so the image can replace the corresponding stock kernel package. The image is custom and unsigned by Debian's kernel signing keys. The target is this legacy-BIOS Dell Latitude D630 / Core 2 Duo T7250, not the GitHub runner.

## Build workflows

Run either workflow from the Actions tab:

- [Build D630 stripped Debian 12 kernel (amd64)](.github/workflows/build-d630-kernel-amd64.yml)
- [Build D630 stripped Debian 12 kernel (amd64-rt)](.github/workflows/build-d630-kernel-amd64-rt.yml)

Both workflows use Debian's own native image targets and the version-pinned Debian source archives. They verify the exact binary package name/version/kernel-release, module tree, effective configuration, embedded firmware, and checksums before upload. If a package is missing, the workflow fails before artifact upload. Artifacts have distinct per-workflow names, 90-day retention, and are also published to a uniquely tagged GitHub pre-release with the installable packages and audit report.

The previous 6.1.187 workbench workflows are retired. Do not use the former `prepare-debian-inputs.yml` or `build-d630-kernel.yml` flow for this target; its configuration/package inputs were version-stale, and it could report a successful artifact upload containing only logs.

## D630 hardware/configuration policy

- CPU: `CONFIG_MCORE2=y`, with MSR and CPUID support built in. No `-march=native`; the runner CPU is not the D630.
- Storage/filesystems: ext4, Btrfs, NTFS3, FAT/MS-DOS/VFAT, exFAT and UDF are built in. ISO9660 remains a module. SquashFS is built in with zlib, LZ4, LZO, XZ and Zstd support.
- zram: built in, LZ4 default, all compressors provided by Linux 6.1 enabled (LZO-RLE, Zstd, LZ4, LZO, LZ4HC and 842).
- Wi-Fi: Intel PRO/Wireless 3945ABG (`iwl3945`) remains a module. `iwlwifi-3945-2.ucode` is embedded in the kernel, and the matching Debian `firmware-iwlwifi` package is provided alongside it for future updates.
- Graphics: retain Debian's generated Intel i915 and Intel AGP settings. GM965/GMA X3100 on this kernel does not require separate DMC/GuC/HuC firmware.
- Audio: built-in ALSA/HDA core with modular Intel HDA PCI driver and Sigmatel/IDT codec. The Linux 6.1 Kconfig symbol is `SND_HDA_CODEC_SIGMATEL`; the resulting codec module is named `snd-hda-codec-idt`. This codec does not need external firmware.
- CPU microcode: the T7250 CPUID 0x000006fd blob `intel-ucode/06-0f-0d` is embedded in both kernels, validated during the build, and accompanied by license/copyright notices. The official `intel-microcode` package is included too.
- Input: PS/2 touchpad protocol driver (`psmouse`) remains modular/unloadable; the legacy `/dev/input/mice` interface for GPM is preserved.
- Firewall: preserve Debian's nftables FIB/IPv4/IPv6/inet support at its baseline values.
- Pruning: disable unrelated sound codecs, filesystem implementations, vendor GPU families, DVB/radio/SDR/test-media APIs, unused SCSI host adapters/transports, NVMe, and unsupported bus/protocol families without blanket-disabling all modules.

## Build and audit design

`config/d630-core2-6.1.180.config` is an overlay, not a replacement for Debian's config. The scripts preserve the generated configuration for the selected feature set, append the D630 overlay to only that image target, run `olddefconfig`, then audit the effective result. They do not rewrite the upstream Makefile version, Debian ABI name or `LOCALVERSION`.

The audit checks the requested Core 2 target, built-in filesystems/compressors, zram defaults, firmware paths, sound/Wi-Fi module settings, RT flavour, and critical i915/storage/netfilter values. It records the full config diff and symbol-by-symbol changes, including any remaining module transitions that need review.

## Installing

Download the workflow artifact or the matching pre-release assets. Review `RELEASE-NOTES.md`, `D630-CONFIG-DIFF.txt`, `D630-CONFIG-AUDIT.tsv` and `SHA256SUMS` before installation. The `firmware-iwlwifi` and `intel-microcode` Debian packages are included alongside the image package.

Keep a known-good kernel and initramfs boot entry until the new image has booted on the physical D630. Debian-hosted CI can validate the build, package contents and config, but cannot prove physical boot, Wi-Fi, graphics, audio, touchpad or firewalld behaviour.
