#!/usr/bin/env python3
"""Parse SIMT kernel simulation logs and produce validated performance reports."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

KERNELS = {
    "UNIFORM_KERNEL": "Uniform",
    "DIVERGENT_KERNEL": "Divergent",
    "NESTED_DIVERGENT_KERNEL": "Nested divergent",
    "VECTOR_ADD": "Vector addition",
}

METRIC_PATTERNS = {
    "cycles": re.compile(r"^\s*Sampled cycles\s*:\s*(\d+)\s*$", re.MULTILINE),
    "useful": re.compile(r"^\s*Useful lane-cycles\s*:\s*(\d+)\s*$", re.MULTILINE),
    "masked": re.compile(r"^\s*Masked lane-cycles\s*:\s*(\d+)\s*$", re.MULTILINE),
    "reported_efficiency": re.compile(r"^\s*Lane efficiency\s*:\s*(\d+)\s*%\s*$", re.MULTILINE),
}


class AnalysisError(Exception):
    """Raised when a log is missing required or internally consistent data."""


@dataclass(frozen=True)
class KernelMetrics:
    kernel_id: str
    kernel: str
    cycles: int
    useful_lane_cycles: int
    masked_lane_cycles: int
    total_lane_cycles: int
    calculated_efficiency_percent: float
    reported_efficiency_percent: int
    ideal_packed_cycles_lower_bound: int


def _one_metric(pattern: re.Pattern[str], text: str, label: str, path: Path) -> int:
    matches = pattern.findall(text)
    if len(matches) != 1:
        raise AnalysisError(
            f"{path}: expected exactly one '{label}' metric, found {len(matches)}"
        )
    return int(matches[0])


def parse_log(path: Path, kernel_id: str, lane_count: int) -> KernelMetrics:
    if not path.is_file():
        raise AnalysisError(f"Missing simulation log: {path}")

    text = path.read_text(encoding="utf-8", errors="replace")
    cycles = _one_metric(METRIC_PATTERNS["cycles"], text, "Sampled cycles", path)
    useful = _one_metric(METRIC_PATTERNS["useful"], text, "Useful lane-cycles", path)
    masked = _one_metric(METRIC_PATTERNS["masked"], text, "Masked lane-cycles", path)
    reported = _one_metric(
        METRIC_PATTERNS["reported_efficiency"], text, "Lane efficiency", path
    )

    success_marker = {
        "UNIFORM_KERNEL": "ALL ASSEMBLED UNIFORM KERNEL CHECKS PASSED",
        "DIVERGENT_KERNEL": "ALL ASSEMBLED DIVERGENT KERNEL CHECKS PASSED",
        "NESTED_DIVERGENT_KERNEL": "ALL ASSEMBLED NESTED KERNEL CHECKS PASSED",
        "VECTOR_ADD": "ALL VECTOR ADD TESTS PASSED",
    }[kernel_id]
    if success_marker not in text:
        raise AnalysisError(
            f"{path}: expected successful test marker is absent: {success_marker}"
        )

    if cycles <= 0:
        raise AnalysisError(f"{path}: sampled cycles must be greater than zero")
    if useful < 0 or masked < 0:
        raise AnalysisError(f"{path}: lane-cycle counters cannot be negative")

    total = cycles * lane_count
    if useful + masked != total:
        raise AnalysisError(
            f"{path}: useful + masked = {useful + masked}, but "
            f"cycles * lanes = {cycles} * {lane_count} = {total}"
        )

    calculated = 100.0 * useful / total
    # RTL reports integer percentage using truncation, not rounding.
    expected_reported = int(calculated)
    if reported != expected_reported:
        raise AnalysisError(
            f"{path}: reported efficiency {reported}% does not match "
            f"calculated truncated efficiency {expected_reported}%"
        )

    return KernelMetrics(
        kernel_id=kernel_id,
        kernel=KERNELS[kernel_id],
        cycles=cycles,
        useful_lane_cycles=useful,
        masked_lane_cycles=masked,
        total_lane_cycles=total,
        calculated_efficiency_percent=calculated,
        reported_efficiency_percent=reported,
        ideal_packed_cycles_lower_bound=(useful + lane_count - 1) // lane_count,
    )


def analyze(log_dir: Path, lane_count: int) -> list[KernelMetrics]:
    if lane_count <= 0:
        raise AnalysisError("Lane count must be greater than zero")
    results = []
    for kernel_id in KERNELS:
        path = log_dir / f"{kernel_id}_simulation.log"
        results.append(parse_log(path, kernel_id, lane_count))
    return results


def write_csv(rows: Iterable[KernelMetrics], output: Path) -> None:
    fieldnames = list(asdict(next(iter(rows))).keys())
    # Materialize again because callers may supply any iterable.
    rows = list(rows)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            data = asdict(row)
            data["calculated_efficiency_percent"] = (
                f"{row.calculated_efficiency_percent:.2f}"
            )
            writer.writerow(data)


def write_markdown(rows: list[KernelMetrics], lane_count: int, output: Path) -> None:
    lines = [
        "# SIMT Kernel Performance Report",
        "",
        f"- SIMD/SIMT width: **{lane_count} lanes**",
        "- Source: simulation logs generated by `run_simt_regression.sh`",
        "- Efficiency is independently recalculated from lane-cycle counters.",
        "- Ideal packed cycles are a mathematical lower bound, not measured hardware cycles.",
        "",
        "| Kernel | Cycles | Useful lane-cycles | Masked lane-cycles | Lane efficiency | Ideal packed-cycle lower bound |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            f"| {row.kernel} | {row.cycles} | {row.useful_lane_cycles} | "
            f"{row.masked_lane_cycles} | {row.calculated_efficiency_percent:.2f}% | "
            f"{row.ideal_packed_cycles_lower_bound} |"
        )

    lines += [
        "",
        "## Interpretation",
        "",
        "- Uniform execution and vector addition report no masked lane-cycles in these tests.",
        "- Divergent execution records masked lane-cycles while the two paths are serialized.",
        "- Nested divergence has additional masked lane-cycles due to nested path execution.",
        "- The ideal packed-cycle lower bound assumes all useful lane work could be perfectly packed "
        "into full-width cycles. It does not account for dependencies, control-flow overhead, "
        "memory latency, or the actual scheduler.",
        "",
        "## Validation",
        "",
        "All four logs contained exactly one instance of each required metric and the expected "
        "successful-test marker. For every kernel, useful plus masked lane-cycles equaled "
        "sampled cycles multiplied by the configured lane count. The printed integer efficiency "
        "also matched the independently calculated percentage truncated to an integer.",
        "",
    ]
    output.write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate SIMT kernel metrics and generate CSV/Markdown reports."
    )
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=Path("regression_build/logs"),
        help="directory containing *_simulation.log files (default: regression_build/logs)",
    )
    parser.add_argument("--lanes", type=int, default=8, help="SIMT width (default: 8)")
    parser.add_argument(
        "--csv", type=Path, default=Path("simt_performance.csv"),
        help="CSV output path (default: simt_performance.csv)",
    )
    parser.add_argument(
        "--markdown", type=Path, default=Path("simt_performance_report.md"),
        help="Markdown report path (default: simt_performance_report.md)",
    )
    args = parser.parse_args(argv)

    try:
        rows = analyze(args.log_dir, args.lanes)
        write_csv(rows, args.csv)
        write_markdown(rows, args.lanes, args.markdown)
    except (AnalysisError, OSError, StopIteration) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"Validated {len(rows)} kernel simulation logs ({args.lanes} lanes).")
    for row in rows:
        print(
            f"{row.kernel:18s} cycles={row.cycles:2d} "
            f"useful={row.useful_lane_cycles:3d} masked={row.masked_lane_cycles:3d} "
            f"efficiency={row.calculated_efficiency_percent:6.2f}%"
        )
    print(f"CSV report:      {args.csv}")
    print(f"Markdown report: {args.markdown}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
