/*
* Module: EX_Forwarding_Unit.v
* Description: Detects data hazards for Rs1, Rs2, and the MAC Accumulator (Rs3).
* Controls three forwarding muxes in the EX stage.
* This unit exclusively handles ALU and Memory dependencies. Branch dependencies 
* are entirely isolated to the Decode stage hazard logic, keeping this 
* critical path lean for 100MHz routing.
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh" 

module EX_Forwarding_Unit #(
    parameter REG_COUNT = 32
    )(
    // Inputs from ID/EX Pipeline Register
    input  wire [$clog2(REG_COUNT)-1:0] EX_Rs1Addr,   // Origin: ID_EX_Reg
    input  wire [$clog2(REG_COUNT)-1:0] EX_Rs2Addr,   // Origin: ID_EX_Reg
    input  wire [$clog2(REG_COUNT)-1:0] EX_Rs3Addr,   // Origin: ID_EX_Reg
    input  wire                         EX_MACSel,    // Origin: ID_EX_Reg
    
    // Inputs from EX/MEM Pipeline Register (Forwarding from MEM stage)
    input  wire                         MEM_RegWrite, // Origin: EX_MEM_Reg
    input  wire [$clog2(REG_COUNT)-1:0] MEM_RdAddr,   // Origin: EX_MEM_Reg
    
    // Inputs from MEM/WB Pipeline Register (Forwarding from WB stage)
    input  wire                         WB_RegWrite,  // Origin: MEM_WB_Reg
    input  wire [$clog2(REG_COUNT)-1:0] WB_RdAddr,    // Origin: MEM_WB_Reg
    
    // Outputs to Forwarding Muxes in EX Stage
    output reg  [1:0]                   EX_ForwardA,  // Destination: EX_ALU_Input_Sel
    output reg  [1:0]                   EX_ForwardB,  // Destination: EX_ALU_Input_Sel
    output reg  [1:0]                   EX_ForwardC   // Destination: EX_ALU_Input_Sel
    );

    always @(*) begin
        // Default: Use value from Register File
        EX_ForwardA = `FWD_NO_FORWARD;
        EX_ForwardB = `FWD_NO_FORWARD;
        EX_ForwardC = `FWD_NO_FORWARD;

        // =========================================================
        // 1. EX HAZARD (Forward from MEM Stage) - Priority 1
        // =========================================================
        
        // Rs1 Forwarding
        if (MEM_RegWrite && (MEM_RdAddr != 0) && (MEM_RdAddr == EX_Rs1Addr)) begin
            EX_ForwardA = `FWD_FROM_MEM;
        end
        
        // Rs2 Forwarding
        if (MEM_RegWrite && (MEM_RdAddr != 0) && (MEM_RdAddr == EX_Rs2Addr)) begin
            EX_ForwardB = `FWD_FROM_MEM;
        end

        // Rs3 (Accumulator) Forwarding
        if (EX_MACSel && MEM_RegWrite && (MEM_RdAddr != 0) && (MEM_RdAddr == EX_Rs3Addr)) begin
            EX_ForwardC = `FWD_FROM_MEM;
        end
        
        // =========================================================
        // 2. MEM HAZARD (Forward from WB Stage) - Priority 2
        // =========================================================
        
        // Rs1 Forwarding
        if (WB_RegWrite && (WB_RdAddr != 0) && (WB_RdAddr == EX_Rs1Addr) && 
        !(MEM_RegWrite && (MEM_RdAddr != 0) && (MEM_RdAddr == EX_Rs1Addr))) begin
            EX_ForwardA = `FWD_FROM_WB;
        end
        
        // Rs2 Forwarding
        if (WB_RegWrite && (WB_RdAddr != 0) && (WB_RdAddr == EX_Rs2Addr) && 
        !(MEM_RegWrite && (MEM_RdAddr != 0) && (MEM_RdAddr == EX_Rs2Addr))) begin
            EX_ForwardB = `FWD_FROM_WB;
        end

        // Rs3 (Accumulator) Forwarding
        if (EX_MACSel && WB_RegWrite && (WB_RdAddr != 0) && (WB_RdAddr == EX_Rs3Addr) && 
        !(MEM_RegWrite && (MEM_RdAddr != 0) && (MEM_RdAddr == EX_Rs3Addr))) begin
            EX_ForwardC = `FWD_FROM_WB;
        end
    end

endmodule