#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build reports
python3 scripts/generate_rtl.py
python3 scripts/prepare_baseline.py
iverilog -g2012 -s snn__tb -o build/baseline vendor/HDL-SpikingNet-ECG/{top,input_neuron,hidden_neuron,output_neuron,main_counter,arbitrator,handler_block,hidden_controler,output_controller}.v tb/original_instrumented.v 2> reports/baseline_compile.log
(cd vendor/HDL-SpikingNet-ECG; vvp ../../build/baseline > ../../reports/baseline.log)
iverilog -g2012 -Wall -s tb_core -o build/core rtl/*.v tb/tb_core.sv 2> reports/core_compile.log
vvp build/core | tee reports/core_simulation.log
iverilog -g2012 -s tb_protocol -o build/protocol rtl/*.v tb/tb_protocol.sv
vvp build/protocol | tee reports/protocol.log
yosys -Q -T -l reports/synthesis.log -p 'read_verilog rtl/*.v; hierarchy -check -top ecg_snn_core; synth -top ecg_snn_core; check -assert; stat; write_verilog -noattr build/ecg_snn_core_generic.v; write_json build/ecg_snn_core.json'
iverilog -g2012 -s tb_core -o build/gates build/ecg_snn_core_generic.v tb/tb_core.sv
cp reports/core_predictions.csv reports/rtl_predictions.csv
mv reports/core_first_beat.vcd reports/rtl_first_beat.vcd
vvp build/gates | tee reports/generic_gate_simulation.log
mv reports/core_predictions.csv reports/generic_gate_predictions.csv
mv reports/core_first_beat.vcd reports/generic_gate_first_beat.vcd
iverilog -g2012 -s tb_protocol -o build/gate_protocol build/ecg_snn_core_generic.v tb/tb_protocol.sv
vvp build/gate_protocol | tee reports/generic_gate_protocol.log
