# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "IMEM_DEPTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "INSTR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PC_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.IMEM_DEPTH { PARAM_VALUE.IMEM_DEPTH } {
	# Procedure called to update IMEM_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IMEM_DEPTH { PARAM_VALUE.IMEM_DEPTH } {
	# Procedure called to validate IMEM_DEPTH
	return true
}

proc update_PARAM_VALUE.INSTR_WIDTH { PARAM_VALUE.INSTR_WIDTH } {
	# Procedure called to update INSTR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.INSTR_WIDTH { PARAM_VALUE.INSTR_WIDTH } {
	# Procedure called to validate INSTR_WIDTH
	return true
}

proc update_PARAM_VALUE.PC_WIDTH { PARAM_VALUE.PC_WIDTH } {
	# Procedure called to update PC_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PC_WIDTH { PARAM_VALUE.PC_WIDTH } {
	# Procedure called to validate PC_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.PC_WIDTH { MODELPARAM_VALUE.PC_WIDTH PARAM_VALUE.PC_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PC_WIDTH}] ${MODELPARAM_VALUE.PC_WIDTH}
}

proc update_MODELPARAM_VALUE.INSTR_WIDTH { MODELPARAM_VALUE.INSTR_WIDTH PARAM_VALUE.INSTR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.INSTR_WIDTH}] ${MODELPARAM_VALUE.INSTR_WIDTH}
}

proc update_MODELPARAM_VALUE.IMEM_DEPTH { MODELPARAM_VALUE.IMEM_DEPTH PARAM_VALUE.IMEM_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IMEM_DEPTH}] ${MODELPARAM_VALUE.IMEM_DEPTH}
}

