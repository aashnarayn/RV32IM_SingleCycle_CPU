/*
* Module: Branch_Target_Gen.v
* Description: Computes the branch target address by adding 
* the already-aligned Immediate (from Imm_Gen) 
* to the current PC.
* Stage: EX
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps


//top level module for Branch Target Calculation
//(* dont_touch = "true" *)
module Branch_Target_Gen #(
    parameter WIDTH = 32,       //NOTE: PC_WIDTH AND WIDTH SHOULD BE THE SAME
    parameter PC_WIDTH = 32 
    )(
    input  wire [WIDTH-1:0]    EX_Immediate,    // Origin: ID/EX Pipeline Register
    input  wire [PC_WIDTH-1:0] EX_PC,           // Origin: ID/EX Pipeline Register
    output reg  [PC_WIDTH-1:0] EX_BranchTarget  // Destination: Next-PC Mux (IF Stage) via Branch Control Logic
    );
    
    always @(*) begin
        EX_BranchTarget = EX_PC + EX_Immediate;
    end
    
endmodule