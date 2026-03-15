/*
* Module: Data_Memory.v
* Description: 32-bit data memory with Asynchronous Read / Synchronous Write. 
* Supports Load and Store operations with variable width read and write.
* Supported operations - LW, LH, LB, LHU, LBU, SW, SH, SB
* Stage: MEM
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module Data_Memory #(
    parameter WIDTH      = 32,
    parameter DMEM_DEPTH = 4096
    )(
    input  wire             CPU_clk,
    
    // --- Control Signals (Input from EX/MEM Pipeline Register) ---
    input  wire             MEM_MemWrite,    // Origin: EX_MEM_reg
    input  wire             MEM_MemRead,     // Origin: EX_MEM_reg
    input  wire [2:0]       MEM_MemDataType, // Origin: EX_MEM_reg
    
    // --- Address & Data (Input from EX/MEM Pipeline Register) ---
    input  wire [WIDTH-1:0] MEM_ALUResult,   // Origin: EX_MEM_reg (The Address) (only a part of this address size will be used)
    input  wire [WIDTH-1:0] MEM_WriteData,   // Origin: EX_MEM_reg (Store Data - Forwarded Rs2)
    
    // --- Output (To MEM/WB Pipeline Register) ---
    output reg  [WIDTH-1:0] MEM_ReadData     // Destination: MEM_WB_reg
    );
    
    // 1. The Memory Array (Distributed RAM)
    reg [WIDTH-1:0] DataMem [0:DMEM_DEPTH-1];
    
    // Address decoding
    wire [($clog2(DMEM_DEPTH)-1):0] Word_Addr = MEM_ALUResult[($clog2(DMEM_DEPTH)+1):2];
    wire [1:0]                      Byte_Offset = MEM_ALUResult[1:0];

    // ========================================================================
    // 2. SYNCHRONOUS WRITE (Standard)
    // ========================================================================
    always @(posedge CPU_clk) begin
        if (MEM_MemWrite) begin
            case(MEM_MemDataType)
                `MEM_BYTE_SIGNED, `MEM_BYTE_UNSIGNED: begin // SB
                    if (Byte_Offset == 2'b00) DataMem[Word_Addr][7:0]   <= MEM_WriteData[7:0];
                    if (Byte_Offset == 2'b01) DataMem[Word_Addr][15:8]  <= MEM_WriteData[7:0];
                    if (Byte_Offset == 2'b10) DataMem[Word_Addr][23:16] <= MEM_WriteData[7:0];
                    if (Byte_Offset == 2'b11) DataMem[Word_Addr][31:24] <= MEM_WriteData[7:0];
                end
                `MEM_HALF_SIGNED, `MEM_HALF_UNSIGNED: begin // SH
                    if (Byte_Offset == 2'b00) DataMem[Word_Addr][15:0]  <= MEM_WriteData[15:0];
                    if (Byte_Offset == 2'b10) DataMem[Word_Addr][31:16] <= MEM_WriteData[15:0];
                end
                `MEM_WORD: DataMem[Word_Addr] <= MEM_WriteData; // SW
                default: DataMem[Word_Addr] <= DataMem[Word_Addr]; // No Write
            endcase
        end
    end

    // ========================================================================
    // 3. ASYNCHRONOUS READ (Combinational)
    // ========================================================================
    // Logic: Read happen immediately so data is ready for MEM/WB setup time.
    
    reg [WIDTH-1:0] Raw_Read_Word;
    
    // Read the full word immediately
    always @(*) begin
        if (MEM_MemRead) 
            Raw_Read_Word = DataMem[Word_Addr];
        else 
            Raw_Read_Word = 32'b0;
    end

    // 4. Output Formatting (Combinational Sign Extension)
    always @(*) begin
        case(MEM_MemDataType)
            `MEM_BYTE_SIGNED: begin // LB
                case(Byte_Offset)
                    2'b00: MEM_ReadData = {{24{Raw_Read_Word[7]}},  Raw_Read_Word[7:0]};
                    2'b01: MEM_ReadData = {{24{Raw_Read_Word[15]}}, Raw_Read_Word[15:8]};
                    2'b10: MEM_ReadData = {{24{Raw_Read_Word[23]}}, Raw_Read_Word[23:16]};
                    2'b11: MEM_ReadData = {{24{Raw_Read_Word[31]}}, Raw_Read_Word[31:24]};
                endcase
            end
            `MEM_HALF_SIGNED: begin // LH
                case(Byte_Offset[1])
                    1'b0: MEM_ReadData = {{16{Raw_Read_Word[15]}}, Raw_Read_Word[15:0]};
                    1'b1: MEM_ReadData = {{16{Raw_Read_Word[31]}}, Raw_Read_Word[31:16]};
                endcase
            end
            `MEM_BYTE_UNSIGNED: begin // LBU
                case(Byte_Offset)
                    2'b00: MEM_ReadData = {24'b0, Raw_Read_Word[7:0]};
                    2'b01: MEM_ReadData = {24'b0, Raw_Read_Word[15:8]};
                    2'b10: MEM_ReadData = {24'b0, Raw_Read_Word[23:16]};
                    2'b11: MEM_ReadData = {24'b0, Raw_Read_Word[31:24]};
                endcase
            end
            `MEM_HALF_UNSIGNED: begin // LHU
                 case(Byte_Offset[1])
                    1'b0: MEM_ReadData = {16'b0, Raw_Read_Word[15:0]};
                    1'b1: MEM_ReadData = {16'b0, Raw_Read_Word[31:16]};
                endcase
            end
            `MEM_WORD: MEM_ReadData = Raw_Read_Word;
            default:   MEM_ReadData = 32'b0;
        endcase
    end

    // Simulation Loading
    initial begin
        $readmemh(`DMEM_HEX_BLOCK, DataMem);
    end

endmodule