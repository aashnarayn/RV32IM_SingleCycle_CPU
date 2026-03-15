/*
* Module: IF_Program_Counter.v
* Description: Holds the address of the current instruction and updates it on
* each clock cycle if PCWrite is asserted. Supports asynchronous reset.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module IF_Program_Counter #(
    parameter PC_WIDTH     = 32,
    parameter PC_STEP      = 4
    )(
    // PC_Next is resolved fully in the ID Stage to hit 1-cycle branch penalties.
    input  wire [PC_WIDTH-1:0] IF_PC_Next,    // Origin: ID_PC_Next_Mux (ID Stage) (Selects between PC+4, Branch, or Jump targets)
    input  wire                CPU_clk,
    input  wire                CPU_rst_n, 
    input  wire                IF_PCWrite,    // Origin: ID_Hazard_Detector (ID Stage - Stall Signal)
    output reg  [PC_WIDTH-1:0] IF_PC          // Destination: IF_Instruction Memory & IF_ID_Reg
    );
    
    localparam RESET_PC = 32'h80000000;         //PC Reset value before clock update
                                                //RISC-V convention - used for simulation
                                                //32'h00000000 is used for Bootrom style approaches
    always @(posedge CPU_clk or negedge CPU_rst_n) begin
       if (!CPU_rst_n) begin
           IF_PC <= RESET_PC;                   //ensures that on next PC update, PC is already 0 
       end else begin
           IF_PC <= (IF_PCWrite) ? IF_PC_Next : IF_PC;
       end
    end
    
endmodule