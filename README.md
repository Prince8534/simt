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

## Project structure

- `simt_top.v` — integrated top-level design
- `simt_core.v`, `simt_lane.v` — core and lane components
- `simt_decoder.v`, `simt_alu.v` — instruction decoder and ALU
- `simt_thread_mask.v`, `simt_split.v` — supporting mask/split modules
- `simt_divergence_controller.v`, `ipdom_stack.v`, `simt_join_control.v` — divergence and reconvergence support
- `simt_metrics.v` — sampled execution metrics
- `assembler.py`, `test_assembler.py` — assembler and its unit tests
- `test_ipdom_tools.py` — checks that unsupported control flow and unsafe IPDOM metadata are rejected
- `simt_ipdom_analyzer.py` — analysis for the project's structured JOIN convention
- `simt_ipdom_to_verilog.py` — IPDOM lookup-module generator
- `*_kernel.asm`, `*_kernel_runner_tb.v` — regression kernels and testbenches
- `cfg_controller_tb.v` — divergent and uniform branch-control cases
- `simt_missing_ipdom_tb.v` — negative test for missing reconvergence metadata
- `run_simt_regression.sh` — complete regression entry point
- `build_simt_kernel.sh` — build/test one kernel

## Limitations

This is a learning prototype, not a general-purpose GPU or a complete RISC-V implementation. The IPDOM analyzer supports the project's structured forward-branch/JOIN convention; it is not a general analyzer for arbitrary control-flow graphs. Missing IPDOM metadata for an executed divergent branch triggers a simulation-time fatal check. FPGA synthesis, timing closure, and physical hardware performance have not been established.

## Author

Prince

Repository: https://github.com/Prince8534/simt
