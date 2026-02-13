/*
* Module: Data_Memory.v
* Description: Implements 32-bit data memory for RV32IM single-cycle CPU. 
* Supports Load and Store operations with synchronous write and 
* combinational read access. Implements variable width read and write.
* Updated to support synchronous read for 5-stage pipeline
* Supported operations - LW, LH, LB, LHU, LBU, SW, SH, SB
* Author: Aashrith S Narayn
* Date: 07/07/2025
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module Data_Memory #(
    parameter WIDTH      = 32,
    parameter DMEM_DEPTH = 4096
    )(
    input  wire             CPU_clk,
    input  wire             CPU_rst_n,
    
    // Control Signals (From EX/MEM Pipeline Register)
    input  wire             MEM_MemWrite,    // Origin: EX/MEM Pipeline Register
    input  wire             MEM_MemRead,     // Origin: EX/MEM Pipeline Register
    input  wire [2:0]       MEM_MemDataType, // Origin: EX/MEM Pipeline Register
    
    // Address & Data (From EX/MEM Pipeline Register)
    input  wire [WIDTH-1:0] MEM_ALUResult,   // Origin: EX/MEM Pipeline Register (The Address)
    input  wire [WIDTH-1:0] MEM_WriteData,   // Origin: EX/MEM Pipeline Register (Store Data - Rs2)
    
    // Output (To MEM/WB Pipeline Register)
    output reg  [WIDTH-1:0] MEM_ReadData     // Destination: MEM/WB Pipeline Register
    );
    
    // Data Memory Array - Byte-wise access
    (* ram_style = "block" *)                // Block RAM inference
    reg     [WIDTH-1:0] DataMem [0:DMEM_DEPTH-1];
    
    wire    [1:0]       Byte_Offset = MEM_ALUResult[1:0];
    reg     [WIDTH-1:0] WordTempRd;         
    
    localparam BYTE_RANGE = $clog2(4*DMEM_DEPTH);
    localparam DATA_ZERO  = {WIDTH{1'b0}};
    
    // Combined Synchronous Read and Write Logic
    always @(posedge CPU_clk) begin
        // --- Write Logic ---
        if (MEM_MemWrite && !MEM_MemRead) begin
            case(MEM_MemDataType)
                3'b000: begin // SB
                    case (Byte_Offset)
                         2'b00: DataMem[MEM_ALUResult[BYTE_RANGE-1:2]][7:0]   <= MEM_WriteData[7:0]; 
                         2'b01: DataMem[MEM_ALUResult[BYTE_RANGE-1:2]][15:8]  <= MEM_WriteData[7:0];
                         2'b10: DataMem[MEM_ALUResult[BYTE_RANGE-1:2]][23:16] <= MEM_WriteData[7:0];
                         2'b11: DataMem[MEM_ALUResult[BYTE_RANGE-1:2]][31:24] <= MEM_WriteData[7:0];
                    endcase
                end
                3'b001: begin // SH
                    case (Byte_Offset)
                         2'b00: DataMem[MEM_ALUResult[BYTE_RANGE-1:2]][15:0]  <= MEM_WriteData[15:0];
                         2'b10: DataMem[MEM_ALUResult[BYTE_RANGE-1:2]][31:16] <= MEM_WriteData[15:0];
                    endcase
                end
                3'b010: DataMem[MEM_ALUResult[BYTE_RANGE-1:2]] <= MEM_WriteData; // SW
            endcase
        end

        // --- Synchronous Read Logic ---
        if (MEM_MemRead && !MEM_MemWrite) begin 
            case(MEM_MemDataType)
                3'b000: begin // LB
                    WordTempRd = DataMem[MEM_ALUResult[BYTE_RANGE-1:2]] >> (Byte_Offset * 8);
                    MEM_ReadData <= { {24{WordTempRd[7]}}, WordTempRd[7:0] };
                end
                3'b001: begin // LH
                    WordTempRd = DataMem[MEM_ALUResult[BYTE_RANGE-1:2]] >> (Byte_Offset * 8);
                    MEM_ReadData <= { {16{WordTempRd[15]}}, WordTempRd[15:0] };
                end    
                3'b010: MEM_ReadData <= DataMem[MEM_ALUResult[BYTE_RANGE-1:2]]; // LW
                3'b100: MEM_ReadData <= (DataMem[MEM_ALUResult[BYTE_RANGE-1:2]] >> (Byte_Offset * 8)) & 8'hFF; // LBU
                3'b101: MEM_ReadData <= (DataMem[MEM_ALUResult[BYTE_RANGE-1:2]] >> (Byte_Offset * 8)) & 16'hFFFF; // LHU
                default: MEM_ReadData <= DATA_ZERO;
            endcase
        end else begin
            MEM_ReadData <= DATA_ZERO; 
        end
    end
    
    initial begin
        $readmemh(`DMEM_HEX_BLOCK, DataMem);
    end

    //pragma synthesis off
    
    /*
    initial begin
        //waiting for simulation to end
        #(`SIM_TIME);

        //data memory dump
        $writememh(`DMEM_HEX_DUMP, CPU_DataPath.CPU_DMEM.DataMem);
    end  
    */
    
    //pragma synthesis on

endmodule