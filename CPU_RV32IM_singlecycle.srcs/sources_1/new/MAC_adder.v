
/*
* Module: MAC_Adder.v
* Description: Dedicated adder for the MAC operation. 
* Calculates: Result = Product + Accumulator_Value
*/
`timescale 1ns / 1ps

module MAC_Adder #(parameter WIDTH = 32)(
    input  wire [WIDTH-1:0] Product,         // Result from ALU_RV32M (A * B)
    input  wire [WIDTH-1:0] Accumulator_Val, // The old value of the register (ReadData)
    output wire [WIDTH-1:0] MAC_Result       // The final result to write back
);

    assign MAC_Result = Product + Accumulator_Val;

endmodule
