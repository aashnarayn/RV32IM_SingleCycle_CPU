/*
* Module: PC_Adder.v
* Description: Computes the address of the next sequential instruction 
* by adding 4 to the current Program Counter (PC).
* Stage - IF
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

//(* dont_touch = "true" *)
module PC_Incrementer #(
    parameter PC_WIDTH = 32,
    parameter PC_STEP  = 4
    )(
    input  wire [PC_WIDTH-1:0] IF_PC,        // Origin: Program Counter (IF Stage)
    output reg  [PC_WIDTH-1:0] IF_PC_Plus_4  // Destination: Next-PC Mux (IF) & IF/ID Pipeline Register
    );
    
    always @(*) begin
        IF_PC_Plus_4 = IF_PC + PC_STEP;    //incrementing PC with step size
    end
    
endmodule