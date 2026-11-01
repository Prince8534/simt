Action 8: SIMT performance analyzer

Copy both Python files into the repository root:
  simt_performance_analyzer.py
  test_simt_performance_analyzer.py

Run the analyzer from the repository root:
  python3 simt_performance_analyzer.py

Optional arguments:
  python3 simt_performance_analyzer.py --log-dir regression_build/logs --lanes 8
  python3 simt_performance_analyzer.py --csv results.csv --markdown report.md

The tool expects these four logs:
  UNIFORM_KERNEL_simulation.log
  DIVERGENT_KERNEL_simulation.log
  NESTED_DIVERGENT_KERNEL_simulation.log
  VECTOR_ADD_simulation.log

It verifies success markers, unique metric fields, lane-cycle conservation, and
the RTL's integer-truncated efficiency percentage. It writes:
  simt_performance.csv
  simt_performance_report.md

The ideal packed-cycle figure is explicitly labeled as a theoretical lower
bound, not measured performance.

Run unit tests:
  python3 -m unittest test_simt_performance_analyzer -v

Then run the full project regression:
  ./run_simt_regression.sh
