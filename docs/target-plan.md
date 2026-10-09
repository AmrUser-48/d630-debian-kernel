# Target contract — Debian 12 / D630

## Pinned inputs

- Source: Debian `linux` source package `6.1.187-1` (Bookworm security).
- Official signed image reference: `linux-image-6.1.0-53-amd64=6.1.187-1`.
- Official config package: `linux-config-6.1=6.1.187-1`.
- Intended custom release string: `6.1.187-d630-core2`.

The official image is a reference for the exact Debian-built configuration and package layout. It is not the custom output and is not installed by this workflow.

## Configuration policy

- Begin with Debian source/package configuration and rules.
- Keep each retained Debian `=m` option modular by default.
- Disable unsupported hardware and unnecessary subsystems through explicit, reviewed exclusions.
- Promote ext4, Btrfs, NTFS3, FAT/VFAT/MS-DOS, UDF, and zram plus required dependencies to built-in after validating Linux 6.1.187 Kconfig dependencies.
- Keep ISO9660 modular.
- Keep DRM/i915 and the relevant Intel AGP arrangement consistent with the exact Debian baseline.
- Keep `CONFIG_MOUSE_PS2=m` (module name `psmouse`) and required PS/2 protocol support modular; keep module unloading enabled; preserve `MOUSEDEV` if stock Debian uses it.
- Preserve netfilter/nftables features required by firewalld. In particular, audit the nftables FIB expression support for IPv4, IPv6 and inet tables.
- Retain Debian userspace support (cgroups, namespaces, seccomp, AppArmor, eBPF and related facilities) unless a specific option is shown unnecessary.
- Disable debug info and exclude debug/development binary packages from the published runtime release.

## Required audit before any custom build

1. Record source version and verify `dpkg-source -x` succeeds.
2. Compare the Debian config package's amd64 config, the reference image's embedded `/boot/config-6.1.0-53-amd64`, and the proposed final config.
3. Every changed option must be present in a generated diff and classified as retained, explicitly disabled, or promoted to built-in.
4. Verify no retained Debian module was silently converted to `n`.
5. Verify release string, package version, module directory, firmware contents, and the contents of the resulting `linux-image` package.

## Safety gate

The input-preparation workflow performs no compilation, no custom `linux-image` packaging, no installation, and no release publication. Await explicit user approval before implementing a custom build workflow.
