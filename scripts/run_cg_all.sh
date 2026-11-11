#!/usr/bin/env bash
# One-shot clock-gating evaluation (run from WSL2 Ubuntu, not PowerShell):
#   sudo bash scripts/run_cg_all.sh
# Steps: cg ORFS flow + DRC + LVS, ICG check, functional verification
# (RTL + cg post-route netlist), power for cg and base on their final
# netlists, comparison table. Stops at the first failing step.
# Baseline results in */base/ are only read (the base power run writes to
# reports/power_base/, a new folder).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/cg
LOG=reports/cg/run_all.log
: > "$LOG"
step() {
  local name=$1; shift
  echo "=== $(date -Is) START $name" | tee -a "$LOG"
  local t0=$SECONDS
  if "$@"; then
    echo "=== $(date -Is) OK    $name ($((SECONDS - t0)) s)" | tee -a "$LOG"
  else
    echo "=== $(date -Is) FAIL  $name ($((SECONDS - t0)) s)" | tee -a "$LOG"
    exit 1
  fi
}
step physical_cg   bash scripts/run_physical_cg.sh
step icg_check     bash -c 'cat reports/cg/icg_check.txt; ! grep -q ": *0$" reports/cg/icg_check.txt'
step verify_cg     bash scripts/verify_cg.sh
step power_cg      bash scripts/activity_power_variant.sh cg
step power_base    bash scripts/activity_power_variant.sh base
step compare       python3 scripts/compare_cg.py
echo "All steps passed. Results: reports/cg/comparison.md" | tee -a "$LOG"
