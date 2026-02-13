/*
* Module: Forwarding_Unit.v
* Description: Detects data hazards for Rs1, Rs2, and the MAC Accumulator (Rs3)
* in the Execute stage to bypass the register file.
* Controls three forwarding muxes to handle EX-to-EX and MEM-to-EX forwarding.
* Stage: EX
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/
/*
* Module: Forwarding_Unit.v
* Description: Detects data hazards for Rs1, Rs2, and the MAC Accumulator (Rs3).
* Controls three forwarding muxes in the EX stage.
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh" 

module Forwarding_Unit #(
    parameter REG_COUNT = 32
    )(
    // Inputs from ID/EX Pipeline Register
    input  wire [$clog2(REG_COUNT)-1:0] EX_Rs1Addr,   // Origin: ID/EX Reg
    input  wire [$clog2(REG_COUNT)-1:0] EX_Rs2Addr,   // Origin: ID/EX Reg
    input  wire [$clog2(REG_COUNT)-1:0] EX_Rs3Addr,   // Origin: ID/EX Reg (Accumulator Address)
    input  wire                         EX_MACSel,    // Origin: ID/EX Reg (Is current instruction MAC?)
    
    // Inputs from EX/MEM Pipeline Register (Forwarding from MEM stage)
    input  wire                         MEM_RegWrite, // Origin: EX/MEM Reg
    input  wire [$clog2(REG_COUNT)-1:0] MEM_RdAddr,   // Origin: EX/MEM Reg
    
    // Inputs from MEM/WB Pipeline Register (Forwarding from WB stage)
    input  wire                         WB_RegWrite,  // Origin: MEM/WB Reg
    input  wire [$clog2(REG_COUNT)-1:0] WB_RdAddr,    // Origin: MEM/WB Reg
    
    // Outputs to Forwarding Muxes in EX Stage
    output reg  [1:0]                   EX_ForwardA,  // Destination: Mux for Rs1
    output reg  [1:0]                   EX_ForwardB,  // Destination: Mux for Rs2
    output reg  [1:0]                   EX_ForwardC   // Destination: Mux for Accumulator (Rs3/Rd)
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