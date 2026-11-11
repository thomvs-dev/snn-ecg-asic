# Clock-gated variant. Identical to flow/config.mk except the RTL directory.
# Run with FLOW_VARIANT=cg so results land in physical/*/sky130hd/ecg_snn_core/cg/
# and the baseline (base/) results are not touched.
export DESIGN_NAME = ecg_snn_core
export PLATFORM = sky130hd
export VERILOG_FILES = $(sort $(wildcard /work/rtl_cg/*.v))
export SDC_FILE = /work/flow/constraint.sdc
export CORE_UTILIZATION = 35
export CORE_ASPECT_RATIO = 1
export CORE_MARGIN = 10
export PLACE_DENSITY_LB_ADDON = 0.10
export TNS_END_PERCENT = 100
export NUM_CORES = 4
