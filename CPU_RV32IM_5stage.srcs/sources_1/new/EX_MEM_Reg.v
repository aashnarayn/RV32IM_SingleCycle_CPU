/*
* Module: EX_MEM_reg.v
* Description: Pipeline register between Execute (EX) and 
* Memory (MEM) stages. 
* Carries Memory Access signals, Write-Back control, and ALU results.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module EX_MEM_reg #(
    parameter WIDTH       = 32,
    parameter PC_WIDTH    = 32,
    parameter REG_COUNT   = 32
    )(
    input  wire             CPU_clk,
    input  wire             CPU_rst_n,
    
    // --- Control Signals (Input from EX Stage) ---
    // Memory Control
    input  wire             EX_MemRead,      // Origin: ID_EX_reg
    input  wire             EX_MemWrite,     // Origin: ID_EX_reg
    input  wire [2:0]       EX_MemDataType,  // Origin: ID_EX_reg
    
    // Write-Back Control
    input  wire             EX_RegWrite,     // Origin: ID_EX_reg
    input  wire [1:0]       EX_MemToReg,     // Origin: ID_EX_reg
    
    // --- Data Path Signals (Input from EX Stage) ---
    input  wire [PC_WIDTH-1:0]          EX_PC_Plus_4,   // Origin: ID_EX_reg (Passed through)
    input  wire [WIDTH-1:0]             EX_ALUResult,   // Origin: ALUSelect_Mux
    input  wire [WIDTH-1:0]             EX_Rs2Data,     // Origin: Forwarding Mux B (The data to be stored)
    input  wire [$clog2(REG_COUNT)-1:0] EX_RdAddr,      // Origin: ID_EX_reg
    
    // ================= OUTPUTS (To MEM Stage) =================
    
    // --- Control Signals (Output to MEM Logic) ---
    output reg              MEM_MemRead,     // Destination: Data_Memory
    output reg              MEM_MemWrite,    // Destination: Data_Memory
    output reg [2:0]        MEM_MemDataType, // Destination: Data_Memory
    
    // Write-Back Control (Passed to MEM/WB)
    output reg              MEM_RegWrite,    // Destination: MEM/WB_reg & Hazard Unit
    output reg [1:0]        MEM_MemToReg,    // Destination: MEM/WB_reg
    
    // --- Data Path Signals (Output to MEM Logic / WB) ---
    output reg [PC_WIDTH-1:0]          MEM_PC_Plus_4,   // Destination: MEM/WB_reg
    output reg [WIDTH-1:0]             MEM_ALUResult,   // Destination: Data_Memory (Addr) & MEM/WB_reg
    output reg [WIDTH-1:0]             MEM_WriteData,   // Destination: Data_Memory (Data)
    output reg [$clog2(REG_COUNT)-1:0] MEM_RdAddr       // Destination: MEM/WB_reg (WB Propagation) & Hazard Unit
    );

    always @(posedge CPU_clk) begin
        if (!CPU_rst_n) begin
            // Reset Control
            MEM_MemRead     <= 1'b0;
            MEM_MemWrite    <= 1'b0;
            MEM_MemDataType <= 3'b111; // Invalid
            MEM_RegWrite    <= 1'b0;
            MEM_MemToReg    <= 2'b00;
            
            // Reset Data
            MEM_PC_Plus_4   <= 0;
            MEM_ALUResult   <= 0;
            MEM_WriteData   <= 0;
            MEM_RdAddr      <= 0;
        end 
        else begin
            // Pass Control
            MEM_MemRead     <= EX_MemRead;
            MEM_MemWrite    <= EX_MemWrite;
            MEM_MemDataType <= EX_MemDataType;
            MEM_RegWrite    <= EX_RegWrite;
            MEM_MemToReg    <= EX_MemToReg;
            
            // Pass Data
            MEM_PC_Plus_4   <= EX_PC_Plus_4;
            MEM_ALUResult   <= EX_ALUResult;
            MEM_WriteData   <= EX_Rs2Data; // Note: This is usually the Forwarded Rs2
            MEM_RdAddr      <= EX_RdAddr;
        end
    end

endmodule