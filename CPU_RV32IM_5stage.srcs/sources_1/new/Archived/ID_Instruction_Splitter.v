/*
* Module: ID_Instruction_Splitter.v
* Description: Extracts register addresses AND function codes (Funct3, 
* Funct7, Opcode) from the 32-bit RV32IM instruction.
* Updated to support 3-operand source extraction for MAC units.
* Acts as the structural "De-Mux" (Output interface) for the ID Stage.
* This module contains zero logic gates. It is purely structural wire
* routing for the synthesis tool.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module ID_Instruction_Splitter #(
    parameter INSTR_WIDTH = 32,
    parameter REG_COUNT   = 32
    )(
    input  wire [INSTR_WIDTH-1:0]       ID_Instr_RV32IM, // Origin: IF_ID Pipeline Register (bypass wire from IMEM)
    
    // Passthrough
    output wire [INSTR_WIDTH-1:0]       ID_Instr_Out,    // Destination: ID_Control_Unit, ID_Imm_Gen
    
    // Register Addresses
    output wire [$clog2(REG_COUNT)-1:0] ID_Rs1Addr,      // Destination: ID_Register_File, ID_Hazard_Detector, ID_EX_Reg
    output wire [$clog2(REG_COUNT)-1:0] ID_Rs2Addr,      // Destination: ID_Register_File, ID_Hazard_Detector, ID_EX_Reg
    output wire [$clog2(REG_COUNT)-1:0] ID_Rs3Addr,      // Destination: ID_Register_File, ID_Hazard_Detector, ID_EX_Reg (MAC)
    output wire [$clog2(REG_COUNT)-1:0] ID_RdAddr,       // Destination: ID_EX_Reg
    
    // Control Fields
    output wire [2:0]                   ID_Funct3,       // Destination: ID_EX_Reg, ID_Control_Unit, ID_Branch_Comparator
    output wire [6:0]                   ID_Funct7,       // Destination: ID_EX_Reg, ID_Control_Unit
    output wire [6:0]                   ID_Opcode        // Destination: ID_Control_Unit, ID_Hazard_Detector
    );
    
    // Using continuous assignments for better synthesis of purely structural logic
    assign ID_Instr_Out = ID_Instr_RV32IM;
    
    // Standard RISC-V Fields
    assign ID_Rs1Addr = ID_Instr_RV32IM[19:15];
    assign ID_Rs2Addr = ID_Instr_RV32IM[24:20];
    // Field Extraction - Pulling directly from bits [11:7] for both
    assign ID_RdAddr  = ID_Instr_RV32IM[11:7];      
    assign ID_Rs3Addr = ID_Instr_RV32IM[11:7]; // Extraction for MAC Accumulation
    
    // Field Extraction
    assign ID_Funct3  = ID_Instr_RV32IM[14:12];
    assign ID_Funct7  = ID_Instr_RV32IM[31:25];
    assign ID_Opcode  = ID_Instr_RV32IM[6:0];
    
endmodule