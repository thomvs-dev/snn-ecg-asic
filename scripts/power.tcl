# Diagnostic estimate at the platform's TT/25C/1.8 V corner.
read_liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db /work/physical/results/sky130hd/ecg_snn_core/base/6_final.odb
read_sdc /work/physical/results/sky130hd/ecg_snn_core/base/6_final.sdc
read_spef /work/physical/results/sky130hd/ecg_snn_core/base/6_final.spef
report_power > /work/reports/power_vectorless.rpt
report_power -format json -digits 9 > /work/reports/power_vectorless.json
read_vcd -scope tb_core/dut /work/reports/mapped_activity.vcd
report_activity_annotation > /work/reports/power_activity_coverage.rpt
report_power > /work/reports/power_activity.rpt
report_power -format json -digits 9 > /work/reports/power_activity.json
# Annotate a separate 100 us quiescent window to expose clock-on idle power.
read_vcd -scope tb_idle/dut /work/reports/idle_activity.vcd
report_activity_annotation > /work/reports/power_idle_coverage.rpt
report_power > /work/reports/power_idle.rpt
report_power -format json -digits 9 > /work/reports/power_idle.json
report_checks -path_delay min_max -format full_clock_expanded > /work/reports/final_setup_hold.rpt
set block [ord::get_db_block]
set core [$block getCoreArea]
set die [$block getDieArea]
set f [open /work/reports/physical_geometry.txt w]
puts $f "dbu_per_um [$block getDbUnitsPerMicron]"
puts $f "die_dbu [$die xMin] [$die yMin] [$die xMax] [$die yMax]"
puts $f "core_dbu [$core xMin] [$core yMin] [$core xMax] [$core yMax]"
set total 0
set counts [dict create]
set areas [dict create]
foreach inst [$block getInsts] {
 incr total
 set master [$inst getMaster]
 set type [$master getType]
 dict incr counts $type
 dict incr areas $type [expr {[$master getWidth] * [$master getHeight]}]
}
puts $f "total_instances $total"
dict for {type count} $counts { puts $f "type $type count $count area_dbu2 [dict get $areas $type]" }
close $f
