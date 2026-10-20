# 8-Lane SIMT Processor in Verilog

An educational, simulation-oriented Single Instruction, Multiple Threads (SIMT) processor. The project demonstrates a shared instruction stream, eight lane-local register files and ALUs, per-lane branch predicates, active-lane masking, and nested control-flow reconvergence.

## What is implemented

The integrated `simt_top` design and the checked-in kernel testbenches focus on:

- Eight lanes sharing one program counter and instruction stream.
- Lane-local integer register state and ALU execution for the operations exercised by the kernels.
- Per-lane conditional branch comparison.
- Automatic divergence handling for conditional branches, using generated immediate-post-dominator (IPDOM) metadata.
- JOIN-based reconvergence and a stack for nested divergent regions.
- Sampled-cycle, useful-lane-cycle, masked-lane-cycle, and efficiency counters.

The regression kernels cover uniform execution, a single divergent branch, and nested divergence. The regression suite also checks uniform-taken/uniform-fallthrough branch decisions and verifies that a divergent branch with missing IPDOM metadata is rejected. These are simulation tests, not FPGA validation.

## Instruction support: assembler vs. processor

**Assembler support, decoder recognition, and end-to-end processor support are different things.** `assembler.py` can encode a broader RV32I-style set than `simt_top` currently executes completely.

| Instruction/feature | Current status in integrated `simt_top` | Regression evidence |
|---|---|---|
| `addi` and integer register-register ALU operations | Datapath support is present | Kernel regressions exercise `addi`; ALU operations have separate module-level testbenches |
| Conditional branches (`beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`) | Per-lane comparisons and automatic divergence control are present | Kernel regressions exercise `beq`; CFG controller test covers divergent, uniform-taken, and uniform-fallthrough masks |
| `JOIN` | Implemented as the reconvergence instruction for the project's structured control-flow convention | Divergent and nested kernel regressions |
| `nop` | Encodes as `addi x0, x0, 0` | Kernel regressions |
| `lw`/`sw` and other loads/stores | Assembler/decoder support exists, but there is no complete top-level load/store data-memory and write-back path | Not supported end to end |
| `jal` / `jalr` | Assembler/decoder support exists, but jump target selection and link-register write-back are not fully integrated | Not supported end to end |
| `lui` / `auipc` | Assembler/decoder support exists, but U-type write-back is not fully integrated | Not supported end to end |
| `TMC` / explicit `SPLIT` | Decoded, but not wired to change the active mask or trigger explicit splitting in `simt_top` | Not supported end to end |
| `fence`, `ecall`, `ebreak` | Decoded/encoded, but no full architectural side effects or trap/environment behavior are implemented | Not supported end to end |

This is **not** a complete or compliant RV32I processor. Treat the checked-in integrated kernel regressions as evidence only for the paths they exercise; assembler unit tests prove encoding behavior, not processor execution.

## Requirements

- Python 3
- Bash
- Icarus Verilog (`iverilog` and `vvp`) for HDL simulation

## Run tests

Run the assembler and IPDOM-tool unit tests:

```bash
python3 -m unittest -v test_assembler.py test_ipdom_tools.py
```

Run the complete regression (Python assembler tests followed by the three HDL kernel simulations):

```bash
./run_simt_regression.sh
```

Build and run one supported kernel with generated IPDOM metadata:

```bash
./build_simt_kernel.sh simt_nested_kernel.asm
```

The HDL regression requires both `iverilog` and `vvp` on `PATH`. The regression script exits with a clear error if either tool is missing.

## Reported simulation metrics

The values below are the expected results recorded by the existing kernel testbenches. Re-run the regression to verify them against the current source tree.

| Kernel | Sampled cycles | Useful lane-cycles | Masked lane-cycles | Efficiency |
|---|---:|---:|---:|---:|
| Uniform | 4 | 32 | 0 | 100% |
| Divergent | 6 | 32 | 16 | 66% |
| Nested divergence | 11 | 42 | 46 | 47% |

