/*
* Module: WriteBack_Mux.v
* Description: Selects write-back data for the register file based on MemToReg,
* with full support for RV32IM ISA.
* Updated for WB stage signal naming in 5-stage pipeline.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

//(* dont_touch = "true" *)
module WriteBack_Mux #(
    parameter WIDTH    = 32,
    parameter PC_WIDTH = 32
    )(
    input  wire [WIDTH-1:0]     WB_ALUResult,  // Origin: MEM/WB Pipeline Register
    input  wire [WIDTH-1:0]     WB_ReadData,   // Origin: MEM/WB Pipeline Register (from Data Memory)
    input  wire [PC_WIDTH-1:0]  WB_PC_Plus_4,  // Origin: MEM/WB Pipeline Register (Carried from IF)
    input  wire [1:0]           WB_MemToReg,   // Origin: MEM/WB Pipeline Register (Control Bundle)
    output reg  [WIDTH-1:0]     WB_WriteData   // Destination: Register_File (Write Port - WB_WriteData)
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