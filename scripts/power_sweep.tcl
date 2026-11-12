# Power of one variant at one clock period, with time-stretched activity.
# env: VARIANT, PERIOD_NS, ACT_VCD, IDLE_VCD, OUT (directory)
set r /work/physical/results/sky130hd/ecg_snn_core/$::env(VARIANT)
read_liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db $r/6_final.odb
read_sdc $r/6_final.sdc
read_spef $r/6_final.spef
# Redefine only the clock period (power analysis; timing is not reported here).
create_clock -name core_clk -period $::env(PERIOD_NS) [get_ports clk]
set_propagated_clock [all_clocks]
read_vcd -scope tb_core/dut $::env(ACT_VCD)
report_activity_annotation > $::env(OUT)/activity_coverage.rpt
report_power -format json -digits 9 > $::env(OUT)/activity.json
read_vcd -scope tb_idle/dut $::env(IDLE_VCD)
report_activity_annotation > $::env(OUT)/idle_coverage.rpt
report_power -format json -digits 9 > $::env(OUT)/idle.json
