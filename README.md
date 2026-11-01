# 8-Lane SIMT Processor in Verilog

An educational, simulation-oriented Single Instruction, Multiple Threads (SIMT) processor. The integrated design has one shared instruction stream and program counter, eight lane-local register files and ALUs, per-lane branch predicates, active-lane masking, and nested control-flow reconvergence.

The repository includes an integrated simulation top, standalone subsystem experiments, an assembler and IPDOM metadata tools, kernel testbenches, waveform instrumentation, and a performance-report generator.

## What is implemented

The integrated `simt_top` design currently demonstrates:

- Eight lanes sharing one program counter and instruction stream.
- Lane-local integer register state and ALU execution for the supported operations.
- Per-lane conditional branch comparison.
- Automatic divergence handling for conditional branches using immediate-post-dominator (IPDOM) metadata.
- JOIN-based reconvergence and a stack for nested divergent regions.
- Uniform-branch JOIN ownership handling, so a JOIN belonging to an inner uniform branch does not incorrectly pop an outer divergence entry.
- Kernel termination through `ebreak`.
- Safe halt on unsupported or malformed instructions, with architectural side effects suppressed.
- A custom `laneid` instruction that writes each active lane's lane index to a destination register.
- Cycle-based useful-lane, masked-lane, and efficiency metrics.

The checked-in kernels cover uniform execution, a single divergent branch, nested divergence, and register-based eight-lane vector addition. The regression suite also exercises uniform-taken and uniform-fall-through branches, kernel halt, malformed instructions, lane ID, IPDOM lookup, and missing-IPDOM rejection.

These are simulation results, not FPGA validation.

## Instruction support: assembler vs. processor

**Assembler support, decoder recognition, and end-to-end processor support are different things.** `tools/assembler.py` can encode a broader RV32I-style set than `simt_top` currently executes completely.

| Instruction/feature | Current status in integrated `simt_top` | Regression evidence |
|---|---|---|
| `addi` and supported integer register-register ALU operations | Implemented in the lane datapath | Kernel regressions and standalone ALU tests |
| Conditional branches (`beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`) | Per-lane comparisons and divergence control are present | Kernel and branch-control regressions |
| `JOIN` | Implemented for the project's structured branch/JOIN convention | Divergent, nested, and uniform-branch JOIN regressions |
| `nop` | Encodes as `addi x0, x0, 0` | Kernel regressions |
| `ebreak` | Terminates the integrated kernel and freezes further execution | Kernel-halt regression |
| `laneid` | Custom instruction; writes the executing lane's index to the destination register | Lane-ID and vector-add regressions |
| `lw`/`sw` and other loads/stores | Assembler/decoder support exists, but there is no complete top-level load/store data-memory and write-back path | Not supported end to end |
| `jal` / `jalr` | Assembler/decoder support exists, but jump target selection and link-register write-back are not fully integrated | Not supported end to end |
| `lui` / `auipc` | Assembler/decoder support exists, but U-type write-back is not fully integrated | Not supported end to end |
| `TMC` / explicit `SPLIT` | Decoded, but not wired to change the active mask or trigger explicit splitting in `simt_top` | Not supported end to end |
| `fence`, `ecall` | No complete architectural/environment behavior is implemented | Not supported end to end |
| Unsupported or malformed encodings | Detected and cause a safe sticky halt with side effects suppressed | Illegal-instruction regression |

This is **not** a complete or compliant RV32I processor. Treat the integrated kernel regressions as evidence only for the paths they exercise; assembler unit tests prove encoding behavior, not processor execution.

## Requirements

- Python 3
- Bash
- Icarus Verilog (`iverilog` and `vvp`) for HDL simulation
- GTKWave is optional for inspecting generated VCD waveforms

## Repository layout

- `rtl/` — synthesizable and simulation RTL modules.
- `testbench/unit/` — focused module-level testbenches.
- `testbench/integration/` — subsystem and top-level integration testbenches.
- `testbench/kernels/` — assembled-kernel runner and behavior testbenches.
- `kernels/` — example SIMT assembly programs.
- `tools/` — assembler, IPDOM/performance analyzers, and Python tests.
- `scripts/` — build, regression, and waveform helper scripts.
- `testdata/` — checked-in IPDOM lookup memory fixtures.
- `docs/` — technical report and development notes.
- `reports/` — generated performance CSV and Markdown reports.
- `build/` — generated HEX, listing, metadata, logs, and waveform files.

Build outputs are generated under `build/`; performance reports are stored under `reports/`.

## Run tests

Run all discovered Python unit tests:

```bash
python3 -m unittest discover -s tools -p 'test_*.py' -v
```

Run the complete regression:

```bash
./scripts/run_simt_regression.sh
```

The regression script checks required tools and source files, runs Python tests, builds and simulates the example kernels, executes focused HDL regressions, checks the missing-IPDOM negative case, and validates performance logs before generating reports. It currently has 13 numbered stages.

