/*
* Module: IF_Instruction_Memory.v
* Description: Stores and serves 32-bit instructions to the CPU based 
* on the current Program Counter (PC). Read Only in the pipeline.
* Updated to Synchronous Read (for inferring as BRAM) to align with 
* 5-stage pipeline design. The 1-cycle read latency inherently acts 
* as the Instruction portion of the IF/ID Pipeline Register.
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module IF_Instruction_Memory #(
    parameter PC_WIDTH    = 32,
    parameter INSTR_WIDTH = 32,
    parameter IMEM_DEPTH  = 256
    )(
    input  wire                   CPU_clk,          // Origin: System Clock -> Destination: BRAM Clock Pin
    input  wire                   IF_ID_Write,      // Origin: ID_Hazard_Detector -> Destination: BRAM Read Enable (Stall control)
    input  wire [PC_WIDTH-1:0]    IF_PC,            // Origin: Program_Counter    -> Destination: BRAM Address Port

    // Output physically appears in the ID Stage on the next clock edge.
    output reg  [INSTR_WIDTH-1:0] IF_Instr_RV32IM   // Destination: Bypasses IF/ID_Reg -> ID Stage Logic (Splitter/Control)
    );
    
    localparam BYTE_RANGE = $clog2(4 * IMEM_DEPTH);
    
    // Instruction Memory Array (Inferred as Block RAM)
    (* ram_style = "block" *) reg [INSTR_WIDTH-1:0] InstrMem [0:IMEM_DEPTH-1];
    
    // Synchronous Read: Data is latched on the clock edge.
    // By using IF_ID_Write as an enable, the memory holds its output during a stall.
    always @(posedge CPU_clk) begin
        if (IF_ID_Write) begin
            IF_Instr_RV32IM <= InstrMem[IF_PC[BYTE_RANGE-1:2]];
        end
    end
    
    // Linter violation avoidance
    wire [PC_WIDTH-BYTE_RANGE-1:0] IMEM_unused_bits = { (PC_WIDTH-BYTE_RANGE){ |{IF_PC[PC_WIDTH-1:BYTE_RANGE], IF_PC[1:0]} } };
    
    // Initialising InstrMem with program data
    initial begin
        $readmemh(`IMEM_HEX_PROGRAM, InstrMem);
    end

endmodule