The counters sample clock cycles; they do not count retired instructions. These numbers are simulation results, not physical timing, throughput, or FPGA performance measurements.

## Architecture and execution flow

The integrated execution path is organized around these signals and responsibilities:

1. **Fetch:** `simt_pc` provides the shared byte-addressed PC to `simt_instruction_memory`; the fetched instruction is shared by all lanes.
2. **Decode:** `simt_decoder` extracts instruction fields and control signals. Decoder recognition does not imply every decoded instruction is fully implemented by the integrated top.
3. **Lane execution and branch predicates:** the lane datapath performs supported ALU operations; branch comparison produces one predicate bit per lane.
4. **Divergence control:** `simt_cfg_controller` identifies uniform or divergent branch outcomes. For a divergent branch, the integrated controller uses generated IPDOM metadata and the divergence stack to schedule the taken and deferred paths.
5. **Reconvergence:** `JOIN` instructions follow the project's structured branch/JOIN convention to resume deferred execution and eventually restore the reconverged lane mask. Nested divergence is covered by the nested-kernel regression.
6. **Metrics:** `simt_metrics` samples clock cycles and active-lane counts to report useful lane-cycles, masked lane-cycles, and integer lane efficiency.

The standalone modules and alternative control-path testbenches are useful for isolated experiments; they should not be mistaken for proof that every standalone feature is wired into `simt_top`. The module reference below distinguishes these roles.

## IC-style module pin diagrams

The repository includes a 27-page PDF showing selected modules' Verilog ports in an IC-style layout: inputs on the left, outputs on the right, and bus widths beside signals.

**[Open the IC-style Verilog pin diagrams](docs/simt_ic_style_pin_diagrams.pdf)**

These are *logical module interfaces*, not physical IC pin numbers. They are useful for understanding module connections and explaining the design in a presentation or report.

## Module reference

The project contains both the integrated processor path and standalone/alternative modules used for focused experiments. A module appearing in this list does not necessarily mean it is instantiated by `simt_top`.

### Integrated datapath and instruction front end

| Module | Function |
|---|---|
| `simt_top` | Main integrated simulation top. Connects the shared frontend, instruction decode, eight-lane execution, branch/divergence control, thread mask, and execution metrics. Exposes PC, instruction, mask/control signals, and counters for testbenches. |
| `simt_frontend` | Groups the shared program counter and instruction memory. Supplies the current PC and fetched instruction. |
| `simt_pc` | Holds the shared 32-bit byte-addressed PC; loads `next_pc` on a rising clock edge and resets to zero. |
| `simt_instruction_memory` | Combinational instruction lookup using `address[9:2]` into a 256-word array. Initializes words to the RISC-V NOP encoding; regression testbenches load assembled HEX files. |
| `simt_decoder` | Decodes instruction fields, immediates, ALU operation, register-write, memory, branch, jump, and custom SIMT control signals. Decoder recognition alone does not guarantee top-level execution support. |
| `simt_decode_stage` | Wrapper around `simt_decoder`, forwarding decoded fields and control signals. |
| `simt_frontend_decode` | Combines the shared frontend and decoder into a single convenience stage. |
| `simt_core` | Instantiates eight `simt_lane` units and broadcasts decoded operands/control while using one active-thread mask to enable lane writes. |
| `simt_lane` | One lane's 32-register state and ALU path. Reads x0 as zero and suppresses register writes when the lane is inactive or the destination is x0. |
| `simt_alu` | Combinational arithmetic/logic unit for the supported ALU control encodings; produces result and status flags. |
| `simt_execute_stage` | Adapts ALU control and exposes the eight-lane core for execution-stage tests. |
| `simt_execution_top` | Combines the shared lane datapath with per-lane branch comparison to expose lane operand data and the predicate mask. |

### Branch, divergence, and reconvergence control

