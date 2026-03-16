/*
* Module: EX_Accumulator.v
* Description: Dedicated 32-bit adder for Multiply-Accumulate operations. 
* Calculates: Result = (Rs1 * Rs2) + Rs3_Accumulator.
* Timing is naturally safe because EX_ALUResult_M is pipelined. The hazard 
* unit stalls the pipeline during the first cycle of multiplication, ensuring
* the addition only completes when the DSP product is stable.
* Author: Aashrith S Narayn 
* Date: 14/02/2026
*/

`timescale 1ns / 1ps

module EX_Accumulator #(
    parameter WIDTH = 32
    )(
    input  wire [WIDTH-1:0] EX_ALUResult_M,  // Origin: EX_ALU_RV32M (Output of Multiplier)
    input  wire [WIDTH-1:0] EX_RdData,       // Origin: EX_ALU_Input_Sel (Port: EX_Op3)
    output wire [WIDTH-1:0] MAC_Result       // Destination: EX_ALUSelect_Mux 
    );

    // Purely combinational addition
    assign MAC_Result = EX_ALUResult_M + EX_RdData;

endmodule