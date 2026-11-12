# Static timing of a routed variant at one Liberty corner; output goes to stdout
# (run_signoff_extra.sh saves it under reports/signoff_extra/).
# env: VARIANT (base|cg), LIB (Liberty path)
# Parasitics: the single extracted SPEF (OpenRCX, nominal RC). Only the cell
# library corner changes, so this is a library-corner check, not RC-corner signoff.
set r /work/physical/results/sky130hd/ecg_snn_core/$::env(VARIANT)
read_liberty $::env(LIB)
read_db $r/6_final.odb
read_sdc $r/6_final.sdc
read_spef $r/6_final.spef
puts "corner_lib $::env(LIB)"
puts "variant $::env(VARIANT)"
report_worst_slack -max -digits 4
report_worst_slack -min -digits 4
report_tns -digits 4
puts "### worst setup paths"
report_checks -path_delay max -group_path_count 3 -digits 3
puts "### worst hold paths"
report_checks -path_delay min -group_path_count 5 -digits 3
puts "### violators"
report_check_types -max_delay -min_delay -max_slew -max_capacitance -max_fanout -violators -digits 4
puts "### end violators"
puts "### clock skew"
report_clock_skew -digits 3
