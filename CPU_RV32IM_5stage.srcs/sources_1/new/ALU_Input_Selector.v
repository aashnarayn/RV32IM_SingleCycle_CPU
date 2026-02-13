/*
* Module: ALU_input_selector.v
* Description: Selects 32 bit inputs from Registers, Program Counter 
* and Immediate Generator according to control signal inputs 
* to feed into ALU. Wires RdData directly to ALU for MAC operations.
* Updated for EX stage signal naming in 5-stage pipeline with Forwarding hooks.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
    

//MUX for Operand 1 of ALU
module Op1_Mux #(
    parameter WIDTH    = 32,    
    parameter PC_WIDTH = 32     
    )(
    input wire [WIDTH-1:0]    EX_Rs1Data, // Origin: Output of Forwarding Unit Mux A (Selects ID/EX, EX/MEM, or MEM/WB)
    input wire [PC_WIDTH-1:0] EX_PC,      // Origin: ID/EX Pipeline Register
    input wire                EX_ALUSrc1, // Origin: ID/EX Pipeline Register (Control Bundle)
    output reg [WIDTH-1:0]    EX_Op1
    );
    always @(*) begin
        EX_Op1 = (EX_ALUSrc1) ? EX_PC : EX_Rs1Data;     //PC used by LUI, AUIPC and JAL
    end
endmodule

//MUX for Operand 2 of ALU
module Op2_Mux #(parameter WIDTH = 32)(
    input wire [WIDTH-1:0] EX_Rs2Data, // Origin: Output of Forwarding Unit Mux B (Selects ID/EX, EX/MEM, or MEM/WB)
    input wire [WIDTH-1:0] EX_Imm,     // Origin: ID/EX Pipeline Register
    input wire             EX_ALUSrc2, // Origin: ID/EX Pipeline Register (Control Bundle)
    output reg [WIDTH-1:0] EX_Op2
    );
    always @(*) begin
        EX_Op2 = (EX_ALUSrc2) ? EX_Imm : EX_Rs2Data;    //Imm used by I,U-type, LW,SW etc
    end
endmodule

//Top level selector module for both Operands of ALU
//(* dont_touch = "true" *)
module ALU_Input_Selector  #(
    parameter WIDTH    = 32,
    parameter PC_WIDTH = 32     
    )(
    input  wire [WIDTH-1:0]    EX_Rs1Data,     // Origin: Forwarding Unit Mux A Output
    input  wire [WIDTH-1:0]    EX_Rs2Data,     // Origin: Forwarding Unit Mux B Output
    input  wire [WIDTH-1:0]    EX_RdData_MAC,  // Origin: ID/EX Pipeline Register (Future: Forwarding Unit Mux C)
    input  wire [PC_WIDTH-1:0] EX_PC,          // Origin: ID/EX Pipeline Register
    input  wire [WIDTH-1:0]    EX_Imm,         // Origin: ID/EX Pipeline Register
    input  wire                EX_ALUSrc1,     // Origin: ID/EX Pipeline Register
    input  wire                EX_ALUSrc2,     // Origin: ID/EX Pipeline Register
    output wire [WIDTH-1:0]    EX_Op1, 
    output wire [WIDTH-1:0]    EX_Op2, 
    output wire [WIDTH-1:0]    EX_Op3
    );
    
    Op1_Mux #(.WIDTH(WIDTH), .PC_WIDTH(PC_WIDTH)) Mux1(
        .EX_Rs1Data(EX_Rs1Data),
        .EX_PC(EX_PC),
        .EX_ALUSrc1(EX_ALUSrc1),
        .EX_Op1(EX_Op1)    
        );
        
    Op2_Mux #(.WIDTH(WIDTH)) Mux2(
        .EX_Rs2Data(EX_Rs2Data),
        .EX_Imm(EX_Imm),
        .EX_ALUSrc2(EX_ALUSrc2),
        .EX_Op2(EX_Op2)    
        );
        
    assign EX_Op3 = EX_RdData_MAC; // Origin: ID/EX Pipeline Register -> Future MAC Adder
    
endmodule