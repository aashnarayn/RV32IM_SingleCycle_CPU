/*
* Testbench: CPU_RV32IM_Test.v
* Description: Verifies the integrated functionality of the complete RV32IM 
*              single-cycle CPU datapath. Includes instruction fetch, decode, 
*              execution, memory access, and writeback stages combined in 1 cycle.
*              
*              This testbench provides stimulus via instruction memory, drives 
*              clock and reset, and monitors critical outputs such as PC, register 
*              file contents, ALU results, and data memory. Functional correctness 
*              is validated through observation or optional self-checking logic.
* Author: Aashrith S Narayn
* Date: 22/07/2025
*/

`timescale 1ns / 1ps

module CPU_RV32IM_Test();
    
    //CPU parameters
    parameter DATA_WIDTH  = 32;
    parameter PC_WIDTH    = 32;
    parameter PC_STEP     = 4;
    parameter INSTR_WIDTH = 32;
    parameter REG_COUNT   = 32;
    parameter IMEM_DEPTH  = 256;
    parameter DMEM_DEPTH  = 512;
    
    //UUT input signals
    reg                    CPU_PCWrite;
    reg                    CPU_clk;
    reg                    CPU_rst_n;
    
    //Main UUT Debug Outputs           
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
    wire [2:0]             CPU_ImmediateSrc;
    wire [2:0]             CPU_TargetSel;
    wire                   CPU_RegWrite;
    wire                   CPU_MemRead;
    wire                   CPU_MemWrite;
    wire [1:0]             CPU_MemToReg;
    wire [2:0]             CPU_MemDataType;
    wire                   CPU_ALUSrc1, CPU_ALUSrc2;
    wire                   CPU_PCSrc;
    
    
    //Unit under test - full datapath
    CPU_RV32IM_1cyc #(
        .DATA_WIDTH(DATA_WIDTH),
        .PC_WIDTH(PC_WIDTH),
        .PC_STEP(PC_STEP),
        .INSTR_WIDTH(INSTR_WIDTH),
        .REG_COUNT(REG_COUNT),
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH)
        )
    CPU_DataPath (
        .CPU_PCWrite(CPU_PCWrite),
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        
        .CPU_PC(CPU_PC),
        .CPU_Instr_RV32IM(CPU_Instr_RV32IM),
        .CPU_Immediate(CPU_Immediate),
        .CPU_ALUControl(CPU_ALUControl),
        .CPU_ALUResult(CPU_ALUResult),
        .CPU_Zero(CPU_Zero),
        .CPU_ReadData(CPU_ReadData),
        .CPU_WriteDataReg(CPU_WriteDataReg),
        
        .CPU_ALUOp(CPU_ALUOp),
        .CPU_MDSel(CPU_MDSel),
        .CPU_ImmediateSrc(CPU_ImmediateSrc),
        .CPU_TargetSel(CPU_TargetSel),
        .CPU_RegWrite(CPU_RegWrite),
        .CPU_MemRead(CPU_MemRead),
        .CPU_MemWrite(CPU_MemWrite),
        .CPU_MemToReg(CPU_MemToReg),
        .CPU_MemDataType(CPU_MemDataType),
        .CPU_ALUSrc1(CPU_ALUSrc1), 
        .CPU_ALUSrc2(CPU_ALUSrc2),
        .CPU_PCSrc(CPU_PCSrc)
        );
        
                
   // 1. Clock Generation (Simple & Robust)
    // Starts at 0, toggles every 5ns (10ns period = 100MHz)
    initial CPU_clk = 0; 
    always #5 CPU_clk = ~CPU_clk;

    // 2. Main Simulation Control
    initial begin
        // Initialize Inputs
        CPU_rst_n = 0;      // Start in RESET (Active Low)
        CPU_PCWrite = 1;    // Enable PC writing

        // Hold Reset for a short time
        #100;
        
        // Release Reset (Start the CPU)
        $display("Releasing Reset at time %0t", $time);
        CPU_rst_n = 1;

        // Run simulation for enough time to see instructions execute
        #2000; 

        $display("Simulation finished normally.");
        $finish;
    end

    // 3. Waveform Dumping
    initial begin
        $dumpfile("CPU_RV32IM_Test.vcd");
        $dumpvars(0, CPU_RV32IM_Test);
    end

endmodule
