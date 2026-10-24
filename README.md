# Dell Latitude D630 — Debian kernel build

This repository produces installable Debian 12 kernel packages from Debian's **pinned Linux source package 6.1.180-1** for the Dell Latitude D630 / Intel Core 2 Duo T7250.

| Variant | Debian package | Kernel release |
|---|---|---|
| Standard | `linux-image-6.1.0-52-amd64` | `6.1.0-52-amd64` |
| PREEMPT_RT | `linux-image-6.1.0-52-rt-amd64` | `6.1.0-52-rt-amd64` |

The custom binary package version is `6.1.180-1+d6301`. Packages are custom and unsigned by Debian's kernel signing keys. Keep a known-good boot entry until the kernel has been tested on the physical machine.

## Run a build

Use the single **D630 Kernel — Build, Audit & Publish** workflow:

[Open the kernel build workflow](.github/workflows/d630-kernel-build.yml)

On a manual run, select `amd64`, `amd64-rt`, or `both`. A push that changes the workflow, configuration, or build scripts builds both variants. Documentation-only changes do not start a six-hour kernel build.

The Actions UI uses one naming scheme:
- **Workflow:** `D630 Kernel — Build, Audit & Publish`
- **Run:** variant selection, branch, and run number
- **Job:** `Build, validate & publish / <variant>`
- **Steps:** named by operation, such as `Build Debian kernel package / amd64` and `Verify package, configuration & checksums`

The workflow has separate deliverable and diagnostic artifacts. The **installable package artifact is uploaded only after verification succeeds**, and the pre-release is published only after that upload succeeds. Logs and audit files are uploaded on failures too, without being mislabelled as a successful kernel package.

## Build method

The build follows Debian's native kernel packaging rules, not a generic upstream `defconfig` build:

1. Reclaim unused disk space on the fresh GitHub-hosted runner and report disk use before/after cleanup.
2. Run Bash/Python syntax checks, Kconfig unit tests, and checksummed actionlint validation of the workflow schema and expressions.
3. Download the pinned Debian source archive and verify its checksums with `dpkg-source`.
4. Generate Debian's native configuration for the selected featureset.
5. Apply the D630 overlay once, normalize repeated Kconfig assignments, and reject contradictory assignments.
6. Run `olddefconfig`, audit the effective config, and refuse to compile if Kconfig override/choice warnings occur.
7. Build Debian's native `binary-arch_amd64_none_amd64_real_image` or `binary-arch_amd64_rt_amd64_real_image` target.
8. Audit the post-build config, firmware blobs, package identity, required module payloads, and SHA-256 checksums.
9. Upload the verified package and publish its assets to a uniquely tagged pre-release.

The workflows use `actions/checkout@v7` and `actions/upload-artifact@v7`. They run the actual Debian build inside `debian:bookworm`; the host runner is used for orchestration, disk management, artifact upload, and release publication. Builds use two jobs in parallel inside the container to limit memory use.

## Configuration and script ownership

- `config/d630-core2-6.1.180.config`: the committed D630 policy overlay on Debian's generated configuration.
- `scripts/build-d630-6.1.180.sh`: orchestrates source/dependency preparation, native config generation, compilation, firmware checks, and package creation.
- `scripts/apply-d630-6.1.180-policy.py`: applies hardware-specific pruning and appends the overlay to the selected Debian image target's `KCONFIG` chain. It does not rewrite Debian's kernel ABI or `LOCALVERSION`.
- `scripts/d630_kconfig.py`: shared config parser and fragment normalizer. Identical repeated assignments are collapsed; contradictory assignments fail closed.
- `scripts/audit-d630-6.1.180.py`: checks mandatory settings and records the effective diff and symbol classification.
- `scripts/test-d630-kconfig.py`: fast unit tests for config parsing and normalization.
- `scripts/verify-d630-6.1.180-build.sh`: final package/config/firmware/checksum gate before a deliverable artifact or release can be created.

The build preserves Debian's generated settings for Intel i915/AGP, storage, USB mass storage and nftables, while applying an explicit D630 policy. Important required settings include `CONFIG_MCORE2=y`, built-in ALSA/HDA/ALSA PCI core, modular Intel HDA and Sigmatel codec, modular Intel 3945ABG Wi-Fi, built-in zram with LZ4 as the default, and the requested local filesystems. Unsupported symbols or unmet Kconfig dependencies cause the audit to fail.

## Artifacts and diagnosis

A successful run produces an artifact named like `d630-kernel-amd64-<run-id>-<attempt>` or `d630-kernel-amd64-rt-<run-id>-<attempt>`, containing the installable Debian image, firmware packages, configuration audit, release notes and checksums. Matching uniquely tagged GitHub pre-releases contain the same deliverables.

On failure, open the artifact named `d630-kernel-diagnostics-<variant>-<run-id>-<attempt>`. Start with `build-<variant>.log`, then inspect `audit/<variant>/kconfig-merge.log`, `kconfig-olddefconfig.log`, `native-image-build.log`, `d630-config-symbol-audit.tsv`, and `unclassified-module-drops.txt` where present.

Hosted CI can verify the source, effective config and package contents. It cannot prove that the kernel boots or that graphics, audio, Wi-Fi, touchpad and firewalld work on the physical D630; test those after installation.