| Module | Function |
|---|---|
| `simt_branch_compare` | Compares source operands independently for each of the eight lanes and produces an 8-bit predicate mask. |
| `simt_branch_execute` | Connects branch comparison to branch-control decisions in a standalone execution/control path. |
| `simt_branch_control` | Calculates branch target/fall-through PC choices and identifies uniform versus divergent branch outcomes. |
| `simt_cfg_controller` | Derives taken and deferred masks and PCs from the branch predicate mask; signals uniform-taken, uniform-fall-through, or divergent control flow. |
| `simt_branch_divergence` | Standalone branch-divergence control composition used by control-path experiments. |
| `simt_control_flow` | Combines branch decisions and divergence/reconvergence control into a control-flow subsystem. |
| `simt_control_top` | Standalone top for exercising the shared frontend and control-flow path without the full integrated execution/metrics path. |
| `simt_thread_mask` | Clocked 8-bit active-thread mask register with reset-to-all-active and a TMC mask input for standalone use. |
| `simt_split` | Computes `taken_mask = thread_mask & predicate_mask` and `deferred_mask = thread_mask & ~predicate_mask`. |
| `simt_split_control` | Standalone split/JOIN controller that selects the next PC and mask and produces IPDOM stack push/pop data. |
| `simt_divergence_controller` | Manages divergent execution: saves deferred-path state on a split, executes one path, and uses JOIN events to restore deferred execution and reconverge. |
| `simt_join_control` | Implements the JOIN path-state decision using the top IPDOM entry, choosing deferred-path execution or final reconvergence. |
| `ipdom_stack` | Eight-entry stack storing deferred masks/PCs, reconvergence PCs/masks, and path state for nested divergence. Exposes empty/full and top-entry information. |
| `simt_masked_execute` | Combines a lane-parallel execution datapath with active-mask and divergence-controller state for focused masked-execution tests. |

### Metrics, assembler, and verification

| File/module | Function |
|---|---|
| `simt_metrics` | Counts sampled cycles, useful lane-cycles, and masked lane-cycles, then calculates integer lane efficiency. Counters are cycle-based, not retired-instruction counts. |
| `assembler.py` | Converts the project's assembly syntax and supported instruction encodings into machine-code HEX and a listing. |
| `simt_ipdom_analyzer.py` | Analyzes the project's structured forward-branch/JOIN convention and emits IPDOM metadata. It is not a general arbitrary-CFG analyzer. |
| `simt_ipdom_to_verilog.py` | Validates supported IPDOM metadata and generates a Verilog lookup module for branch reconvergence addresses. |
| `test_assembler.py` | Unit tests for assembler encodings, labels, register names, operand counts, and immediate ranges. |
| `test_ipdom_tools.py` | Negative tests for unsupported control-flow structures and unsafe/unknown IPDOM metadata. |
| `cfg_controller_tb.v` | Checks divergent, uniform-taken, and uniform-fall-through branch-control cases. |
| `simt_missing_ipdom_tb.v` | Confirms that executing a divergent branch without the required IPDOM metadata is rejected in simulation. |
| `*_kernel.asm` | Example uniform, divergent, and nested-divergence assembly kernels used by the regression suite. |
| `*_kernel_runner_tb.v` | Testbenches that load assembled HEX files and check lane values, masks, reconvergence, and metrics. |
| `run_simt_regression.sh` | Runs Python unit tests, the three assembled-kernel regressions, branch-control tests, and the missing-IPDOM negative test. |
| `build_simt_kernel.sh` | Assembles, analyzes, generates lookup logic, compiles, and simulates one kernel. |


## Limitations

This is a learning prototype, not a general-purpose GPU or a complete RISC-V implementation. The IPDOM analyzer supports the project's structured forward-branch/JOIN convention; it is not a general analyzer for arbitrary control-flow graphs. Missing IPDOM metadata for an executed divergent branch triggers a simulation-time fatal check. FPGA synthesis, timing closure, and physical hardware performance have not been established.

## Author

Prince

Repository: https://github.com/Prince8534/simt
