# Technical Report: Eight-Lane SIMT Processor in Verilog

**Project:** Mini SIMT Core  
**Repository:** `Prince8534/simt`  
**Branch:** `fix/uniform-branch-reconvergence`  
**Report scope:** Implemented RTL, simulation verification, divergence/reconvergence, kernel demonstrations, and performance analysis  
**Verification status:** Full regression reported as 14 passed, 0 failed

---

## Abstract

This project implements an educational, simulation-oriented eight-lane Single Instruction, Multiple Threads (SIMT) processor in Verilog. A shared program counter and instruction stream drive eight lane-local register files and arithmetic/logic datapaths. Each lane evaluates conditional branches independently, producing a predicate mask. When lanes disagree on a branch outcome, the control unit serializes the paths using an immediate-post-dominator (IPDOM) reconvergence point and a stack that stores deferred execution state.

The implementation has been extended with owner-aware JOIN handling for nested control flow, kernel termination, fail-safe handling of illegal instructions, a custom lane-ID instruction, loadable branch/JOIN metadata tables, waveform instrumentation, and a Python performance-analysis flow. Verification is performed with Icarus Verilog simulation and Python unit tests. The reported results are simulation measurements; this project does not claim FPGA implementation, physical timing, or silicon performance.

## 1. Objectives and scope

The project demonstrates the central control-flow problem in a SIMT machine: multiple lanes share one instruction stream, but a conditional branch can produce different outcomes in different lanes. The processor must execute both paths while ensuring that only the lanes assigned to the current path are active, then restore the correct mask at reconvergence.

The implementation goals are:

1. Provide a shared instruction-fetch path and an eight-lane execution datapath.
2. Maintain lane-local architectural register state.
3. Generate per-lane branch predicates.
4. Detect uniform and divergent branch outcomes.
5. Serialize divergent paths and reconverge at compiler/analyzer-supplied IPDOM locations.
6. Support nested divergence with a bounded stack.
7. Stop kernels deterministically and prevent unsupported instructions from causing unintended architectural side effects.
8. Demonstrate lane-specific execution with a custom lane-ID instruction and a vector-add kernel.
9. Measure lane utilization from simulation counters and generate reproducible reports.

The design is an educational SIMT processor model, not a complete RISC-V implementation or a production GPU.

## 2. Architecture overview

### 2.1 Shared front end

The integrated `simt_top` contains a shared front end:

- `simt_pc` maintains one 32-bit byte-addressed program counter.
- `simt_instruction_memory` supplies the instruction at the shared PC.
- `simt_decoder` decodes the shared instruction and generates operation/control fields.

The same instruction is broadcast to all eight lanes. The PC advances through the selected control-flow path rather than maintaining a separate PC per lane.

### 2.2 Eight-lane execution datapath

`simt_core` instantiates eight `simt_lane` units. Each lane has its own register state and ALU path. Source register indices, destination register index, ALU operation, immediate, and instruction are shared; the values read from and written to registers are lane-local.

The active thread mask controls which lanes may update architectural state. Inactive lanes do not perform the corresponding register write. Register x0 is treated as zero and protected from writes.

### 2.3 Branch predicate generation

`simt_branch_compare` compares the branch operands independently in each lane and produces an eight-bit predicate mask. A set bit represents a lane whose branch condition is true. The current active mask is combined with the predicate mask to derive the taken and deferred lane masks:

- `taken_mask = thread_mask & predicate_mask`
- `deferred_mask = thread_mask & ~predicate_mask`

The branch-control logic distinguishes uniform-taken, uniform-fall-through, and divergent outcomes. A divergent outcome has at least one active lane in each path.

### 2.4 Divergence stack

`ipdom_stack` is an eight-entry stack. Each entry stores:

- Owning branch PC.
- Deferred-path lane mask.
- Deferred-path PC.
- Reconvergence PC.
- Reconvergence lane mask.
- Path-state bit indicating which path is active.

On a divergent split, the deferred path state is pushed and the taken path is selected. The active mask is changed to the taken mask. At the first JOIN associated with that divergence, execution switches to the deferred path and updates the path state. At the second JOIN, the reconvergence mask and PC are restored and the stack entry is popped.

