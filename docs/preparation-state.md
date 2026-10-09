# Preparation and build state

The input workflow prepares Debian Bookworm source package linux 6.1.187-1, the matching official reference image/config package, and Debian intel-microcode for the Intel Core 2 Duo T7250.

The build workflow:
- extracts and validates the pinned Debian source package;
- runs Debian's amd64 setup target to capture the stock generated config;
- applies config/d630-core2.config only to the amd64 runtime image target;
- checks the exact kernel release 6.1.187-d630-core2 before the long compile;
- builds only the runtime image package, with no debug/development targets;
- audits effective configuration changes and rejects unexplained Debian module m-to-n conversions;
- verifies that the Core 2 microcode bytes are built into vmlinux and includes the Intel license/copyright;
- uploads the installable .deb, checksums, log and complete config/packaging audit.

A successful CI package still requires a real boot test on the target Dell Latitude D630. Debian firmware for the Intel PRO/Wireless 3945ABG is separate from the embedded CPU microcode.