Build and run a supported kernel with generated IPDOM metadata:

```bash
./scripts/build_simt_kernel.sh kernels/simt_nested_kernel.asm
```

The HDL regression requires both `iverilog` and `vvp` on `PATH`. The regression script exits with a clear error if either tool is missing.

## Loadable IPDOM metadata

The generic `simt_ipdom_lookup` module reads branch and JOIN metadata from separate memory files using `$readmemh`. This allows metadata to be changed for a kernel at build/simulation time without regenerating a kernel-specific lookup RTL module.

The current memory record formats are:

- `simt_branch_metadata.mem`: one 64-bit record per branch, `{branch_pc[31:0], reconvergence_pc[31:0]}`.
- `simt_join_metadata.mem`: one 96-bit record per JOIN, `{join_pc[31:0], owner_branch_pc[31:0], reconvergence_pc[31:0]}`.

The converter `tools/simt_ipdom_to_mem.py` validates the supported metadata format and writes these files. This is **not** runtime kernel switching or a hardware metadata-loading interface. `$readmemh` behavior and memory inference are tool- and target-dependent; FPGA implementation has not been established.

## Reported simulation metrics

The performance analyzer validates the kernel logs and generates `reports/simt_performance.csv` and `reports/simt_performance_report.md`.

| Kernel | Sampled cycles | Useful lane-cycles | Masked lane-cycles | Efficiency |
|---|---:|---:|---:|---:|
| Uniform | 4 | 32 | 0 | 100.00% |
| Divergent | 6 | 32 | 16 | 66.67% |
| Nested divergence | 11 | 42 | 46 | 47.73% |
| Eight-lane vector addition | 5 | 40 | 0 | 100.00% |

The counters sample clock cycles; they do not count retired instructions. Efficiency is calculated from useful and masked lane-cycles. The analyzer also reports an ideal packed-cycle lower bound, which is a mathematical comparison and **not** a measured hardware cycle count.

These values are simulation results, not physical timing, throughput, power, or FPGA performance measurements. Re-run the regression to verify them against the current source tree.

## Waveform generation

The divergent and nested kernel runner testbenches include VCD dump instrumentation. The kernel build/regression flow creates a `build/waveforms/` directory and writes:

- `build/waveforms/divergent_kernel.vcd`
- `build/waveforms/nested_kernel.vcd`

Inspect them with GTKWave:

```bash
gtkwave build/waveforms/divergent_kernel.vcd
gtkwave build/waveforms/nested_kernel.vcd
```

Waveform files are generated artifacts and are ignored by Git.

## Architecture and execution flow

The integrated execution path is organized around these responsibilities:

1. **Fetch:** `simt_pc` provides the shared byte-addressed PC to `simt_instruction_memory`; the fetched instruction is shared by all lanes.
2. **Decode:** `simt_decoder` extracts instruction fields and control signals. Decoder recognition does not imply every decoded instruction is fully implemented by the integrated top.
3. **Lane execution and branch predicates:** the lane datapath performs supported ALU operations; branch comparison produces one predicate bit per lane. The custom `laneid` operation supplies each lane's index.
4. **Divergence control:** `simt_cfg_controller` identifies uniform or divergent branch outcomes. For a divergent branch, the integrated controller uses IPDOM metadata and the divergence stack to schedule the taken and deferred paths.
5. **Reconvergence:** `JOIN` instructions follow the project's structured branch/JOIN convention to resume deferred execution and eventually restore the reconverged lane mask. Owner-aware JOIN handling protects unrelated outer stack entries.
6. **Termination and safety:** `ebreak` terminates a kernel. Unsupported or malformed instructions trigger a sticky safe halt rather than allowing unintended register, mask, or PC side effects.
7. **Metrics:** `simt_metrics` samples clock cycles and active-lane counts to report useful lane-cycles, masked lane-cycles, and integer lane efficiency.

The standalone modules and alternative control-path testbenches are useful for isolated experiments; they should not be mistaken for proof that every standalone feature is wired into `simt_top`.

## IC-style module pin diagrams

The repository includes a 27-page PDF showing selected modules' Verilog ports in an IC-style layout: inputs on the left, outputs on the right, and bus widths beside signals.

**[Open the IC-style Verilog pin diagrams](docs/pin_diagrams/simt_ic_style_pin_diagrams.pdf)**

These are *logical module interfaces*, not physical IC pin numbers. They are useful for understanding module connections and explaining the design in a presentation or report.

## Module reference

The project contains both the integrated processor path and standalone/alternative modules used for focused experiments. A module appearing in this list does not necessarily mean it is instantiated by `simt_top`.

### Integrated datapath and instruction front end

