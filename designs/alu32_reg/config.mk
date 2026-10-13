export PLATFORM = sky130hd
export DESIGN_NAME = alu32_reg

export VERILOG_FILES = $(DESIGN_DIR)/../alu32/rtl/alu32.sv $(DESIGN_DIR)/rtl/alu32_reg.sv
export SDC_FILE = $(DESIGN_DIR)/constraint.sdc

export CORE_UTILIZATION = 40
export CORE_ASPECT_RATIO = 1
export CORE_MARGIN = 2
export PLACE_DENSITY = 0.60
