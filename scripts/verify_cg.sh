#!/usr/bin/env bash
# Functional verification of the clock-gated variant against reports/baseline.csv.
#   RTL:   500 vectors, protocol bench, idle bench (always)
#   Final: 500 vectors and protocol bench on the cg post-route netlist (if built)
# Zero-delay simulation; tb/sky130_icg_model.v models the SKY130 ICG cell.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build reports/cg
M=tb/sky130_icg_model.v
python3 scripts/generate_rtl_cg.py
iverilog -g2012 -s tb_core -o build/cg_core rtl_cg/*.v $M tb/tb_core.sv 2> reports/cg/rtl_compile.log
vvp build/cg_core +PRED_FILE=reports/cg/rtl_predictions.csv +VCD_FILE=reports/cg/rtl_first_beat.vcd | tee reports/cg/rtl_simulation.log
iverilog -g2012 -s tb_protocol -o build/cg_protocol rtl_cg/*.v $M tb/tb_protocol.sv
vvp build/cg_protocol | tee reports/cg/rtl_protocol.log
iverilog -g2012 -s tb_idle -o build/cg_idle rtl_cg/*.v $M tb/tb_idle_vcd.sv
vvp build/cg_idle +VCD_FILE=build/cg_rtl_idle.vcd | tee reports/cg/rtl_idle.log
cmp reports/cg/rtl_predictions.csv reports/baseline.csv && echo "RTL predictions identical to baseline.csv"

NET=physical/results/sky130hd/ecg_snn_core/cg/6_final.v
if [ -f "$NET" ]; then
  [ -f build/sky130hd_sim.v ] || { echo "run scripts/verify_mapped.sh first (creates build/sky130hd_sim.v)"; exit 1; }
  iverilog -g2012 -s tb_core -o build/cg_final_gates "$NET" build/sky130hd_sim.v $M tb/tb_core.sv 2> reports/cg/final_compile.log
  vvp build/cg_final_gates +PRED_FILE=reports/cg/final_gate_predictions.csv \
    +VCD_FILE=reports/cg/final_gate_first_beat.vcd | tee reports/cg/final_gate_simulation.log
  iverilog -g2012 -s tb_protocol -o build/cg_final_protocol "$NET" build/sky130hd_sim.v $M tb/tb_protocol.sv
  vvp build/cg_final_protocol | tee reports/cg/final_gate_protocol.log
  cmp reports/cg/final_gate_predictions.csv reports/baseline.csv && echo "Final-netlist predictions identical to baseline.csv"
else
  echo "No cg post-route netlist yet; run scripts/run_physical_cg.sh first."
fi
