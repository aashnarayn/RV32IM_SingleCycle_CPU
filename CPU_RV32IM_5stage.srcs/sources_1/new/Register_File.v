/*
* Module: Register_File.v
* Description: Implements the general-purpose register file (x0-x31) of 
* the RV32IM architecture. Supports triple-port read 
* (2 + 1 RdData read for MAC) and single-port write functionality. 
* Register x0 is hardwired to 0 logically. 
* Updated with Internal Forwarding for 5-stage pipelining.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module Register_File #(
    parameter WIDTH      = 32,
    parameter REG_COUNT  = 32
    )(
    input  wire                         CPU_clk,
    input  wire                         CPU_rst_n,
    
    // Write Port (Signals MUST come from the WB Pipeline Register)
    input  wire                         WB_RegWrite,  // Origin: MEM/WB Pipeline Register (Control Bundle)
    input  wire [$clog2(REG_COUNT)-1:0] WB_RdAddr,    // Origin: MEM/WB Pipeline Register
    input  wire [WIDTH-1:0]             WB_WriteData, // Origin: Write-Back Mux (Selects between ALU Result or Memory Data)
    
    // Read Ports (Signals come from the current Instruction in ID stage)
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs1Addr,   // Origin: IF/ID Pipeline Register (Instr[19:15])
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs2Addr,   // Origin: IF/ID Pipeline Register (Instr[24:20])
    input  wire [$clog2(REG_COUNT)-1:0] ID_RdAddr,    // Origin: IF/ID Pipeline Register (Instr[11:7] - Source 3 for MAC)
    
    // Data Outputs (Going into the ID/EX Pipeline Register)
    output wire [WIDTH-1:0]             ID_Rs1Data,   // Destination: ID/EX Pipeline Register
    output wire [WIDTH-1:0]             ID_Rs2Data,   // Destination: ID/EX Pipeline Register
    output wire [WIDTH-1:0]             ID_RdData     // Destination: ID/EX Pipeline Register (Future MAC Accumulator)
    );
    
    //RV32IM Register Array
    reg [WIDTH-1:0] RegArray [0:REG_COUNT-1];
    
    localparam ADDR_WIDTH = $clog2(REG_COUNT); 
    localparam DATA_ZERO  = {WIDTH{1'b0}};
    localparam ADDR_ZERO  = {ADDR_WIDTH{1'b0}};
    
    /* * Read Logic (Combinational with Internal Forwarding)
    * If we are reading a register in ID that is being written in WB in the same cycle,
    * we forward WB_WriteData directly to avoid a stale read.
    */
    assign ID_Rs1Data = (ID_Rs1Addr == ADDR_ZERO) ? DATA_ZERO : 
                        ((ID_Rs1Addr == WB_RdAddr) && WB_RegWrite) ? WB_WriteData : RegArray[ID_Rs1Addr];
                        
    assign ID_Rs2Data = (ID_Rs2Addr == ADDR_ZERO) ? DATA_ZERO : 
                        ((ID_Rs2Addr == WB_RdAddr) && WB_RegWrite) ? WB_WriteData : RegArray[ID_Rs2Addr];
                        
    assign ID_RdData  = (ID_RdAddr  == ADDR_ZERO) ? DATA_ZERO : 
                        ((ID_RdAddr  == WB_RdAddr) && WB_RegWrite) ? WB_WriteData : RegArray[ID_RdAddr];

    //Write Logic (Sequential)
    always @(posedge CPU_clk) begin
        if (WB_RegWrite && WB_RdAddr != ADDR_ZERO) begin
            RegArray[WB_RdAddr] <= WB_WriteData;        // All register resets handled by software
        end
    end
    
endmodule