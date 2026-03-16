/*
* Module: WB_WriteBack_Mux.v
* Description: Selects write-back data for the register file based on MemToReg,
* with full support for RV32IM ISA.
* This logic is deliberately kept combinational and flat because the output 
* net drives the Register File, EX stage forwarding, and ID stage branch 
* resolution simultaneously, requiring heavy fanout buffering by Vivado.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module WB_WriteBack_Mux #(
    parameter WIDTH    = 32,
    parameter PC_WIDTH = 32
    )(
    input  wire [WIDTH-1:0]     WB_ALUResult,  // Origin: MEM_WB_Reg
    input  wire [WIDTH-1:0]     WB_ReadData,   // Origin: MEM_WB_Reg 
    input  wire [PC_WIDTH-1:0]  WB_PC_Plus_4,  // Origin: MEM_WB_Reg 
    input  wire [1:0]           WB_MemToReg,   // Origin: MEM_WB_Reg 
    output reg  [WIDTH-1:0]     WB_WriteData   // Destination: ID_Register_File & EX_ALU_Input_Sel
    );
    
    always @(*) begin
    
       case (WB_MemToReg)
           2'b00:   WB_WriteData = WB_ALUResult;   // R-Type, I-Type, etc.
           2'b01:   WB_WriteData = WB_ReadData;    // Load Instructions
           2'b10:   WB_WriteData = WB_PC_Plus_4;   // JAL / JALR (Link Address)
           default: WB_WriteData = WB_ALUResult;   // Default fallback
           
       endcase 
       
    end
    
endmodule