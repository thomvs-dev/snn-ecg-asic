#!/usr/bin/env bash
# RTL verification of the root-clock-gated variant (rtl_cg3). Needs only iverilog.
#   500 vectors against reports/baseline.csv, protocol bench, root-gate bench
#   (gated clocks static when idle), and random-stimulus output traces compared
#   cycle by cycle with the ungated baseline rtl/ (3 seeds x 400,000 clocks).
# Zero-delay simulation; tb/sky130_icg_model.v models the SKY130 ICG cell.
# Post-route netlist checks are in scripts/verify_variant.sh cg3.
set -euo pipefail
cd "$(dirname "$0")/.."
O=reports/cg3
mkdir -p build "$O"
M=tb/sky130_icg_model.v
python3 scripts/generate_rtl_cg.py
python3 scripts/generate_rtl_cg3.py
iverilog -g2012 -s tb_core -o build/cg3_core rtl_cg3/*.v $M tb/tb_core.sv 2> $O/rtl_compile.log
vvp build/cg3_core +PRED_FILE=$O/rtl_predictions.csv +VCD_FILE=$O/rtl_first_beat.vcd | tee $O/rtl_simulation.log
cmp $O/rtl_predictions.csv reports/baseline.csv && echo "RTL predictions identical to baseline.csv"
iverilog -g2012 -s tb_protocol -o build/cg3_protocol rtl_cg3/*.v $M tb/tb_protocol.sv
vvp build/cg3_protocol | tee $O/rtl_protocol.log
iverilog -g2012 -s tb_root_gate -o build/cg3_root_gate rtl_cg3/*.v $M tb/tb_root_gate.sv
vvp build/cg3_root_gate | tee $O/rtl_root_gate.log
grep -q "^PASS root clock gate" $O/rtl_root_gate.log
iverilog -g2012 -s tb_random -o build/random_base rtl/*.v tb/tb_random.sv
iverilog -g2012 -s tb_random -o build/random_cg3 rtl_cg3/*.v $M tb/tb_random.sv
: > $O/rtl_random.log
for seed in 1 2 3; do
  vvp build/random_base +SEED=$seed +TRACE_FILE=build/random_base_$seed.txt | grep DONE | sed 's/^/base: /' | tee -a $O/rtl_random.log
  vvp build/random_cg3  +SEED=$seed +TRACE_FILE=build/random_cg3_$seed.txt  | grep DONE | sed 's/^/cg3:  /' | tee -a $O/rtl_random.log
  cmp build/random_base_$seed.txt build/random_cg3_$seed.txt
  echo "seed $seed: output traces identical ($(wc -l < build/random_cg3_$seed.txt) clocks)" | tee -a $O/rtl_random.log
done
echo "PASS cg3 RTL: 500 vectors, protocol, root gate, random traces" | tee -a $O/rtl_random.log
