#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <kernel.asm>" >&2
    exit 2
fi

KERNEL="$1"
for tool in python3 iverilog vvp; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "ERROR: Required tool '$tool' was not found on PATH." >&2
        exit 2
    }
done

[[ -f "$KERNEL" ]] || { echo "ERROR: Kernel not found: $KERNEL" >&2; exit 1; }
[[ "$KERNEL" == *.asm ]] || { echo "ERROR: Input must be an .asm file." >&2; exit 1; }

BASE="${KERNEL%.asm}"
HEX="${BASE}.hex"
LISTING="${BASE}.lst"
IPDOM="${BASE}.ipdom"
BRANCH_MEM="simt_branch_metadata.mem"
JOIN_MEM="simt_join_metadata.mem"
TB="${BASE}_runner_tb.v"
TOP="${BASE}_runner_tb"
SIM="${BASE}_sim"
LOG="${BASE}_sim.log"

case "$BASE" in
    simt_divergent_kernel)
        EXPECTED_MARKER="ALL ASSEMBLED DIVERGENT KERNEL CHECKS PASSED" ;;
    simt_nested_kernel)
        EXPECTED_MARKER="ALL ASSEMBLED NESTED KERNEL CHECKS PASSED" ;;
    *)
        echo "ERROR: Unsupported kernel: $KERNEL" >&2
        echo "Supported kernels: simt_divergent_kernel.asm, simt_nested_kernel.asm" >&2
        exit 2 ;;
esac

for file in assembler.py simt_ipdom_analyzer.py simt_ipdom_to_mem.py \
            simt_ipdom_lookup.v "$TB"; do
    [[ -f "$file" ]] || { echo "ERROR: Required file missing: $file" >&2; exit 1; }
done

echo "Building loadable-metadata kernel: $KERNEL"

echo "[1/4] Assemble kernel..."
python3 assembler.py "$KERNEL" -o "$HEX" --listing "$LISTING"
[[ -s "$HEX" && -s "$LISTING" ]] || { echo "ERROR: Assembly outputs missing." >&2; exit 1; }

echo "[2/4] Analyze IPDOM metadata..."
python3 simt_ipdom_analyzer.py "$KERNEL"
[[ -s "$IPDOM" ]] || { echo "ERROR: IPDOM metadata missing: $IPDOM" >&2; exit 1; }

echo "[3/4] Generate loadable metadata memories..."
python3 simt_ipdom_to_mem.py "$IPDOM" \
    --branch-output "$BRANCH_MEM" \
    --join-output "$JOIN_MEM"
[[ -s "$BRANCH_MEM" && -s "$JOIN_MEM" ]] || {
    echo "ERROR: Metadata memory files missing." >&2
    exit 1
}

echo "[4/4] Compile and simulate..."
iverilog -g2012 -s "$TOP" -o "$SIM" \
    simt_decoder.v simt_alu.v simt_lane.v simt_core.v \
    simt_branch_compare.v simt_cfg_controller.v simt_frontend.v \
    simt_instruction_memory.v simt_pc.v simt_ipdom_lookup.v \
    ipdom_stack.v simt_split.v simt_join_control.v \
    simt_divergence_controller.v simt_metrics.v simt_top.v "$TB"

SIM_STATUS=0
vvp "$SIM" 2>&1 | tee "$LOG" || SIM_STATUS=$?
if [[ "$SIM_STATUS" -ne 0 ]]; then
    echo "ERROR: Simulation exited with status $SIM_STATUS. Review $LOG." >&2
    exit 1
fi
grep -Fq "$EXPECTED_MARKER" "$LOG" || {
    echo "ERROR: Expected marker not found: $EXPECTED_MARKER" >&2
    exit 1
}

echo "BUILD AND SIMULATION PASSED"
echo "HEX: $HEX"
echo "IPDOM JSON: $IPDOM"
echo "Branch metadata: $BRANCH_MEM"
echo "JOIN metadata: $JOIN_MEM"
echo "Simulation log: $LOG"
