/*
* Module: IF_ID_Reg.v
* Description: Pipeline register between Instruction Fetch (IF) and Instruction Decode (ID).
* Latches PC metadata and supports synchronous Stall (Hold) and Flush (NOP insertion).
* The instruction port bypasses the flip-flops and acts as a combinational
* wire to absorb the 1-cycle synchronous read latency of the BRAM.
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
    input  wire             IF_ID_Write, // Origin: ID_Hazard_Detector (1=Update, 0=Stall/Freeze)
    input  wire             IF_ID_Flush, // Origin: ID_Hazard_Detector (1=Flush/Insert NOP)
    
    // Data Inputs (From IF Stage)
    input  wire [PC_WIDTH-1:0]    IF_PC,        // Origin: IF_Program_Counter
    input  wire [PC_WIDTH-1:0]    IF_PC_Plus_4, // Origin: IF_PC_Incrementer
    input  wire [INSTR_WIDTH-1:0] IF_Instr,     // Origin: IF_Instruction_Memory
    
    // Data Outputs (To ID Stage)
    output reg  [PC_WIDTH-1:0]    ID_PC,        // Destination: ID_Branch_Target_Gen & ID_Jump_Target_Gen & ID_EX_Reg
    output reg  [PC_WIDTH-1:0]    ID_PC_Plus_4, // Destination: ID_Jump_Target_Gen & ID_EX_Reg
    
    // Instruction bypasses flip-flops due to BRAM latency.
    output wire [INSTR_WIDTH-1:0] ID_Instr      // Destination: ID_Instruction_Splitter & ID_Control_Unit
    );

    // RISC-V NOP: addi x0, x0, 0
    localparam NOP_INSTR = 32'h00000013; 

    // Combinational Flush Mux. If a flush is commanded by the hazard unit,
    // the incoming BRAM data is masked with a NOP before entering the ID decoders.
    assign ID_Instr = (IF_ID_Flush) ? NOP_INSTR : IF_Instr;

    always @(posedge CPU_clk or negedge CPU_rst_n) begin
        if (!CPU_rst_n) begin
            ID_PC        <= 32'b0;
            ID_PC_Plus_4 <= 32'b0;
        end 
        else if (IF_ID_Flush) begin
            // Clear metadata on flush to maintain clean pipeline tracking in simulation
            ID_PC        <= 32'b0;      
            ID_PC_Plus_4 <= 32'b0; 
        end 
        else if (IF_ID_Write) begin
            // Normal Latch
            ID_PC        <= IF_PC;
            ID_PC_Plus_4 <= IF_PC_Plus_4;
        end
        // Implicit Else: If !IF_ID_Write (Stall), retain current values (Freeze).
    end

endmodule