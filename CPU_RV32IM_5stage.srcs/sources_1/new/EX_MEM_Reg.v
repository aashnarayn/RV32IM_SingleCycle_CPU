/*
* Module: EX_MEM_Reg.v
* Description: Pipeline register between Execute (EX) and 
* Memory (MEM) stages. 
* Memory control and data signals are deliberately stripped from this 
* register because the synchronous BRAM physically absorbs the pipeline 
* boundary. This module strictly propagates Write-Back metadata.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module EX_MEM_Reg #(
    parameter WIDTH       = 32,
    parameter PC_WIDTH    = 32,
    parameter REG_COUNT   = 32
    )(
    input  wire             CPU_clk,
    input  wire             CPU_rst_n,
    
    // Stall signal from the EX stage multi-cycle ALUs
    input  wire             EX_Stall,        // Origin: EX_ALU_RV32M
    
    // --- Control Signals (Input from EX Stage) ---

    // Write-Back Control
    input  wire             EX_RegWrite,     // Origin: ID_EX_reg
    input  wire [1:0]       EX_MemToReg,     // Origin: ID_EX_reg
    
    // --- Data Path Signals (Input from EX Stage) ---
    input  wire [PC_WIDTH-1:0]          EX_PC_Plus_4,   // Origin: ID_EX_reg (Passed through)
    input  wire [WIDTH-1:0]             EX_ALUResult,   // Origin: EX_ALUSelect_Mux
    input  wire [$clog2(REG_COUNT)-1:0] EX_RdAddr,      // Origin: ID_EX_reg
    
    // ================= OUTPUTS (To MEM Stage) =================
    
    // Write-Back Control (Passed to MEM/WB)
    output reg              MEM_RegWrite,               // Destination: MEM_WB_Reg & ID_Hazard_Detector
    output reg [1:0]        MEM_MemToReg,               // Destination: MEM_WB_Reg
    
    // --- Data Path Signals (Output to MEM Logic / WB) ---
    output reg [PC_WIDTH-1:0]          MEM_PC_Plus_4,   // Destination: MEM_WB_Reg
    output reg [WIDTH-1:0]             MEM_ALUResult,   // Destination: MEM_WB_Reg
    output reg [$clog2(REG_COUNT)-1:0] MEM_RdAddr       // Destination: MEM_WB_Reg (WB Propagation) & ID_Hazard_Detector
    );

    always @(posedge CPU_clk or negedge CPU_rst_n) begin
        if (!CPU_rst_n) begin
            // Reset Control
            MEM_RegWrite    <= 1'b0;
            MEM_MemToReg    <= 2'b00;
            
            // Reset Data
            MEM_PC_Plus_4   <= 0;
            MEM_ALUResult   <= 0;
            MEM_RdAddr      <= 0;
        end 
        else if (EX_Stall) begin
            // Inject a bubble into the MEM stage if EX is performing a multi-cycle operation.
            MEM_RegWrite    <= 1'b0;
            // Data paths may carry invalid data since control signal (enable) is 0
        end
        else begin
            // Pass Control
            MEM_RegWrite    <= EX_RegWrite;
            MEM_MemToReg    <= EX_MemToReg;
            
            // Pass Data
            MEM_PC_Plus_4   <= EX_PC_Plus_4;
            MEM_ALUResult   <= EX_ALUResult;
            MEM_RdAddr      <= EX_RdAddr;
        end
    end

endmodule