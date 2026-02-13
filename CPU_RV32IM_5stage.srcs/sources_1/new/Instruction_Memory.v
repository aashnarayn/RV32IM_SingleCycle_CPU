/*
* Module: Instruction_Memory.v
* Description: Stores and serves 32-bit instructions to the CPU based on the current 
* Program Counter (PC). Read Only in the pipeline.
* Updated to Asynchronous Read to align with 5-stage pipeline IF/ID latching.
* Stage: IF
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module Instruction_Memory #(
    parameter PC_WIDTH    = 32,
    parameter INSTR_WIDTH = 32,
    parameter IMEM_DEPTH  = 256
    )(
    input  wire [PC_WIDTH-1:0]    IF_PC,            // Origin: Program Counter
    output wire [INSTR_WIDTH-1:0] IF_Instr_RV32IM   // Destination: IF/ID Pipeline Register
    );
    
    localparam BYTE_RANGE = $clog2(4 * IMEM_DEPTH);
    
    // Instruction Memory Array (Inferred as Distributed RAM/ROM)
    reg [INSTR_WIDTH-1:0] InstrMem [0:IMEM_DEPTH-1];
    
    // Instruction Read logic (Asynchronous/Combinational)
    // This ensures data is ready to be latched by IF/ID_reg at the clock edge.
    assign IF_Instr_RV32IM = InstrMem[IF_PC[BYTE_RANGE-1:2]];
    
    // Linter violation avoidance
    wire [PC_WIDTH-BYTE_RANGE-1:0] IMEM_unused_bits = |{IF_PC[PC_WIDTH-1:BYTE_RANGE], IF_PC[1:0]};
    
    // Initialising InstrMem with program data
    initial begin
        $readmemh(`IMEM_HEX_PROGRAM, InstrMem);
    end

endmodule