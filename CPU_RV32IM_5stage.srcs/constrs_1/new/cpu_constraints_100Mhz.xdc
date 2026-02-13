## ----------------------------------------------------------------------
## Clock Constraint for 100 MHz
## ----------------------------------------------------------------------
## period 10.000 = 10ns cycle time
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports CPU_clk]

## ----------------------------------------------------------------------
## Input/Output Delays (Relaxed to avoid false failures on IO)
## ----------------------------------------------------------------------
# We are relaxing IO constraints because we care about the INTERNAL path
# (Register-to-Register) right now, not the switches/LEDs.

set_input_delay -clock sys_clk -min 0.000 [get_ports {CPU_rst_n}]
set_input_delay -clock sys_clk -max 2.000 [get_ports {CPU_rst_n}]

# Grouping all outputs
set_output_delay -clock sys_clk -min 0.000 [all_outputs]
set_output_delay -clock sys_clk -max 2.000 [all_outputs]

# Reset synchronizer constraints
set_false_path -from [get_ports CPU_rst_n]