The stack is bounded to eight nested entries. Stack overflow is not a supported execution condition for the demonstrated kernels.

## 3. IPDOM and structured control-flow metadata

### 3.1 Metadata generation

`simt_ipdom_analyzer.py` reads the project's assembly syntax and identifies structured forward-branch regions. The supported pattern is deliberately constrained:

1. A conditional branch targets a forward instruction address.
2. The fall-through path terminates at a JOIN.
3. The taken path terminates at a separate JOIN.
4. The reconvergence PC is the instruction immediately following the later JOIN.
5. Nested structured regions are skipped recursively during parent-region analysis.

The analyzer rejects backward branches and unsupported/unstructured layouts rather than guessing reconvergence metadata. It is not a general control-flow graph/IPDOM compiler pass for arbitrary programs.

### 3.2 Loadable metadata representation

`simt_ipdom_to_mem.py` validates the analyzer's `simt-ipdom-v1` JSON output and converts it into two memory files consumed by `simt_ipdom_lookup`:

- Branch record: `{branch_pc[31:0], reconvergence_pc[31:0]}` (64 bits).
- JOIN record: `{join_pc[31:0], owner_branch_pc[31:0], reconvergence_pc[31:0]}` (96 bits).

The lookup module initializes unused entries to all-ones sentinels and loads the metadata with `$readmemh`. The implementation supports up to 256 branch records and 256 JOIN records.

This is simulation/build-time loadable metadata. It is not a runtime host loading interface, dynamic context switch, or proof of portable FPGA block-memory inference. `$readmemh` synthesis support and memory inference depend on the target synthesis tool and flow.

### 3.3 JOIN ownership correction

A critical correctness issue addressed in the project is the interaction between JOIN instructions belonging to nested regions and an outer divergence entry.

The stack stores the owning branch PC. The metadata lookup supplies the owner branch PC and reconvergence PC for the JOIN at the current instruction address. The divergence controller compares the JOIN owner with the top stack entry:

- If the JOIN belongs to the top entry, normal deferred-path/reconvergence behavior is applied.
- If the JOIN belongs to a different region, the outer stack entry is not popped or updated; execution follows the JOIN's metadata reconvergence address.
- Legacy controller instances without connected JOIN metadata retain the original stack-based behavior.

This owner-aware decision prevents an inner or otherwise non-owning JOIN from consuming the wrong outer stack entry. Dedicated uniform-branch/JOIN tests and nested-kernel tests exercise this behavior.

## 4. Kernel termination and illegal-instruction safety

### 4.1 Kernel termination

`simt_top` exposes a sticky `halted` status. EBREAK terminates the kernel globally:

- The PC is held on the EBREAK instruction.
- Lane register writes are suppressed on the EBREAK cycle.
- The thread mask is not changed after termination.
- Metrics include the EBREAK instruction cycle.
- Subsequent halted cycles are not sampled.
- Reset clears the halt state and permits a new run.

This is a project-specific simulation termination mechanism. It does not implement the full RISC-V environment-call or breakpoint trap architecture.

### 4.2 Illegal instructions

The decoder validates supported instruction encodings and asserts `illegal` for malformed or unsupported encodings in the tested classes. The integrated top treats this as a sticky fault:

- `illegal_instruction` is asserted.
- The processor halts.
- The PC is held on the faulting instruction.
- Register writes and mask updates are suppressed.

The illegal-instruction regression checks 14 malformed instruction cases. This behavior is intended to fail safely rather than silently allow a partially decoded instruction to modify state.

## 5. Custom lane-ID instruction and vector-add demonstration

### 5.1 Lane ID

A custom `laneid rd` instruction writes each executing lane's lane index to the destination register. The demonstrated encoding uses the RISC-V CUSTOM-0 opcode, `funct3 = 011`, with reserved source fields required to be zero. The testbench uses instruction word `0x0000328B` for `laneid x5`.

For eight active lanes, x5 receives values 0 through 7 respectively. The lane-ID test also checks that a malformed encoding with a nonzero reserved source field is rejected and causes a safe halt.

