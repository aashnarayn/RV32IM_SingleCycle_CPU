/*
* Module: Instr_Splitter.v
* Description: Extracts register address fields (rs1, rs2, rd) from the 
*              32-bit RV32IM instruction word. Used for interfacing 
*              instruction memory output with the register file.
*              Only decodes fixed bit positions per RISC-V spec.
* Author: Aashrith S Narayn
* Date: 07/07/2025
*/


`timescale 1ns / 1ps

//this module is purely for viewing the CPU in block design, to be used
//between Instruction Memory and Register File
module Instr_Splitter #(
    parameter INSTR_WIDTH = 32,
    parameter REG_COUNT   = 32
    )(
    input  wire [INSTR_WIDTH-1:0]       Instr_RV32IM,
    output reg  [$clog2(REG_COUNT)-1:0] Rs1Addr, Rs2Addr,
    output reg  [$clog2(REG_COUNT)-1:0] RdAddr
    );
    
    //harcoding fixed bit values in Instr_RV32IM 
    always @(*) begin
        {Rs1Addr,Rs2Addr,RdAddr} = {Instr_RV32IM[19:15],Instr_RV32IM[24:20],Instr_RV32IM[11:7]};
    end
    
endmodule
