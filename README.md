# Dell Latitude D630 — Debian 12 kernel workbench

Target: Debian 12 (Bookworm), amd64, Dell Latitude D630 / Intel Core 2 Duo T7250 / Intel GM965 GMA X3100 / Intel PRO/Wireless 3945ABG, legacy BIOS.

## Pinned reference inputs

- Debian source package: `linux 6.1.187-1` from Bookworm security.
- Official reference kernel image: `linux-image-6.1.0-53-amd64 6.1.187-1`.
- Official configuration package: `linux-config-6.1 6.1.187-1`.
- Intended custom kernel release: `6.1.187-d630-core2`.

The preparation workflow downloads and validates the Debian source inputs (`.dsc`, `.orig.tar.xz`, `.debian.tar.xz`), the signed Debian reference image package and matching configuration package. It also downloads Debian's `intel-microcode` package, extracts the Core 2 Duo T7250 microcode file `intel-ucode/06-0f-0d`, validates its processor signature, and includes Intel's microcode license/copyright in the artifact. It extracts both the reference image's embedded config and Debian's amd64 config, records package metadata and SHA-256 checksums, and validates source-package extraction. Large archives and .deb files are stored as downloadable workflow artifacts, not committed to Git.

## Safety gate

**Preparation only. No custom kernel is compiled, no custom `linux-image` package is built, and no release is published until explicitly approved.** The current workflow only fetches and audits pinned inputs.

## Configuration policy to apply after review

1. Use Debian's source package, configuration and packaging rules—not upstream `x86_64_defconfig`.
2. Preserve Debian's `=m` choices for retained options by default. Disable unnecessary hardware/subsystems deliberately and document each change.
3. Keep i915/DRM modular as in Debian's reference config.
4. Keep the PS/2 mouse/touchpad stack modular (especially `psmouse`) so it can be reloaded; preserve the legacy mouse interface used by GPM where present in the Debian config.
5. Keep ISO9660 as a module.
6. Promote selected everyday filesystems (ext4, Btrfs, NTFS3, FAT/VFAT/MS-DOS and UDF) and zram/its dependencies to built-in only after checking the Linux 6.1.187 Kconfig symbols and dependencies.
7. Preserve Debian userspace facilities and netfilter/nftables modules needed by firewalld, including nftables FIB expressions used by `inet` rules.
8. Embed the T7250's Intel microcode file `intel-ucode/06-0f-0d` for early boot loading with `CONFIG_EXTRA_FIRMWARE="intel-ucode/06-0f-0d"`, `CONFIG_EXTRA_FIRMWARE_DIR="/lib/firmware"`, `CONFIG_MICROCODE=y`, and `CONFIG_FW_LOADER=y`. Ship Intel's required license/copyright notice alongside the image. Record the microcode package version and digest; updated microcode requires a kernel rebuild.
9. Keep debug information out of the runtime package. Publish only the installable custom image package and required firmware/license materials; do not publish debug/development packages by default.

These are target decisions, not an applied kernel configuration. The final config and every difference from Debian's baseline must be audited before building.

## Inputs workflow

See [Prepare Debian inputs](.github/workflows/prepare-debian-inputs.yml). It runs on the relevant scaffolding changes pushed to `main`, and can also be started manually from Actions. Artifacts contain the source package files, official reference image `.deb`, both baseline configs, Debian packaging references, metadata and checksums.

## Provenance

Downloads use Debian Bookworm / Bookworm security APT repositories and APT's authenticated package indexes. The source archive is validated with Debian source tooling. References: [Debian linux source package](https://packages.debian.org/bookworm/source/linux), [linux-image-6.1.0-53-amd64](https://packages.debian.org/bookworm/linux-image-6.1.0-53-amd64), [linux-config-6.1](https://packages.debian.org/bookworm/linux-config-6.1).
