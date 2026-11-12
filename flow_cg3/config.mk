# cg3: root clock gate (rtl_cg3) plus timing margins for the fast and slow corners.
# Same floorplan settings and pin plan as cg2 (flow_cg2/config.mk), so the two
# layouts are directly comparable.
# Run with FLOW_VARIANT=cg3; results land in physical/*/sky130hd/ecg_snn_core/cg3/.
export DESIGN_NAME = ecg_snn_core
export PLATFORM = sky130hd
export VERILOG_FILES = $(sort $(wildcard /work/rtl_cg3/*.v))
export SDC_FILE = /work/flow_cg3/constraint.sdc
export CORE_UTILIZATION = 55
export CORE_ASPECT_RATIO = 1
export CORE_MARGIN = 10
export PLACE_DENSITY_LB_ADDON = 0.10
export TNS_END_PERCENT = 100
export NUM_CORES = 4
export IO_CONSTRAINTS = /work/flow_cg2/io.tcl

# The flow repairs timing with the TT library only. These margins make the TT
# repair cover the other two library corners, which scripts/sta_corners.tcl
# then checks on the routed design (reports/cg3/sta_*.rpt).
#
# Hold: cg2 lost 0.18 ns of hold slack from TT to ff (+0.036 -> -0.143 ns).
# Repair to +0.30 ns at TT so ff keeps about +0.1 ns.
export HOLD_SLACK_MARGIN = 0.30
# Max slew / max capacitance (percent overfix): cg2 at ss exceeded the limits by
# up to 75 % (slew 2.62 ns against 1.50 ns; cap 0.109 pF against 0.063 pF).
# Repairing to half the TT limit is intended to keep ss inside its limits.
export SLEW_MARGIN = 50
export CAP_MARGIN = 50
