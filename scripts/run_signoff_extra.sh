#!/usr/bin/env bash
# Extra checks on the existing routed databases (no re-layout), WSL2 Ubuntu:
#   sudo bash scripts/run_signoff_extra.sh
# 1. Library-corner STA (ff_n40C_1v95, ss_100C_1v60, PDK tt_025C_1v80 cross-check)
#    for base and cg. Corner .lib files come from an open_pdks build via ciel.
# 2. Full-chip DRC (FEOL+BEOL+off-grid) with the open_pdks sky130A_mr.drc deck.
# 3. Power at 25, 10, 5 and 1 MHz for base and cg (time-stretched activity).
# Outputs: reports/signoff_extra/. Physical results are only read.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
O=reports/signoff_extra
mkdir -p "$O" build/corner_libs build/sweep
LOG=$O/run.log
[ -n "${ONLY:-}" ] || : > "$LOG"
step() {
  local name=$1; shift
  echo "=== $(date -Is) START $name" | tee -a "$LOG"
  local t0=$SECONDS
  if ( set -e; "$@" ); then echo "=== $(date -Is) OK    $name ($((SECONDS - t0)) s)" | tee -a "$LOG"
  else echo "=== $(date -Is) FAIL  $name ($((SECONDS - t0)) s)" | tee -a "$LOG"; exit 1; fi
}
orfs() { docker run --rm "$@"; }

# ---------------------------------------------------------------- 0. corner libraries
get_libs() {
  if [ -n "${CORNER_LIB_DIR:-}" ]; then cp "$CORNER_LIB_DIR"/sky130_fd_sc_hd__{ff_n40C_1v95,ss_100C_1v60,tt_025C_1v80}.lib build/corner_libs/; return; fi
  if [ ! -x build/ciel-venv/bin/ciel ]; then
    # Ubuntu needs python3-venv for "python3 -m venv"; install it if missing.
    if ! python3 -c "import ensurepip" 2>/dev/null; then
      apt-get update -qq && apt-get install -y -qq python3-venv || return 1
    fi
    python3 -m venv --clear build/ciel-venv || return 1
    build/ciel-venv/bin/pip install -q ciel || return 1
  fi
  build/ciel-venv/bin/ciel --version || return 1
  build/ciel-venv/bin/ciel ls-remote --pdk-family sky130 > $O/pdk_versions_available.txt 2>&1 || true
  local v=${PDK_VERSION:-$(grep -oE '\b[0-9a-f]{40}\b' $O/pdk_versions_available.txt | head -1)}
  [ -n "$v" ] || { echo "no sky130 version found; set PDK_VERSION=<open_pdks hash>"; return 1; }
  build/ciel-venv/bin/ciel enable --pdk-family sky130 --pdk-root "$ROOT/build/pdk" -l sky130_fd_sc_hd "$v"
  for c in ff_n40C_1v95 ss_100C_1v60 tt_025C_1v80; do
    f=$(find -L build/pdk -path '*sky130A/libs.ref/sky130_fd_sc_hd/lib/*' -name "sky130_fd_sc_hd__$c.lib" | head -1)
    [ -n "$f" ] || { echo "missing $c lib"; return 1; }
    cp "$f" build/corner_libs/
  done
  { echo "open_pdks sky130 version (ciel): $v"; sha256sum build/corner_libs/*.lib
    echo "ORFS TT lib used for implementation:"
    orfs -v "$ROOT:/work" "$IMAGE" sha256sum /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib; } > $O/corner_libs.txt
  cat $O/corner_libs.txt
}

# ---------------------------------------------------------------- 1. corner STA
sta_all() {
  for v in base cg; do for c in tt_025C_1v80 ff_n40C_1v95 ss_100C_1v60; do
    orfs -e VARIANT=$v -e LIB=/work/build/corner_libs/sky130_fd_sc_hd__$c.lib -v "$ROOT:/work" "$IMAGE" \
      bash -lc 'source /OpenROAD-flow-scripts/env.sh; openroad -no_init -exit /work/scripts/sta_corners.tcl' \
      > $O/sta_${v}_${c}.rpt 2>&1
    grep -E "^worst slack|^tns" $O/sta_${v}_${c}.rpt | sed "s/^/$v $c: /"
  done; done
}

# ---------------------------------------------------------------- 2. FEOL DRC
drc_feol() {
  # Full-chip DRC with the open_pdks manufacturing-rules deck (sky130A_mr.drc,
  # the deck used for SKY130 shuttle precheck), FEOL + BEOL + off-grid, from the
  # same ciel PDK version as the corner libraries. The ORFS deck with FEOL forced
  # on hung for > 8 h in deep mode, so it is not used here.
  # Hard limit per run: DRC_TIMEOUT (SIGKILL; klayout ignores SIGTERM).
  local deck
  deck=$(ls build/pdk/ciel/sky130/versions/*/sky130A/libs.tech/klayout/drc/sky130A_mr.drc | head -1)
  [ -f "$deck" ] || { echo "sky130A_mr.drc not found; run the corner_libs step first"; return 1; }
  echo "deck: $deck ($(sha256sum "$deck" | cut -c1-16))"
  local pids=()
  for v in base cg; do
    orfs -v "$ROOT:/work" -e V=$v -e DECK=/work/$deck -e T=${DRC_TIMEOUT:-60m} -e THR=${DRC_THREADS:-2} "$IMAGE" bash -lc '
      source /OpenROAD-flow-scripts/env.sh
      timeout -s KILL $T klayout -b -r $DECK \
        -rd input=/work/physical/results/sky130hd/ecg_snn_core/$V/6_final.gds -rd top_cell=ecg_snn_core \
        -rd report=/work/reports/signoff_extra/drc_mr_$V.lyrdb \
        -rd feol=true -rd beol=true -rd offgrid=true -rd floating_met=false -rd seal=false -rd thr=$THR
      echo "klayout exit status $?"' > $O/drc_mr_$v.log 2>&1 &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait $p; done
  for v in base cg; do
    echo "$v: $(grep -c '<item>' $O/drc_mr_$v.lyrdb 2>/dev/null || echo 'no report') items; $(grep 'exit status' $O/drc_mr_$v.log)"
  done
}

