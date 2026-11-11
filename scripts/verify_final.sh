#!/usr/bin/env bash
# Functional regression of the FINAL post-route logical netlist (6_final.v).
# Zero-delay simulation with SKY130 TT cell functions; no SDF back-annotation.
# Requires build/sky130hd_sim.v (created by scripts/verify_mapped.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
NETLIST=physical/results/sky130hd/ecg_snn_core/base/6_final.v
[ -f build/sky130hd_sim.v ] || { echo "run scripts/verify_mapped.sh first (creates build/sky130hd_sim.v)"; exit 1; }
mkdir -p build reports
# 500 supplied vectors: class, timeout flag and cycle count against reports/baseline.csv
iverilog -g2012 -s tb_core -o build/final_gates "$NETLIST" build/sky130hd_sim.v tb/tb_core.sv 2> reports/final_compile.log
vvp build/final_gates +PRED_FILE=reports/final_gate_predictions.csv +VCD_FILE=reports/final_gate_first_beat.vcd \
  | tee reports/final_gate_simulation.log
# Directed protocol cases: timeout, excess load, period zero, consecutive repeat,
# reset during RUN, stale start after reset
iverilog -g2012 -s tb_protocol -o build/final_protocol "$NETLIST" build/sky130hd_sim.v tb/tb_protocol.sv 2> reports/final_protocol_compile.log
vvp build/final_protocol | tee reports/final_gate_protocol.log
python3 scripts/summarize.py > /dev/null
