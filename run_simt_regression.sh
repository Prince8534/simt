#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

PASS_COUNT=0
FAIL_COUNT=0

COMMON_SOURCES=(
    simt_decoder.v
    simt_alu.v
    simt_lane.v
    simt_core.v
    simt_thread_mask.v
    simt_split.v
    ipdom_stack.v
    simt_join_control.v
    simt_divergence_controller.v
    simt_pc.v
    simt_instruction_memory.v
    simt_frontend.v
    simt_decode_stage.v
    simt_frontend_decode.v
    simt_execute_stage.v
    simt_masked_execute.v
    simt_branch_compare.v
    simt_branch_execute.v
    simt_cfg_controller.v
    simt_branch_control.v
    simt_control_flow.v
    simt_branch_divergence.v
    simt_execution_top.v
    simt_metrics.v
    simt_ipdom_lookup.v
    simt_top.v
)

run_simple_kernel() {
    local name="$1"
    local expected="$2"
    local tb="${name}_runner_tb"
    local sim="${name}_regression_sim"
    local log="${name}_regression.log"

    echo
    echo "========================================"
    echo " KERNEL: $name"
    echo "========================================"

    if ! python3 assembler.py "${name}.asm" \
        -o "${name}.hex" --listing "${name}.lst"; then
        echo "FAIL: $name assembly"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    if [[ "$name" == "simt_uniform_kernel" ]]; then
        echo "Uniform kernel: no branch metadata required."

        cat > simt_ipdom_lookup.v <<'VERILOG'
module simt_ipdom_lookup (
    input  wire [31:0] branch_pc,
    output reg  [31:0] reconvergence_pc,
    output reg         metadata_found
);
    always @(*) begin
        reconvergence_pc = 32'b0;
        metadata_found = 1'b0;
    end
endmodule
VERILOG

    else
        if ! python3 simt_ipdom_analyzer.py "${name}.asm"; then
            echo "FAIL: $name IPDOM analysis"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return
        fi

        if ! python3 simt_ipdom_to_verilog.py "${name}.ipdom" \
            -o simt_ipdom_lookup.v; then
            echo "FAIL: $name IPDOM lookup generation"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return
        fi
    fi

    if ! iverilog -g2012 -s "$tb" \
        -o "$sim" \
        "${COMMON_SOURCES[@]}" \
        "${tb}.v"; then
        echo "FAIL: $name compilation"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    if ! vvp "$sim" 2>&1 | tee "$log"; then
        echo "FAIL: $name simulation"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    if grep -Fq "$expected" "$log"; then
        echo "PASS: $name kernel"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $name test assertions"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo "========================================"
echo " SIMT REGRESSION SUITE"
echo "========================================"

run_simple_kernel \
    simt_uniform_kernel \
    "ALL ASSEMBLED UNIFORM KERNEL CHECKS PASSED"

run_simple_kernel \
    simt_divergent_kernel \
    "ALL ASSEMBLED DIVERGENT KERNEL CHECKS PASSED"

echo
echo "========================================"
echo " KERNEL: simt_nested_kernel"
echo "========================================"

if ./build_simt_kernel.sh simt_nested_kernel.asm \
    2>&1 | tee simt_nested_regression.log; then

    if grep -Fq "ALL ASSEMBLED NESTED KERNEL CHECKS PASSED" \
        simt_nested_regression.log; then
        echo "PASS: simt_nested_kernel"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: nested-kernel assertions"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "FAIL: nested-kernel build or simulation"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo
echo "========================================"
echo " REGRESSION SUMMARY"
echo "========================================"
echo "Passed kernels: $PASS_COUNT"
echo "Failed kernels: $FAIL_COUNT"

if [[ "$PASS_COUNT" -eq 3 && "$FAIL_COUNT" -eq 0 ]]; then
    echo "ALL SIMT REGRESSION TESTS PASSED"
    exit 0
else
    echo "SIMT REGRESSION FAILED"
    exit 1
fi
