/*
* Module: ALUSelect_Mux.v
* Description: Final multiplexer for the Execute stage. Selects between 
* Integer ALU, M-Extension (Mul/Div), and MAC Adder results.
* Stage: EX
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps

module ALUSelect_Mux #(
    parameter WIDTH = 32
    )(
    // Inputs from various execution units
    input  wire [WIDTH-1:0] EX_ALUResult_I, // Origin: ALU_RV32I
    input  wire [WIDTH-1:0] EX_ALUResult_M, // Origin: ALU_RV32M (Product or Div Result)
    input  wire [WIDTH-1:0] EX_MACResult,   // Origin: MAC_Adder
    
    // Condition Flags
    input  wire             EX_Zero_I,      // Origin: ALU_RV32I
    input  wire             EX_Zero_M,      // Origin: ALU_RV32M
    
    // Control Signals
    input  wire             EX_MDSel,       // Origin: ID/EX Pipeline Register
    input  wire             EX_MACSel,      // Origin: ID/EX Pipeline Register
    
    // Final Outputs
    output reg  [WIDTH-1:0] EX_ALUResult,   // Destination: EX/MEM Pipeline Register & Forwarding Unit
    output reg              EX_Zero         // Destination: Target_Controller
    );
    
    always @(*) begin
        // Priority 1: MAC Operation (Highest Specificity)
        if (EX_MACSel) begin
            EX_ALUResult = EX_MACResult;
            EX_Zero      = (EX_MACResult == {WIDTH{1'b0}}); // MACs don't usually branch, but for consistency
        end 
        // Priority 2: Standard M-Extension (Mul/Div)
        else if (EX_MDSel) begin
            EX_ALUResult = EX_ALUResult_M;
            EX_Zero      = EX_Zero_M;
        end 
        // Priority 3: Standard Integer ALU (Includes Branches)
        else begin
            EX_ALUResult = EX_ALUResult_I;
            EX_Zero      = EX_Zero_I;
        end
    end
    
endmodule