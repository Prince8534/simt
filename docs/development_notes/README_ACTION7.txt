# Action 7 — SIMT waveform capture

## What this adds

- `simt_divergent_kernel_runner_tb.v` writes `waveforms/divergent_kernel.vcd`.
- `simt_nested_kernel_runner_tb.v` writes `waveforms/nested_kernel.vcd`.
- `build_simt_kernel.sh` creates the `waveforms/` directory before simulation.
- `$dumpvars(0, <testbench>)` captures the complete testbench/DUT hierarchy.

The processor RTL and functional test assertions are not changed.

## Apply

Copy `enable_waveforms.py` into the repository root and run:

```bash
python3 enable_waveforms.py
```

The script creates `.action7.bak` backups of modified files. Do not commit those backups.

## Verify

```bash
./run_simt_regression.sh
ls -lh waveforms/*.vcd
```

Expected files:

- `waveforms/divergent_kernel.vcd`
- `waveforms/nested_kernel.vcd`

## Open in GTKWave

```bash
gtkwave waveforms/divergent_kernel.vcd
gtkwave waveforms/nested_kernel.vcd
```

Useful signals to add in GTKWave:

- `dut.clk`
- `dut.reset`
- `dut.current_pc`
- `dut.instruction`
- `dut.thread_mask`
- `dut.predicate_mask`
- `dut.branch_instr`
- `dut.divergence`
- `dut.split`
- `dut.stack_push`
- `dut.stack_pop`
- `dut.divergence_controller.ipdom.stack_pointer`
- `dut.reconvergence_pc`
- `dut.next_pc`

Some internal hierarchy names may vary if the RTL is refactored. The VCD contains the complete hierarchy, so inspect the available scope names if a signal is not listed exactly as above.

## Expected behavior

Single divergence:
- Initial active mask: `11111111`
- Taken path mask: `00110011`
- Deferred path mask: `11001100`
- Final reconverged mask: `11111111`

Nested divergence:
- Outer split: stack depth increases to 1
- Inner split: stack depth increases to 2
- Inner reconvergence: stack depth returns to 1
- Outer reconvergence: stack depth returns to 0 and all lanes become active

These are simulation traces, not FPGA timing measurements.