# ---------------------------------------------------------------- 3. frequency sweep
power_sweep() {
  for v in base cg; do
    for fk in 25:1 10:2.5 5:5 1:25; do
      f=${fk%%:*}; k=${fk##*:}
      p=$(python3 -c "print(40*$k)")
      d=$O/power_${v}_${f}MHz; mkdir -p $d
      python3 scripts/scale_vcd.py reports/power_$v/activity.vcd build/sweep/act.vcd $k
      python3 scripts/scale_vcd.py reports/power_$v/idle.vcd build/sweep/idle.vcd $k
      orfs -e VARIANT=$v -e PERIOD_NS=$p -e ACT_VCD=/work/build/sweep/act.vcd -e IDLE_VCD=/work/build/sweep/idle.vcd \
        -e OUT=/work/$d -v "$ROOT:/work" "$IMAGE" \
        bash -lc 'source /OpenROAD-flow-scripts/env.sh; openroad -no_init -exit /work/scripts/power_sweep.tcl' > $d/power.log 2>&1
      echo "$k" > $d/time_scale.txt
      rm -f build/sweep/act.vcd build/sweep/idle.vcd
    done
  done
}

# ONLY="drc_feol power_sweep summarize" runs a subset (completed steps are not repeated).
run() { [ -z "${ONLY:-}" ] || [[ " $ONLY " == *" $1 "* ]] && step "$@" || true; }
run corner_libs get_libs
run sta_corners sta_all
run drc_feol    drc_feol
run power_sweep power_sweep
run summarize   python3 scripts/summarize_extra.py
echo "Done: $O/summary.md" | tee -a "$LOG"
