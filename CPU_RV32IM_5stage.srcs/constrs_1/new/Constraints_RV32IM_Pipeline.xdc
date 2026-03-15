# ---------------------------------------------------------------------------------------
# File: Constraints_RV32IM_Pipeline.xdc
# Description: Physical and Timing Constraints for the 100MHz RV32IM CPU.
# Author: Aashrith S Narayn
# Date: 15/03/2026 (Updated for 100MHz Hardened Micro-arch)
# ---------------------------------------------------------------------------------------

# =======================================================================================
# 1. TIMING CONSTRAINTS
# =======================================================================================

# ---------------------------------------------------------------------------------------
# Primary Clock Definition
# Target: 70 MHz (14.280 ns Period)
# ---------------------------------------------------------------------------------------
create_clock -period 14.280 -name sys_clk_pin -waveform {0.000 7.140} [get_ports CPU_clk]

# ---------------------------------------------------------------------------------------
# Reset Path Constraints
# ---------------------------------------------------------------------------------------
# Treat the raw external reset as asynchronous. The Reset_Synchronizer handles 
# the transition into the clock domain.
set_false_path -from [get_ports CPU_rst_n]

# ---------------------------------------------------------------------------------------
# DEBUG OUTPUT CONSTRAINTS (False Paths)
# ---------------------------------------------------------------------------------------
# These signals are for monitoring and are not part of any synchronous logic 
# outside the CPU. We set false paths to prevent "routing-to-pin" delays 
# from skewing the internal timing analysis of the pipeline.

#Core State Debug
set_false_path -to [get_ports {CPU_PC[*]}]
set_false_path -to [get_ports {CPU_Instr_RV32IM[*]}]
set_false_path -to [get_ports {CPU_Immediate[*]}]
set_false_path -to [get_ports {CPU_ALUResult[*]}]
set_false_path -to [get_ports {CPU_ReadData[*]}]
set_false_path -to [get_ports {CPU_WriteDataReg[*]}]

#Comparison/Branch Debug (Updated for new ports)
set_false_path -to [get_ports CPU_Eq]
set_false_path -to [get_ports CPU_Lt]
set_false_path -to [get_ports CPU_Ltu]

#Control Signal Debugs
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
set_false_path -to [get_ports {CPU_ALUControl[*]}]

#Pipeline & MAC Debugs
set_false_path -to [get_ports {CPU_MAC_Accumulator[*]}]
set_false_path -to [get_ports CPU_MAC_Active]
set_false_path -to [get_ports CPU_Stall_Divider]
set_false_path -to [get_ports CPU_Stalled]
set_false_path -to [get_ports CPU_Flush_Event]
set_false_path -to [get_ports {CPU_FwdC_Sel[*]}]

# =======================================================================================
# 2. IMPLEMENTATION & BITSTREAM PROPERTIES
# =======================================================================================

# Voltage and I/O Standards (Standard for Nexys Video / Artix-7)
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Bitstream Compression (Faster loading from SPI Flash)
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
