#!/usr/bin/env python3
"""Apply a narrowly scoped D630 policy to Debian's native amd64 image target."""

from difflib import unified_diff
from pathlib import Path
import re
import sys

if len(sys.argv) != 4:
    raise SystemExit("usage: apply-d630-build-policy.py SOURCE_DIR AUDIT_DIR OVERLAY_CONFIG")

source = Path(sys.argv[1]).resolve()
audit = Path(sys.argv[2]).resolve()
overlay = Path(sys.argv[3]).resolve()
audit.mkdir(parents=True, exist_ok=True)

makefile = source / "Makefile"
rules = source / "debian/rules.gen"
target_config = source / "debian/config/d630-core2.config"
if not makefile.is_file() or not rules.is_file():
    raise SystemExit("Debian source tree lacks Makefile or debian/rules.gen")
if not overlay.is_file():
    raise SystemExit("Missing committed D630 config overlay: " + str(overlay))

make_before = makefile.read_text()
rules_before = rules.read_text()
(audit / "kernel-Makefile-before.txt").write_text(make_before)
(audit / "rules.gen-before.txt").write_text(rules_before)
target_config.parent.mkdir(parents=True, exist_ok=True)
target_config.write_text(overlay.read_text())

make_after = make_before
for key, value in (("VERSION", "6"), ("PATCHLEVEL", "1"), ("SUBLEVEL", "187"), ("EXTRAVERSION", "")):
    pattern = re.compile(r"(?m)^" + re.escape(key) + r"\s*=.*$")
    make_after, count = pattern.subn(key + " = " + value, make_after, count=1)
    if count != 1:
        raise SystemExit("Could not set exactly one top-level Makefile variable: " + key)
makefile.write_text(make_after)

lines = rules_before.splitlines(keepends=True)
target_indices = [i for i, line in enumerate(lines) if line.startswith("binary-arch_amd64_none_amd64_real_image:")]
if len(target_indices) != 1:
    raise SystemExit("Expected exactly one binary-arch_amd64_none_amd64_real_image target; got " + str(len(target_indices)))

index = target_indices[0]
recipe_index = None
for i in range(index + 1, min(index + 8, len(lines))):
    if lines[i].startswith("\t") and "binary_image" in lines[i]:
        recipe_index = i
        break
    if lines[i].strip() and not lines[i].startswith("\t"):
        break
if recipe_index is None:
    raise SystemExit("Could not locate Debian image build recipe immediately below the target")

recipe = lines[recipe_index]
kconfig_match = re.search(r"KCONFIG='([^']*)'", recipe)
if not kconfig_match:
    raise SystemExit("Cannot safely parse KCONFIG in Debian image recipe")
kconfig_parts = kconfig_match.group(1).split()
if "debian/config/d630-core2.config" not in kconfig_parts:
    kconfig_parts.append("debian/config/d630-core2.config")
recipe = recipe[:kconfig_match.start(1)] + " ".join(kconfig_parts) + recipe[kconfig_match.end(1):]

for pattern, replacement in (
    (r"\bABINAME='[^']*'", "ABINAME='6.1.187'"),
    (r"\bLOCALVERSION='[^']*'", "LOCALVERSION='-d630-core2'"),
    (r"\bLOCALVERSION_IMAGE='[^']*'", "LOCALVERSION_IMAGE='-d630-core2'"),
):
    recipe, count = re.subn(pattern, replacement, recipe, count=1)
    if count != 1:
        raise SystemExit("Could not safely set Debian image recipe variable: " + pattern)
lines[recipe_index] = recipe
rules_after = "".join(lines)
rules.write_text(rules_after)

(audit / "kernel-Makefile.diff").write_text(
    "".join(unified_diff(make_before.splitlines(keepends=True), make_after.splitlines(keepends=True),
                         fromfile="Debian-Makefile.before", tofile="Debian-Makefile.after"))
)
(audit / "rules.gen.diff").write_text(
    "".join(unified_diff(rules_before.splitlines(keepends=True), rules_after.splitlines(keepends=True),
                         fromfile="Debian-rules.gen.before", tofile="Debian-rules.gen.after"))
)
(audit / "build-policy-applied.txt").write_text(
    "Debian source package: linux 6.1.187-1\n"
    "Native build target: binary-arch_amd64_none_amd64_real_image\n"
    "Source Makefile: VERSION=6 PATCHLEVEL=1 SUBLEVEL=187 EXTRAVERSION empty\n"
    "Debian ABI name passed to image target: 6.1.187\n"
    "Debian LOCALVERSION and LOCALVERSION_IMAGE: -d630-core2\n"
    "The image target KCONFIG chain includes debian/config/d630-core2.config last\n"
    "The generated config diff is checked by audit-d630-config.py\n"
)
print("Applied D630 policy to Debian's native amd64 image target.")
