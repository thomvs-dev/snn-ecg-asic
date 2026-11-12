#!/usr/bin/env bash
# Post-route netlist regression for any flow variant (500 vectors + protocol bench).
# Usage: bash scripts/verify_variant.sh cg2      -> reports/cg2/final_gate_*
set -euo pipefail
cd "$(dirname "$0")/.."
V=${1:?usage: verify_variant.sh <variant>}
NET=physical/results/sky130hd/ecg_snn_core/$V/6_final.v
O=reports/$V
M=tb/sky130_icg_model.v
[ -f "$NET" ] || { echo "missing $NET"; exit 1; }
[ -f build/sky130hd_sim.v ] || { echo "run scripts/verify_mapped.sh first (creates build/sky130hd_sim.v)"; exit 1; }
mkdir -p build "$O"
iverilog -g2012 -s tb_core -o build/${V}_final_gates "$NET" build/sky130hd_sim.v $M tb/tb_core.sv 2> $O/final_compile.log
vvp build/${V}_final_gates +PRED_FILE=$O/final_gate_predictions.csv +VCD_FILE=$O/final_gate_first_beat.vcd \
  | tee $O/final_gate_simulation.log
iverilog -g2012 -s tb_protocol -o build/${V}_final_protocol "$NET" build/sky130hd_sim.v $M tb/tb_protocol.sv
vvp build/${V}_final_protocol | tee $O/final_gate_protocol.log
cmp $O/final_gate_predictions.csv reports/baseline.csv && echo "Final-netlist predictions identical to baseline.csv"
