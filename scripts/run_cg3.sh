#!/usr/bin/env bash
# cg3: cg2 plus a root clock gate (rtl_cg3) and timing margins for the fast and
# slow library corners (flow_cg3/config.mk, flow_cg3/constraint.sdc).
# WSL2 Ubuntu:  sudo bash scripts/run_cg3.sh
# One stage:    sudo ONLY="sta" bash scripts/run_cg3.sh
# Writes physical/*/cg3/ and reports/cg3/; base, cg and cg2 results are only read.
# Requires build/corner_libs/ and build/pdk/ from scripts/run_signoff_extra.sh.
# Pin metal: pin rectangles copied onto the drawing layer (scripts/pin_metal.py).
# npc.2: narrow npc notches between abutting cells merged (scripts/npc_fix.py).
# Chip art on met5 (scripts/chip_art.py).
# Timing: hold uncertainty 0.2 ns (setup 0.4 ns), HOLD_SLACK_MARGIN 0.30 ns,
# SLEW_MARGIN/CAP_MARGIN 50 %. The sta stage reports all three corners.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
V=cg3
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
    "source /OpenROAD-flow-scripts/env.sh; make DESIGN_CONFIG=/work/flow_cg3/config.mk WORK_HOME=/work/physical FLOW_VARIANT=$V $1" \
    2>&1 | tee "$O/physical_${1:-flow}.log"
}

physical() {
  python3 scripts/generate_rtl_cg.py
  python3 scripts/generate_rtl_cg3.py
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
  # Chip art: heart outline + ECG trace on met5, in the free bands between the
  # PDN straps, isolated from all existing met5/via4 (scripts/chip_art.py).
  orfs -v "$ROOT:/work" -e GDS_IN=/work/$R/6_final.gds -e GDS_OUT=/work/$R/6_final.gds \
    -e REPORT=/work/$O/chip_art.txt -e QT_QPA_PLATFORM=offscreen "$IMAGE" bash -lc \
    'source /OpenROAD-flow-scripts/env.sh; klayout -b -r /work/scripts/chip_art.py'
  grep -q "RESULT: PASS" $O/chip_art.txt
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
    # Rows of the violator table: path-group rows carry a negative slack, slew/cap/fanout
    # rows end in (VIOLATED). 0 means the corner is clean.
    echo "$c: violating endpoints and pins: $(awk '/^### violators/{f=1;next} /^### end violators/{f=0} f && (/^core_clk +-/ || /\(VIOLATED\)$/)' $O/sta_$c.rpt | wc -l)"
  done
}

run rtl      bash scripts/verify_cg3.sh
# Random load/start/reset stimulus on the post-route netlist; the output trace
# must equal the ungated baseline RTL's trace (tb/tb_random.sv, zero delay).
random_net() {
  local n=${RANDOM_CYCLES:-100000}
  iverilog -g2012 -s tb_random -o build/random_base rtl/*.v tb/tb_random.sv
  iverilog -g2012 -s tb_random -o build/random_${V}_net $R/6_final.v build/sky130hd_sim.v tb/sky130_icg_model.v tb/tb_random.sv
  vvp build/random_base +SEED=1 +CYCLES=$n +TRACE_FILE=build/random_base_ref.txt | grep DONE | sed 's/^/baseline RTL:   /' | tee $O/final_gate_random.log
  vvp build/random_${V}_net +SEED=1 +CYCLES=$n +TRACE_FILE=build/random_${V}_net.txt | grep DONE | sed 's/^/final netlist:  /' | tee -a $O/final_gate_random.log
  cmp build/random_base_ref.txt build/random_${V}_net.txt
  echo "PASS final netlist: output trace identical to baseline RTL (seed 1, $n clocks)" | tee -a $O/final_gate_random.log
}

run physical physical
run checks   checks
run verify   bash scripts/verify_variant.sh $V
run random   random_net
run drc_mr   drc_mr
run sta      sta
run power    bash scripts/activity_power_variant.sh $V
run compare  python3 scripts/compare_cg.py base cg cg2 $V
echo "Done: $O/comparison.md" | tee -a "$LOG"
