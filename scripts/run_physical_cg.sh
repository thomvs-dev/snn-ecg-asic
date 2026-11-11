#!/usr/bin/env bash
# Clock-gated variant: ORFS flow, KLayout DRC and LVS into FLOW_VARIANT=cg.
# The baseline results in physical/*/sky130hd/ecg_snn_core/base/ are not touched.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
MAKE_ARGS="DESIGN_CONFIG=/work/flow_cg/config.mk WORK_HOME=/work/physical FLOW_VARIANT=cg"
mkdir -p reports/cg
python3 scripts/generate_rtl_cg.py
for target in "" drc lvs; do
  log=reports/cg/physical_${target:-flow}.log
  docker run --rm -v "$ROOT:/work" -w /OpenROAD-flow-scripts/flow "$IMAGE" bash -lc \
    "source /OpenROAD-flow-scripts/env.sh; make $MAKE_ARGS $target" 2>&1 | tee "$log"
done
R=physical/results/sky130hd/ecg_snn_core/cg
echo "ICG instances in synthesis netlist: $(grep -c 'sky130_fd_sc_hd__dlclkp' $R/1_2_yosys.v || true)" | tee reports/cg/icg_check.txt
echo "ICG instances in final netlist:     $(grep -c 'sky130_fd_sc_hd__dlclkp' $R/6_final.v || true)" | tee -a reports/cg/icg_check.txt
