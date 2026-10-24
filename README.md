# Dell Latitude D630 — Debian 12 Bookworm-backports kernel workbench

Build stripped Debian kernels for the Dell Latitude D630 / Intel Core 2 Duo T7250, using Debian's native package rules and the **Bookworm-backports** kernel source, not Debian 13.

As verified on 2026-10-25, the newest Linux source package listed for Debian 12 Bookworm-backports is **`6.12.95-1~bpo12+1`**. Debian lists normal and PREEMPT_RT images from this source. References: [Debian backports Linux source](https://packages.debian.org/bookworm-backports/source/linux), [normal image](https://packages.debian.org/bookworm-backports/linux-image-6.12.95%2Bdeb12-amd64), [RT image](https://packages.debian.org/bookworm-backports/linux-image-6.12.95%2Bdeb12-rt-amd64).

## Two independent build workflows

- [Build D630 Bookworm-backports kernel 6.12.95 (normal amd64)](.github/workflows/build-d630-kernel-amd64.yml)
- [Build D630 Bookworm-backports kernel 6.12.95 (amd64-rt)](.github/workflows/build-d630-kernel-amd64-rt.yml)

Each workflow uses Debian's native setup target (`setup_amd64_none_amd64` or `setup_amd64_rt_amd64`) and corresponding image target (`binary-arch_amd64_none_amd64_image` or `binary-arch_amd64_rt_amd64_image`). Inside the runner, the script edits the generated `.config` directly; it does not layer the policy through `merge_config.sh`, which previously produced noisy duplicate-choice/override warnings. It clears each relevant Kconfig choice group before selecting the intended value: Core 2 (`MCORE2`), XZ kernel image compression, no debug info, LZ4 zram default, and the RT preemption model when applicable. It resolves dependencies with `olddefconfig`, rejects configuration-override warnings, and runs a strict audit before compilation. The final config is audited again after the Debian image target; any missing critical hardware setting or unexplained `m` → `n` module removal fails the run. Only then does it verify the installable package and module tree, check embedded firmware bytes and checksums, upload the artifact, and publish a uniquely tagged pre-release. Missing output makes the workflow fail; logs alone cannot count as a successful artifact.

### Exact output package identities

| Variant | Kernel release | Custom binary package | Custom binary version |
|---|---|---|---|
| Normal amd64 | `6.12.95+deb12-amd64` | `linux-image-6.12.95+deb12-amd64` | `6.12.95-1~bpo12+1+d6301` |
| PREEMPT_RT | `6.12.95+deb12-rt-amd64` | `linux-image-6.12.95+deb12-rt-amd64` | `6.12.95-1~bpo12+1+d6301` |

The custom package version sorts after Debian's backport version while preserving the expected Debian ABI and `/lib/modules` path. These are custom unsigned images, not kernels signed by Debian for Secure Boot.

## D630 hardware and configuration

- **CPU:** select `CONFIG_MCORE2=y` for the T7250, along with MSR and CPUID support. Never use the GitHub runner's `-march=native`.
- **zram:** built in, LZ4 default, with every Linux 6.12 backend enabled: LZO-RLE/LZO, Zstd, LZ4, LZ4HC, DEFLATE and 842.
- **Filesystems:** built-in ext4, Btrfs, NTFS3, FAT/MS-DOS/VFAT, exFAT and UDF; ISO9660 remains modular. SquashFS is built in with zlib, LZ4, LZO, XZ and Zstd compression.
- **Wi-Fi:** Intel PRO/Wireless 3945ABG `iwl3945` stays a module. Its exact requested `iwlwifi-3945-2.ucode` firmware is embedded; Debian's `firmware-iwlwifi` package is also published beside the kernel.
- **CPU microcode:** the T7250 CPUID `0x000006fd` blob `intel-ucode/06-0f-0d` is validated and embedded. The Debian `intel-microcode` package and copyright/license sidecars are included.
- **Graphics:** preserve Debian's native Intel i915/AGP setting and dependencies for GM965/GMA X3100. This GPU generation does not need modern Intel DMC/GuC/HuC firmware. Linux 6.12's upstream i915 Kconfig depends on `!PREEMPT_RT`, so the RT image intentionally cannot include i915; the RT build cannot use accelerated i915 graphics. The audit also checks that any VESA/VGA16 framebuffer options enabled by Debian's baseline are preserved.
- **Audio:** preserve the Intel ICH8 HDA/SigmaTel STAC9205 codec path. The correct Linux 6.12 Kconfig symbol is `SND_HDA_CODEC_SIGMATEL`; the module is named `snd-hda-codec-idt`. It needs no separate codec firmware.
- **Touchpad:** keep `psmouse` modular and unloadable and preserve the built-in legacy `/dev/input/mice` interface for GPM.
- **Storage/firewall:** preserve SATA/AHCI, PATA/ATAPI, SCSI disk/CD, USB mass storage and Debian's nftables FIB/IPv4/IPv6/inet support.
- **Pruning:** remove unrelated sound codecs, vendor GPU drivers, filesystems and unsupported protocol families without blanket-disabling all modules. The config audit logs all changes and highlights any remaining unexplained module removals.

## Validation and installation

Artifacts include the installable kernel image `.deb`, the official firmware packages, effective final config, config diff, symbol-by-symbol audit, microcode validation, package metadata, release notes, build report and `SHA256SUMS`.

Check the package's release notes and hashes. Keep a working kernel/initramfs boot entry until the new image has been tested on the physical D630. Hosted CI verifies build, package and configuration; it cannot prove real hardware boot, Wi-Fi, graphics, audio, touchpad or firewalld behavior.

The older `6.1.180` and `6.1.187` workflow paths are obsolete for this request and are retired; use only the two 6.12.95 Bookworm-backports workflows above.
