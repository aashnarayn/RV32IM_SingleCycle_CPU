/*
* Module: Instruction_Memory.v
* Description: Stores and serves 32-bit instructions to the CPU based on the current 
* Program Counter (PC). Supports asynchronous fetch from an initialized 
* instruction memory ROM. Read-only in RV32IM single-cycle architecture.
* Updated to support Synchronous read for 5-stage pipelining.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

//(* dont_touch = "true" *)
module Instruction_Memory #(
    parameter PC_WIDTH    = 32,
    parameter INSTR_WIDTH = 32,
    parameter IMEM_DEPTH  = 256
    )(
    input  wire                   CPU_clk,          // Added for synchronous read
    input  wire [PC_WIDTH-1:0]    IF_PC,            // Origin: Program Counter
    output reg  [INSTR_WIDTH-1:0] IF_Instr_RV32IM   // Destination: IF/ID Pipeline Register
    );
    
    localparam BYTE_RANGE = $clog2(4*IMEM_DEPTH);
    
    // Instruction Memory Array
    (* ram_style = "block" *)                    // Inferable as Block RAM due to synchronous read
    reg [INSTR_WIDTH-1:0] InstrMem [0:IMEM_DEPTH-1];
    
    // Instruction Read logic (Synchronous)
    // The instruction for the current PC will be ready at the 
    // beginning of the next clock cycle (the ID stage).
    always @(posedge CPU_clk) begin
        IF_Instr_RV32IM <= InstrMem[IF_PC[BYTE_RANGE-1:2]];
    end
    
    // Linter violation avoidance
    wire [PC_WIDTH-BYTE_RANGE-1:0] IMEM_unused_bits = |{IF_PC[PC_WIDTH-1:BYTE_RANGE], IF_PC[1:0]};
    
    // Initialising InstrMem with program data
    initial begin
        $readmemh(`IMEM_HEX_PROGRAM, InstrMem);
    end
    
    //pragma synthesis off
    
    /*
    initial begin
        //waiting for simulation to end
        #(`SIM_TIME);
        
        //instruction memory dump
        $writememh(`IMEM_HEX_DUMP, CPU_DataPath.CPU_IMEM.InstrMem);
    end  
    */
    
    //pragma synthesis on

endmodule