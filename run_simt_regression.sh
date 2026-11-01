#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

# ============================================================
# MINI SIMT CORE REGRESSION SUITE
# Uses one generic simt_ipdom_lookup.v module and loadable
# branch/JOIN metadata memory files.
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
LOG_DIR="regression_build/logs"
BRANCH_METADATA="simt_branch_metadata.mem"
JOIN_METADATA="simt_join_metadata.mem"

mkdir -p "$LOG_DIR"

# ------------------------------------------------------------
# Common RTL sources
# ------------------------------------------------------------

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

pass() {
    echo "[PASS] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_files() {
    local missing=0
    for file in "$@"; do
        if [[ ! -f "$file" ]]; then
            echo "Missing required file: $file"
            missing=1
        fi
    done
    return "$missing"
}

check_common_sources() {
    local missing=0
    for file in "${COMMON_SOURCES[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Missing RTL source: $file"
            missing=1
        fi
    done
    return "$missing"
}

# ------------------------------------------------------------
# Empty metadata files
#
# Used by kernels/tests that do not execute divergent branches.
# The generic RTL initializes unused table entries to all ones.
# ------------------------------------------------------------

write_empty_metadata() {
    printf '%s\n' "ffffffffffffffff" > "$BRANCH_METADATA"
    printf '%s\n' "ffffffffffffffffffffffff" > "$JOIN_METADATA"
}

# ------------------------------------------------------------
# Compile and run a testbench
# ------------------------------------------------------------

run_testbench() {
    local test_name="$1"
    local testbench="$2"
    local expected_marker="$3"

    local executable="$LOG_DIR/${test_name}.out"
    local compile_log="$LOG_DIR/${test_name}_compile.log"
    local simulation_log="$LOG_DIR/${test_name}_simulation.log"

    echo
    echo "----------------------------------------"
    echo "Running: $test_name"
    echo "----------------------------------------"

    if ! iverilog -g2012 \
        -s "${testbench%.v}" \
        -o "$executable" \
        "${COMMON_SOURCES[@]}" \
        "$testbench" \
        >"$compile_log" 2>&1; then
        cat "$compile_log"
        fail "$test_name - compilation"
        return
    fi

    if ! vvp "$executable" >"$simulation_log" 2>&1; then
        cat "$simulation_log"
        fail "$test_name - simulation"
        return
    fi

    cat "$simulation_log"

    if grep -Fq "$expected_marker" "$simulation_log"; then
        pass "$test_name"
    else
        echo "Expected marker not found: $expected_marker"
        fail "$test_name - expected marker missing"
    fi
}

# ------------------------------------------------------------
# Negative test:
# Missing IPDOM metadata must cause a runtime fatal.
# ------------------------------------------------------------

run_missing_ipdom_test() {
    local test_name="MISSING_IPDOM"
    local testbench="simt_missing_ipdom_tb.v"
    local executable="$LOG_DIR/${test_name}.out"
    local compile_log="$LOG_DIR/${test_name}_compile.log"
    local simulation_log="$LOG_DIR/${test_name}_simulation.log"

    if ! check_files "$testbench"; then
        fail "$test_name - testbench missing"
        return
    fi

    write_empty_metadata

    if ! iverilog -g2012 \
        -s simt_missing_ipdom_tb \
        -o "$executable" \
        "${COMMON_SOURCES[@]}" \
        "$testbench" \
        >"$compile_log" 2>&1; then
        cat "$compile_log"
        fail "$test_name - compilation"
        return
    fi

    local simulation_status=0
    vvp "$executable" >"$simulation_log" 2>&1 \
        || simulation_status=$?

    cat "$simulation_log"

    if [[ "$simulation_status" -ne 0 ]] &&
       grep -Fq "Cannot execute divergent split without IPDOM metadata" "$simulation_log"; then
        pass "$test_name - expected fatal detected"
    else
        echo "Expected a nonzero exit and the missing-IPDOM fatal message."
        echo "Simulation exit status: $simulation_status"
        fail "$test_name - expected fatal was not detected"
    fi
}

