# =======================================================================================
# 1. TIMING CONSTRAINTS (The "Performance" section)
# =======================================================================================

# ---------------------------------------------------------------------------------------
# Primary Clock Definition
# Target: 100 MHz (10.000 ns Period)
# ---------------------------------------------------------------------------------------
# This is the single most important line. It forces the tool to work hard to place 
# logic close together to ensure signal propagation happens within 10ns.
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports CPU_clk]

# ---------------------------------------------------------------------------------------
# Input Delay Constraints
# ---------------------------------------------------------------------------------------
# Associate rst_n with the clock. Even though your design has a "Reset Synchronizer",
# defining this delay prevents the router from placing the reset path 'lazily' far away.
# We assume the external reset signal arrives 1ns after the clock edge (conservative).
set_input_delay -clock [get_clocks sys_clk_pin] -min 1.000 [get_ports CPU_rst_n]
set_input_delay -clock [get_clocks sys_clk_pin] -max 1.000 [get_ports CPU_rst_n]

# ---------------------------------------------------------------------------------------
# Output Delay Constraints
# ---------------------------------------------------------------------------------------
# This constrains your debug outputs (PC, ALUResult, etc.).
# Without this, Vivado assumes outputs can take infinite time, leading to sloppy routing.
# We demand outputs be valid 2ns before the next clock edge.
set_output_delay -clock [get_clocks sys_clk_pin] 2.000 [get_ports {CPU_PC_WB[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] 2.000 [get_ports {CPU_ALUResult_WB[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] 2.000 [get_ports {CPU_WriteData_WB[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] 2.000 [get_ports {CPU_ALUControl_EX[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] 2.000 [get_ports TIMING_CHECK_LED]


# =======================================================================================
# 2. IMPLEMENTATION OPTIMIZATIONS (The "Bitstream" section)
# =======================================================================================

# ---------------------------------------------------------------------------------------
# Configuration Voltage
# ---------------------------------------------------------------------------------------
# Explicitly telling Vivado the voltage banks prevents warnings and potential damage 
# during configuration. (Standard for Artix-7 is usually 3.3V or 1.8V - Defaulting to 3.3V)
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# ---------------------------------------------------------------------------------------
# Bitstream Compression
# ---------------------------------------------------------------------------------------
# Optimizes the final .bit file size. Makes flashing the FPGA significantly faster.
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# ---------------------------------------------------------------------------------------
# Configuration Rate (SPI Flash speed)
# ---------------------------------------------------------------------------------------
# Increases the speed at which the FPGA loads from flash memory on boot.
# Default is often 3MHz (slow). 33MHz is a safe, fast baseline for most boards.
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]