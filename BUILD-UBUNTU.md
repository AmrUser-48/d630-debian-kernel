# Native Ubuntu build guide

Build Debian Bookworm Linux source package `6.1.180-1` on an Ubuntu x86_64 runner, using the repository's stripped `config/config.thin` and Kbuild's `bindeb-pkg` target. This route does not use Docker.

**This is a direct upstream-Kbuild package build, not the repository's Debian `debian/rules.gen` CI build.** The guide below shows how to give the native build the requested kernel release and package name `6.1.0-52-d630-core2`, while keeping the actual Debian source package version `6.1.180-1`. This matches the kernel release string and image package name, but does not run Debian's ABI-generation or the repository CI audit/repackaging pipeline.

The commands below use the runner workspace `/home/runner/d630-kernel` and a four-vCPU runner.

## 1. Install Ubuntu build dependencies

```bash
sudo apt update
sudo apt install -y \
  build-essential bc bison flex \
  libssl-dev libelf-dev libncurses-dev dwarves \
  rsync cpio kmod fakeroot dpkg-dev \
  python3 curl ca-certificates \
  xz-utils zstd lz4 \
  intel-microcode linux-firmware linux-firmware-intel-wireless iucode-tool
```

## Firmware required before compiling

The stripped config requests built-in firmware:

- `intel-ucode/06-0f-0d` — Intel microcode for the D630's T7250.
- `iwlwifi-3945-2.ucode` — Intel PRO/Wireless 3945ABG firmware.

Because `CONFIG_EXTRA_FIRMWARE_DIR="/lib/firmware"`, Kbuild requires these exact, **uncompressed** files at these paths while compiling:

- `/lib/firmware/intel-ucode/06-0f-0d`
- `/lib/firmware/iwlwifi-3945-2.ucode`

Install the firmware packages:

```bash
sudo apt install -y intel-microcode linux-firmware-intel-wireless zstd iucode-tool
```

Ubuntu 24.04's `linux-firmware-intel-wireless` package stores this legacy Wi-Fi blob compressed at `/lib/firmware/intel/iwlwifi/iwlwifi-3945-2.ucode.zst`. Decompress it to the exact top-level filename expected by `CONFIG_EXTRA_FIRMWARE`:

```bash
sudo mkdir -p /lib/firmware/intel-ucode
sudo zstd -q -d -f \
  /lib/firmware/intel/iwlwifi/iwlwifi-3945-2.ucode.zst \
  -o /lib/firmware/iwlwifi-3945-2.ucode
```

Verify **both** firmware inputs before running `make`:

```bash
ls -lh \
  /lib/firmware/intel-ucode/06-0f-0d \
  /lib/firmware/iwlwifi-3945-2.ucode

iucode_tool -l /lib/firmware/intel-ucode/06-0f-0d
```

The microcode listing must include CPU signature `0x000006fd` (T7250). If either `ls` path is missing, do not start the kernel build. The error `No rule to make target '/lib/firmware/intel-ucode/06-0f-0d'` means the built-in firmware input is missing; it is not a compiler or Kconfig failure. After installing/placing the files, rerun the same build command.

## 2. Download and unpack Debian source

Source package: `linux=6.1.180-1`.

If the source has already been unpacked into `/home/runner/d630-kernel/source/linux`, skip this section.

```bash
mkdir -p /home/runner/d630-kernel/download
mkdir -p /home/runner/d630-kernel/source
cd /home/runner/d630-kernel/download

curl -fL --retry 3 \
  https://security.debian.org/debian-security/pool/updates/main/l/linux/linux_6.1.180-1.dsc \
  -o linux_6.1.180-1.dsc

curl -fL --retry 3 \
  https://security.debian.org/debian-security/pool/updates/main/l/linux/linux_6.1.180.orig.tar.xz \
  -o linux_6.1.180.orig.tar.xz

curl -fL --retry 3 \
  https://security.debian.org/debian-security/pool/updates/main/l/linux/linux_6.1.180-1.debian.tar.xz \
  -o linux_6.1.180-1.debian.tar.xz

dpkg-source -x \
  /home/runner/d630-kernel/download/linux_6.1.180-1.dsc \
  /home/runner/d630-kernel/source/linux
```

## 3. Load the stripped configuration

