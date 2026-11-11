#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
LIB=build/sky130hd_tt.lib
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
if [ ! -f "$LIB" ]; then
 docker run --rm -v "$(pwd):/work" "$IMAGE" cp /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib /work/build/sky130hd_tt.lib
fi
yosys -Q -T -p "read_liberty -ignore_miss_func -ignore_miss_dir $LIB; write_verilog -noattr build/sky130hd_sim.v" > reports/cell_model_generation.log
NETLIST=${NETLIST:-physical/results/sky130hd/ecg_snn_core/base/1_2_yosys.v}
iverilog -g2012 -s tb_core -o build/mapped_gates "$NETLIST" build/sky130hd_sim.v tb/tb_core.sv 2> reports/mapped_compile.log
vvp build/mapped_gates | tee reports/mapped_gate_simulation.log
mv reports/core_predictions.csv reports/mapped_gate_predictions.csv
mv reports/core_first_beat.vcd reports/mapped_gate_first_beat.vcd
iverilog -g2012 -s tb_protocol -o build/mapped_protocol "$NETLIST" build/sky130hd_sim.v tb/tb_protocol.sv
vvp build/mapped_protocol | tee reports/mapped_gate_protocol.log
