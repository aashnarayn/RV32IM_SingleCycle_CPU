/*
* Module: Hazard_Detection_Unit.v
* Description: Detects Load-Use hazards (Stall) and Control Hazards (Flush).
* Implements "Always Not Taken" static branch prediction recovery.
* Updated for ID stage signal naming in 5-stage pipeline.
* Stage: ID
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module Hazard_Detection_Unit #(
    parameter REG_COUNT = 32
    )(
    // --- Inputs from ID Stage (Current Instruction being decoded) ---
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs1Addr,   // Origin: Instruction_Splitter (ID Stage)
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs2Addr,   // Origin: Instruction_Splitter (ID Stage)
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs3Addr,   // Origin: Instruction_Splitter (MAC Accumulator Source)
    input  wire                         ID_MACSel,    // Origin: Control_Unit (Current instruction is MAC)
    
    // --- Inputs from ID/EX Pipeline Register (Previous Instruction) ---
    input  wire                         EX_MemRead,   // Origin: ID_EX_reg (1 = Instruction in EX is a Load)
    input  wire [$clog2(REG_COUNT)-1:0] EX_RdAddr,    // Origin: ID_EX_reg (Check the destination register of instruction in EX )
    
    // --- Inputs from EX Stage (Branch Decision) ---
    input  wire [1:0]                   EX_PCSrc,     // Origin: Branch_Unit (EX Stage Logic) (01=Branch Taken, 10=Jump Taken, 00=Next)
    input  wire                         EX_ALU_Stall, // Origin: ALU_RV32M (To stall for a division operation)
    
    // --- Outputs to Control Pipeline ---
    output reg                          PC_Write,     // Destination: Program_Counter (Enable Signal)    1=Update PC, 0=Stall (Freeze PC)
    output reg                          IF_ID_Write,  // Destination: IF_ID_reg       (Write Enable)     1=Update IF/ID, 0=Stall (Freeze Instruction)
    output reg                          ID_EX_Write,  // Destination: ID_EX_reg       (Write Enable)     1=Update ID/EX, 0=Stall (Freeze Instruction)
    output reg                          IF_ID_Flush,  // Destination: IF_ID_reg       (Sync Reset/Flush) 1=Flush IF/ID (Kill instruction in ID)
    output reg                          ID_EX_Flush   // Destination: ID_EX_reg       (Sync Reset/Flush) 1=Flush ID/EX (Kill instruction in EX)
    );

    always @(*) begin
        // ---------------------------------------------------------
        // Default Behavior: "Green Light"
        // ---------------------------------------------------------
        PC_Write    = 1'b1; // Keep fetching
        IF_ID_Write = 1'b1; // Keep decoding
        ID_EX_Write = 1'b1; // Keep executing
        IF_ID_Flush = 1'b0; 
        ID_EX_Flush = 1'b0; 

        // ---------------------------------------------------------
        // PRIORITY 1: ALU MULTI-CYCLE STALL
        // ---------------------------------------------------------
        // If the ALU says "Wait!", we freeze everything in place.
        if (EX_ALU_Stall) begin
            PC_Write    = 1'b0; // Stop fetching
            IF_ID_Write = 1'b0; // Stop decoding
            ID_EX_Write = 1'b0; // Stop executing (Hold current inputs for ALU)
            // No Flush: We want to resume exactly where we left off.
        end
        
        // ---------------------------------------------------------
        // PRIORITY 2: CONTROL HAZARD (Branch Taken)
        // ---------------------------------------------------------
        // If Branch is taken, the instructions in IF and ID are wrong.
        else if (EX_PCSrc != 2'b00) begin
            IF_ID_Flush = 1'b1; // Kill instruction in ID
            ID_EX_Flush = 1'b1; // Kill instruction entering EX
            // PC_Write remains 1 to allow Jump to Target.
        end
        
        // ---------------------------------------------------------
        // PRIORITY 3: LOAD-USE HAZARD
        // ---------------------------------------------------------
        // If we need data that is currently being loaded...
        else if (EX_MemRead && (EX_RdAddr != 0) && 
                ((EX_RdAddr == ID_Rs1Addr) || (EX_RdAddr == ID_Rs2Addr) ||
                (ID_MACSel && (EX_RdAddr == ID_Rs3Addr)))) begin        // Adding a check on accumulator source for MAC
            PC_Write    = 1'b0; // Freeze PC
            IF_ID_Write = 1'b0; // Freeze IF/ID
            ID_EX_Flush = 1'b1; // Send Bubble to EX
            // ID_EX_Write remains 1 to allow the Bubble to enter EX.
        end
    end

endmodule