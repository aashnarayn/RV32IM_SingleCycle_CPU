/*
* Module: IF_PC_Next_Mux.v
* Description: Selects next Program Counter value based on jump/branch conditions 
* and control signals. Supports JAL, JALR, Branch and PC+4 updates.
* Updated 5-stage pipeline. 
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module IF_PC_Next_Mux #(
    parameter PC_WIDTH = 32,
    parameter WIDTH    = 32
    )(
    input  wire [PC_WIDTH-1:0] IF_PC_Plus_4,    // Origin: IF_PC_Incrementer
    input  wire [PC_WIDTH-1:0] ID_BranchTarget, // Origin: Top-Level Register (ID_BTarget_Reg)
    input  wire [WIDTH-1:0]    ID_JumpTarget,   // Origin: Top-Level Register (ID_JTarget_Reg)
    input  wire [1:0]          ID_PCSrc,        // Origin: Top-Level Register (ID_PCSrc_Reg)
    output reg  [PC_WIDTH-1:0] IF_PC_Next       // Destination: IF_Program_Counter
    );
    
    always @(*) begin
    
        case (ID_PCSrc)
            2'b00:   IF_PC_Next = IF_PC_Plus_4;    // Normal execution
            2'b01:   IF_PC_Next = ID_BranchTarget; // Branch Taken
            2'b10:   IF_PC_Next = ID_JumpTarget;   // Jump Taken (JAL/JALR)
            default: IF_PC_Next = IF_PC_Plus_4;    // Default fallback
            
        endcase
    
    end
    
endmodule