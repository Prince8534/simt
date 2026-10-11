# 8-Lane SIMT Processor in Verilog

An educational Single Instruction, Multiple Threads (SIMT) processor implemented in Verilog, exploring parallel execution, lane masking, divergent branches, and nested reconvergence.

## Architecture

The processor uses a shared instruction front end and eight execution lanes. Each lane maintains its own register state and executes instructions according to a shared thread mask.

Key components:
- Shared instruction fetch and decode
- Eight parallel execution lanes
- Per-lane register files and ALUs
- Thread masking and divergent branch handling
- SPLIT and JOIN control instructions
- IPDOM stack for nested reconvergence
- Assembly toolchain and control-flow analysis
- Simulation metrics and regression testbenches

## Instruction Support

The assembler supports a set of RV32I-style instructions, labels, and custom SIMT instructions: TMC, SPLIT, and JOIN.

This is an educational prototype, not a claim of complete RV32I compliance. Refer to `assembler.py` and `simt_decoder.v` for the implemented instruction set.

## Requirements

- Python 3
- Icarus Verilog (`iverilog` and `vvp`)
- Bash

## Run Tests

Run the assembler tests:

```bash
python3 -m unittest -v test_assembler.py
```

Run the kernel regression suite:

```bash
./run_simt_regression.sh
```

## Benchmark Results

| Kernel | Sampled cycles | Useful lane-cycles | Masked lane-cycles | Efficiency |
|---|---:|---:|---:|---:|
| Uniform | 4 | 32 | 0 | 100% |
| Divergent | 6 | 32 | 16 | 66% |
| Nested divergence | 11 | 42 | 46 | 47% |

These are results from the current simulation testbenches, not physical hardware measurements. The counters measure sampled clock cycles rather than retired instructions.

## Project Structure

- `simt_top.v` — integrated top-level design
- `simt_core.v`, `simt_lane.v` — core and lane components
- `simt_decoder.v`, `simt_alu.v` — instruction decoding and ALU
- `simt_thread_mask.v`, `simt_split.v` — thread masking and split control
- `simt_join_control.v`, `ipdom_stack.v` — reconvergence control
- `simt_metrics.v` — execution metrics
- `assembler.py` — assembly-to-HEX assembler
- `simt_cfg_analyzer.py` — control-flow graph analysis
- `simt_ipdom_analyzer.py` — structured IPDOM analysis
- `simt_ipdom_to_verilog.py` — generates the IPDOM lookup module
- `*_tb.v` — simulation testbenches
- `run_simt_regression.sh` — regression suite
- `build_simt_kernel.sh` — builds and tests a selected kernel

## Limitations

This is a simulation-oriented educational prototype. The IPDOM analyzer targets structured control flow using the project's JOIN convention; it is not a general-purpose analyzer for arbitrary control-flow graphs. FPGA synthesis, timing closure, and physical hardware performance have not been established.

## Author

Prince

Repository: https://github.com/Prince8534/simt
