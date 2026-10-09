# Preparation state

This repository is being initialized for the Debian Bookworm `linux` source package `6.1.187-1`.

The first workflow downloads:
- `linux_6.1.187-1.dsc`
- `linux_6.1.187.orig.tar.xz`
- `linux_6.1.187-1.debian.tar.xz`
- `linux-image-6.1.0-53-amd64_6.1.187-1_amd64.deb`
- `linux-config-6.1_6.1.187-1_amd64.deb`
- the Bookworm `intel-microcode` amd64 package
- extracted `microcode/intel-ucode/06-0f-0d` plus Intel license/copyright and verification metadata

It extracts the two reference configs, validates Debian source extraction, and checks the Intel microcode blob for CPUID signature `06fd`. Source archives and binary packages live in the Actions artifact, not Git.

**This workflow does not compile or package the D630 kernel. Wait for explicit approval before adding or running the custom build.**
