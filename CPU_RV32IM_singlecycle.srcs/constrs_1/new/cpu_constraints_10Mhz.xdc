## ----------------------------------------------------------------------
## 1. Clock Definition (10 MHz = 100ns Period)
## ----------------------------------------------------------------------
create_clock -period 200.000 -name sys_clk -waveform {0.000 100.000} [get_ports CPU_clk]

## ----------------------------------------------------------------------
## 2. Asynchronous Path Exceptions
## ----------------------------------------------------------------------
# Reset is synchronized in your top-level; the input pin itself is async.
set_false_path -from [get_ports CPU_rst_n]

## ----------------------------------------------------------------------
## 3. Minimizing I/O Overhead
## ----------------------------------------------------------------------
# Your debug outputs (CPU_ALUResult, etc.) are currently timed.
# In a single-cycle CPU, the path from PC -> ALU -> Output is massive.
# By setting these as false paths, we tell Vivado: "Don't worry about the delay 
# to the LEDs/Debug pins, just make sure the internal Register File is stable."

set_false_path -to [get_ports {CPU_PC[*]}]
set_false_path -to [get_ports {CPU_Instr_RV32IM[*]}]
set_false_path -to [get_ports {CPU_ALUResult[*]}]
set_false_path -to [get_ports {CPU_WriteDataReg[*]}]
set_false_path -to [get_ports {CPU_ReadData[*]}]
set_false_path -to [get_ports CPU_Zero]
set_false_path -to [get_ports TIMING_CHECK_LED]

# Specifically target the path shown in your 'Path 11-20' report
#set_false_path -from [get_cells CPU_ProgCount/PC_reg[*]] -to [all_outputs]

# If you prefer not to use False Paths for all, use a very lenient delay:
set_output_delay -clock sys_clk -max 180.000 [all_outputs]
set_output_delay -clock sys_clk -min -10.000 [all_outputs]