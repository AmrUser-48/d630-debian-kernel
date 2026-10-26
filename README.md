# Dell Latitude D630 — Debian Core 2 kernel

Build an installable Debian kernel package for the Dell Latitude D630 and Intel Core 2 Duo T7250 using Debian Bookworm's patched Linux source package `6.1.180-1`.

## Target

| Property | Value |
|---|---|
| Debian source package | `linux=6.1.180-1` |
| Kernel release / module directory | `6.1.0-52-d630-core2` |
| Installable package | `linux-image-6.1.0-52-d630-core2` |
| Binary package version | `6.1.180-1` |
| CPU target | `CONFIG_MCORE2=y`, `CONFIG_GENERIC_CPU=n` |

The workflow is **D630 Debian Core 2 Kernel — Build, Audit & Release**. It builds one standard amd64 kernel, not a real-time variant.

## Machine-specific configuration

The build starts from Debian's generated amd64 settings, then applies explicit D630 policy. It retains Intel GM965/i915 and AGP, SATA/AHCI and USB storage, ACPI, nftables, autofs built in, ext4/Btrfs/NTFS3, FUSE/CUSE, overlayfs, XFS/F2FS/EROFS, FAT/VFAT/exFAT, UDF/ISO9660/SquashFS, NFS client/server and CIFS/SMB, plus Intel 3945ABG/4965 and newer iwlwifi, ICH8 HDA/Sigmatel/Realtek and USB audio.

CPU scaling is mandatory: `CONFIG_CPU_FREQ=y`, `CONFIG_CPU_FREQ_GOV_USERSPACE=y` and `CONFIG_X86_ACPI_CPUFREQ=m`. zram remains built in with LZ4 as its default compressor. Core 2 microcode and Intel 3945ABG firmware are embedded; the official firmware packages and license/copyright notices are included in the release bundle.

The pruning policy disables unrelated GPU vendors, NVMe, tuner/DVB/radio/SDR/test-media drivers, and unselected legacy SCSI controllers while retaining the explicitly selected storage adapters. Selected SCSI/iSCSI handlers, common RAID/SAS adapters, VirtIO devices and Xen guest drivers remain modular. Kernel modules stay as plain `.ko` files inside a Debian package compressed with XZ; this prioritizes a smaller downloadable `.deb` over compressed on-disk module storage. Deliberate removals are recorded. Unexplained enabled-module-to-disabled transitions fail validation.

## Build and release gates

The workflow builds in Debian Bookworm using Debian's native source-package setup and amd64 runtime image target. It pins source `6.1.180-1` and requires the custom kernel release `6.1.0-52-d630-core2`. It checks the generated release before compiling, then verifies the effective configuration, Kconfig warnings, required modules, embedded firmware, package metadata, boot image path, module directory and checksums.

Artifacts and the uniquely tagged GitHub pre-release are published only after validation succeeds. Diagnostics and configuration audits are uploaded when the build fails.

## Files

- `config/d630-core2.config` — Core 2 and D630 Kconfig overlay.
- `scripts/apply-d630-policy.py` — applies the overlay, records intentional pruning and configures the custom release.
- `scripts/audit-d630.py` — checks required symbols and classifies configuration changes.
- `scripts/build-d630-kernel.sh` — downloads and validates Debian source, builds and packages the kernel.
- `scripts/verify-d630-kernel-build.sh` — package/configuration/firmware/checksum gate.
- `scripts/d630_kconfig.py` and `scripts/test-d630-kconfig.py` — Kconfig parser and unit tests.

The output package name follows Debian's ABI: `linux-image-6.1.0-52-d630-core2_6.1.180-1_amd64.deb`. The kernel release and module directory are `6.1.0-52-d630-core2`; the Debian source version remains `6.1.180-1`.

## Installation and updates

The package is a custom build, not signed by Debian's kernel/UEFI signing key. The stock Latitude D630 has no Secure Boot, so a boot-image signature would not add protection on this machine. Signing for Secure Boot requires a private signing key and enrollment of its certificate on the target system; no signing key is stored in this repository. Keep a known-good kernel and initramfs entry, then test boot, storage, i915, Wi-Fi, audio, touchpad, CPU frequency scaling and nftables/firewalld on the physical laptop.

Debian will not deliver prebuilt updates for this custom image. Keep the known-good kernel and initramfs until the custom kernel is boot-tested. This repository deliberately pins the requested historical source release `6.1.180-1` and matching Debian ABI `6.1.0-52`; do not silently switch kernel versions. Any later security update must be explicitly selected and must update the source version and Debian ABI together.
