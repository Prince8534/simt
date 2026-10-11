#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <kernel.asm>" >&2
    exit 2
fi

KERNEL="$1"

if [[ ! -f "$KERNEL" ]]; then
    echo "ERROR: Kernel not found: $KERNEL" >&2
    exit 1
fi

if [[ "$KERNEL" != *.asm ]]; then
    echo "ERROR: Input must be an .asm file." >&2
    exit 1
fi

BASE="${KERNEL%.asm}"
HEX="${BASE}.hex"
LISTING="${BASE}.lst"
IPDOM="${BASE}.ipdom"
LOOKUP="simt_ipdom_lookup.v"
TB="${BASE}_runner_tb.v"
TOP="${BASE}_runner_tb"
SIM="${BASE}_sim"
LOG="${BASE}_sim.log"

for tool in assembler.py simt_ipdom_analyzer.py simt_ipdom_to_verilog.py; do
    if [[ ! -f "$tool" ]]; then
        echo "ERROR: Required tool missing: $tool" >&2
        exit 1
    fi
done

echo
echo "========================================"
echo " SIMT KERNEL BUILD AND TEST"
echo "========================================"
echo "Kernel: $KERNEL"

echo
echo "[1/4] Assemble kernel..."
python3 assembler.py "$KERNEL" -o "$HEX" --listing "$LISTING"

[[ -s "$HEX" ]] || {
    echo "ERROR: HEX file missing or empty: $HEX" >&2
    exit 1
}

[[ -s "$LISTING" ]] || {
    echo "ERROR: Listing missing or empty: $LISTING" >&2
    exit 1
}

echo
echo "[2/4] Analyze IPDOM metadata..."
python3 simt_ipdom_analyzer.py "$KERNEL"

[[ -s "$IPDOM" ]] || {
    echo "ERROR: IPDOM metadata missing: $IPDOM" >&2
    exit 1
}

python3 - "$IPDOM" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

if data.get("format") != "simt-ipdom-v1":
    raise SystemExit("ERROR: Unsupported IPDOM metadata format.")

if data.get("hardware_metadata_safe") is not True:
    raise SystemExit("ERROR: Metadata is not marked hardware-safe.")

regions = data.get("regions")
mapping = data.get("branch_to_reconvergence")

if not isinstance(regions, list) or not isinstance(mapping, dict):
    raise SystemExit("ERROR: Missing IPDOM regions or branch mapping.")

for region in regions:
    branch_pc = region.get("branch_pc")
    reconvergence_pc = region.get("reconvergence_pc")

    if branch_pc not in mapping:
        raise SystemExit(f"ERROR: Missing mapping for branch {branch_pc}")

    if mapping[branch_pc] != reconvergence_pc:
        raise SystemExit(f"ERROR: Inconsistent mapping for {branch_pc}")

print(f"Validated {len(regions)} structured IPDOM region(s).")
PY

echo
echo "[3/4] Generate Verilog lookup..."
python3 simt_ipdom_to_verilog.py "$IPDOM" -o "$LOOKUP"

[[ -s "$LOOKUP" ]] || {
    echo "ERROR: Lookup module missing: $LOOKUP" >&2
    exit 1
}

if [[ ! -f "$TB" ]]; then
    echo "ERROR: Matching testbench not found: $TB" >&2
    echo "Expected: $TB" >&2
    exit 1
fi

echo
echo "[4/4] Compile and run testbench..."

iverilog -g2012 -s "$TOP" -o "$SIM" \
    simt_decoder.v \
    simt_alu.v \
    simt_lane.v \
    simt_core.v \
    simt_branch_compare.v \
    simt_cfg_controller.v \
    simt_frontend.v \
    simt_instruction_memory.v \
    simt_pc.v \
    "$LOOKUP" \
    ipdom_stack.v \
    simt_split.v \
    simt_join_control.v \
    simt_divergence_controller.v \
    simt_metrics.v \
    simt_top.v \
    "$TB"

vvp "$SIM" | tee "$LOG"

if ! grep -q "ALL ASSEMBLED NESTED KERNEL CHECKS PASSED" "$LOG"; then
    echo "ERROR: Expected testbench success message not found." >&2
    echo "Review $LOG for failed assertions." >&2
    exit 1
fi

echo
echo "========================================"
echo " BUILD AND SIMULATION PASSED"
echo "========================================"
echo "HEX:      $HEX"
echo "Listing:  $LISTING"
echo "IPDOM:    $IPDOM"
echo "Lookup:   $LOOKUP"
echo "Test log: $LOG"