Use the full `config.thin` file as the kernel's `.config`. Do not start from `defconfig` or Debian's generic amd64 config.

```bash
curl -fL \
  https://raw.githubusercontent.com/AmrUser-48/d630-debian-kernel/main/config/config.thin \
  -o /home/runner/d630-kernel/source/linux/.config

cd /home/runner/d630-kernel/source/linux
make olddefconfig
```

`olddefconfig` resolves Kconfig dependencies and choice values in the supplied stripped configuration. Review the resolved `.config` before compiling; it is the actual build input.

The stripped configuration must retain:

- `CONFIG_MCORE2=y` and `# CONFIG_GENERIC_CPU is not set`.
- D630 storage, filesystem, graphics, Wi-Fi, HDA/Sigmatel, input and ACPI support.
- ZRAM and the requested compressor implementations/default.
- `CONFIG_LOCALVERSION=""` and `# CONFIG_LOCALVERSION_AUTO is not set`.

Check the important config values before setting the release override:

```bash
grep -E '^(CONFIG_MCORE2=y|# CONFIG_GENERIC_CPU is not set|CONFIG_LOCALVERSION=|CONFIG_ZRAM=|CONFIG_ZRAM_DEF_COMP=|CONFIG_SND_HDA_INTEL=|CONFIG_SND_HDA_CODEC_SIGMATEL=)' .config
```

## 4. Set the exact build flags

Run these exports in the same shell used for the build:

```bash
export ARCH=x86_64
export KCFLAGS="-march=core2"
export LOCALVERSION="-d630-core2"
```

- `ARCH=x86_64` selects the 64-bit x86 kernel target.
- `KCFLAGS="-march=core2"` explicitly compiles kernel C code for the Intel Core 2 target.
- `LOCALVERSION="-d630-core2"` appends the D630 identifier to the kernel release.

Keep `CONFIG_MCORE2=y` in `.config`; the explicit `KCFLAGS` is retained as requested.

### Set the Debian-style kernel release

The source tree is still Debian Linux `6.1.180-1`. To make Kbuild name the kernel release and image package `6.1.0-52-d630-core2`, override the kernel Makefile version fields at build time. Keep the `LOCALVERSION` export above:

```bash
make VERSION=6 PATCHLEVEL=1 SUBLEVEL=0 EXTRAVERSION=-52 -s kernelrelease
```

Expected output:

```text
6.1.0-52-d630-core2
```

These Make variables change release and package naming only; they do **not** change the source code from Linux `6.1.180` to `6.1.0`. `KDEB_PKGVERSION` is a separate Debian binary-package version and remains `6.1.180-1`.

## 5. Build Debian binary packages

The runner has four vCPUs; use four parallel jobs:

```bash
make -j4 VERSION=6 PATCHLEVEL=1 SUBLEVEL=0 EXTRAVERSION=-52 KDEB_PKGVERSION=6.1.180-1 bindeb-pkg
```

The expected image package is:

```text
linux-image-6.1.0-52-d630-core2_6.1.180-1_amd64.deb
```

The installed kernel release and module directory are `6.1.0-52-d630-core2`. Kbuild derives the `linux-image-...` package name from `KERNELRELEASE`; `KDEB_PKGVERSION=6.1.180-1` sets the Debian package version, not the kernel release.

The package build runs from `/home/runner/d630-kernel/source/linux`. Kbuild places the resulting `.deb` files in the parent directory:

```bash
ls -lh /home/runner/d630-kernel/source/*.deb
```

Keep the currently working kernel and boot entry until the new package has been installed and tested on the D630.

## Important distinction from the CI build

Do not run `scripts/build-d630-kernel.sh` as an Ubuntu-host build recipe. That script is designed for the repository's disposable Debian Bookworm build environment; it changes APT source-list files and removes/recreates the repository's `build-work/amd64`, `audit/amd64` and `dist/amd64` output directories.

This native guide intentionally uses `make bindeb-pkg` with the complete stripped `.config`. The explicit `VERSION=6 PATCHLEVEL=1 SUBLEVEL=0 EXTRAVERSION=-52` arguments reproduce the requested release string and image package name, but they do not reproduce Debian's generated `debian/rules.gen` build environment, CI audits, or repackaging pipeline. The CI verifier is not applicable to this native package.
