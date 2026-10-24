# Kernel workbench status

The earlier prepared-input/build workflow targeted Linux 6.1.187-1 and is retired. It must not be used to produce the requested stock ABI kernel.

The current target is Debian Bookworm Linux source package 6.1.180-1:
- normal ABI: 6.1.0-52-amd64
- RT ABI: 6.1.0-52-rt-amd64
- custom binary version: 6.1.180-1+d6301

The new pair of workflows downloads the historical Debian source archives directly, validates their source descriptor, prepares the exact feature-set config with Debian's native rules, applies the D630 overlay, audits modules/configuration/firmware, builds only the runtime image target, and fails before publication if the package or checksum set is missing.

No physical D630 boot test is performed by hosted CI. Keep a known-good kernel and initramfs entry until both normal or RT build has been tested on the laptop.
