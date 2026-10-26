# Build state — D630 Debian Core 2 kernel

Approved target: Debian Bookworm security source package `linux=6.1.180-1`, custom kernel release `6.1.0-52-d630-core2`, binary package `linux-image-6.1.0-52-d630-core2`.

The single GitHub Actions workflow uses Debian's native amd64 runtime image setup/build targets. It applies the D630 configuration, confirms `CONFIG_MCORE2=y`, checks the userspace CPU-frequency governor and ACPI P-state driver, records deliberate module pruning, audits the effective configuration, validates firmware and package contents, and only then publishes the installable package.

The custom package is not signed by Debian's kernel/UEFI signing key; Secure Boot signing requires a user-owned key and certificate enrollment. CI validates build/configuration/package integrity; boot and hardware functionality still require testing on the Latitude D630. Keep the known-good kernel until that test passes.
