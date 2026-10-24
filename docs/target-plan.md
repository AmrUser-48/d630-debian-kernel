# Target contract — Debian 12 Bookworm-backports / Dell Latitude D630

## Pinned source and ABI

- Debian suite: `bookworm-backports`, not Trixie/ Debian 13.
- Source package: `linux=6.12.95-1~bpo12+1`.
- Normal image release: `6.12.95+deb12-amd64`.
- RT image release: `6.12.95+deb12-rt-amd64`.
- Custom package version: `6.12.95-1~bpo12+1+d6301`.
- Normal package: `linux-image-6.12.95+deb12-amd64`.
- RT package: `linux-image-6.12.95+deb12-rt-amd64`.

The source is fetched from APT's signed Bookworm-backports metadata and checked through Debian's source descriptor. Debian's native generated configuration and image target are used for each feature set. Do not patch kernel Makefile version components, `ABINAME`, or `LOCALVERSION`.

## Core config requirements

- `CONFIG_MCORE2=y`; `CONFIG_GENERIC_CPU` unset; `CONFIG_X86_MSR=y`, `CONFIG_X86_CPUID=y`.
- `CONFIG_KERNEL_XZ=y`; debug information disabled with `CONFIG_DEBUG_INFO_NONE=y`.
- `CONFIG_MODULES=y`, module unloading remains enabled, and the PS/2 protocol module remains `CONFIG_MOUSE_PS2=m`.
- Built-in ext4, Btrfs, NTFS3, FAT/MS-DOS/VFAT, exFAT and UDF; modular ISO9660; built-in OverlayFS and SquashFS with zlib/LZ4/LZO/XZ/Zstd.
- Built-in zram with LZ4 default and all 6.12 zram compression backends (LZO, Zstd, LZ4, LZ4HC, DEFLATE, 842).
- Embed microcode `intel-ucode/06-0f-0d` and Intel 3945ABG firmware `iwlwifi-3945-2.ucode`. Validate the T7250 CPUID signature `0x000006fd` and assert exact firmware bytes occur in `vmlinux`.
- Retain `iwl3945`, Intel HDA/SigmaTel, and PS/2 touchpad modules when the effective config sets them to `m`. Use `SND_HDA_CODEC_SIGMATEL`, not an obsolete codec symbol.
- Preserve the Debian baseline's i915/AGP, SATA/ATAPI, SCSI core/disk/CD, USB mass storage, input mouse interface and nftables FIB values.
- Normal image requires `CONFIG_PREEMPT_RT=n`; RT image requires `CONFIG_PREEMPT_RT=y` and the native Debian `rt` image target.

## Pipeline acceptance criteria

Each separate workflow must: fetch exact source version `6.12.95-1~bpo12+1`; generate the matching Debian `none` or `rt` config; apply the D630 overlay to only the target's KCONFIG chain; run `olddefconfig`; audit critical symbols; build only the native runtime image; and verify the exact expected package name, custom version, architecture, `/boot/vmlinuz-<release>`, `/lib/modules/<release>`, required modules, embedded firmware and SHA-256 checksums.

The workflow uploads and publishes only after verification, with unique tags and distinct normal/RT artifact names. Artifact upload is `if-no-files-found: error`; logs without the package are a failed build.

## Hardware test remains required

Hosted CI cannot validate physical boot. Keep a known-good boot entry. On the actual D630 test legacy-BIOS boot, initramfs generation, SATA/USB storage, i915 graphics, 3945ABG Wi-Fi, HDA audio, touchpad, zram compressors and nftables/firewalld.


## Runner configuration must be deterministic

Do not use `merge_config.sh` to layer the D630 policy on top of the Debian baseline: duplicate choice entries create an override cascade that made earlier logs hard to reason about. The runner must:
1. invoke the exact native `setup_amd64_<featureset>_amd64` target and snapshot Debian's generated `.config`;
2. edit that actual generated `.config` directly from the committed policy and explicit device rules;
3. clear all `ZRAM_DEF_COMP_*` choice selections before selecting only `ZRAM_DEF_COMP_LZ4`;
4. run `olddefconfig`, fail if override/choice warnings appear, and audit the *resolved* config before compilation;
5. hard-fail for missing audio/Wi-Fi/i915/storage/filesystem/compressor/microcode/RT requirements or unexplained Debian module `m -> n` drops;
6. re-audit the config produced by the actual image build before repackaging.
