#!/usr/bin/env python3
"""Enable reproducible VCD waveform dumping for the divergent SIMT kernels.

Run from the repository root:
    python3 enable_waveforms.py

The script is idempotent: running it more than once will not duplicate
$dumpfile/$dumpvars calls.
"""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent

TARGETS = {
    "simt_divergent_kernel_runner_tb.v": (
        "simt_divergent_kernel_runner_tb",
        "waveforms/divergent_kernel.vcd",
    ),
    "simt_nested_kernel_runner_tb.v": (
        "simt_nested_kernel_runner_tb",
        "waveforms/nested_kernel.vcd",
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
            f"{filename} already contains a different waveform setup; "
            "inspect it manually rather than inserting duplicate directives."
        )

    anchor = "        errors = 0;"
    if text.count(anchor) != 1:
        raise RuntimeError(
            f"Expected exactly one '{anchor}' in {filename}; "
            "file layout differs from the reviewed version."
        )

    replacement = (
        anchor
        + "\n\n"
        + "        // Capture the complete SIMT hierarchy for GTKWave analysis.\n"
        + dumpfile_line
        + "\n"
        + dumpvars_line
    )
    text = text.replace(anchor, replacement, 1)

    backup = path.with_suffix(path.suffix + ".action7.bak")
    if not backup.exists():
        backup.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")

    path.write_text(text, encoding="utf-8")
    print(f"[UPDATED] {filename}: {vcd_path}")


def patch_build_script() -> None:
    path = ROOT / "build_simt_kernel.sh"
    if not path.is_file():
        raise FileNotFoundError(f"Required build script not found: {path}")

    text = path.read_text(encoding="utf-8")
    anchor = 'LOG="${BASE}_sim.log"'
    insertion = anchor + '\nWAVEFORM_DIR="waveforms"\nmkdir -p "$WAVEFORM_DIR"'

    if 'WAVEFORM_DIR="waveforms"' in text:
        print("[UNCHANGED] build_simt_kernel.sh: waveform directory setup exists")
        return

    if text.count(anchor) != 1:
        raise RuntimeError(
            "build_simt_kernel.sh does not match the expected reviewed layout."
        )

    backup = path.with_suffix(path.suffix + ".action7.bak")
    if not backup.exists():
        backup.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")

    path.write_text(text.replace(anchor, insertion, 1), encoding="utf-8")
    print("[UPDATED] build_simt_kernel.sh: creates waveforms/ before simulation")


def main() -> int:
    try:
        for filename, (module_name, vcd_path) in TARGETS.items():
            patch_testbench(filename, module_name, vcd_path)
        patch_build_script()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        print("No commit was made. Review the affected files.", file=sys.stderr)
        return 1

    print("\nAction 7 waveform instrumentation installed.")
    print("Backups use the suffix .action7.bak and should not be committed.")
    print("Next run: ./run_simt_regression.sh")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
