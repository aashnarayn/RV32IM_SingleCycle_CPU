/*
* Module: EX_ALUSelect_Mux.v
* Description: Final multiplexer for the Execute stage. Selects between 
* Integer ALU, M-Extension (Mul/Div), and MAC Adder results.
* Priority routing ensures MAC instructions correctly bypass the raw 
* multiplier output and capture the accumulator result instead.
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps

module EX_ALUSelect_Mux #(
    parameter WIDTH = 32
    )(
    // Inputs from various execution units
    input  wire [WIDTH-1:0] EX_ALUResult_I, // Origin: EX_ALU_RV32I
    input  wire [WIDTH-1:0] EX_ALUResult_M, // Origin: EX_ALU_RV32M (Product or Div Result)
    input  wire [WIDTH-1:0] EX_MACResult,   // Origin: EX_Accumulator
    
    // Control Signals
    input  wire             EX_MDSel,       // Origin: ID_EX_Reg
    input  wire             EX_MACSel,      // Origin: ID_EX_Reg
    
    // Final Outputs
    output reg  [WIDTH-1:0] EX_ALUResult    // Destination: EX_MEM Pipeline Register & Forwarding Unit
    );
    
    always @(*) begin
        // Priority 1: MAC Operation (Highest Specificity)
        if (EX_MACSel) begin
            EX_ALUResult = EX_MACResult;
        end 
        // Priority 2: Standard M-Extension (Mul/Div)
        else if (EX_MDSel) begin
            EX_ALUResult = EX_ALUResult_M;
        end 
        // Priority 3: Standard Integer ALU
        else begin
            EX_ALUResult = EX_ALUResult_I;
        end
    end
    
endmodule