# ============================================================
# START REGRESSION
# ============================================================

echo
echo "============================================================"
echo "          MINI SIMT CORE REGRESSION SUITE"
echo "          LOADABLE IPDOM METADATA FLOW"
echo "============================================================"

# ------------------------------------------------------------
# 1. Required tools
# ------------------------------------------------------------

echo
echo "[1/12] Checking required tools..."

for tool in python3 iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found: $tool"
        exit 1
    fi
done

pass "Required tools available"

# ------------------------------------------------------------
# 2. RTL and metadata tool files
# ------------------------------------------------------------

echo
echo "[2/12] Checking RTL and metadata tool files..."

if check_common_sources && check_files \
    assembler.py \
    simt_ipdom_analyzer.py \
    simt_ipdom_to_mem.py \
    build_simt_kernel.sh; then
    pass "RTL and metadata tool files present"
else
    echo "One or more required files are missing."
    exit 1
fi

# ------------------------------------------------------------
# 3. Python tests
# ------------------------------------------------------------

echo
echo "[3/12] Running Python tests..."

PYTHON_LOG="$LOG_DIR/python_tests.log"

if python3 -m unittest discover -v >"$PYTHON_LOG" 2>&1; then
    cat "$PYTHON_LOG"
    pass "Python unit tests"
else
    cat "$PYTHON_LOG"
    fail "Python unit tests"
fi

# ------------------------------------------------------------
# 4. Uniform kernel
# ------------------------------------------------------------

echo
echo "[4/12] Running uniform kernel test..."

if check_files simt_uniform_kernel_runner_tb.v simt_uniform_kernel.asm; then
    write_empty_metadata

    if python3 assembler.py simt_uniform_kernel.asm \
        -o simt_uniform_kernel.hex \
        --listing "$LOG_DIR/simt_uniform_kernel.lst" \
        >"$LOG_DIR/uniform_assembler.log" 2>&1; then
        run_testbench \
            "UNIFORM_KERNEL" \
            "simt_uniform_kernel_runner_tb.v" \
            "ALL ASSEMBLED UNIFORM KERNEL CHECKS PASSED"
    else
        cat "$LOG_DIR/uniform_assembler.log"
        fail "UNIFORM_KERNEL - assembly"
    fi
else
    fail "UNIFORM_KERNEL - required files missing"
fi

# ------------------------------------------------------------
# 5. Divergent kernel
#
# build_simt_kernel.sh generates and loads this kernel's
# branch/JOIN metadata memory files before simulation.
# ------------------------------------------------------------

echo
echo "[5/12] Running divergent kernel test..."

if check_files simt_divergent_kernel_runner_tb.v simt_divergent_kernel.asm; then
    if bash ./build_simt_kernel.sh simt_divergent_kernel.asm \
        >"$LOG_DIR/divergent_build.log" 2>&1; then
        cat "$LOG_DIR/divergent_build.log"
        run_testbench \
            "DIVERGENT_KERNEL" \
            "simt_divergent_kernel_runner_tb.v" \
            "ALL ASSEMBLED DIVERGENT KERNEL CHECKS PASSED"
    else
        cat "$LOG_DIR/divergent_build.log"
        fail "DIVERGENT_KERNEL - build"
    fi
else
    fail "DIVERGENT_KERNEL - required files missing"
fi

# ------------------------------------------------------------
# 6. Nested divergent kernel
# ------------------------------------------------------------

echo
echo "[6/12] Running nested divergent kernel test..."

if check_files simt_nested_kernel_runner_tb.v simt_nested_kernel.asm; then
    if bash ./build_simt_kernel.sh simt_nested_kernel.asm \
        >"$LOG_DIR/nested_build.log" 2>&1; then
        cat "$LOG_DIR/nested_build.log"
        run_testbench \
            "NESTED_DIVERGENT_KERNEL" \
            "simt_nested_kernel_runner_tb.v" \
            "ALL ASSEMBLED NESTED KERNEL CHECKS PASSED"
    else
        cat "$LOG_DIR/nested_build.log"
        fail "NESTED_DIVERGENT_KERNEL - build"
    fi
