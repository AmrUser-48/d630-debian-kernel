#!/usr/bin/env python3
"""Shared parsing and normalization for Linux Kconfig files and fragments."""
from __future__ import annotations

from pathlib import Path
import re

CONFIG_SET = re.compile(r"^CONFIG_([A-Z0-9_]+)=(.*)$")
CONFIG_UNSET = re.compile(r"^# CONFIG_([A-Z0-9_]+) is not set$")


def parse_config_text(text: str) -> dict[str, str]:
    """Parse effective .config syntax; absent symbols are intentionally omitted."""
    values: dict[str, str] = {}
    for line in text.splitlines():
        match = CONFIG_SET.match(line)
        if match:
            values[match.group(1)] = match.group(2)
            continue
        match = CONFIG_UNSET.match(line)
        if match:
            values[match.group(1)] = "n"
    return values


def read_config(path: str | Path) -> dict[str, str]:
    """Read a Kconfig file into CONFIG_SYMBOL -> value (n/m/y/string/int)."""
    return parse_config_text(Path(path).read_text(encoding="utf-8", errors="replace"))


def normalize_fragment(text: str) -> tuple[str, list[str]]:
    """Collapse equivalent repeated assignments and reject contradictory ones.

    A Kconfig fragment must contain at most one effective assignment per symbol.
    Both 'CONFIG_FOO=n' and '# CONFIG_FOO is not set' represent the same value.
    Comments and ordering are preserved; only redundant assignment lines are
    dropped. Conflicts fail immediately rather than relying on merge_config.sh's
    last-occurrence-wins behaviour.
    """
    values: dict[str, str] = {}
    output: list[str] = []
    duplicates: list[str] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        match = CONFIG_SET.match(line)
        if match:
            symbol, requested = match.group(1), match.group(2)
        else:
            match = CONFIG_UNSET.match(line)
            if not match:
                output.append(line)
                continue
            symbol, requested = match.group(1), "n"

        if symbol in values:
            if values[symbol] != requested:
                raise ValueError(
                    f"conflicting duplicate CONFIG_{symbol}: "
                    f"{values[symbol]!r} then {requested!r} (line {line_number})"
                )
            duplicates.append(symbol)
            continue

        values[symbol] = requested
        output.append(line)

    normalized = "\n".join(output).rstrip() + "\n"
    return normalized, sorted(duplicates)
