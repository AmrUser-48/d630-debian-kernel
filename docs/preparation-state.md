# Current kernel workbench state

Target: Debian 12 Bookworm-backports Linux source `6.12.95-1~bpo12+1`, not Debian 13.

Normal ABI: `6.12.95+deb12-amd64`.
RT ABI: `6.12.95+deb12-rt-amd64`.
Custom binary version: `6.12.95-1~bpo12+1+d6301`.

No kernel package has been produced yet. The last normal and RT attempts reached the pre-compile configuration audit and correctly refused to compile because the audit expected the nonexistent Linux 6.12 `MICROCODE_INTEL` symbol and incorrectly required the hidden `SND_HDA` tristate to be built in. The RT audit also exposed the upstream Linux 6.12 `DRM_I915 depends on !PREEMPT_RT` constraint.

The current correction uses `CPU_SUP_INTEL=y` with `MICROCODE=y`, expects the modular HDA core at `m`, preserves i915 in the normal kernel, and explicitly audits the upstream i915 RT limitation. The strict baseline-symbol gate now accounts for the one conditional `EXTRA_FIRMWARE_DIR` symbol: it is not generated while the firmware list is empty, so the runner verifies the symbol declaration in source Kconfig and adds it only alongside the nonempty firmware request. The runner edits Debian's native generated `.config` directly, normalizes choice groups before `olddefconfig`, rejects config warnings, audits critical symbols before compilation, and fails closed on unexplained module removals. The required firmware, compressors, filesystems, packages and checksums remain hard gates.

Only the paired normal and RT Bookworm-backports workflows should be used. A successful CI build still needs a physical boot test on the Dell Latitude D630.
