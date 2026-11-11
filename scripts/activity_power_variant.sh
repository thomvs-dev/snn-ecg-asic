#!/usr/bin/env bash
# Activity and power for one variant, simulated on its FINAL post-route netlist
# so clock-tree and repair buffers are annotated from the VCD.
# Usage: sudo bash scripts/activity_power_variant.sh base|cg
# Writes reports/power_<variant>/ only; reports/power_*.json (original run) untouched.
set -euo pipefail
cd "$(dirname "$0")/.."
V=${1:?usage: activity_power_variant.sh base|cg}
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
NET=physical/results/sky130hd/ecg_snn_core/$V/6_final.v
O=reports/power_$V
[ -f "$NET" ] || { echo "missing $NET"; exit 1; }
[ -f build/sky130hd_sim.v ] || { echo "run scripts/verify_mapped.sh first (creates build/sky130hd_sim.v)"; exit 1; }
mkdir -p build "$O"
M=tb/sky130_icg_model.v   # harmless for base (no ICG instances)

# Same 20-vector workload window as reports/mapped_activity.vcd (628.861 us).
iverilog -g2012 -s tb_core -o build/act_$V "$NET" build/sky130hd_sim.v $M tb/tb_core.sv
vvp build/act_$V +COUNT=20 +ACTIVITY +PRED_FILE=$O/activity_predictions.csv +VCD_FILE=$O/activity.vcd \
  | tee $O/activity_simulation.log
# Same 100 us clock-running idle window as reports/idle_activity.vcd.
iverilog -g2012 -s tb_idle -o build/idle_$V "$NET" build/sky130hd_sim.v $M tb/tb_idle_vcd.sv
vvp build/idle_$V +VCD_FILE=$O/idle.vcd | tee $O/idle_simulation.log
python3 scripts/normalize_vcd_origin.py $O/idle.vcd

docker run --rm -e VARIANT=$V -v "$(pwd):/work" "$IMAGE" bash -lc \
  'source /OpenROAD-flow-scripts/env.sh; openroad -exit /work/scripts/power_variant.tcl' 2>&1 | tee $O/power_estimation.log
