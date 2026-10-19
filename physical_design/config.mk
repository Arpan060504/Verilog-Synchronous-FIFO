export DESIGN_NAME = fifo
export PLATFORM    = nangate45

export VERILOG_FILES = $(DESIGN_HOME)/src/fifo/fifo.sv
export SDC_FILE      = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/constraint.sdc

export ABC_AREA = 1
export CORE_UTILIZATION ?= 55
export PLACE_DENSITY_LB_ADDON = 0.20
export TNS_END_PERCENT = 100
export SYNTH_REPEATABLE_BUILD ?= 1
