Action 6: Loadable IPDOM/JOIN metadata

Replace/add these files in the repository root:
- simt_ipdom_lookup.v (generic RTL lookup; keep tracked)
- simt_ipdom_to_mem.py (JSON -> .mem converter)
- build_simt_kernel.sh (updated kernel build flow)
- test_ipdom_tools.py (updated converter tests)
- simt_ipdom_lookup_tb.v (standalone RTL lookup test)
- simt_ipdom_lookup_test_branch.mem and simt_ipdom_lookup_test_join.mem (test data)

Important integration change for run_simt_regression.sh:
1. Keep simt_ipdom_lookup.v in COMMON_SOURCES. It is now real, generic RTL.
2. Remove the write_empty_lookup function that overwrites simt_ipdom_lookup.v.
3. Replace each call to write_empty_lookup with creation of two empty/sentinel metadata files:
   printf '%s\n' ffffffffffffffff > simt_branch_metadata.mem
   printf '%s\n' ffffffffffffffffffffffff > simt_join_metadata.mem
4. At the divergent and nested kernel stages, build_simt_kernel.sh now creates those files
   from the current kernel metadata. Do not overwrite them before the matching testbench.
5. The old simt_ipdom_to_verilog.py is no longer used by the build flow; retain it for history
   during this action, then remove it only after the regression suite has been migrated.

Test:
  python3 -m unittest discover -v
  iverilog -g2012 -s simt_ipdom_lookup_tb -o ipdom_lookup_test simt_ipdom_lookup.v simt_ipdom_lookup_tb.v
  vvp ipdom_lookup_test
  ./build_simt_kernel.sh simt_divergent_kernel.asm
  ./build_simt_kernel.sh simt_nested_kernel.asm

The generic lookup uses simulation-time $readmemh initialization. This is loadable per build/simulation,
not a runtime hardware kernel-loading interface. FPGA initialization-file support depends on the target
synthesis tool and memory inference constraints.
