/*
* Module: PC_Next_Mux.v
* Description: Selects next Program Counter value based on jump/branch conditions 
* and control signals. Supports JAL, JALR, Branch and PC+4 updates.
* Updated 5-stage pipeline. //TODO: Check the execution stage of this module and review
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

//(* dont_touch = "true" *)
module PC_Next_Mux #(
    parameter PC_WIDTH = 32,
    parameter WIDTH    = 32
    )(
    input  wire [PC_WIDTH-1:0] IF_PC_Plus_4,    // Origin: PC_Incrementer (IF Stage)
    input  wire [PC_WIDTH-1:0] EX_BranchTarget, // Origin: Branch_Target_Gen (EX Stage)
    input  wire [WIDTH-1:0]    EX_JumpTarget,   // Origin: Jump_Target_Gen (EX Stage)
    input  wire [1:0]          EX_PCSrc,        // Origin: Target_Controller (EX Stage)
    output reg  [PC_WIDTH-1:0] IF_PC_Next       // Destination: Program_Counter (IF Stage)
    );
    
    always @(*) begin
    
        case (EX_PCSrc)
            2'b00:   IF_PC_Next = IF_PC_Plus_4;    // Normal execution
            2'b01:   IF_PC_Next = EX_BranchTarget; // Branch Taken
            2'b10:   IF_PC_Next = EX_JumpTarget;   // Jump Taken (JAL/JALR)
            default: IF_PC_Next = IF_PC_Plus_4;    // Default fallback
            
        endcase
    
    end
    
endmodule