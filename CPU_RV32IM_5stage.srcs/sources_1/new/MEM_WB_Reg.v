/*
* Module: MEM_WB_reg.v
* Description: Pipeline register between Memory (MEM) and 
* Write-Back (WB) stages. 
* Carries final data for Register File update.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module MEM_WB_reg #(
    parameter WIDTH       = 32,
    parameter PC_WIDTH    = 32,
    parameter REG_COUNT   = 32
    )(
    input  wire             CPU_clk,
    input  wire             CPU_rst_n,
    
    // --- Control Signals (Input from MEM Stage) ---
    input  wire             MEM_RegWrite,    // Origin: EX_MEM_reg
    input  wire [1:0]       MEM_MemToReg,    // Origin: EX_MEM_reg
    
    // --- Data Path Signals (Input from MEM Stage) ---
    input  wire [PC_WIDTH-1:0]          MEM_PC_Plus_4,   // Origin: EX_MEM_reg
    input  wire [WIDTH-1:0]             MEM_ALUResult,   // Origin: EX_MEM_reg
    input  wire [WIDTH-1:0]             MEM_ReadData,    // Origin: Data_Memory
    input  wire [$clog2(REG_COUNT)-1:0] MEM_RdAddr,      // Origin: EX_MEM_reg
    
    // ================= OUTPUTS (To WB Stage) =================
    
    // --- Control Signals (Output to WB Logic) ---
    output reg              WB_RegWrite,     // Destination: Register_File (Write Enable) & Hazard Unit
    output reg [1:0]        WB_MemToReg,     // Destination: WriteBack_Mux
    
    // --- Data Path Signals (Output to WB Mux) ---
    output reg [PC_WIDTH-1:0]          WB_PC_Plus_4,    // Destination: WriteBack_Mux
    output reg [WIDTH-1:0]             WB_ALUResult,    // Destination: WriteBack_Mux
    output reg [WIDTH-1:0]             WB_ReadData,     // Destination: WriteBack_Mux
    output reg [$clog2(REG_COUNT)-1:0] WB_RdAddr        // Destination: Register_File (Write Addr with WB Propagation) & Hazard Unit
    );

    always @(posedge CPU_clk or negedge CPU_rst_n) begin
        if (!CPU_rst_n) begin
            // Reset Control
            WB_RegWrite    <= 1'b0;
            WB_MemToReg    <= 2'b00;
            
            // Reset Data
            WB_PC_Plus_4   <= 0;
            WB_ALUResult   <= 0;
            WB_ReadData    <= 0;
            WB_RdAddr      <= 0;
        end 
        else begin
            // Pass Control
            WB_RegWrite    <= MEM_RegWrite;
            WB_MemToReg    <= MEM_MemToReg;
            
            // Pass Data
            WB_PC_Plus_4   <= MEM_PC_Plus_4;
            WB_ALUResult   <= MEM_ALUResult;
            WB_ReadData    <= MEM_ReadData;
            WB_RdAddr      <= MEM_RdAddr;
        end
    end

endmodule