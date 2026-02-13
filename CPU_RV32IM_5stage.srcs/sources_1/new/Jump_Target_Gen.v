/*
* Module: Jump_Target_Gen.v
* Description: Computes the Jump target address for JALR by masking LSB
* and passing JAL target address as is.
* Updated for 5-stage pipeline.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

//(* dont_touch = "true" *)
module Jump_Target_Gen #(
    parameter WIDTH = 32,
    parameter PC_WIDTH = 32)
    (
    input wire [WIDTH-1:0]    EX_ALUResult,  // Origin: ALUSelect_Mux (EX Stage)
    input wire [3:0]          EX_TargetSel,  // Origin: ID/EX Pipeline Register (Control Bundle)
    input wire [PC_WIDTH-1:0] EX_PC_Plus_4,  // Origin: ID/EX Pipeline Register (Carried from IF)
    output reg [WIDTH-1:0]    EX_JumpTarget  // Destination: Next-PC Mux (IF Stage)
    );
    
    //0 and 1 notation for width-parametrized use
    localparam ZERO = {WIDTH{1'b0}};
    localparam ONE  = {{WIDTH-1{1'b0}}, 1'b1}; 
    
    always @(*) begin
        case(EX_TargetSel)
        `UJ_AL:  EX_JumpTarget = EX_ALUResult;            //passing result for JAL (PC+Imm calculated by ALU)
        `UJ_ALR: EX_JumpTarget = EX_ALUResult & ~ONE;     //masking LSB for JALR
        default: EX_JumpTarget = EX_PC_Plus_4;            //Default to next sequential instruction
        endcase
    end
    
endmodule