/*
* Module: ID_Hazard_Detector.v
* Description: Detects Load-Use hazards (Stall) and Control Hazards (Flush).
* Implements "Always Not Taken" static branch prediction recovery.
* By enforcing a 2-cycle stall (Option B) for early branches, we sacrifice 
* 1 cycle of IPC to completely isolate the ID critical path, guaranteeing 
* maximum operating frequency on standard FPGA logic.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module ID_Hazard_Detector #(
    parameter REG_COUNT = 32
    )(
    // --- Inputs from ID Stage (Current Instruction) ---
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs1Addr,   // Origin: IF_Instruction_Memory (Raw BRAM output IF_Instr bypass)
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs2Addr,   // Origin: IF_Instruction_Memory (Raw BRAM output IF_Instr bypass)
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs3Addr,   // Origin: IF_Instruction_Memory (Raw BRAM output IF_Instr bypass) 
    input  wire                         ID_MACSel,    // Origin: Top-Level Logic (Raw hz_MACSel pre-flush decode)
    input  wire [6:0]                   ID_Opcode,    // Origin: IF_Instruction_Memory (Raw BRAM output IF_Instr bypass) 
    
    // Branch decisions originate in ID
    input  wire [1:0]                   ID_PCSrc,     // Origin: ID_Target_Controller 

    // --- Inputs from ID/EX Pipeline Register (Previous Instruction) ---
    input  wire                         EX_MemRead,   // Origin: ID_EX_Reg 
    input  wire [$clog2(REG_COUNT)-1:0] EX_RdAddr,    // Origin: ID_EX_Reg 
    input  wire                         EX_RegWrite,  // Origin: ID_EX_Reg 
    
    // --- Inputs from EX Stage ---
    input  wire                         EX_ALU_Stall, // Origin: EX_ALU_RV32M 

    // --- Inputs from MEM Stage (Branch Dependency Check) ---
    input  wire                         MEM_RegWrite, // Origin: EX_MEM_Reg 
    input  wire [$clog2(REG_COUNT)-1:0] MEM_RdAddr,   // Origin: EX_MEM_Reg 
    
    // --- Outputs to Control Pipeline ---
    output reg                          PCWrite,      // Destination: IF_Program_Counter
    output reg                          IF_ID_Write,  // Destination: IF_ID_Reg       
    (* max_fanout = 20 *) output reg    ID_EX_Write,  // Destination: ID_EX_Reg       
    output reg                          IF_ID_Flush,  // Destination: IF_ID_Reg       
    (* max_fanout = 20 *) output reg    ID_EX_Flush   // Destination: ID_EX_Reg       
    );

    always @(*) begin
        // ---------------------------------------------------------
        // Default: Standard operation
        // ---------------------------------------------------------
        PCWrite     = 1'b1; 
        IF_ID_Write = 1'b1; 
        ID_EX_Write = 1'b1; 
        IF_ID_Flush = 1'b0; 
        ID_EX_Flush = 1'b0; 

        // ---------------------------------------------------------
        // PRIORITY 1: ALU MULTI-CYCLE STALL
        // ---------------------------------------------------------
        if (EX_ALU_Stall) begin
            PCWrite     = 1'b0; 
            IF_ID_Write = 1'b0; 
            ID_EX_Write = 1'b0; 
        end
        
        // ---------------------------------------------------------
        // PRIORITY 2: LOAD-USE HAZARD (Standard ALU Ops)
        // ---------------------------------------------------------
        else if (EX_MemRead && (EX_RdAddr != 0) && 
                ((EX_RdAddr == ID_Rs1Addr) || (EX_RdAddr == ID_Rs2Addr) ||
                (ID_MACSel && (EX_RdAddr == ID_Rs3Addr)))) begin        
            PCWrite     = 1'b0; 
            IF_ID_Write = 1'b0; 
            ID_EX_Flush = 1'b1; 
        end

        // ---------------------------------------------------------
        // PRIORITY 3: EARLY BRANCH DATA HAZARDS 
        // ---------------------------------------------------------
        // 2-cycle stall implemented. If data is computing in EX or sitting 
        // in MEM, we stall ID until it hits WB for internal Register File forwarding.
        else if ((ID_Opcode == `OPCODE_BRANCH || ID_Opcode == `OPCODE_JALR) &&
                 ( (EX_RegWrite && EX_RdAddr != 0 && (EX_RdAddr == ID_Rs1Addr || EX_RdAddr == ID_Rs2Addr)) || 
                   (MEM_RegWrite && MEM_RdAddr != 0 && (MEM_RdAddr == ID_Rs1Addr || MEM_RdAddr == ID_Rs2Addr)) )) begin
            
            PCWrite     = 1'b0; 
            IF_ID_Write = 1'b0; 
            ID_EX_Flush = 1'b1; 
        end

        // ---------------------------------------------------------
        // PRIORITY 4: CONTROL HAZARD (Branch Taken in ID Stage)
        // ---------------------------------------------------------
        // Only the instruction in IF is wrong. We do NOT flush ID_EX.
        else if (ID_PCSrc != 2'b00) begin
            IF_ID_Flush = 1'b1; 
        end
    end

endmodule