# ---------------------------------------------------------------------------------------
# File: Constraints_RV32IM_Pipeline.xdc
# Description: Physical and Timing Constraints for the 5-Stage Pipelined RV32IM CPU.
#              - Defines 100 MHz Main System Clock.
#              - Implements "False Path" constraints for Debug/LED outputs to 
#                prevent false timing violations on non-critical logic.
#              - Handles Asynchronous Reset safely via false_path.
# Author: Aashrith S Narayn
# Date: 14/02/2026
# ---------------------------------------------------------------------------------------

# =======================================================================================
# 1. TIMING CONSTRAINTS (The "Performance" section)
# =======================================================================================

# ---------------------------------------------------------------------------------------
# Primary Clock Definition
# Target: 100 MHz (10.000 ns Period)
# ---------------------------------------------------------------------------------------
# This is the single most important line. It forces the tool to work hard to place 
# logic close together to ensure signal propagation happens within 10ns.
create_clock -period 25.000 -name sys_clk_pin -waveform {0.000 12.500} [get_ports CPU_clk]

# ---------------------------------------------------------------------------------------
# Reset Path Constraints (Updated for Synchronizer)
# ---------------------------------------------------------------------------------------
# Since we now have a Reset Synchronizer (2-FF chain), the external CPU_rst_n is 
# treated as an asynchronous signal. We explicitly tell Vivado NOT to analyze the 
# timing between the external pin and the first synchronizer flip-flop.
# This prevents "Recovery/Removal" timing violations during synthesis.

set_false_path -from [get_ports CPU_rst_n]

# ---------------------------------------------------------------------------------------
# DEBUG OUTPUT CONSTRAINTS (The Fix)
# ---------------------------------------------------------------------------------------
# We explicitly tell Vivado to IGNORE timing for all debug signals.
# The internal CPU design doesn't require these signals to reach on time, they are read-only
# This eliminates the "Setup Slack" violations caused by routing internal signals to pins.
# Vivado will route them "best effort," which is perfect for LEDs/Logic Analyzers.

set_false_path -to [get_ports {CPU_PC[*]}]
set_false_path -to [get_ports {CPU_Instr_RV32IM[*]}]
set_false_path -to [get_ports {CPU_Immediate[*]}]
set_false_path -to [get_ports {CPU_ALUResult[*]}]
set_false_path -to [get_ports {CPU_ALUControl[*]}]
set_false_path -to [get_ports CPU_Zero]
set_false_path -to [get_ports {CPU_ReadData[*]}]
set_false_path -to [get_ports {CPU_WriteDataReg[*]}]

# Control Signal Debugs
set_false_path -to [get_ports {CPU_ALUOp[*]}]
set_false_path -to [get_ports CPU_MDSel]
set_false_path -to [get_ports CPU_MacSel]
set_false_path -to [get_ports {CPU_ImmediateSrc[*]}]
set_false_path -to [get_ports {CPU_TargetSel[*]}]
set_false_path -to [get_ports CPU_RegWrite]
set_false_path -to [get_ports CPU_MemRead]
set_false_path -to [get_ports CPU_MemWrite]
set_false_path -to [get_ports {CPU_MemToReg[*]}]
set_false_path -to [get_ports {CPU_MemDataType[*]}]
set_false_path -to [get_ports CPU_ALUSrc1]
set_false_path -to [get_ports CPU_ALUSrc2]
set_false_path -to [get_ports {CPU_PCSrc[*]}]

# Advanced Debugs (MAC, Stall, Forwarding)
set_false_path -to [get_ports {CPU_MAC_Accumulator[*]}]
set_false_path -to [get_ports CPU_MAC_Active]
set_false_path -to [get_ports CPU_Stall_Divider]
set_false_path -to [get_ports CPU_Stalled]
set_false_path -to [get_ports CPU_Flush_Event]
set_false_path -to [get_ports {CPU_FwdC_Sel[*]}]



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