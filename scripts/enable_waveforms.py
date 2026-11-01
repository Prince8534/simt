#!/usr/bin/env python3
"""Enable reproducible VCD waveform dumping for divergent SIMT kernels."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent

TARGETS = {
    "testbench/kernels/simt_divergent_kernel_runner_tb.v": (
        "simt_divergent_kernel_runner_tb",
        "build/waveforms/divergent_kernel.vcd",
    ),
    "testbench/kernels/simt_nested_kernel_runner_tb.v": (
        "simt_nested_kernel_runner_tb",
        "build/waveforms/nested_kernel.vcd",
    ),
}


def patch_testbench(filename: str, module_name: str, vcd_path: str) -> None:
    path = ROOT / filename

    if not path.is_file():
        raise FileNotFoundError(f"Required testbench not found: {path}")

    text = path.read_text(encoding="utf-8")
    dumpfile_line = f'        $dumpfile("{vcd_path}");'
    dumpvars_line = f"        $dumpvars(0, {module_name});"

    if dumpfile_line in text and dumpvars_line in text:
        print(f"[UNCHANGED] {filename}: waveform dumping already enabled")
        return

    if "$dumpfile(" in text or "$dumpvars(" in text:
        raise RuntimeError(
            f"{filename} already contains a different waveform setup."
        )

    anchor = "        errors = 0;"
    if text.count(anchor) != 1:
        raise RuntimeError(
            f"Expected exactly one '{anchor}' in {filename}."
        )

    replacement = (
        anchor
        + "\n\n"
        + "        // Capture the complete SIMT hierarchy for GTKWave analysis.\n"
        + dumpfile_line
        + "\n"
        + dumpvars_line
    )

    backup = path.with_suffix(path.suffix + ".action7.bak")
    if not backup.exists():
        backup.write_text(text, encoding="utf-8")

    path.write_text(text.replace(anchor, replacement, 1), encoding="utf-8")
    print(f"[UPDATED] {filename}: {vcd_path}")


def main() -> int:
    try:
        for filename, (module_name, vcd_path) in TARGETS.items():
            patch_testbench(filename, module_name, vcd_path)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print("\nWaveform instrumentation is enabled.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
