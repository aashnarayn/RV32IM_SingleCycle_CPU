/*
* Module: CPU_RV32IM_1cyc.v
* Description: Top-level RV32IM Single-Cycle CPU integrating all datapath and control modules,
*              with separate ALUs for RV32I and RV32M operations. Performs complete instruction
*              execution in a single cycle. Completely parametrized with hardware for expansion
*              into 5-stage pipelined implementation. Modules follow Pascal Case nomenclature
* 
* Resume: Designed and implemented a fully modular single-cycle CPU supporting the 
*         RV32IM ISA with separate ALUs for integer and multiplication/division operations. 
*         Developed 17 parameterized RTL modules including instruction decode, immediate
*         generator, memory subsystems, and custom control logic. Demonstrated 100% 
*         functional coverage across 40+ RV32I/M instructions and verified using 
*         waveform-driven testbenches and exposed debug ports for integration and 
*         visualization. Architecture designed to scale toward 5-stage pipelined 
*         implementation.
*
* Author: Aashrith S Narayn
* Date: 13/07/2025
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module CPU_RV32IM_1cyc #(
    parameter DATA_WIDTH   = 32,
    parameter PC_WIDTH     = 32,
    parameter PC_STEP      = 4,
    parameter INSTR_WIDTH  = 32,
    parameter REG_COUNT    = 32,
    parameter IMEM_DEPTH   = 256,
    parameter DMEM_DEPTH   = 512
    )(
    
    //CPU Inputs
    input  wire                   CPU_PCWrite,
    input  wire                   CPU_clk,
    input  wire                   CPU_rst_n,
    
    //Main Debug Outputs
    output wire [PC_WIDTH-1:0]    CPU_PC,
    output wire [INSTR_WIDTH-1:0] CPU_Instr_RV32IM,
    output wire [DATA_WIDTH-1:0]  CPU_Immediate,
    output wire [5:0]             CPU_ALUControl,
    output wire [DATA_WIDTH-1:0]  CPU_ALUResult,
    output wire                   CPU_Zero,
    output wire [DATA_WIDTH-1:0]  CPU_ReadData,
    output wire [DATA_WIDTH-1:0]  CPU_WriteDataReg,
    
    //Control Signals
    output wire [2:0]             CPU_ALUOp,
    output wire                   CPU_MDSel,
    output wire [2:0]             CPU_ImmediateSrc,
    output wire [2:0]             CPU_TargetSel,
    output wire                   CPU_RegWrite,
    output wire                   CPU_MemRead,
    output wire                   CPU_MemWrite,
    output wire [1:0]             CPU_MemToReg,
    output wire [2:0]             CPU_MemDataType,
    output wire                   CPU_ALUSrc1, CPU_ALUSrc2,
    output wire                   CPU_PCSrc,
    
    output wire TIMING_CHECK_LED        //Timing Anchor: To force synthesis to verify critical path
    );
    
    // Reset Synchronizer (Active Low)
    reg rst_sync_1, rst_sync_2;
    
    always @(posedge CPU_clk or negedge CPU_rst_n) begin
        if (!CPU_rst_n) begin
            rst_sync_1 <= 1'b0;
            rst_sync_2 <= 1'b0;
        end else begin
            rst_sync_1 <= 1'b1;
            rst_sync_2 <= rst_sync_1;       //rst_sync_2 is the reset signal for all CPU modules
        end
    end
    
    
    //----------------------------------------------------------------------------------
    //All connecting wires between the 16 CPU Modules
    //----------------------------------------------------------------------------------
    
    //PC
    (* keep = "true" *) wire [PC_WIDTH-1:0]    PC;                //ProgCount --> IMEM, PCAdd, ALUInputSel, BrTargetGen
    
    //IMEM
    (* keep = "true" *) wire [INSTR_WIDTH-1:0] Instr_RV32IM;      //IMEM --> RegFile, ImmGen, Control
    
    //PCAdd
    (* keep = "true" *) wire [PC_WIDTH-1:0]    PC_Plus_4;         //PCAdd --> NextPCMux, WrBackMux, UjTargetGen
    
    //RegFile
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  Rs1Data, Rs2Data, RdData;  //RegFile --> ALUInputSel, DMEM(Rs2Data) ,Holds the value of Rd (Accumulator)
    
    //Imm Gen
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  Immediate;         //Imm Gen --> ALUInputSel, BrTargetGen
    
    //Control
    (* keep = "true" *) wire [2:0]             ALUOp;             //Control --> ALUCtrlGen
    (* keep = "true" *) wire                   MDSel;             //Control --> ALU_I, ALU_M, ALUSelMux
    (* keep = "true" *) wire [2:0]             ImmediateSrc;      //Control --> ImmGen
    (* keep = "true" *) wire [3:0]             TargetSel;         //Control --> TrCtrl, UjTargetGen
    (* keep = "true" *) wire                   RegWrite;          //Control --> RegFile
    (* keep = "true" *) wire                   MemRead;           //Control --> DMEM
    (* keep = "true" *) wire                   MemWrite;          //Control --> DMEM
    (* keep = "true" *) wire [1:0]             MemToReg;          //Control --> WrBackMux
    (* keep = "true" *) wire [2:0]             MemDataType;       //Control --> DMEM
    (* keep = "true" *) wire                   ALUSrc1,ALUSrc2;   //Control --> ALUInputSel
    
    //ALUInputSel
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  Op1, Op2, Op3;          //ALUInputSel --> ALU_I, ALU_M
    
    //ALUCtrlGen
    (* keep = "true" *) wire [5:0]             ALUControl;        //ALUCtrlGen --> ALU_I, ALU_M
    
    //BrTargetGen
    (* keep = "true" *) wire [PC_WIDTH-1:0]    BranchTarget;      //BrTargetGen --> NextPCMux
    
    //ALU_I
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  ALUResult_I;       //ALU_I --> ALUSelMux
    (* keep = "true" *) wire                   Zero_I;            //ALU_I --> ALUSelMux
    
    //ALU_M
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  ALUResult_M;       //ALU_M --> ALUSelMux
    (* keep = "true" *) wire                   Zero_M;            //ALU_M --> ALUSelMux
    
    //TrCtrl
    (* keep = "true" *) wire [1:0]             PCSrc;             //TrCtrl --> NextPCMux
    
    //ALUSelMux
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  ALUResult;         //ALUSelMux --> DMEM, WrBackMux, NextPCMux, UjTargetGen
    (* keep = "true" *) wire                   Zero;              //ALUSelMux --> TrCtrl
    
    //UjTargetGen
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  JumpTarget;        //UjTargetGen --> NextPCMux
    
    //DMEM
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  ReadData;          //DMEM --> WrBackMux
    
    //WrBackMux
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  WriteDataReg;      //WrBackMux --> RegFile
    
    //NextPCMux
    (* keep = "true" *) wire [PC_WIDTH-1:0]    PC_Next;           //NextPCMux --> ProgCount
        
    //MAC Integration  
 
    (* keep = "true" *) wire [DATA_WIDTH-1:0] MAC_Result;    // Holds (Op1 * Op2) + Op3
    (* keep = "true" *) wire             MACSel;        // Control signal from Control Unit
    reg [DATA_WIDTH-1:0] MAC_ACC;
    //----------------------------------------------------------------------------------
    //All CPU Modules (16 total)
    //----------------------------------------------------------------------------------
        
    //----------------------------------
    //Module 1
    //Program Counter
    //----------------------------------   
    (* dont_touch = "true" *)
    Program_Counter #(
        .PC_WIDTH(PC_WIDTH),
        .PC_STEP(PC_STEP)
        )
    CPU_ProgCount (
        .PC_Next(PC_Next),
        .CPU_clk(CPU_clk),
        .CPU_rst_n(rst_sync_2),
        .PCWrite(CPU_PCWrite),
        .PC(PC)
    );
    
    
    //--------------------------------
    //Module 2
    //Instruction Memory (IMEM)
    //--------------------------------  
    (* dont_touch = "true" *)
    Instruction_Memory #(
        .PC_WIDTH(PC_WIDTH),
        .INSTR_WIDTH(INSTR_WIDTH),
        .IMEM_DEPTH(IMEM_DEPTH)
        )
    CPU_IMEM (
        .PC(PC),
        .Instr_RV32IM(Instr_RV32IM)
        );
    
        
    //--------------------------------
    //Module 3
    //PC Incrementer
    //-------------------------------- 
    (* dont_touch = "true" *) 
    PC_Incrementer #(
        .PC_WIDTH(PC_WIDTH),
        .PC_STEP(PC_STEP)
        )
    CPU_PCAdd (
        .PC(PC),
        .PC_Plus_4(PC_Plus_4)
        );
        
    
    //-------------------------------
    //Module 4
    //Register File
    //-------------------------------  
    (* dont_touch = "true" *)   
    Register_File #(
        .WIDTH(DATA_WIDTH),
        .REG_COUNT(REG_COUNT)
        )
    CPU_RegFile (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(rst_sync_2),
        .RegWrite(RegWrite),
        .Rs1Addr(Instr_RV32IM[19:15]),
        .Rs2Addr(Instr_RV32IM[24:20]),
        .RdAddr(Instr_RV32IM[11:7]),
        .WriteData(WriteDataReg),
        .Rs1Data(Rs1Data),
        .Rs2Data(Rs2Data),
        .RdData(RdData)
        );
     
    
    //------------------------------
    //Module 5
    //Immediate Generator
    //------------------------------   
    (* dont_touch = "true" *)
    Imm_Gen #(
        .WIDTH(DATA_WIDTH),
        .INSTR_WIDTH(INSTR_WIDTH)
        )   
     CPU_ImmGen (    
        .Instr_RV32IM(Instr_RV32IM),
        .ImmediateSrc(ImmediateSrc),
        .Immediate(Immediate)
        );
      
        
    //-----------------------------
    //Module 6
    //Control Unit
    //-----------------------------    
    (* dont_touch = "true" *)  
    Control_Unit #(
        .WIDTH(DATA_WIDTH),
        .INSTR_WIDTH(INSTR_WIDTH)
        )
    CPU_Control (
        .Instr_RV32IM(Instr_RV32IM),
        .ALUOp(ALUOp),
        .ImmediateSrc(ImmediateSrc),
        .TargetSel(TargetSel),
        .MACSel(MACSel),
        .MDSel(MDSel),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .MemToReg(MemToReg),
        .MemDataType(MemDataType),
        .ALUSrc1(ALUSrc1),
        .ALUSrc2(ALUSrc2)
        );
     
        
    //-----------------------------
    //Module 7
    //ALU Input Selector
    //-----------------------------   
    (* dont_touch = "true" *)
    ALU_Input_Selector #(
        .WIDTH(DATA_WIDTH),
        .PC_WIDTH(PC_WIDTH)
        )
    CPU_ALUInputSel (
        .Rs1Data(Rs1Data),
        .Rs2Data(Rs2Data),
        .RdData(RdData),
        .PC(PC),
        .Immediate(Immediate),
        .ALUSrc1(ALUSrc1),
        .ALUSrc2(ALUSrc2),
        .Op1(Op1),
        .Op2(Op2),
        .Op3(Op3_dummy)
        );
     
        
    //-----------------------------
    //Module 8
    //ALU Control Generator
    //-----------------------------    
    (* dont_touch = "true" *)
    ALUControl_Gen #(
        .WIDTH(DATA_WIDTH),
        .INSTR_WIDTH(INSTR_WIDTH)
        )
    CPU_ALUCtrlGen (
        .ALUOp(ALUOp),
        .Instr_RV32IM(Instr_RV32IM),
        .ALUControl(ALUControl)
        );
        
        
    //----------------------------
    //Module 9
    //Branch Target Generator
    //----------------------------    
    (* dont_touch = "true" *)
    Branch_Target_Gen #(
        .WIDTH(DATA_WIDTH),
        .PC_WIDTH(PC_WIDTH)
        )
    CPU_BrTargetGen (
        .Immediate(Immediate),
        .PC(PC),
        .BranchTarget(BranchTarget)
        );
    
    
    //----------------------------
    //Module 10
    //ALU for RV32I
    //----------------------------    
    (* dont_touch = "true" *)
    ALU_RV32I #(
        .WIDTH(DATA_WIDTH)
        )
    CPU_ALU_I (
        .Op1(Op1),
        .Op2(Op2),
        .ALUControl(ALUControl),
        .MDSel(MDSel),
        .ALUResult_I(ALUResult_I),
        .Zero_I(Zero_I)
        );
      
     
    //----------------------------
    //Module 11
    //ALU for RV32M
    //----------------------------    
    (* keep_hierarchy = "no" *)
    ALU_RV32M #(
        .WIDTH(DATA_WIDTH)
        )
    CPU_ALU_M (
        .Op1(Op1),
        .Op2(Op2),
        .Op3(RdData),
        .ALUControl(ALUControl),
        .MDSel(MDSel),
        .ALUResult_M(ALUResult_M),
        .Zero_M(Zero_M)
        );  
        always @(posedge CPU_clk or negedge rst_sync_2) begin
            if (!rst_sync_2)
                MAC_ACC <= 0;
            else if (MACSel)
                MAC_ACC <= MAC_ACC + ALUResult_M;
        end 
        assign MAC_Result = MAC_ACC;

    //----------------------------    
    //Module 12
    //Target Controller
    //----------------------------    
    (* dont_touch = "true" *)
    Target_Controller #()
    CPU_TrCtrl (
        .TargetSel(TargetSel),
        .Zero(Zero),
        .PCSrc(PCSrc)
        );
    
    
    //----------------------------
    //Module 13
    //ALU Selector Mux
    //----------------------------
    (* dont_touch = "true" *)
    ALUSelect_Mux #(
        .WIDTH(DATA_WIDTH)
        )
    CPU_ALUSelMux (
        .ALUResult_I(ALUResult_I),
        .ALUResult_M(ALUResult_M),
        .MAC_Result(ALUResult_M),
        .Zero_I(Zero_I),
        .Zero_M(Zero_M),
        .MDSel(MDSel),
        .MACSel(MACSel),
        .ALUResult(ALUResult),
        .Zero(Zero)
        );
        
    
    //----------------------------
    //Module 14
    //Jump Target Generator
    //----------------------------
    (* dont_touch = "true" *) 
    Jump_Target_Gen #(
        .WIDTH(DATA_WIDTH),
        .PC_WIDTH(PC_WIDTH)
        )
    CPU_UjTargetGen(
        .ALUResult(ALUResult),
        .TargetSel(TargetSel),
        .PC_Plus_4(PC_Plus_4),
        .JumpTarget(JumpTarget)
        );   
        
        
    //----------------------------
    //Module 15
    //Data Memory (DMEM)
    //----------------------------   
    (* dont_touch = "true" *)
    Data_Memory #(
        .WIDTH(DATA_WIDTH),
        .DMEM_DEPTH(DMEM_DEPTH)
        )
    CPU_DMEM (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(rst_sync_2),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .MemDataType(MemDataType),
        .ALUResult_Addr(ALUResult),
        .WriteData(Rs2Data),
        .ReadData(ReadData)
        );


    //----------------------------
    //Module 16
    //Data WriteBack Mux
    //----------------------------   
    (* dont_touch = "true" *)
    WriteBack_Mux #(
        .WIDTH(DATA_WIDTH),
        .PC_WIDTH(PC_WIDTH)
        )
    CPU_WrBackMux (
        .ALUResult(ALUResult),
        .ReadData(ReadData),
        .PC_Plus_4(PC_Plus_4),
        .MemToReg(MemToReg),
        .WriteData(WriteDataReg)
        );
     
        
    //---------------------------
    //Module 17
    //Next PC Mux
    //---------------------------    
    (* dont_touch = "true" *)
    PC_Next_Mux #(
        .PC_WIDTH(PC_WIDTH),
        .WIDTH(DATA_WIDTH)
        )
    CPU_NextPCMux (
        .PC_Plus_4(PC_Plus_4),
        .BranchTarget(BranchTarget),
        .JumpTarget(JumpTarget),
        .PCSrc(PCSrc),
        .PC_Next(PC_Next)
        );
        
        
    
        
    //----------------------------------------------------------------------------------
    //Module Output Assignments from wires (may be removed after simulation)
    //----------------------------------------------------------------------------------
    
    //Main output assignments
    assign CPU_PC            = PC;
    assign CPU_Instr_RV32IM  = Instr_RV32IM;
    assign CPU_Immediate     = Immediate;
    assign CPU_ALUControl    = ALUControl;
    assign CPU_ALUResult     = ALUResult;
    assign CPU_Zero          = Zero;
    assign CPU_ReadData      = ReadData;
    assign CPU_WriteDataReg  = WriteDataReg;  
    
    //Control signal assignments
    assign CPU_ALUOp         = ALUOp;
    assign CPU_MDSel         = MDSel;
    assign CPU_ImmediateSrc  = ImmediateSrc;
    assign CPU_TargetSel     = TargetSel;
    assign CPU_RegWrite      = RegWrite;
    assign CPU_MemRead       = MemRead;
    assign CPU_MemWrite      = MemWrite;
    assign CPU_MemToReg      = MemToReg;
    assign CPU_MemDataType   = MemDataType;
    assign CPU_ALUSrc1       = ALUSrc1;
    assign CPU_ALUSrc2       = ALUSrc2;
    assign CPU_PCSrc         = PCSrc;
    
    //XOR-reduce all critical signals. 
    //If the tool wants to drive this LED, it MUST calculate the result of the Divider.
    assign TIMING_CHECK_LED = ^ALUResult ^ ^PC ^ ^Instr_RV32IM ^ ^ReadData;

    
endmodule