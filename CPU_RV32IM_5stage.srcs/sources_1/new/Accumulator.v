/*
* Module: Accumulator.v
* Description: Dedicated 32-bit adder for Multiply-Accumulate operations. 
* Calculates: Result = (Rs1 * Rs2) + Rs3_Accumulator.
* Stage: EX
* Author: Teammate (Integrated by Aashrith S Narayn)
* Date: 14/02/2026
*/

`timescale 1ns / 1ps

module Accumulator #(
    parameter WIDTH = 32
    )(
    input  wire [WIDTH-1:0] EX_ALUResult_M,  // Origin: ALU_RV32M (Output of Multiplier)
    input  wire [WIDTH-1:0] EX_RdData,       // Origin: Forwarding Mux for Rs3/RdData (Accumulator)
    output wire [WIDTH-1:0] MAC_Result       // Destination: ALUSelect_Mux (EX Stage)
    );

    // Purely combinational addition
    assign MAC_Result = EX_ALUResult_M + EX_RdData;

endmodule