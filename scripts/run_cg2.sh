#!/usr/bin/env bash
# Clock-gated design, denser core (~63 % utilization) and evenly spaced pins.
# WSL2 Ubuntu:  sudo bash scripts/run_cg2.sh
# Writes physical/*/cg2/ and reports/cg2/; base and cg results are only read.
# Requires build/corner_libs/ and build/pdk/ from scripts/run_signoff_extra.sh.
# Pin metal: pin rectangles copied onto the drawing layer (scripts/pin_metal.py).
# npc.2: narrow npc notches between abutting cells merged (scripts/npc_fix.py).
# Timing margins are intentionally NOT changed (deferred).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
V=cg2
O=reports/$V
R=physical/results/sky130hd/ecg_snn_core/$V
mkdir -p "$O"
LOG=$O/run_all.log
[ -n "${ONLY:-}" ] || : > "$LOG"
step() {
  local name=$1; shift
  echo "=== $(date -Is) START $name" | tee -a "$LOG"
  local t0=$SECONDS
  # Not inside "if": bash ignores set -e in if-conditions, even in subshells.
  local rc=0
  set +e; ( set -e; "$@" ); rc=$?; set -e
  if [ $rc -eq 0 ]; then echo "=== $(date -Is) OK    $name ($((SECONDS - t0)) s)" | tee -a "$LOG"
  else echo "=== $(date -Is) FAIL  $name ($((SECONDS - t0)) s, exit $rc)" | tee -a "$LOG"; exit 1; fi
}
# step must not run inside an && / || list: bash ignores set -e there, even in subshells.
run() { if [ -z "${ONLY:-}" ] || [[ " $ONLY " == *" $1 "* ]]; then step "$@"; fi; }
orfs() { docker run --rm "$@"; }

orfs_make() {
  orfs -v "$ROOT:/work" -w /OpenROAD-flow-scripts/flow "$IMAGE" bash -lc \
    "source /OpenROAD-flow-scripts/env.sh; make DESIGN_CONFIG=/work/flow_cg2/config.mk WORK_HOME=/work/physical FLOW_VARIANT=$V $1" \
    2>&1 | tee "$O/physical_${1:-flow}.log"
}

physical() {
  python3 scripts/generate_rtl_cg.py
  orfs_make ""
  # Pin metal: copy top-level pin rectangles (.pin datatype) onto the drawing
  # layer, keeping the ORFS output as 6_final_no_pin_metal.gds. DRC and LVS
  # below then check the modified 6_final.gds.
  # Always start from ORFS's fresh merged GDS (its 6_final.gds is a plain copy of
  # 6_1_merged.gds), never from an older backup.
  cp -f $R/6_1_merged.gds $R/6_final_no_pin_metal.gds
  orfs -v "$ROOT:/work" -e GDS_IN=/work/$R/6_final_no_pin_metal.gds -e GDS_OUT=/work/$R/6_final.gds \
    -e REPORT=/work/$O/pin_metal.txt -e QT_QPA_PLATFORM=offscreen "$IMAGE" bash -lc \
    'source /OpenROAD-flow-scripts/env.sh; klayout -b -r /work/scripts/pin_metal.py'
  cat $O/pin_metal.txt
  # npc.2: merge npc notches/gaps < 0.27 um left by abutting cells (in place).
  orfs -v "$ROOT:/work" -e GDS_IN=/work/$R/6_final.gds -e GDS_OUT=/work/$R/6_final.gds \
    -e REPORT=/work/$O/npc_fix.txt -e QT_QPA_PLATFORM=offscreen "$IMAGE" bash -lc \
    'source /OpenROAD-flow-scripts/env.sh; klayout -b -r /work/scripts/npc_fix.py'
  grep -q "RESULT: PASS" $O/npc_fix.txt
  orfs_make drc
  orfs_make lvs
}

checks() {
  echo "ICG instances in final netlist: $(grep -c 'sky130_fd_sc_hd__dlclkp' $R/6_final.v)" | tee $O/icg_check.txt
  grep -h "pin plan:" physical/logs/sky130hd/ecg_snn_core/$V/2_1_floorplan.log > $O/pin_plan.txt || true
  echo "pins placed by io.tcl: $(wc -l < $O/pin_plan.txt)"
  echo "DRC (ORFS deck) items: $(cat physical/reports/sky130hd/ecg_snn_core/$V/6_drc_count.rpt)"
  grep -q "Congratulations! Netlists match." physical/logs/sky130hd/ecg_snn_core/$V/6_lvs.log && echo "LVS: match"
}

drc_mr() {
  local deck
  deck=$(ls build/pdk/ciel/sky130/versions/*/sky130A/libs.tech/klayout/drc/sky130A_mr.drc | head -1)
  orfs -v "$ROOT:/work" -e DECK=/work/$deck "$IMAGE" bash -lc "
    source /OpenROAD-flow-scripts/env.sh
    timeout -s KILL 60m klayout -b -r \$DECK -rd input=/work/$R/6_final.gds -rd top_cell=ecg_snn_core \
      -rd report=/work/$O/drc_mr.lyrdb -rd feol=true -rd beol=true -rd offgrid=true \
      -rd floating_met=false -rd seal=false -rd thr=4
    echo klayout exit status \$?" > $O/drc_mr.log 2>&1
  echo "mr deck items: $(grep -c '<item>' $O/drc_mr.lyrdb || true)"
}

sta() {
  for c in tt_025C_1v80 ff_n40C_1v95 ss_100C_1v60; do
    orfs -e VARIANT=$V -e LIB=/work/build/corner_libs/sky130_fd_sc_hd__$c.lib -v "$ROOT:/work" "$IMAGE" \
      bash -lc 'source /OpenROAD-flow-scripts/env.sh; openroad -no_init -exit /work/scripts/sta_corners.tcl' \
      > $O/sta_$c.rpt 2>&1
    grep -E "^worst slack|^tns" $O/sta_$c.rpt | sed "s/^/$c: /"
  done
}

run physical physical
run checks   checks
run verify   bash scripts/verify_variant.sh $V
run drc_mr   drc_mr
run sta      sta
run power    bash scripts/activity_power_variant.sh $V
run compare  python3 scripts/compare_cg.py base cg $V
echo "Done: $O/comparison.md" | tee -a "$LOG"
