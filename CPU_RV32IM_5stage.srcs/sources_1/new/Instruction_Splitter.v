/*
* Module: Instruction_Splitter.v
* Description: Extracts register addresses AND function codes (Funct3, Funct7, Opcode)
* from the 32-bit RV32IM instruction.
* Updated to support 3-operand source extraction for MAC units.
* Acts as the structural "De-Mux" (Output interface) for the ID Stage.
* Stage: ID
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module Instruction_Splitter #(
    parameter INSTR_WIDTH = 32,
    parameter REG_COUNT   = 32
    )(
    input  wire [INSTR_WIDTH-1:0]       ID_Instr_RV32IM, // Origin: IF_ID Pipeline Register
    
    // Passthrough
    output wire [INSTR_WIDTH-1:0]       ID_Instr_Out,    // Destination: Control_Unit, Imm_Gen
    
    // Register Addresses
    output wire [$clog2(REG_COUNT)-1:0] ID_Rs1Addr,      // Destination: Register_File (RP1), Hazard Unit, Forwarding
    output wire [$clog2(REG_COUNT)-1:0] ID_Rs2Addr,      // Destination: Register_File (RP2), Hazard Unit, Forwarding
    output wire [$clog2(REG_COUNT)-1:0] ID_Rs3Addr,      // Destination: Register_File (RP3), Hazard Unit, Forwarding (MAC)
    output wire [$clog2(REG_COUNT)-1:0] ID_RdAddr,       // Destination: ID/EX Reg (for WB propagation)
    
    // Control Fields
    output wire [2:0]                   ID_Funct3,       // Destination: ID/EX Reg, Control_Unit
    output wire [6:0]                   ID_Funct7,       // Destination: ID/EX Reg
    output wire [6:0]                   ID_Opcode        // Destination: Control_Unit
    );
    
    // Using continuous assignments for better synthesis of purely structural logic
    assign ID_Instr_Out = ID_Instr_RV32IM;
    
    // Standard RISC-V Fields
    assign ID_Rs1Addr = ID_Instr_RV32IM[19:15];
    assign ID_Rs2Addr = ID_Instr_RV32IM[24:20];
    assign ID_RdAddr  = ID_Instr_RV32IM[11:7];      
    assign ID_Rs3Addr = ID_RdAddr;               // Also used for MAC Accumulation
    
    // Field Extraction
    assign ID_Funct3  = ID_Instr_RV32IM[14:12];
    assign ID_Funct7  = ID_Instr_RV32IM[31:25];
    assign ID_Opcode  = ID_Instr_RV32IM[6:0];
    
endmodule