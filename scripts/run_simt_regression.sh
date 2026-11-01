#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ============================================================
# MINI SIMT CORE REGRESSION SUITE
# Uses one generic simt_ipdom_lookup.v module and loadable
# branch/JOIN metadata memory files.
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
LOG_DIR="build/logs"
BRANCH_METADATA="build/metadata/simt_branch_metadata.mem"
JOIN_METADATA="build/metadata/simt_join_metadata.mem"

mkdir -p "$LOG_DIR" build/metadata build/kernels build/waveforms

# ------------------------------------------------------------
# Common RTL sources
# ------------------------------------------------------------

COMMON_SOURCES=(
    rtl/simt_decoder.v
    rtl/simt_alu.v
    rtl/simt_lane.v
    rtl/simt_core.v
    rtl/simt_thread_mask.v
    rtl/simt_split.v
    rtl/ipdom_stack.v
    rtl/simt_join_control.v
    rtl/simt_divergence_controller.v
    rtl/simt_pc.v
    rtl/simt_instruction_memory.v
    rtl/simt_frontend.v
    rtl/simt_decode_stage.v
    rtl/simt_frontend_decode.v
    rtl/simt_execute_stage.v
    rtl/simt_masked_execute.v
    rtl/simt_branch_compare.v
    rtl/simt_branch_execute.v
    rtl/simt_cfg_controller.v
    rtl/simt_branch_control.v
    rtl/simt_control_flow.v
    rtl/simt_branch_divergence.v
    rtl/simt_execution_top.v
    rtl/simt_metrics.v
    rtl/simt_ipdom_lookup.v
    rtl/simt_top.v
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
        -s "$(basename "${testbench%.v}")" \
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
    local testbench="testbench/kernels/simt_missing_ipdom_tb.v"
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
echo "[1/13] Checking required tools..."

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
echo "[2/13] Checking RTL and metadata tool files..."

if check_common_sources && check_files \
    tools/assembler.py \
    tools/simt_ipdom_analyzer.py \
    tools/simt_ipdom_to_mem.py \
    scripts/build_simt_kernel.sh \
    tools/simt_performance_analyzer.py; then
    pass "RTL and metadata tool files present"
else
    echo "One or more required files are missing."
    exit 1
fi

# ------------------------------------------------------------
# 3. Python tests
# ------------------------------------------------------------

echo
echo "[3/13] Running Python tests..."

PYTHON_LOG="$LOG_DIR/python_tests.log"

if python3 -m unittest discover -s tools -p 'test_*.py' -v >"$PYTHON_LOG" 2>&1; then
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
echo "[4/13] Running uniform kernel test..."

if check_files testbench/kernels/simt_uniform_kernel_runner_tb.v kernels/simt_uniform_kernel.asm; then
    write_empty_metadata

    if python3 tools/assembler.py kernels/simt_uniform_kernel.asm \
        -o build/kernels/simt_uniform_kernel.hex \
        --listing "$LOG_DIR/simt_uniform_kernel.lst" \
        >"$LOG_DIR/uniform_assembler.log" 2>&1; then
        run_testbench \
            "UNIFORM_KERNEL" \
            "testbench/kernels/simt_uniform_kernel_runner_tb.v" \
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
# scripts/build_simt_kernel.sh generates and loads this kernel's
# branch/JOIN metadata memory files before simulation.
# ------------------------------------------------------------

echo
echo "[5/13] Running divergent kernel test..."

if check_files testbench/kernels/simt_divergent_kernel_runner_tb.v kernels/simt_divergent_kernel.asm; then
    if bash ./scripts/build_simt_kernel.sh kernels/simt_divergent_kernel.asm \
        >"$LOG_DIR/divergent_build.log" 2>&1; then
        cat "$LOG_DIR/divergent_build.log"
        run_testbench \
            "DIVERGENT_KERNEL" \
            "testbench/kernels/simt_divergent_kernel_runner_tb.v" \
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
echo "[6/13] Running nested divergent kernel test..."

if check_files testbench/kernels/simt_nested_kernel_runner_tb.v kernels/simt_nested_kernel.asm; then
    if bash ./scripts/build_simt_kernel.sh kernels/simt_nested_kernel.asm \
        >"$LOG_DIR/nested_build.log" 2>&1; then
        cat "$LOG_DIR/nested_build.log"
        run_testbench \
            "NESTED_DIVERGENT_KERNEL" \
            "testbench/kernels/simt_nested_kernel_runner_tb.v" \
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
echo "[7/13] Running uniform branch JOIN regression..."

if check_files testbench/kernels/simt_uniform_branch_tb.v build/kernels/simt_nested_kernel.hex \
    "$BRANCH_METADATA" "$JOIN_METADATA"; then
    run_testbench \
        "UNIFORM_BRANCH_JOIN" \
        "testbench/kernels/simt_uniform_branch_tb.v" \
        "ALL UNIFORM BRANCH JOIN TESTS PASSED"
else
    fail "UNIFORM_BRANCH_JOIN - required files missing"
fi

# ------------------------------------------------------------
# 8. Kernel halt regression
# ------------------------------------------------------------

echo
echo "[8/13] Running kernel halt regression..."

write_empty_metadata

if check_files testbench/kernels/simt_kernel_halt_tb.v; then
    run_testbench \
        "KERNEL_HALT" \
        "testbench/kernels/simt_kernel_halt_tb.v" \
        "ALL KERNEL HALT TESTS PASSED"
else
    fail "KERNEL_HALT - testbench missing"
fi

# ------------------------------------------------------------
# 9. Illegal instruction handling regression
# ------------------------------------------------------------

echo
echo "[9/13] Running illegal instruction regression..."

write_empty_metadata

if check_files testbench/kernels/simt_illegal_instruction_tb.v; then
    run_testbench \
        "ILLEGAL_INSTRUCTION" \
        "testbench/kernels/simt_illegal_instruction_tb.v" \
        "ALL ILLEGAL INSTRUCTION TESTS PASSED (14 cases)"
else
    fail "ILLEGAL_INSTRUCTION - testbench missing"
fi

# ------------------------------------------------------------
# 10. Lane ID execution regression
# ------------------------------------------------------------

echo
echo "[10/13] Running lane ID regression..."

write_empty_metadata

if check_files testbench/kernels/simt_lane_id_tb.v; then
    run_testbench \
        "LANE_ID" \
        "testbench/kernels/simt_lane_id_tb.v" \
        "ALL LANE ID TESTS PASSED"
else
    fail "LANE_ID - testbench missing"
fi

# ------------------------------------------------------------
# 11. Vector addition kernel regression
# ------------------------------------------------------------

echo
echo "[11/13] Running eight-lane vector addition kernel..."

write_empty_metadata

if check_files tools/assembler.py kernels/simt_vector_add.asm testbench/kernels/simt_vector_add_tb.v; then
    if python3 tools/assembler.py kernels/simt_vector_add.asm \
        -o build/kernels/simt_vector_add.hex \
        --listing "$LOG_DIR/simt_vector_add.lst" \
        >"$LOG_DIR/vector_add_assembler.log" 2>&1; then
        cat "$LOG_DIR/vector_add_assembler.log"
        run_testbench \
            "VECTOR_ADD" \
            "testbench/kernels/simt_vector_add_tb.v" \
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
echo "[12/13] Running divergence controller and negative tests..."

write_empty_metadata

run_testbench \
    "DIVERGENCE_CONTROLLER" \
    "testbench/unit/divergence_controller_tb.v" \
    "ONE-LEVEL DIVERGENCE TEST COMPLETE"

run_missing_ipdom_test

# ------------------------------------------------------------
# 13. SIMT performance analysis
# ------------------------------------------------------------

echo
echo "[13/13] Validating kernel metrics and generating performance reports..."

if [[ "$FAIL_COUNT" -eq 0 ]]; then
    if python3 tools/simt_performance_analyzer.py \
        --log-dir "$LOG_DIR" \
        --lanes 8 \
        --csv reports/simt_performance.csv \
        --markdown reports/simt_performance_report.md; then
        pass "SIMT performance analysis"
    else
        fail "SIMT performance analysis"
    fi
else
    echo "[SKIP] Performance analysis skipped because earlier regression stages failed."
fi

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