### 5.2 Vector addition kernel

The vector-add demonstration uses the lane ID to construct two per-lane values and add them:

```asm
laneid x5
addi x6, x5, 1
addi x7, x5, 11
add  x8, x6, x7
ebreak
```

For lane index `i`:

- `A[i] = i + 1`
- `B[i] = i + 11`
- `C[i] = A[i] + B[i] = 2i + 12`

The expected results for lanes 0–7 are:

`12, 14, 16, 18, 20, 22, 24, 26`

The testbench checks all eight lane-local results, confirms EBREAK termination, and validates the metrics. This is register-based vector arithmetic. The integrated top does not yet provide a complete load/store data-memory and write-back path, so this demonstration is not a memory-backed vector addition implementation.

## 6. Verification methodology

### 6.1 Tools

The verification flow uses:

- Python 3 for the assembler, IPDOM analysis/conversion, and unit tests.
- Icarus Verilog (`iverilog`) for HDL compilation.
- `vvp` for simulation.
- GTKWave for inspection of generated VCD waveforms.

The project is simulation-verified. No FPGA synthesis, place-and-route, timing closure, board-level test, or power measurement is claimed in this report.

### 6.2 Regression coverage

The regression script checks tool/source availability, runs Python unit tests, assembles supported kernels, compiles and runs the relevant testbenches, checks expected success markers, and runs the performance analyzer after the preceding stages pass.

The final reported regression summary was:

```text
Passed: 14
Failed: 0
ALL SIMT REGRESSION TESTS PASSED
```

The regression includes the following coverage:

| Test area | Verification purpose |
|---|---|
| Python assembler/IPDOM tests | Encoding, parsing, metadata validation and negative cases |
| Uniform kernel | All lanes follow one common path |
| Divergent kernel | Taken/deferred path scheduling and reconvergence |
| Nested divergent kernel | Nested stack operation and reconvergence |
| Uniform branch JOIN | Uniform taken/fall-through behavior does not incorrectly consume divergence state |
| Kernel halt | EBREAK global stop, PC hold, write suppression, reset restart |
| Illegal instructions | Fourteen malformed instruction classes safely halt |
| Lane ID | Each lane receives its unique lane index; malformed encoding is rejected |
| Vector addition | Eight per-lane results are correct and EBREAK terminates |
| Divergence controller | Focused controller behavior |
| Missing IPDOM metadata | Expected fatal error is detected |
| Performance analyzer | Metric consistency and report generation |

The Python performance-analyzer test module has five unit tests covering valid parsing, all four logs, lane-cycle inconsistency, missing success marker, and incorrect reported efficiency.

### 6.3 Waveform evidence

Waveforms were generated for the divergent and nested kernels and inspected from the VCD files.

For the single divergent kernel, the observed active-mask progression was:

1. `11111111` — all lanes active.
2. `00110011` — taken-path lanes active.
3. `11001100` — deferred-path lanes active.
4. `11111111` — all lanes restored at reconvergence.

The nested waveform showed stack depth progressing from 0 to 1 to 2, then returning to 1 and finally 0. The inner reconvergence restored the outer active mask without discarding the outer stack entry. These observations agree with the corresponding testbench checks.

VCD files are generated artifacts and are not required as source files. They can be regenerated by running the waveform-enabled testbenches.

## 7. Performance methodology and results

### 7.1 Definitions

The metrics are sampled per execution cycle. They are not retired-instruction counters.

For an eight-lane design:

- `total_lane_cycles = sampled_cycles × 8`
- `useful_lane_cycles` is the sum of active lanes over sampled cycles.
- `masked_lane_cycles` is the sum of inactive lanes over sampled cycles.
- `lane_efficiency = useful_lane_cycles / total_lane_cycles × 100%`

The RTL reports integer efficiency. The Python analyzer independently calculates the percentage with decimal precision and checks that the RTL's printed integer equals the truncated calculated value. It also checks that useful plus masked lane-cycles equals sampled cycles multiplied by lane count.

### 7.2 Measured simulation results

