/*
* Module: Register_File.v
* Description: Implements the general-purpose register file (x0-x31) of 
*              the RV32IM architecture. Supports triple-port read 
*              (2 + 1 RdData read for MAC) and single-port write functionality. 
*              Register x0 is hardwired to 0.
* Author: Aashrith S Narayn
* Date: 21/09/2025
*/

`timescale 1ns / 1ps

//(* dont_touch = "true" *)
module Register_File #(
    parameter WIDTH      = 32,
    parameter REG_COUNT  = 32
    )(
    input  wire                         CPU_clk,
    input  wire                         CPU_rst_n,
    input  wire                         RegWrite,
    input  wire [$clog2(REG_COUNT)-1:0] Rs1Addr, Rs2Addr,
    input  wire [$clog2(REG_COUNT)-1:0] RdAddr,
    input  wire [WIDTH-1:0]             WriteData,
    output wire  [WIDTH-1:0]             Rs1Data, Rs2Data, RdData
    );
    
    //RV32IM Register Array
    reg [WIDTH-1:0] RegArray [0:REG_COUNT-1];
    integer i;                                      //used for resetting RegArray

    
    localparam ADDR_WIDTH = $clog2(REG_COUNT); 
    localparam DATA_ZERO  = {WIDTH{1'b0}};
    localparam ADDR_ZERO  = {ADDR_WIDTH{1'b0}};
    assign Rs1Data = (Rs1Addr == 0) ? 0 : RegArray[Rs1Addr];
    assign Rs2Data = (Rs2Addr == 0) ? 0 : RegArray[Rs2Addr];
    assign RdData  = (RdAddr  == 0) ? 0 : RegArray[RdAddr];
    //Read Logic (Combinational)
//    always @(*) begin       
//        Rs1Data = (Rs1Addr == ADDR_ZERO) ? DATA_ZERO : RegArray[Rs1Addr];    //Reading Rs1
//        Rs2Data = (Rs2Addr == ADDR_ZERO) ? DATA_ZERO : RegArray[Rs2Addr];    //Reading Rs2
//        RdData  = (RdAddr  == ADDR_ZERO) ? DATA_ZERO : RegArray[RdAddr];     //Reading Rd (for MAC)
//    end
    
always @(posedge CPU_clk or negedge CPU_rst_n) begin
    if (!CPU_rst_n) begin
        for (i=0; i<REG_COUNT; i=i+1)
            RegArray[i] <= 0;
    end
    else if (RegWrite && RdAddr != 0) begin
        RegArray[RdAddr] <= WriteData;
    end
end


    
endmodule
