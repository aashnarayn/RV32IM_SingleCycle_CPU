/*
* Testbench: CPU_RPath_Test.v
* Description: Verifies the integrated functionality of the RV32IM R-Type
*              datapath, including arithmetic, logical and M-type instructins.  
*              
*              This testbench provides stimulus via instruction memory, drives 
*              clock and reset, and monitors critical outputs such as PC, register 
*              file contents and ALU results. Functional correctness 
*              is validated through observation or optional self-checking logic.
*
* Author: Aashrith S Narayn
* Date: 30/09/2025
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes_TB.vh"


module CPU_RPath_Test();
    
    //CPU parameters
    parameter DATA_WIDTH  = 32;
    parameter PC_WIDTH    = 32;
    parameter PC_STEP     = 4;
    parameter INSTR_WIDTH = 32;
    parameter REG_COUNT   = 32;
    parameter IMEM_DEPTH  = 256;
    
    //UUT input signals
    reg                    CPU_PCWrite;
    reg                    CPU_clk;
    reg                    CPU_rst_n;
    
    //Main UUT Debug Outputs            //CONVERT BACK TO WIRES FOR UUT
    wire [PC_WIDTH-1:0]    CPU_PC;
    wire [INSTR_WIDTH-1:0] CPU_Instr_RV32IM;
    wire [DATA_WIDTH-1:0]  CPU_Immediate;
    wire [5:0]             CPU_ALUControl;
    wire [DATA_WIDTH-1:0]  CPU_ALUResult;
    wire                   CPU_Zero;
    wire [DATA_WIDTH-1:0]  CPU_ReadData;
    wire [DATA_WIDTH-1:0]  CPU_WriteDataReg;
    
    //UUT Control Signals
    wire [2:0]             CPU_ALUOp;
    wire                   CPU_MDSel;
    wire                   CPU_RegWrite;
    wire                   CPU_ALUSrc1, CPU_ALUSrc2;
    
    //Reference Model Arrays 
    reg  [DATA_WIDTH-1:0]  Golden_IMEM    [0:IMEM_DEPTH-1];
    
    
    //Unit under test - R-Type datapath
    CPU_RPath #(
        .DATA_WIDTH(DATA_WIDTH),
        .PC_WIDTH(PC_WIDTH),
        .PC_STEP(PC_STEP),
        .INSTR_WIDTH(INSTR_WIDTH),
        .REG_COUNT(REG_COUNT),
        .IMEM_DEPTH(IMEM_DEPTH)
        )
    R_DataPath (
        .CPU_PCWrite(CPU_PCWrite),
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        
        .CPU_PC(CPU_PC),
        .CPU_Instr_RV32IM(CPU_Instr_RV32IM),
        .CPU_ALUControl(CPU_ALUControl),
        .CPU_ALUResult(CPU_ALUResult),
        .CPU_Zero(CPU_Zero),
        .CPU_Op1(CPU_OP1),
        .CPU_Op2(CPU_Op2),
        
        .CPU_ALUOp(CPU_ALUOp),
        .CPU_MDSel(CPU_MDSel),
        .CPU_RegWrite(CPU_RegWrite),
        .CPU_ALUSrc1(CPU_ALUSrc1), 
        .CPU_ALUSrc2(CPU_ALUSrc2)
        );
        
                
    //simulation tuning variables
    integer  i,j;
    integer  ClockTime, ResetTime;     //optional for optimising waits, repeats etc
    integer  fdump_imem, fd_dmem;      //only if needed for writeback
  
    
    //clk logic
    initial begin
        CPU_clk = 0;
        forever #5 CPU_clk = ~CPU_clk;          //100 MHz (synthesis supported)
    end
    
     
    //initialisation logic
    initial begin
        ClockTime   = 0;
        ResetTime   = 0;
        CPU_clk     = 0;
        CPU_PCWrite = 1;
        CPU_rst_n   = 0;
        
        $readmemh(`IMEM_HEX_PROGRAM, Golden_IMEM);       //preloading golden reference array
       
        #20;
        CPU_rst_n = 1;  
        

 
    end

    
endmodule