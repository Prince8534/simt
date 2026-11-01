"""Regression tests for IPDOM analysis and loadable metadata conversion."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import simt_ipdom_analyzer
import simt_ipdom_to_mem

ROOT = Path(__file__).resolve().parent


class IpdomAnalyzerTests(unittest.TestCase):
    def analyze_source(self, source):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "kernel.asm"
            path.write_text(source, encoding="utf-8")
            instructions, labels = simt_ipdom_analyzer.parse_source(path)
            return simt_ipdom_analyzer.analyze(instructions, labels, path)

    def test_rejects_backward_branch(self):
        with self.assertRaisesRegex(ValueError, "backward branch"):
            self.analyze_source("start:\n  beq x1, x2, start\n")

    def test_rejects_branch_without_fallthrough_join(self):
        with self.assertRaisesRegex(ValueError, "no fallthrough JOIN"):
            self.analyze_source("beq x1, x2, target\nnop\ntarget:\n  nop\n")


class IpdomMemoryConverterTests(unittest.TestCase):
    def valid_metadata(self):
        return {
            "format": "simt-ipdom-v1",
            "hardware_metadata_safe": True,
            "regions": [{
                "branch_pc": "0x00000004",
                "reconvergence_pc": "0x00000018",
                "fallthrough_join_pc": "0x0000000c",
                "taken_join_pc": "0x00000014"
            }],
            "branch_to_reconvergence": {
                "0x00000004": "0x00000018"
            }
        }

    def test_generates_branch_and_join_records(self):
        branches, joins = simt_ipdom_to_mem.convert(self.valid_metadata())
        self.assertEqual(branches, ["0000000400000018"])
        self.assertEqual(
            joins,
            ["0000000c0000000400000018", "000000140000000400000018"]
        )

    def test_empty_metadata_generates_sentinels(self):
        data = self.valid_metadata()
        data["regions"] = []
        data["branch_to_reconvergence"] = {}
        branches, joins = simt_ipdom_to_mem.convert(data)
        self.assertEqual(branches, ["ffffffffffffffff"])
        self.assertEqual(joins, ["ffffffffffffffffffffffff"])

    def test_rejects_unknown_format(self):
        data = self.valid_metadata()
        data["format"] = "unknown"
        with self.assertRaisesRegex(ValueError, "unsupported metadata format"):
            simt_ipdom_to_mem.convert(data)

    def test_rejects_unsafe_metadata(self):
        data = self.valid_metadata()
        data["hardware_metadata_safe"] = False
        with self.assertRaisesRegex(ValueError, "not marked"):
            simt_ipdom_to_mem.convert(data)

    def test_rejects_inconsistent_branch_mapping(self):
        data = self.valid_metadata()
        data["branch_to_reconvergence"]["0x00000004"] = "0x00000020"
        with self.assertRaisesRegex(ValueError, "inconsistent"):
            simt_ipdom_to_mem.convert(data)

    def test_rejects_duplicate_join_pc(self):
        data = self.valid_metadata()
        data["regions"].append({
            "branch_pc": "0x00000020",
            "reconvergence_pc": "0x00000030",
            "fallthrough_join_pc": "0x0000000c",
            "taken_join_pc": "0x00000028"
        })
        data["branch_to_reconvergence"]["0x00000020"] = "0x00000030"
        with self.assertRaisesRegex(ValueError, "duplicate/overlapping JOIN"):
            simt_ipdom_to_mem.convert(data)


if __name__ == "__main__":
    unittest.main()
