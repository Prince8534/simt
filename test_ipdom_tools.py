"""Regression tests for conservative IPDOM metadata generation."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import simt_ipdom_analyzer

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
        source = "beq x1, x2, target\nnop\ntarget:\n  nop\n"
        with self.assertRaisesRegex(ValueError, "no fallthrough JOIN"):
            self.analyze_source(source)


class IpdomConverterTests(unittest.TestCase):
    def run_converter(self, metadata):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "metadata.json"
            output = tmp_path / "lookup.v"
            source.write_text(json.dumps(metadata), encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(ROOT / "simt_ipdom_to_verilog.py"),
                 str(source), "-o", str(output)],
                capture_output=True, text=True, check=False,
            )

    def test_rejects_unknown_metadata_format(self):
        result = self.run_converter({
            "format": "unknown-format",
            "hardware_metadata_safe": True,
            "branch_to_reconvergence": {"0x00000000": "0x00000010"},
        })
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported metadata format", result.stderr)

    def test_rejects_metadata_not_marked_safe(self):
        result = self.run_converter({
            "format": "simt-ipdom-v1",
            "hardware_metadata_safe": False,
            "branch_to_reconvergence": {"0x00000000": "0x00000010"},
        })
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not marked hardware_metadata_safe", result.stderr)


if __name__ == "__main__":
    unittest.main()
