import tempfile
import unittest
from pathlib import Path

import assembler


class LaneIdAssemblerTests(unittest.TestCase):
    def assemble_one(self, source_text):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "laneid.asm"
            source.write_text(source_text)
            statements, labels = assembler.parse_source(source)
            return assembler.encode(statements[0], labels)

    def test_laneid_x5_encoding(self):
        self.assertEqual(self.assemble_one("laneid x5\n"), 0x0000328B)

    def test_laneid_requires_one_destination(self):
        with self.assertRaisesRegex(ValueError, "expects 1 operand"):
            self.assemble_one("laneid\n")

    def test_laneid_rejects_extra_operand(self):
        with self.assertRaisesRegex(ValueError, "expects 1 operand"):
            self.assemble_one("laneid x5, x6\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
