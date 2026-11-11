# OpenSTA power for one flow variant (env VARIANT = base | cg), TT 25C 1.8 V,
# final ODB/SDC/SPEF, activity from simulations of that variant's FINAL netlist.
set v $::env(VARIANT)
set r /work/physical/results/sky130hd/ecg_snn_core/$v
set o /work/reports/power_$v
read_liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db $r/6_final.odb
read_sdc $r/6_final.sdc
read_spef $r/6_final.spef
report_power > $o/vectorless.rpt
report_power -format json -digits 9 > $o/vectorless.json
read_vcd -scope tb_core/dut $o/activity.vcd
report_activity_annotation > $o/activity_coverage.rpt
report_power > $o/activity.rpt
report_power -format json -digits 9 > $o/activity.json
read_vcd -scope tb_idle/dut $o/idle.vcd
report_activity_annotation > $o/idle_coverage.rpt
report_power > $o/idle.rpt
report_power -format json -digits 9 > $o/idle.json
