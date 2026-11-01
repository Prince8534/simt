#!/usr/bin/env bash
set -Eeuo pipefail

# ------------------------------------------------------------
# SIMT kernel build and simulation
#
# Usage:
#   ./scripts/build_simt_kernel.sh kernels/simt_divergent_kernel.asm
#   ./scripts/build_simt_kernel.sh kernels/simt_nested_kernel.asm
# ------------------------------------------------------------

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <kernel.asm>" >&2
    exit 2
fi

# Resolve paths before changing the working directory.
KERNEL="$(realpath -m "$1")"
KERNEL_NAME="$(basename "$KERNEL" .asm)"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ------------------------------------------------------------
# Validate input and dependencies
# ------------------------------------------------------------

if [[ ! -f "$KERNEL" ]]; then
    echo "ERROR: Kernel not found: $KERNEL" >&2
    exit 1
fi

if [[ "$KERNEL" != *.asm ]]; then
    echo "ERROR: Input must be an .asm file." >&2
    exit 1
fi

for tool in python3 iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Required tool '$tool' was not found on PATH." >&2
        exit 2
    fi
done

# ------------------------------------------------------------
# Supported kernels
# ------------------------------------------------------------

case "$KERNEL_NAME" in
    simt_divergent_kernel)
        EXPECTED_MARKER="ALL ASSEMBLED DIVERGENT KERNEL CHECKS PASSED"
        ;;
    simt_nested_kernel)
        EXPECTED_MARKER="ALL ASSEMBLED NESTED KERNEL CHECKS PASSED"
        ;;
    *)
        echo "ERROR: Unsupported kernel: $KERNEL" >&2
        echo "Supported kernels: simt_divergent_kernel.asm, simt_nested_kernel.asm" >&2
        exit 2
        ;;
esac

# ------------------------------------------------------------
# Build paths
# ------------------------------------------------------------

BASE="build/kernels/$KERNEL_NAME"

HEX="${BASE}.hex"
LISTING="${BASE}.lst"
IPDOM="build/metadata/${KERNEL_NAME}.ipdom"

BRANCH_MEM="build/metadata/simt_branch_metadata.mem"
JOIN_MEM="build/metadata/simt_join_metadata.mem"

TB="testbench/kernels/${KERNEL_NAME}_runner_tb.v"
TOP="${KERNEL_NAME}_runner_tb"

SIM="build/kernels/${KERNEL_NAME}_sim"
LOG="build/logs/${KERNEL_NAME}_sim.log"

mkdir -p build/kernels build/metadata build/logs build/waveforms

# ------------------------------------------------------------
# Validate required source files
# ------------------------------------------------------------

for file in \
    tools/assembler.py \
    tools/simt_ipdom_analyzer.py \
    tools/simt_ipdom_to_mem.py \
    rtl/simt_decoder.v \
    rtl/simt_alu.v \
    rtl/simt_lane.v \
    rtl/simt_core.v \
    rtl/simt_branch_compare.v \
    rtl/simt_cfg_controller.v \
    rtl/simt_frontend.v \
    rtl/simt_instruction_memory.v \
    rtl/simt_pc.v \
    rtl/simt_ipdom_lookup.v \
    rtl/ipdom_stack.v \
    rtl/simt_split.v \
    rtl/simt_join_control.v \
    rtl/simt_divergence_controller.v \
    rtl/simt_metrics.v \
    rtl/simt_top.v \
    "$TB"
do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Required file missing: $file" >&2
        exit 1
    fi
done

echo "========================================"
echo " SIMT KERNEL BUILD AND TEST"
echo "========================================"
echo "Kernel: $KERNEL_NAME"
echo "Expected marker: $EXPECTED_MARKER"
echo

# ------------------------------------------------------------
# 1. Assemble kernel
# ------------------------------------------------------------

echo "[1/4] Assemble kernel..."

python3 tools/assembler.py "$KERNEL" \
    -o "$HEX" \
    --listing "$LISTING"

if [[ ! -s "$HEX" || ! -s "$LISTING" ]]; then
    echo "ERROR: Assembly outputs missing." >&2
    exit 1
fi

# ------------------------------------------------------------
# 2. Analyze IPDOM metadata
# ------------------------------------------------------------

echo
echo "[2/4] Analyze IPDOM metadata..."

python3 tools/simt_ipdom_analyzer.py "$KERNEL" \
    --output "$IPDOM"

if [[ ! -s "$IPDOM" ]]; then
    echo "ERROR: IPDOM metadata missing: $IPDOM" >&2
    exit 1
fi

# ------------------------------------------------------------
# 3. Generate branch and JOIN metadata memories
# ------------------------------------------------------------

echo
echo "[3/4] Generate loadable metadata memories..."

python3 tools/simt_ipdom_to_mem.py "$IPDOM" \
    --branch-output "$BRANCH_MEM" \
    --join-output "$JOIN_MEM"

if [[ ! -s "$BRANCH_MEM" || ! -s "$JOIN_MEM" ]]; then
    echo "ERROR: Metadata memory files missing." >&2
    exit 1
fi

# ------------------------------------------------------------
# 4. Compile and simulate
# ------------------------------------------------------------

echo
echo "[4/4] Compile and simulate..."

iverilog -g2012 \
    -s "$TOP" \
    -o "$SIM" \
    rtl/simt_decoder.v \
    rtl/simt_alu.v \
    rtl/simt_lane.v \
    rtl/simt_core.v \
    rtl/simt_branch_compare.v \
    rtl/simt_cfg_controller.v \
    rtl/simt_frontend.v \
    rtl/simt_instruction_memory.v \
    rtl/simt_pc.v \
    rtl/simt_ipdom_lookup.v \
    rtl/ipdom_stack.v \
    rtl/simt_split.v \
    rtl/simt_join_control.v \
    rtl/simt_divergence_controller.v \
    rtl/simt_metrics.v \
    rtl/simt_top.v \
    "$TB"

SIM_STATUS=0

if vvp "$SIM" 2>&1 | tee "$LOG"; then
    SIM_STATUS=0
else
    SIM_STATUS=$?
fi

if [[ "$SIM_STATUS" -ne 0 ]]; then
    echo "ERROR: Simulation exited with status $SIM_STATUS." >&2
    echo "Review log: $LOG" >&2
    exit 1
fi

# ------------------------------------------------------------
# Verify expected testbench result
# ------------------------------------------------------------

if ! grep -Fq "$EXPECTED_MARKER" "$LOG"; then
    echo "ERROR: Expected success marker not found:" >&2
    echo "$EXPECTED_MARKER" >&2
    echo "Review log: $LOG" >&2
    exit 1
fi

# ------------------------------------------------------------
# Success summary
# ------------------------------------------------------------

echo
echo "========================================"
echo " BUILD AND SIMULATION PASSED"
echo "========================================"
echo "Kernel:            $KERNEL_NAME"
echo "HEX:               $HEX"
echo "Listing:           $LISTING"
echo "IPDOM JSON:        $IPDOM"
echo "Branch metadata:   $BRANCH_MEM"
echo "JOIN metadata:     $JOIN_MEM"
echo "Simulation binary: $SIM"
echo "Simulation log:    $LOG"
