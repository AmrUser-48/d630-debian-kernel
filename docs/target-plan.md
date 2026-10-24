# Target contract — Debian 12 / D630 / Linux 6.1.180-1

## Pinned binary ABI

- Debian source package: `linux=6.1.180-1`.
- Normal image package: `linux-image-6.1.0-52-amd64=6.1.180-1`.
- RT image package: `linux-image-6.1.0-52-rt-amd64=6.1.180-1`.
- Custom version suffix: `+d6301`; the output package keeps the stock package name and exact stock kernel release, while the Debian package version is greater than the stock package version.
- The build reuses Debian's own generated amd64/RT configuration and packaging rules. It must not patch Makefile version components or replace Debian's ABI/LOCALVERSION.

The custom image is unsigned by Debian's kernel signing keys. The D630 uses legacy BIOS, but the operator must keep a known-good boot entry and inspect the final package before installation.

## Effective config requirements

- `CONFIG_MCORE2=y`; `CONFIG_GENERIC_CPU` unset; built-in MSR and CPUID.
- `CONFIG_MODULES=y`, module unloading retained, no blanket m-to-n conversion.
- Built-in ext4, Btrfs, NTFS3, FAT/MS-DOS/VFAT, exFAT and UDF; modular ISO9660; built-in SquashFS with zlib/LZ4/LZO/XZ/Zstd.
- Built-in zram with LZ4 default and the Linux 6.1 compressors enabled: LZO-RLE, Zstd, LZ4, LZO, LZ4HC and 842.
- Built-in microcode plus embedded Intel PRO/Wireless 3945ABG firmware. Validate CPU microcode CPUID 0x000006fd and assert exact firmware bytes exist in vmlinux.
- Preserve Debian's i915/Intel AGP, storage, input mouse interface, and nftables FIB values. Do not prune the IWL3945, Intel HDA/Sigmatel or PS/2 touchpad modules.
- Retain ALSA/HDA core and set the Linux 6.1 Sigmatel Kconfig symbol `SND_HDA_CODEC_SIGMATEL=m`, not the invalid `SND_HDA_CODEC_IDT` symbol.
- Normal target must not have PREEMPT_RT enabled. RT target must have `CONFIG_PREEMPT_RT=y`.

## Build and publish contract

Each workflow builds only its native Debian image target from the exact 6.1.180-1 source package. Source files are fetched from the official Debian security pool and checked by dpkg-source against the source descriptor. Build dependencies come from current Bookworm metadata, because the old binary package is no longer the current APT candidate.

Before any artifact or release is published, the workflow must verify:
1. The exact expected image package exists, and its package name, version and architecture match.
2. The package contains `/boot/vmlinuz-<expected release>` and `/lib/modules/<expected release>`.
3. Required modules exist whenever the effective config sets them to `m`.
4. The effective config passes the D630 audit, firmware bytes are embedded, and SHA-256 checks pass.
5. `dist/<variant>/SHA256SUMS` exists and verifies.

Artifact upload uses `if-no-files-found: error`; each variant uses its own artifact name and a unique GitHub pre-release tag. A failed/missing package must never be represented by a successful artifact upload containing only logs.

## Limits

Hosted CI cannot boot the physical laptop. Test legacy-BIOS boot, initramfs generation, SATA/USB storage, i915 graphics, Intel 3945ABG Wi-Fi, HDA audio, PS/2 touchpad and firewalld/nftables on the D630 before relying on the custom kernel.
