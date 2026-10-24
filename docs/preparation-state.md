# Current kernel workbench state

Target: Debian 12 Bookworm-backports Linux source `6.12.95-1~bpo12+1`, not Debian 13.

Normal ABI: `6.12.95+deb12-amd64`.
RT ABI: `6.12.95+deb12-rt-amd64`.
Custom binary version: `6.12.95-1~bpo12+1+d6301`.

The first 6.12.95 attempts stopped on setup-target naming and did **not** compile kernel images. The active workflow pair now uses Debian's documented native targets and edits Debian's generated configuration in place. It clears the zram default choice before selecting LZ4, resolves dependencies through `olddefconfig`, audits before and after the image build, and fails on critical configuration loss or unexplained module removals. CA bootstrap is also fixed by installing the Debian CA bundle from signed APT metadata before switching repository traffic to HTTPS.

Do not use the retired 6.1.180/6.1.187 workflows for this request. No kernel package should be considered successful until a matching installable image .deb, its expected `/lib/modules` release path, firmware checks, the config audit and checksums all pass. Hosted CI cannot replace the physical D630 boot test.
