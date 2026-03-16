/*
* Module: ID_Jump_Target_Gen.v
* Description: Computes the Jump target addresses for JAL and JALR.
* JALR masks the LSB. Extracted from the main ALU to sit in the 
* Decode stage. Dedicated lightweight adder to resolve jumps fast.
* - Implements Carry-Chain Truncation (Limits adders to ACTIVE_BITS)
* - Implements Late-Muxing (Adders run in parallel with decode)
* - Forces LSB to 0 for JALR per RISC-V Spec.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/
/*
* Module: ID_Jump_Target_Gen.v
* Description: Generates target addresses for JAL and JALR.
* 100MHz TIMING OPTIMIZED: 

*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module ID_Jump_Target_Gen #(
    parameter WIDTH = 32,
    parameter PC_WIDTH = 32,
    parameter IMEM_DEPTH = 256
)(
    // Computing all jump targets in ID stage
    input wire [PC_WIDTH-1:0] ID_PC,         // Origin: IF_ID_Reg (ID Stage)
    input wire [WIDTH-1:0]    ID_Rs1Data,    // Origin: Top-Level Fast-Path Mux (ID_Rs1_Fast)
    input wire [WIDTH-1:0]    ID_Immediate,  // Origin: ID_Imm_Gen (ID Stage)
    
    input  wire [3:0]          ID_TargetSel,  // Origin: ID_Control_Unit
    input  wire [PC_WIDTH-1:0] ID_PC_Plus_4,  // Origin: IF_ID_Reg (unused wire)
    output wire [WIDTH-1:0]    ID_JumpTarget  // Destination: Top-Level Register (ID_JTarget_Reg)
);

    // =========================================================================
    // OPTIMIZATION 1: Carry-Chain Truncation
    // =========================================================================
    // We calculate active bits based on IMEM size for parameterized use
    localparam ACTIVE_BITS = $clog2(IMEM_DEPTH * 4);

    // Run both additions simultaneously so we don't wait for the mux
    wire [ACTIVE_BITS-1:0] jal_target  = ID_PC[ACTIVE_BITS-1:0] + ID_Immediate[ACTIVE_BITS-1:0];
    
    // RISC-V Spec: JALR target MUST have its least-significant bit set to 0.
    wire [ACTIVE_BITS-1:0] jalr_target = (ID_Rs1Data[ACTIVE_BITS-1:0] + ID_Immediate[ACTIVE_BITS-1:0]) & ~((1<<1)-1);   // Dynamic ~1 masking

    // =========================================================================
    // OPTIMIZATION 2: Late Muxing
    // =========================================================================
    // We select the result AFTER the math is done. This hides the muxing delay
    // behind the adder's propagation delay.
    wire [ACTIVE_BITS-1:0] active_target = (ID_TargetSel == `UJ_ALR) ? jalr_target : jal_target;

    // =========================================================================
    // OPTIMIZATION 3: Dead Logic Padding
    // =========================================================================
    // We hardwire the upper 20 bits to zero. This explicitly tells Vivado's 
    // timing engine: "Do not route or optimize the upper bits, they are dead."
    assign ID_JumpTarget = { {(PC_WIDTH - ACTIVE_BITS){1'b0}}, active_target };

    // =========================================================================
    // Linter Violation Avoidance ("Bit Sink")
    // =========================================================================
    // Explicitly sink the upper bits that are optimized away to prevent 
    // unused signal warnings in Verilator and Vivado.
    
    wire _unused_ok = &{
        1'b0,
        ID_PC[PC_WIDTH-1 : ACTIVE_BITS],
        ID_Rs1Data[WIDTH-1 : ACTIVE_BITS],
        ID_Immediate[WIDTH-1 : ACTIVE_BITS],
        ID_PC_Plus_4[PC_WIDTH-1:0] // Entirely unused in Target Gen 
    };

endmodule