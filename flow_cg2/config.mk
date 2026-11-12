# Clock-gated design, denser core and evenly spaced pins (FLOW_VARIANT=cg2).
# Same RTL (rtl_cg) and SDC as cg. Differences from flow_cg/config.mk:
#  - CORE_UTILIZATION 55 (cg: 35). ORFS sizes the core from synthesis area;
#    cells grow ~14 % through the flow, so final utilization is expected ~63 %.
#  - IO_CONSTRAINTS: inputs evenly spaced on the west edge, outputs on the east
#    edge, snapped to met3 tracks (flow_cg2/io.tcl).
export DESIGN_NAME = ecg_snn_core
export PLATFORM = sky130hd
export VERILOG_FILES = $(sort $(wildcard /work/rtl_cg/*.v))
export SDC_FILE = /work/flow/constraint.sdc
export CORE_UTILIZATION = 55
export CORE_ASPECT_RATIO = 1
export CORE_MARGIN = 10
export PLACE_DENSITY_LB_ADDON = 0.10
export TNS_END_PERCENT = 100
export NUM_CORES = 4
export IO_CONSTRAINTS = /work/flow_cg2/io.tcl
