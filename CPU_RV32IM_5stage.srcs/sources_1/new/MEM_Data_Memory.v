/*
* Module: MEM_Data_Memory.v
* Description: 32-bit data memory with Synchronous Read and Write. 
* Supports Load and Store operations with variable width read and write.
* Supported operations - LW, LH, LB, LHU, LBU, SW, SH, SB
* Optimised for BRAM inference and Byte masked writes (SB and SH)
* The inputs bypass the EX_MEM register entirely. The internal BRAM 
* flip-flops absorb the 1-cycle latency, aligning the read data 
* perfectly with the MEM stage clock cycle.
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module MEM_Data_Memory #(
    parameter WIDTH      = 32,
    parameter DMEM_DEPTH = 4096
    )(
    input  wire             CPU_clk,
    
    // --- Control Signals (Inputs bypass EX_MEM_reg and come from EX) ---
    input  wire             EX_MemWrite,    // Origin: ID_EX_Reg (Control Unit)
    input  wire             EX_MemRead,     // Origin: ID_EX_Reg (Control Unit)
    input  wire [2:0]       EX_MemDataType, // Origin: ID_EX_Reg (Control Unit)
    
    // --- Address & Data (Inputs bypass EX_MEM_reg and come from EX) ---
    input  wire [WIDTH-1:0] EX_ALUResult,   // Origin: EX_ALUSelect_Mux
    input  wire [WIDTH-1:0] EX_WriteData,   // Origin: EX_ALU_Input_Sel (EX_StoreData signal)
    
    // --- Output (To MEM/WB Pipeline Register) ---
    // Note: This data appears in the MEM stage, one cycle after the EX inputs are provided.
    output reg  [WIDTH-1:0] MEM_ReadData     // Destination: MEM_WB_Reg
    );
    
    // 1. The Memory Array (Forced to Block RAM)
    (* ram_style = "block" *) reg [WIDTH-1:0] DataMem [0:DMEM_DEPTH-1];
    
    // Address decoding
    wire [($clog2(DMEM_DEPTH)-1):0] Word_Addr = EX_ALUResult[($clog2(DMEM_DEPTH)+1):2];
    wire [1:0]                      Byte_Offset = EX_ALUResult[1:0];

    // ========================================================================
    // 2. DATA WRITE SETUP (Byte Masking with a Data Bus for Partial Writes)
    // ========================================================================
    reg [3:0]       Write_Mask;
    reg [WIDTH-1:0] Aligned_Data;

    always @(*) begin
        // Default
        Write_Mask   = 4'b0000;
        Aligned_Data = 32'b0;

        if (EX_MemWrite) begin
            case (EX_MemDataType)
                `MEM_BYTE_SIGNED, `MEM_BYTE_UNSIGNED: begin // SB
                    Aligned_Data = {4{EX_WriteData[7:0]}};  // Replicate byte across all byte lanes
                    case (Byte_Offset)
                        2'b00: Write_Mask = 4'b0001;
                        2'b01: Write_Mask = 4'b0010;
                        2'b10: Write_Mask = 4'b0100;
                        2'b11: Write_Mask = 4'b1000;
                    endcase
                end
                `MEM_HALF_SIGNED, `MEM_HALF_UNSIGNED: begin // SH
                    Aligned_Data = {2{EX_WriteData[15:0]}}; // Replicate halfword accross double byte lanes
                    case (Byte_Offset[1])
                        1'b0: Write_Mask = 4'b0011;
                        1'b1: Write_Mask = 4'b1100;
                    endcase
                end
                `MEM_WORD: begin // SW
                    Aligned_Data = EX_WriteData;            // Complete write (fully set mask)
                    Write_Mask   = 4'b1111;
                end
                default: Write_Mask = 4'b0000;
            endcase
        end
    end

    // ========================================================================
    // 3. SYNCHRONOUS WRITE OPERATION
    // ========================================================================
    reg [WIDTH-1:0] Raw_Read_Word;
    
    always @(posedge CPU_clk) begin
        // Byte Lane Write Operations
        if (Write_Mask[0]) DataMem[Word_Addr][7:0]   <= Aligned_Data[7:0];
        if (Write_Mask[1]) DataMem[Word_Addr][15:8]  <= Aligned_Data[15:8];
        if (Write_Mask[2]) DataMem[Word_Addr][23:16] <= Aligned_Data[23:16];
        if (Write_Mask[3]) DataMem[Word_Addr][31:24] <= Aligned_Data[31:24];
        
        // Synchronous Read
        if (EX_MemRead) begin
            Raw_Read_Word <= DataMem[Word_Addr];
        end else begin
            Raw_Read_Word <= 32'b0;
        end
    end

    // ========================================================================
    // 4. DATA READ SETUP (MEM Stage)
    // ========================================================================
    // Note: We use the MEM stage control signal here, which must still be latched
    // by the EX/MEM register so it aligns with the delayed Raw_Read_Word.
    
    // We need to pass the formatting control signals through a 1-cycle delay
    // to match the BRAM read latency.
    reg [2:0] MEM_MemDataType;
    reg [1:0] MEM_Byte_Offset;
    
    always @(posedge CPU_clk) begin
        MEM_MemDataType <= EX_MemDataType;
        MEM_Byte_Offset <= Byte_Offset;
    end

    always @(*) begin
        case(MEM_MemDataType)
            `MEM_BYTE_SIGNED: begin // LB
                case(MEM_Byte_Offset)
                    2'b00: MEM_ReadData = {{24{Raw_Read_Word[7]}},  Raw_Read_Word[7:0]};
                    2'b01: MEM_ReadData = {{24{Raw_Read_Word[15]}}, Raw_Read_Word[15:8]};
                    2'b10: MEM_ReadData = {{24{Raw_Read_Word[23]}}, Raw_Read_Word[23:16]};
                    2'b11: MEM_ReadData = {{24{Raw_Read_Word[31]}}, Raw_Read_Word[31:24]};
                endcase
            end
            `MEM_HALF_SIGNED: begin // LH
                case(MEM_Byte_Offset[1])
                    1'b0: MEM_ReadData = {{16{Raw_Read_Word[15]}}, Raw_Read_Word[15:0]};
                    1'b1: MEM_ReadData = {{16{Raw_Read_Word[31]}}, Raw_Read_Word[31:16]};
                endcase
            end
            `MEM_BYTE_UNSIGNED: begin // LBU
                case(MEM_Byte_Offset)
                    2'b00: MEM_ReadData = {24'b0, Raw_Read_Word[7:0]};
                    2'b01: MEM_ReadData = {24'b0, Raw_Read_Word[15:8]};
                    2'b10: MEM_ReadData = {24'b0, Raw_Read_Word[23:16]};
                    2'b11: MEM_ReadData = {24'b0, Raw_Read_Word[31:24]};
                endcase
            end
            `MEM_HALF_UNSIGNED: begin // LHU
                 case(MEM_Byte_Offset[1])
                    1'b0: MEM_ReadData = {16'b0, Raw_Read_Word[15:0]};
                    1'b1: MEM_ReadData = {16'b0, Raw_Read_Word[31:16]};
                endcase
            end
            `MEM_WORD: MEM_ReadData = Raw_Read_Word;
            default:   MEM_ReadData = 32'b0;
        endcase
    end

    initial begin
        $readmemh(`DMEM_HEX_BLOCK, DataMem);
    end

endmodule