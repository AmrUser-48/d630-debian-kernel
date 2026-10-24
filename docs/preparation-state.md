# Current kernel workbench state

The previous Linux 6.1.180 and 6.1.187 build attempts did not produce a kernel package. Their config/audit and source-package inputs are obsolete for this target; old workflow entry points are retired.

The active target is Debian 12 Bookworm-backports Linux 6.12.95-1~bpo12+1, verified as the newest listed backport as of 2026-10-25:
- Normal ABI: `6.12.95+deb12-amd64`.
- RT ABI: `6.12.95+deb12-rt-amd64`.
- Custom binary version: `6.12.95-1~bpo12+1+d6301`.

Use only the paired normal and RT workflows. They share one version-pinned build script and produce separate artifacts/releases. They verify package identity, expected module paths, the Core 2 CPU selection, all requested filesystem/zram/SquashFS compressors, the Wi-Fi and audio modules, embedded CPU microcode and Wi-Fi firmware, the RT preemption option, and checksums before publishing.

A successful CI run still needs a real boot test on the Dell Latitude D630.
