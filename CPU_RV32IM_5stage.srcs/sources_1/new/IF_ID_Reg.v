/*
* Module: IF_ID_Reg.v
* Description: Pipeline register between Instruction Fetch (IF) and 
* Instruction Decode (ID) stages. 
* Latchs PC and Instruction on clock edge and supports synchronous 
* Stall (Hold) and Flush (Reset).
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module IF_ID_Reg #(
    parameter WIDTH = 32,
    parameter INSTR_WIDTH = 32,
    parameter PC_WIDTH = 32
    )(
    input  wire             CPU_clk,
    input  wire             CPU_rst_n,
    
    // Hazard Unit Controls
    input  wire             IF_ID_Write, // Origin: Hazard Detection Unit (1=Update, 0=Stall/Freeze)
    input  wire             IF_ID_Flush, // Origin: Hazard Detection Unit / Branch Logic (1=Flush/Insert NOP)
    
    // Data Inputs (From IF Stage)
    input  wire [PC_WIDTH-1:0]    IF_PC,        // Origin: Program_Counter (IF Stage)
    input  wire [PC_WIDTH-1:0]    IF_PC_Plus_4, // Origin: PC_Incrementer (For JAL/Link)
    input  wire [INSTR_WIDTH-1:0] IF_Instr,     // Origin: Instruction_Memory (IF Stage)
    
    // Data Outputs (To ID Stage)
    output reg  [PC_WIDTH-1:0]    ID_PC,        // Destination: ID/EX Pipeline Register & Branch Target Adder (if in ID)
    output reg  [PC_WIDTH-1:0]    ID_PC_Plus_4, // Destination: ID/EX Reg
    output reg  [INSTR_WIDTH-1:0] ID_Instr      // Destination: Instruction Splitter (treated as output interface)
    );

    // RISC-V NOP: addi x0, x0, 0
    localparam NOP_INSTR = 32'h00000013; 

    always @(posedge CPU_clk or negedge CPU_rst_n) begin
        if (!CPU_rst_n) begin
            ID_PC        <= 32'b0;
            ID_PC_Plus_4 <= 32'b0;
            ID_Instr     <= NOP_INSTR;
        end 
        else if (IF_ID_Flush) begin
            // Flush to NOP
            ID_PC        <= IF_PC;      
            ID_PC_Plus_4 <= IF_PC_Plus_4; 
            ID_Instr     <= NOP_INSTR; 
        end 
        else if (IF_ID_Write) begin
            // Normal Latch
            ID_PC        <= IF_PC;
            ID_PC_Plus_4 <= IF_PC_Plus_4;
            ID_Instr     <= IF_Instr; 
        end
        // Implicit Else: If !IF_ID_Write (Stall), retain current values (Freeze).
    end

endmodule