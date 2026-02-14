/*
* Module: ALU_Input_Selector.v
* Description: Top-level Muxing unit for the ALU. 
* 1. Implements Forwarding Muxes (3-to-1) to resolve Data Hazards.
* 2. Implements Source Muxes (2-to-1) to select between Reg/Forwarded data and PC/Imm.
* 3. Extracts correct Store Data for MEM stage (handling hazards for SW).
* Stage: EX
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

// --- Forwarding Mux (3-to-1) ---
module Forwarding_Mux #(parameter WIDTH = 32)(
    input  wire [WIDTH-1:0] Base_Data,    // Origin: ID/EX Reg (ForwardSel = 00)
    input  wire [WIDTH-1:0] MEM_Data,     // Origin: EX/MEM Reg (ForwardSel = 10)
    input  wire [WIDTH-1:0] WB_Data,      // Origin: MEM/WB Reg (ForwardSel = 01)
    input  wire [1:0]       ForwardSel,   // Origin: Forwarding Unit
    output reg  [WIDTH-1:0] Out_Data      // Destination: Source Muxes
    );
    
    always @(*) begin
        case(ForwardSel)
            `FWD_NO_FORWARD: Out_Data = Base_Data;
            `FWD_FROM_MEM:   Out_Data = MEM_Data;
            `FWD_FROM_WB:    Out_Data = WB_Data;
            default:         Out_Data = Base_Data;
        endcase
    end
endmodule


// --- Op1 Source Mux (2-to-1) ---
module Op1_Mux #(parameter WIDTH = 32, parameter PC_WIDTH = 32)(
    input  wire [WIDTH-1:0]    Reg_Data,   // Origin: Forwarding Mux A
    input  wire [PC_WIDTH-1:0] PC_Data,    // Origin: ID/EX Reg
    input  wire                ALUSrc1,    // Origin: Control Unit
    output reg  [WIDTH-1:0]    Op1         // Destination: ALU Operand 1
    );
    
    always @(*) begin
        // If ALUSrc1 is 1, use PC (JAL, AUIPC). Else use Register (Forwarded).
        Op1 = (ALUSrc1) ? PC_Data : Reg_Data; 
    end
endmodule


// --- Op2 Source Mux (2-to-1) ---
module Op2_Mux #(parameter WIDTH = 32)(
    input  wire [WIDTH-1:0]    Reg_Data,   // Origin: Forwarding Mux B
    input  wire [WIDTH-1:0]    Imm_Data,   // Origin: ID/EX Reg
    input  wire                ALUSrc2,    // Origin: Control Unit
    output reg  [WIDTH-1:0]    Op2         // Destination: ALU Operand 2
    );
    
    always @(*) begin
        // If ALUSrc2 is 1, use Imm (ADDI, LW, SW). Else use Register (Forwarded).
        Op2 = (ALUSrc2) ? Imm_Data : Reg_Data;
    end
endmodule

//(* dont_touch = "true" *)
module ALU_Input_Selector #(
    parameter WIDTH    = 32,
    parameter PC_WIDTH = 32     
    )(
    // Data Inputs (Base Sources from ID/EX)
    input  wire [WIDTH-1:0]    EX_Rs1Data,      // Origin: ID/EX Pipeline Register
    input  wire [WIDTH-1:0]    EX_Rs2Data,      // Origin: ID/EX Pipeline Register
    input  wire [WIDTH-1:0]    EX_RdData_MAC,   // Origin: ID/EX Pipeline Register (Rs3/Rd)
    input  wire [PC_WIDTH-1:0] EX_PC,           // Origin: ID/EX Pipeline Register
    input  wire [WIDTH-1:0]    EX_Imm,          // Origin: ID/EX Pipeline Register
    
    // Data Inputs (Forwarding Sources)
    input  wire [WIDTH-1:0]    MEM_ForwardData, // Origin: EX/MEM_reg (The ALU Result from previous instr)
    input  wire [WIDTH-1:0]    WB_ForwardData,  // Origin: WriteBack_Mux (The final WriteBack data)
    
    // Control Inputs
    input  wire                EX_ALUSrc1,      // Origin: ID/EX Pipeline Register
    input  wire                EX_ALUSrc2,      // Origin: ID/EX Pipeline Register
    input  wire [1:0]          EX_ForwardA,     // Origin: Forwarding Unit
    input  wire [1:0]          EX_ForwardB,     // Origin: Forwarding Unit
    input  wire [1:0]          EX_ForwardC,     // Origin: Forwarding Unit 

    // Outputs to ALU & Memory
    output wire [WIDTH-1:0]    EX_Op1,          // Destination: ALU_RV32I / ALU_RV32M
    output wire [WIDTH-1:0]    EX_Op2,          // Destination: ALU_RV32I / ALU_RV32M
    output wire [WIDTH-1:0]    EX_Op3,          // Destination: MAC Unit (Accumulator)
    output wire [WIDTH-1:0]    EX_StoreData     // Destination: EX_MEM_reg (Data input for Data Memory)
    );
    
    // Internal wires to hold the result of the Forwarding Stage
    wire [WIDTH-1:0] Forwarded_Rs1;
    wire [WIDTH-1:0] Forwarded_Rs2;
    wire [WIDTH-1:0] Forwarded_Rs3;     // RdData for MAC

    // 1. Forwarding Logic (Solves Data Hazards)
    Forwarding_Mux #(.WIDTH(WIDTH)) FwdMuxA (
        .Base_Data (EX_Rs1Data),
        .MEM_Data  (MEM_ForwardData),
        .WB_Data   (WB_ForwardData),
        .ForwardSel(EX_ForwardA),
        .Out_Data  (Forwarded_Rs1)
    );
    
    Forwarding_Mux #(.WIDTH(WIDTH)) FwdMuxB (
        .Base_Data (EX_Rs2Data),
        .MEM_Data  (MEM_ForwardData),
        .WB_Data   (WB_ForwardData),
        .ForwardSel(EX_ForwardB),
        .Out_Data  (Forwarded_Rs2)
    );

    // Additional Forwarding Mux for the Accumulator (Rs3)
    Forwarding_Mux #(.WIDTH(WIDTH)) FwdMuxC (
        .Base_Data (EX_RdData_MAC),
        .MEM_Data  (MEM_ForwardData),
        .WB_Data   (WB_ForwardData),
        .ForwardSel(EX_ForwardC),
        .Out_Data  (Forwarded_Rs3)
    );

    // 2. Source Selection Logic (Selects between Reg/Fwd and PC/Imm)
    Op1_Mux #(.WIDTH(WIDTH), .PC_WIDTH(PC_WIDTH)) SourceMux1(
        .Reg_Data(Forwarded_Rs1),
        .PC_Data (EX_PC),
        .ALUSrc1 (EX_ALUSrc1),
        .Op1     (EX_Op1)    
    );
        
    Op2_Mux #(.WIDTH(WIDTH)) SourceMux2(
        .Reg_Data(Forwarded_Rs2),
        .Imm_Data(EX_Imm),
        .ALUSrc2 (EX_ALUSrc2),
        .Op2     (EX_Op2)    
    );
        
    // 3. Final Assignments + Passthroughs
    // CRITICAL: For Store instructions (SW), the data to be stored is Rs2.
    // We MUST use 'Forwarded_Rs2' here. If we used 'EX_Rs2Data', we would miss 
    // updates from previous instructions. If we used 'EX_Op2', we would get 
    // the Immediate offset instead of the data.
    assign EX_StoreData = Forwarded_Rs2; 
    
    // Passthrough for Accumulator
    assign EX_Op3 = Forwarded_Rs3;  // RdData protected from Stalls
    
endmodule