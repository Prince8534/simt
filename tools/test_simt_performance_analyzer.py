import tempfile
import unittest
from pathlib import Path

from simt_performance_analyzer import AnalysisError, analyze, parse_log


def make_log(cycles, useful, masked, efficiency, marker):
    return (
        f"Sampled cycles       : {cycles}\n"
        f"Useful lane-cycles   : {useful}\n"
        f"Masked lane-cycles   : {masked}\n"
        f"Lane efficiency      : {efficiency}%\n"
        f"{marker}\n"
    )


MARKERS = {
    "UNIFORM_KERNEL": "ALL ASSEMBLED UNIFORM KERNEL CHECKS PASSED",
    "DIVERGENT_KERNEL": "ALL ASSEMBLED DIVERGENT KERNEL CHECKS PASSED",
    "NESTED_DIVERGENT_KERNEL": "ALL ASSEMBLED NESTED KERNEL CHECKS PASSED",
    "VECTOR_ADD": "ALL VECTOR ADD TESTS PASSED",
}


class PerformanceAnalyzerTests(unittest.TestCase):
    def test_parse_valid_divergent_log(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "divergent.log"
            path.write_text(make_log(6, 32, 16, 66, MARKERS["DIVERGENT_KERNEL"]))
            result = parse_log(path, "DIVERGENT_KERNEL", 8)
            self.assertEqual(result.total_lane_cycles, 48)
            self.assertAlmostEqual(result.calculated_efficiency_percent, 66.6666, places=3)
            self.assertEqual(result.ideal_packed_cycles_lower_bound, 4)

    def test_reject_inconsistent_lane_cycle_total(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.log"
            path.write_text(make_log(6, 32, 15, 66, MARKERS["DIVERGENT_KERNEL"]))
            with self.assertRaises(AnalysisError):
                parse_log(path, "DIVERGENT_KERNEL", 8)

    def test_reject_wrong_reported_efficiency(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.log"
            path.write_text(make_log(6, 32, 16, 67, MARKERS["DIVERGENT_KERNEL"]))
            with self.assertRaises(AnalysisError):
                parse_log(path, "DIVERGENT_KERNEL", 8)

    def test_reject_missing_success_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.log"
            path.write_text(make_log(4, 32, 0, 100, "simulation ended"))
            with self.assertRaises(AnalysisError):
                parse_log(path, "UNIFORM_KERNEL", 8)

    def test_analyze_all_four_logs(self):
        expected = {
            "UNIFORM_KERNEL": (4, 32, 0, 100),
            "DIVERGENT_KERNEL": (6, 32, 16, 66),
            "NESTED_DIVERGENT_KERNEL": (11, 42, 46, 47),
            "VECTOR_ADD": (5, 40, 0, 100),
        }
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, values in expected.items():
                (root / f"{name}_simulation.log").write_text(
                    make_log(*values, MARKERS[name])
                )
            rows = analyze(root, 8)
            self.assertEqual(len(rows), 4)
            self.assertEqual([r.cycles for r in rows], [4, 6, 11, 5])


if __name__ == "__main__":
    unittest.main()
