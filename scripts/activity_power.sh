#!/usr/bin/env bash
# Regenerate switching activity and the OpenSTA power estimates exactly as
# recorded in reports/power_*.{rpt,json}.
#
# Activity netlist: the SKY130-mapped SYNTHESIS netlist (1_2_yosys.v) was
# simulated, and its VCD was annotated onto the final routed database
# (6_final.odb + 6_final.spef). Cells inserted after synthesis (CTS buffers,
# repair buffers, antenna diodes) have no VCD entries: 1482 unannotated pins.
# Set ACT_NETLIST=physical/results/sky130hd/ecg_snn_core/base/6_final.v to
# simulate the post-route netlist instead (not the recorded run).
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
ACT_NETLIST=${ACT_NETLIST:-physical/results/sky130hd/ecg_snn_core/base/1_2_yosys.v}
[ -f build/sky130hd_sim.v ] || { echo "run scripts/verify_mapped.sh first (creates build/sky130hd_sim.v)"; exit 1; }
mkdir -p build reports

# 1. Workload window: reset, rejected early start, 20 supplied vectors
#    (256 loads, start, rejected writes/starts while busy, RUN to done each),
#    then reset during partial load. Full-design VCD from t=0 to $finish.
iverilog -g2012 -s tb_core -o build/activity "$ACT_NETLIST" build/sky130hd_sim.v tb/tb_core.sv
vvp build/activity +COUNT=20 +ACTIVITY +PRED_FILE=reports/activity_predictions.csv \
  +VCD_FILE=reports/mapped_activity.vcd | tee reports/activity_simulation.log

# 2. Clock-running idle window: full valid buffer, start low, 2500 clocks (100 us).
iverilog -g2012 -s tb_idle -o build/idle "$ACT_NETLIST" build/sky130hd_sim.v tb/tb_idle.sv
vvp build/idle | tee reports/idle_simulation.log
python3 scripts/normalize_idle_vcd.py   # shift VCD origin to 0; duration unchanged

# 3. OpenSTA power on the routed design: TT 25C 1.8 V Liberty, final SDC, extracted SPEF.
docker run --rm -v "$(pwd):/work" "$IMAGE" bash -lc \
  'source /OpenROAD-flow-scripts/env.sh; openroad -exit /work/scripts/power.tcl' 2>&1 | tee reports/power_estimation.log
python3 scripts/summarize.py > /dev/null