| Module | Function |
|---|---|
| `simt_top` | Main integrated simulation top. Connects the shared frontend, instruction decode, eight-lane execution, branch/divergence control, IPDOM lookup, and execution metrics. |
| `simt_frontend` | Groups the shared program counter and instruction memory. Supplies the current PC and fetched instruction. |
| `simt_pc` | Holds the shared 32-bit byte-addressed PC. |
| `simt_instruction_memory` | Combinational instruction lookup; regression testbenches load assembled HEX files. |
| `simt_decoder` | Decodes instruction fields, immediates, ALU operation, register-write, memory, branch, jump, and custom SIMT control signals. |
| `simt_decode_stage` | Wrapper around `simt_decoder`, forwarding decoded fields and control signals. |
| `simt_frontend_decode` | Combines the shared frontend and decoder into a convenience stage. |
| `simt_core` | Instantiates eight `simt_lane` units and broadcasts decoded operands/control while using one active-thread mask to enable lane writes. |
| `simt_lane` | One lane's 32-register state and ALU path. Reads x0 as zero and suppresses register writes when the lane is inactive or the destination is x0. |
| `simt_alu` | Combinational arithmetic/logic unit for the supported ALU control encodings. |
| `simt_execute_stage` | Adapts ALU control and exposes the eight-lane core for execution-stage tests. |
| `simt_execution_top` | Combines the shared lane datapath with per-lane branch comparison. |

### Branch, divergence, and reconvergence control

| Module | Function |
|---|---|
| `simt_branch_compare` | Compares source operands independently for each lane and produces an 8-bit predicate mask. |
| `simt_branch_execute` | Connects branch comparison to branch-control decisions in a standalone execution/control path. |
| `simt_branch_control` | Calculates branch target/fall-through PC choices and identifies uniform versus divergent branch outcomes. |
| `simt_cfg_controller` | Derives taken and deferred masks and PCs from the branch predicate mask. |
| `simt_branch_divergence` | Standalone branch-divergence control composition used by control-path experiments. |
| `simt_control_flow` | Combines branch decisions and divergence/reconvergence control into a control-flow subsystem. |
| `simt_control_top` | Standalone top for exercising the shared frontend and control-flow path. |
| `simt_thread_mask` | Clocked 8-bit active-thread mask register with reset-to-all-active and a TMC mask input for standalone use. |
| `simt_split` | Computes taken and deferred lane masks from the current mask and branch predicate. |
| `simt_split_control` | Standalone split/JOIN controller that selects the next PC and mask and produces IPDOM stack push/pop data. |
| `simt_divergence_controller` | Manages divergent execution using deferred-path state and JOIN events. |
| `simt_join_control` | Implements the JOIN path-state decision using the top IPDOM entry. |
| `ipdom_stack` | Stack storing deferred masks/PCs, reconvergence PCs/masks, path state, and branch ownership for nested divergence. |
| `simt_ipdom_lookup` | Loads branch and JOIN ownership/reconvergence records from memory files and supplies lookup results to the integrated top. |
| `simt_masked_execute` | Combines a lane-parallel execution datapath with active-mask and divergence-controller state for focused tests. |

### Metrics, assembler, and verification

| File/module | Function |
|---|---|
| `simt_metrics` | Counts sampled cycles, useful lane-cycles, and masked lane-cycles, then calculates lane efficiency. |
| `tools/assembler.py` | Converts the project's assembly syntax and supported instruction encodings into machine-code HEX and a listing. |
| `tools/simt_ipdom_analyzer.py` | Analyzes the project's structured forward-branch/JOIN convention and emits IPDOM metadata; it is not a general arbitrary-CFG analyzer. |
| `tools/simt_ipdom_to_verilog.py` | Validates supported IPDOM metadata and generates a Verilog lookup module. |
| `tools/simt_ipdom_to_mem.py` | Validates IPDOM metadata and converts it into the branch and JOIN memory-file formats. |
| `tools/simt_performance_analyzer.py` | Validates kernel simulation metrics and generates CSV and Markdown performance reports. |
| `scripts/run_simt_regression.sh` | Runs Python tests, assembled-kernel simulations, focused HDL regressions, negative tests, and performance-report validation. |
| `scripts/build_simt_kernel.sh` | Assembles, analyzes, converts metadata, compiles, and simulates one supported kernel. |
| `testbench/` | HDL testbenches for integrated kernels and standalone modules. |
| `kernels/` | Example assembly kernels used by the regression suite. |

## Limitations

This is a learning prototype, not a general-purpose GPU or a complete RISC-V implementation. The IPDOM analyzer supports the project's structured forward-branch/JOIN convention; it is not a general analyzer for arbitrary control-flow graphs. The vector-add example performs lane-local register arithmetic; it is not a memory-based vector load/store demonstration. IPDOM metadata is read at build/simulation time, not loaded dynamically by a running processor. FPGA synthesis, timing closure, and physical hardware performance have not been established.

## Technical report

The repository's `docs/SIMT_Core_Technical_Report.md` documents the architecture, implementation decisions, verification methodology, simulation metrics, limitations, and reproduction steps.

## Author

Prince

Repository: https://github.com/Prince8534/simt
