#!/usr/bin/env python3
"""Unit tests for assembler.py. Run with: python3 test_assembler.py"""

import tempfile
import unittest
from pathlib import Path

import assembler


class AssemblerTests(unittest.TestCase):
    def assemble_text(self, source):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "test.asm"
            path.write_text(source)
            statements, labels = assembler.parse_source(path)
            return [(stmt[0], assembler.encode(stmt, labels)) for stmt in statements], labels

    def test_r_type_add(self):
        words, _ = self.assemble_text("add x1, x2, x3\n")
        self.assertEqual(words[0][1], 0x003100B3)

    def test_positive_addi(self):
        words, _ = self.assemble_text("addi x3, x1, 5\n")
        self.assertEqual(words[0][1], 0x00508193)

    def test_negative_addi(self):
        words, _ = self.assemble_text("addi x3, x1, -1\n")
        self.assertEqual(words[0][1], 0xFFF08193)

    def test_srai(self):
        words, _ = self.assemble_text("srai x5, x6, 7\n")
        self.assertEqual(words[0][1], 0x40735293)

    def test_load_word(self):
        words, _ = self.assemble_text("lw x5, 12(x2)\n")
        self.assertEqual(words[0][1], 0x00C12283)

    def test_store_word(self):
        words, _ = self.assemble_text("sw x5, -4(x2)\n")
        self.assertEqual(words[0][1], 0xFE512E23)

    def test_forward_branch_label(self):
        source = "beq x1, x2, target\nnop\ntarget: nop\n"
        words, labels = self.assemble_text(source)
        self.assertEqual(labels["target"], 8)
        self.assertEqual(words[0][1], 0x00208463)

    def test_backward_branch_label(self):
        source = "start: nop\nbne x1, x2, start\n"
        words, labels = self.assemble_text(source)
        self.assertEqual(labels["start"], 0)
        self.assertEqual(words[1][1], 0xFE209EE3)

    def test_jal_label(self):
        source = "jal x1, target\nnop\ntarget: nop\n"
        words, labels = self.assemble_text(source)
        self.assertEqual(labels["target"], 8)
        self.assertEqual(words[0][1], 0x008000EF)

    def test_simt_custom_encodings(self):
        words, _ = self.assemble_text("tmc\nsplit\njoin\n")
        self.assertEqual([word for _, word in words],
                         [0x0000000B, 0x0000100B, 0x0000200B])

    def test_register_alias(self):
        words, _ = self.assemble_text("addi a0, zero, 1\n")
        self.assertEqual(words[0][1], 0x00100513)

    def test_rejects_out_of_range_immediate(self):
        with self.assertRaisesRegex(ValueError, "signed 12-bit range"):
            self.assemble_text("addi x1, x2, 2048\n")

    def test_rejects_unknown_register(self):
        with self.assertRaisesRegex(ValueError, "unknown register"):
            self.assemble_text("add x1, x2, x32\n")

    def test_rejects_undefined_label(self):
        with self.assertRaisesRegex(ValueError, "invalid immediate/label"):
            self.assemble_text("beq x1, x2, missing_label\n")

    def test_rejects_duplicate_label(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "test.asm"
            path.write_text("again: nop\nagain: nop\n")
            with self.assertRaisesRegex(ValueError, "duplicate label"):
                assembler.parse_source(path)

    def test_rejects_bad_operand_count(self):
        with self.assertRaisesRegex(ValueError, "expects 3 operand"):
            self.assemble_text("add x1, x2\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