else
    fail "NESTED_DIVERGENT_KERNEL - required files missing"
fi

# ------------------------------------------------------------
# 7. Uniform branch and JOIN ownership regression
#
# Uses the nested kernel's generated metadata. Do not replace
# those files before this test.
# ------------------------------------------------------------

echo
echo "[7/12] Running uniform branch JOIN regression..."

if check_files simt_uniform_branch_tb.v simt_nested_kernel.hex \
    "$BRANCH_METADATA" "$JOIN_METADATA"; then
    run_testbench \
        "UNIFORM_BRANCH_JOIN" \
        "simt_uniform_branch_tb.v" \
        "ALL UNIFORM BRANCH JOIN TESTS PASSED"
else
    fail "UNIFORM_BRANCH_JOIN - required files missing"
fi

# ------------------------------------------------------------
# 8. Kernel halt regression
# ------------------------------------------------------------

echo
echo "[8/12] Running kernel halt regression..."

write_empty_metadata

if check_files simt_kernel_halt_tb.v; then
    run_testbench \
        "KERNEL_HALT" \
        "simt_kernel_halt_tb.v" \
        "ALL KERNEL HALT TESTS PASSED"
else
    fail "KERNEL_HALT - testbench missing"
fi

# ------------------------------------------------------------
# 9. Illegal instruction handling regression
# ------------------------------------------------------------

echo
echo "[9/12] Running illegal instruction regression..."

write_empty_metadata

if check_files simt_illegal_instruction_tb.v; then
    run_testbench \
        "ILLEGAL_INSTRUCTION" \
        "simt_illegal_instruction_tb.v" \
        "ALL ILLEGAL INSTRUCTION TESTS PASSED (14 cases)"
else
    fail "ILLEGAL_INSTRUCTION - testbench missing"
fi

# ------------------------------------------------------------
# 10. Lane ID execution regression
# ------------------------------------------------------------

echo
echo "[10/12] Running lane ID regression..."

write_empty_metadata

if check_files simt_lane_id_tb.v; then
    run_testbench \
        "LANE_ID" \
        "simt_lane_id_tb.v" \
        "ALL LANE ID TESTS PASSED"
else
    fail "LANE_ID - testbench missing"
fi

# ------------------------------------------------------------
# 11. Vector addition kernel regression
# ------------------------------------------------------------

echo
echo "[11/12] Running eight-lane vector addition kernel..."

write_empty_metadata

if check_files assembler.py simt_vector_add.asm simt_vector_add_tb.v; then
    if python3 assembler.py simt_vector_add.asm \
        -o simt_vector_add.hex \
        --listing "$LOG_DIR/simt_vector_add.lst" \
        >"$LOG_DIR/vector_add_assembler.log" 2>&1; then
        cat "$LOG_DIR/vector_add_assembler.log"
        run_testbench \
            "VECTOR_ADD" \
            "simt_vector_add_tb.v" \
            "ALL VECTOR ADD TESTS PASSED"
    else
        cat "$LOG_DIR/vector_add_assembler.log"
        fail "VECTOR_ADD - assembly"
    fi
else
    fail "VECTOR_ADD - required source file missing"
fi

# ------------------------------------------------------------
# 12. Controller unit test and negative test
# ------------------------------------------------------------

echo
echo "[12/12] Running divergence controller and negative tests..."

write_empty_metadata

run_testbench \
    "DIVERGENCE_CONTROLLER" \
    "divergence_controller_tb.v" \
    "ONE-LEVEL DIVERGENCE TEST COMPLETE"

run_missing_ipdom_test

# ============================================================
# FINAL SUMMARY
# ============================================================

echo
echo "============================================================"
echo "                 REGRESSION SUMMARY"
echo "============================================================"

echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo
echo "Logs are available in:"
echo "$LOG_DIR"

if [[ "$FAIL_COUNT" -eq 0 ]]; then
    echo
    echo "ALL SIMT REGRESSION TESTS PASSED"
    exit 0
else
    echo
    echo "SIMT REGRESSION FAILED"
    exit 1
fi
