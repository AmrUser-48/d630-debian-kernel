#!/usr/bin/env python3
"""Unit tests for the shared D630 Kconfig parser and fragment normalizer."""
from __future__ import annotations

import unittest

from d630_kconfig import normalize_fragment, parse_config_text


class KconfigFragmentTests(unittest.TestCase):
    def test_identical_assignments_are_collapsed(self):
        source = (
            "# Device policy\n"
            "CONFIG_SND_PCI=y\n"
            "CONFIG_SND_PCI=y\n"
            "CONFIG_EXTRA_FIRMWARE=\"one two\"\n"
        )
        result, duplicates = normalize_fragment(source)
        self.assertEqual(result.count("CONFIG_SND_PCI=y"), 1)
        self.assertIn('CONFIG_EXTRA_FIRMWARE="one two"', result)
        self.assertEqual(duplicates, ["SND_PCI"])

    def test_n_and_unset_are_equivalent(self):
        source = "# CONFIG_NVME_CORE is not set\nCONFIG_NVME_CORE=n\n"
        result, duplicates = normalize_fragment(source)
        self.assertEqual(result.count("NVME_CORE"), 1)
        self.assertEqual(duplicates, ["NVME_CORE"])

    def test_conflicting_assignments_fail_closed(self):
        source = "CONFIG_SND_HDA_INTEL=m\n# CONFIG_SND_HDA_INTEL is not set\n"
        with self.assertRaisesRegex(ValueError, "conflicting duplicate CONFIG_SND_HDA_INTEL"):
            normalize_fragment(source)

    def test_config_parser_reads_set_and_unset_symbols(self):
        values = parse_config_text(
            'CONFIG_MCORE2=y\nCONFIG_SND_HDA_INTEL=m\n'
            '# CONFIG_ZRAM_DEF_COMP_LZORLE is not set\n'
            'CONFIG_EXTRA_FIRMWARE="a b"\n'
        )
        self.assertEqual(values["MCORE2"], "y")
        self.assertEqual(values["SND_HDA_INTEL"], "m")
        self.assertEqual(values["ZRAM_DEF_COMP_LZORLE"], "n")
        self.assertEqual(values["EXTRA_FIRMWARE"], '"a b"')


if __name__ == "__main__":
    unittest.main(verbosity=2)
