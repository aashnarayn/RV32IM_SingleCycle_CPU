/*
* Module: EX_ALU_Input_Sel.v
* Description: Top-level Muxing unit for the ALU datapath. 
* 1. Implements Forwarding Muxes (3-to-1) to resolve Data Hazards.
* 2. Implements Source Muxes (2-to-1) to select between Reg/Forwarded data and PC/Imm.
* 3. Extracts correct Store Data for MEM stage (handling hazards for SW).
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

// --- Forwarding Mux (3-to-1) ---
module Forwarding_Mux #(parameter WIDTH = 32)(
    input  wire [WIDTH-1:0] Base_Data,    // Origin: ID_EX_Reg (ForwardSel = 00)
    input  wire [WIDTH-1:0] MEM_Data,     // Origin: EX_MEM_Reg (ForwardSel = 10)
    input  wire [WIDTH-1:0] WB_Data,      // Origin: MEM_WB_Reg (ForwardSel = 01)
    input  wire [1:0]       ForwardSel,   // Origin: EX_Forwarding_Unit
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
    input  wire [PC_WIDTH-1:0] PC_Data,    // Origin: ID_EX_Reg
    input  wire                ALUSrc1,    // Origin: ID_EX_Reg (Control Bundle)
    output reg  [WIDTH-1:0]    Op1         // Destination: ALU Operand 1
    );
    
    always @(*) begin
        Op1 = (ALUSrc1) ? PC_Data : Reg_Data; 
    end
endmodule

// --- Op2 Source Mux (2-to-1) ---
module Op2_Mux #(parameter WIDTH = 32)(
    input  wire [WIDTH-1:0]    Reg_Data,   // Origin: Forwarding Mux B
    input  wire [WIDTH-1:0]    Imm_Data,   // Origin: ID_EX_Reg
    input  wire                ALUSrc2,    // Origin: ID_EX_Reg (Control Bundle)
    output reg  [WIDTH-1:0]    Op2         // Destination: ALU Operand 2
    );
    
    always @(*) begin
        Op2 = (ALUSrc2) ? Imm_Data : Reg_Data;
    end
endmodule

module EX_ALU_Input_Sel #(
    parameter WIDTH    = 32,
    parameter PC_WIDTH = 32     
    )(
    // Data Inputs (Base Sources from ID/EX)
    input  wire [WIDTH-1:0]    EX_Rs1Data,      // Origin: ID_EX_Reg
    input  wire [WIDTH-1:0]    EX_Rs2Data,      // Origin: ID_EX_Reg
    input  wire [WIDTH-1:0]    EX_RdData_MAC,   // Origin: ID_EX_Reg (Rs3/Rd)
    input  wire [PC_WIDTH-1:0] EX_PC,           // Origin: ID_EX_Reg
    input  wire [WIDTH-1:0]    EX_Imm,          // Origin: ID_EX_Reg
    
    // Data Inputs (Forwarding Sources)
    input  wire [WIDTH-1:0]    MEM_ForwardData, // Origin: EX_MEM_Reg (ALU Result)
    input  wire [WIDTH-1:0]    WB_ForwardData,  // Origin: WriteBack_Mux 
    
    // Control Inputs
    input  wire                EX_ALUSrc1,      // Origin: ID_EX_Reg
    input  wire                EX_ALUSrc2,      // Origin: ID_EX_Reg
    input  wire [1:0]          EX_ForwardA,     // Origin: EX_Forwarding_Unit
    input  wire [1:0]          EX_ForwardB,     // Origin: EX_Forwarding_Unit
    input  wire [1:0]          EX_ForwardC,     // Origin: EX_Forwarding_Unit 

    // Outputs to ALU & Memory
    output wire [WIDTH-1:0]    EX_Op1,          // Destination: EX_ALU_RV32I / EX_ALU_RV32M
    output wire [WIDTH-1:0]    EX_Op2,          // Destination: EX_ALU_RV32I / EX_ALU_RV32M
    output wire [WIDTH-1:0]    EX_Op3,          // Destination: EX_MAC_Adder (Accumulator)
    output wire [WIDTH-1:0]    EX_StoreData     // Destination: MEM_Data_Memory (Bypasses EX_MEM_Reg)
    );
    
    wire [WIDTH-1:0] Forwarded_Rs1;
    wire [WIDTH-1:0] Forwarded_Rs2;
    wire [WIDTH-1:0] Forwarded_Rs3;     

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

    Forwarding_Mux #(.WIDTH(WIDTH)) FwdMuxC (
        .Base_Data (EX_RdData_MAC),
        .MEM_Data  (MEM_ForwardData),
        .WB_Data   (WB_ForwardData),
        .ForwardSel(EX_ForwardC),
        .Out_Data  (Forwarded_Rs3)
    );

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
        
    // CRITICAL: For Store instructions (SW), the data to be stored is Rs2.
    // We MUST use 'Forwarded_Rs2' here. If we used 'EX_Rs2Data', we would miss 
    // updates from previous instructions. If we used 'EX_Op2', we would get 
    // the Immediate offset instead of the data.
    assign EX_StoreData = Forwarded_Rs2; 
    assign EX_Op3 = Forwarded_Rs3;  // RdData protected from Stalls
    
endmodule