| Kernel | Sampled cycles | Useful lane-cycles | Masked lane-cycles | Calculated efficiency |
|---|---:|---:|---:|---:|
| Uniform | 4 | 32 | 0 | 100.00% |
| Divergent | 6 | 32 | 16 | 66.67% |
| Nested divergent | 11 | 42 | 46 | 47.73% |
| Vector addition | 5 | 40 | 0 | 100.00% |

These are the results captured by the checked-in simulation testbenches and parsed by the performance analyzer.

### 7.3 Interpretation

The uniform and vector-add kernels keep all eight lanes active for every sampled cycle in these tests. The divergent kernel incurs 16 masked lane-cycles while the two paths are serialized. The nested kernel incurs 46 masked lane-cycles and has the lowest measured lane efficiency of the four tested kernels.

The analyzer also reports an ideal packed-cycle lower bound computed as the ceiling of useful lane-cycles divided by lane count. This is a mathematical lower bound under perfect full-width packing. It is not a measured execution time, predicted clock count, speedup, or hardware performance claim. It ignores dependencies, control-flow overhead, memory behavior, and scheduling constraints.

### 7.4 Generated reports

Running the complete regression generates:

- `simt_performance.csv`
- `simt_performance_report.md`

The analyzer rejects missing or duplicate metric fields, missing successful-test markers, inconsistent lane-cycle totals, and disagreement between calculated and RTL-reported integer efficiency.

## 8. Limitations

The current implementation has important boundaries:

1. **Not a complete RV32I processor.** Assembler and decoder support are broader than the integrated top-level execution support.
2. **No complete load/store path.** Load/store encoding and decode exist, but the integrated top lacks a complete data-memory and write-back path.
3. **No complete jump path.** JAL/JALR target selection and link-register write-back are not fully integrated.
4. **Structured control-flow restriction.** The IPDOM analyzer supports a constrained forward-branch/JOIN assembly form and rejects backward/unstructured control flow.
5. **Static metadata loading.** `$readmemh` loads metadata at simulation initialization; no runtime kernel metadata programming interface is implemented.
6. **Finite divergence stack.** The IPDOM stack has eight entries.
7. **Register-based vector demonstration.** Vector addition does not fetch/store array elements through a memory subsystem.
8. **Simulation-only evidence.** The reported cycles and lane efficiencies are simulation counters, not FPGA frequency, throughput, power, or silicon measurements.
9. **No demonstrated multi-warp scheduling.** The implementation demonstrates one eight-lane execution group sharing a PC; it does not implement a multi-warp scheduler or full GPU memory hierarchy.

## 9. Future work

Potential next engineering steps include:

- Integrate a complete per-lane data-memory path and load/store write-back.
- Add memory-backed vector kernels and tests.
- Implement and verify a fully integrated jump/link path if required by the instruction-set scope.
- Extend control-flow analysis beyond the current structured forward-branch/JOIN convention.
- Define a runtime metadata-loading interface if dynamic kernel dispatch is a goal.
- Characterize stack-full behavior and add explicit overflow/underflow handling tests.
- Add synthesis constraints and an FPGA implementation flow before making hardware timing or resource claims.
- Add more kernels and compare lane utilization across different branch distributions and nesting patterns.

## 10. Reproduction

From the repository root:

```bash
python3 -m unittest discover -v
./run_simt_regression.sh
```

The regression requires Python 3, Bash, Icarus Verilog, and `vvp` on `PATH`.

To inspect a generated waveform, for example:

```bash
gtkwave waveforms/divergent_kernel.vcd
```

The regression automatically runs the performance analyzer after the preceding stages pass and regenerates the CSV and Markdown performance reports.

## Conclusion

The project demonstrates an eight-lane SIMT execution model with shared instruction control, lane-local state, per-lane branch predicates, stack-based divergence handling, and IPDOM-guided reconvergence. The implementation work addresses a key nested-control-flow correctness issue through JOIN ownership metadata and adds deterministic termination, safe illegal-instruction handling, lane identification, loadable metadata tables, waveform evidence, and automated performance reporting.

The final reported simulation regression completed with 14 passes and no failures. The results provide evidence for the implemented and tested paths described here, while the limitations section defines the features that remain outside the current implementation.
