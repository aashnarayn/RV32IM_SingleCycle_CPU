/*
* Module: CPU_RV32IM_Pipeline.v
* Description: Top-level RV32IM 5-Stage Pipelined CPU.
* Integrates all datapath, control, and pipeline register modules.
* Supports standard RISC-V ISA + Custom MAC/MACI Extensions.
* Features:
* - 5-Stage Pipeline (IF, ID, EX, MEM, WB)
* - Hazard Detection (Stall/Flush) & Forwarding (EX/MEM/WB)
* - Custom MAC Unit with Accumulator Forwarding
* - Multi-cycle Divider Support
* * Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module CPU_RV32IM_Pipeline #(
    parameter DATA_WIDTH   = 32,
    parameter PC_WIDTH     = 32,
    parameter PC_STEP      = 4,
    parameter INSTR_WIDTH  = 32,
    parameter REG_COUNT    = 32,
    parameter IMEM_DEPTH   = 256,
    parameter DMEM_DEPTH   = 4096
    )(
    
    //CPU Inputs
    input  wire                   CPU_clk,
    input  wire                   CPU_rst_n,
    
    // --- Main Debug Outputs (Pipeline Equivalents) ---
    output wire [PC_WIDTH-1:0]    CPU_PC,           // Current Fetch PC
    output wire [INSTR_WIDTH-1:0] CPU_Instr_RV32IM, // Instruction being Decoded (ID)
    output wire [DATA_WIDTH-1:0]  CPU_Immediate,    // Immediate Value (ID)
    output wire [5:0]             CPU_ALUControl,   // ALU Control Signal (EX)
    output wire [DATA_WIDTH-1:0]  CPU_ALUResult,    // Calculation Result (EX)
    output wire                   CPU_Zero,         // Zero Flag (EX)
    output wire [DATA_WIDTH-1:0]  CPU_ReadData,     // Memory Read Data (MEM)
    output wire [DATA_WIDTH-1:0]  CPU_WriteDataReg, // Final WriteBack Data (WB)
    
    // --- Control Signals (From ID Stage - Decode Verification) ---
    output wire [2:0]             CPU_ALUOp,
    output wire                   CPU_MDSel,
    output wire [2:0]             CPU_ImmediateSrc,
    output wire [2:0]             CPU_TargetSel,
    output wire                   CPU_RegWrite,
    output wire                   CPU_MemRead,
    output wire                   CPU_MemWrite,
    output wire [1:0]             CPU_MemToReg,
    output wire [2:0]             CPU_MemDataType,
    output wire                   CPU_ALUSrc1, 
    output wire                   CPU_ALUSrc2,
    output wire [1:0]             CPU_PCSrc,        // Note: From EX Stage (Calculated)

    // --- Surgical Debug Signals (Intricate Details) ---
    
    // MAC Extension Debug
    output wire [DATA_WIDTH-1:0]  CPU_MAC_Accumulator, // The actual value entering the adder (EX_Op3)
    output wire                   CPU_MAC_Active,      // Is a MAC executing right now?
    
    // Hazard & Stall Debug
    output wire                   CPU_Stall_Divider,   // Is the Divider FSM freezing the pipe?
    output wire                   CPU_Stall_FrontEnd,  // Is the Hazard Unit stopping PC/Fetch?
    output wire                   CPU_Flush_Event,     // Are we flushing due to branch/jump?
    
    // Forwarding Debug
    output wire [1:0]             CPU_FwdC_Sel,        // Critical: Are we forwarding the Accumulator?
    
    output wire TIMING_CHECK_LED
    );
    

    // ===========================================================================
    // Internal Wires (Grouped by Stage)
    // ===========================================================================
    
    // ---------------------------------------------------------------------------
    // IF Stage Signals
    // ---------------------------------------------------------------------------
    (* keep = "true" *) wire [PC_WIDTH-1:0]    PC_Next;       // Origin: PC_Next_Mux         -> Destination: Program_Counter
    (* keep = "true" *) wire [PC_WIDTH-1:0]    PC_Current;    // Origin: Program_Counter     -> Destination: Instruction_Memory, PC_Incrementer, IF/ID_Reg
    (* keep = "true" *) wire [PC_WIDTH-1:0]    PC_Plus_4_IF;  // Origin: PC_Incrementer      -> Destination: PC_Next_Mux, IF/ID_Reg
    (* keep = "true" *) wire [INSTR_WIDTH-1:0] Instr_IF;      // Origin: Instruction_Memory  -> Destination: IF/ID_Reg
    (* keep = "true" *) wire                   PC_Write;      // Origin: Hazard_Detection_Unit -> Destination: Program_Counter (Enable)
    
    // ---------------------------------------------------------------------------
    // IF/ID Pipeline Register Outputs (Wires emerging in ID Stage)
    // ---------------------------------------------------------------------------
    (* keep = "true" *) wire [PC_WIDTH-1:0]    ID_PC;         // Origin: IF/ID_Reg           -> Destination: ID/EX_Reg
    (* keep = "true" *) wire [PC_WIDTH-1:0]    ID_PC_Plus_4;  // Origin: IF/ID_Reg           -> Destination: ID/EX_Reg
    (* keep = "true" *) wire [INSTR_WIDTH-1:0] ID_Instr;      // Origin: IF/ID_Reg           -> Destination: Instruction_Splitter, Imm_Gen
    
    // ---------------------------------------------------------------------------
    // ID Stage Signals
    // ---------------------------------------------------------------------------
    // Splitter Outputs
    (* keep = "true" *) wire [6:0]             ID_Opcode;        // Origin: Instruction_Splitter -> Destination: Control_Unit, ID/EX_Reg
    (* keep = "true" *) wire [6:0]             ID_Funct7;        // Origin: Instruction_Splitter -> Destination: Control_Unit, ID/EX_Reg
    (* keep = "true" *) wire [2:0]             ID_Funct3;        // Origin: Instruction_Splitter -> Destination: Control_Unit, ID/EX_Reg
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] ID_Rs1Addr; // Origin: Instruction_Splitter -> Destination: Register_File, Hazard_Unit, ID/EX_Reg
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] ID_Rs2Addr; // Origin: Instruction_Splitter -> Destination: Register_File, Hazard_Unit, ID/EX_Reg
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] ID_RdAddr;  // Origin: Instruction_Splitter -> Destination: Register_File(Port3), Hazard_Unit, ID/EX_Reg
    
    // Control Unit Outputs
    (* keep = "true" *) wire [2:0]             ID_ALUOp;        // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire                   ID_MDSel;        // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire                   ID_MACSel;       // Origin: Control_Unit -> Destination: ID/EX_Reg, Hazard_Unit
    (* keep = "true" *) wire [2:0]             ID_ImmediateSrc; // Origin: Control_Unit -> Destination: Imm_Gen
    (* keep = "true" *) wire [3:0]             ID_TargetSel;    // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire                   ID_RegWrite;     // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire                   ID_MemRead;      // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire                   ID_MemWrite;     // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire [1:0]             ID_MemToReg;     // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire [2:0]             ID_MemDataType;  // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire                   ID_ALUSrc1;      // Origin: Control_Unit -> Destination: ID/EX_Reg
    (* keep = "true" *) wire                   ID_ALUSrc2;      // Origin: Control_Unit -> Destination: ID/EX_Reg
    
    // Data Path (Operands)
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  ID_Rs1Data;      // Origin: Register_File (Port 1) -> Destination: ID/EX_Reg
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  ID_Rs2Data;      // Origin: Register_File (Port 2) -> Destination: ID/EX_Reg
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  ID_Rs3Data;      // Origin: Register_File (Port 3) -> Destination: ID/EX_Reg (Accumulator Value)
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  ID_Immediate;    // Origin: Imm_Gen                -> Destination: ID/EX_Reg
    
    // Hazard Unit Outputs
    (* keep = "true" *) wire                   IF_ID_Write;     // Origin: Hazard_Detection_Unit -> Destination: IF/ID_Reg (Write Enable)
    (* keep = "true" *) wire                   IF_ID_Flush;     // Origin: Hazard_Detection_Unit -> Destination: IF/ID_Reg (Sync Reset)
    (* keep = "true" *) wire                   ID_EX_Write;     // Origin: Hazard_Detection_Unit -> Destination: ID/EX_Reg (Write Enable)
    (* keep = "true" *) wire                   ID_EX_Flush;     // Origin: Hazard_Detection_Unit -> Destination: ID/EX_Reg (Sync Reset)
    
    // ---------------------------------------------------------------------------
    // ID/EX Pipeline Register Outputs (Wires emerging in EX Stage)
    // ---------------------------------------------------------------------------
    // Control Signals
    (* keep = "true" *) wire [2:0]             EX_ALUOp;        // Origin: ID/EX_Reg -> Destination: ALUControl_Gen
    (* keep = "true" *) wire                   EX_MDSel;        // Origin: ID/EX_Reg -> Destination: ALU_RV32M, ALUSelect_Mux
    (* keep = "true" *) wire                   EX_MACSel;       // Origin: ID/EX_Reg -> Destination: Forwarding_Unit, ALUSelect_Mux
    (* keep = "true" *) wire [3:0]             EX_TargetSel;    // Origin: ID/EX_Reg -> Destination: Target_Controller, Jump_Target_Gen
    (* keep = "true" *) wire                   EX_ALUSrc1;      // Origin: ID/EX_Reg -> Destination: ALU_Input_Selector
    (* keep = "true" *) wire                   EX_ALUSrc2;      // Origin: ID/EX_Reg -> Destination: ALU_Input_Selector
    (* keep = "true" *) wire                   EX_MemRead;      // Origin: ID/EX_Reg -> Destination: EX/MEM_Reg, Hazard_Unit(Feedback)
    (* keep = "true" *) wire                   EX_MemWrite;     // Origin: ID/EX_Reg -> Destination: EX/MEM_Reg
    (* keep = "true" *) wire [2:0]             EX_MemDataType;  // Origin: ID/EX_Reg -> Destination: EX/MEM_Reg
    (* keep = "true" *) wire                   EX_RegWrite;     // Origin: ID/EX_Reg -> Destination: EX/MEM_Reg
    (* keep = "true" *) wire [1:0]             EX_MemToReg;     // Origin: ID/EX_Reg -> Destination: EX/MEM_Reg
    
    // Data Path Signals
    (* keep = "true" *)wire [PC_WIDTH-1:0]    EX_PC;           // Origin: ID/EX_Reg -> Destination: Branch_Target_Gen, ALU_Input_Selector
    (* keep = "true" *)wire [PC_WIDTH-1:0]    EX_PC_Plus_4;    // Origin: ID/EX_Reg -> Destination: Jump_Target_Gen, EX/MEM_Reg
    (* keep = "true" *)wire [DATA_WIDTH-1:0]  EX_Rs1Data;      // Origin: ID/EX_Reg -> Destination: ALU_Input_Selector (via Forwarding Logic)
    (* keep = "true" *)wire [DATA_WIDTH-1:0]  EX_Rs2Data;      // Origin: ID/EX_Reg -> Destination: ALU_Input_Selector (via Forwarding Logic)
    (* keep = "true" *)wire [DATA_WIDTH-1:0]  EX_Rs3Data;      // Origin: ID/EX_Reg -> Destination: ALU_Input_Selector (via Forwarding Logic)
    (* keep = "true" *)wire [DATA_WIDTH-1:0]  EX_Immediate;    // Origin: ID/EX_Reg -> Destination: ALU_Input_Selector, Branch_Target_Gen
    
    // Split Fields
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] EX_Rs1Addr; // Origin: ID/EX_Reg -> Destination: Forwarding_Unit
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] EX_Rs2Addr; // Origin: ID/EX_Reg -> Destination: Forwarding_Unit
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] EX_Rs3Addr; // Origin: ID/EX_Reg -> Destination: Forwarding_Unit
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] EX_RdAddr;  // Origin: ID/EX_Reg -> Destination: EX/MEM_Reg, Hazard_Unit(Feedback)
    (* keep = "true" *) wire [2:0]             EX_Funct3;        // Origin: ID/EX_Reg -> Destination: ALUControl_Gen
    (* keep = "true" *) wire [6:0]             EX_Funct7;        // Origin: ID/EX_Reg -> Destination: ALUControl_Gen
    (* keep = "true" *) wire [6:0]             EX_Opcode;        // Origin: ID/EX_Reg -> Destination: ALUControl_Gen
    
    // ---------------------------------------------------------------------------
    // EX Stage Signals
    // ---------------------------------------------------------------------------
    (* keep = "true" *)wire [5:0]             EX_ALUControl;   // Origin: ALUControl_Gen -> Destination: ALU_RV32I, ALU_RV32M
    (* keep = "true" *)wire [1:0]             EX_ForwardA;     // Origin: Forwarding_Unit -> Destination: ALU_Input_Selector
    (* keep = "true" *)wire [1:0]             EX_ForwardB;     // Origin: Forwarding_Unit -> Destination: ALU_Input_Selector
    (* keep = "true" *)wire [1:0]             EX_ForwardC;     // Origin: Forwarding_Unit -> Destination: ALU_Input_Selector
    
    // ALU Inputs (Post-Mux/Forwarding)
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  EX_Op1;          // Origin: ALU_Input_Selector -> Destination: ALU_RV32I, ALU_RV32M
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  EX_Op2;          // Origin: ALU_Input_Selector -> Destination: ALU_RV32I, ALU_RV32M
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  EX_Op3;          // Origin: ALU_Input_Selector -> Destination: MAC_Adder
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  EX_StoreData;    // Origin: ALU_Input_Selector -> Destination: EX/MEM_Reg
    
    // ALU Outputs
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  Result_I;        // Origin: ALU_RV32I -> Destination: ALUSelect_Mux
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  Result_M;        // Origin: ALU_RV32M -> Destination: ALUSelect_Mux, MAC_Adder
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  MACResult;       // Origin: MAC_Adder -> Destination: ALUSelect_Mux
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  EX_ALUResult;    // Origin: ALUSelect_Mux -> Destination: EX/MEM_Reg, Jump_Target_Gen, Forwarding_Unit (Feedback)
    (* keep = "true" *) wire                   Zero_I;          // Origin: ALU_RV32I -> Destination: ALUSelect_Mux
    (* keep = "true" *) wire                   Zero_M;          // Origin: ALU_RV32M -> Destination: ALUSelect_Mux
    (* keep = "true" *) wire                   EX_Zero;         // Origin: ALUSelect_Mux -> Destination: Target_Controller
    (* keep = "true" *) wire                   EX_Stall_M;      // Origin: ALU_RV32M -> Destination: Hazard_Detection_Unit
    (* keep = "true" *) wire [1:0]             EX_PCSrc;        // Origin: Target_Controller -> Destination: PC_Next_Mux, Hazard_Detection_Unit
    
    // Calculated Targets
    (* keep = "true" *) wire [PC_WIDTH-1:0]    EX_BranchTarget; // Origin: Branch_Target_Gen -> Destination: PC_Next_Mux
    (* keep = "true" *) wire [PC_WIDTH-1:0]    EX_JumpTarget;   // Origin: Jump_Target_Gen -> Destination: PC_Next_Mux
    
    // ---------------------------------------------------------------------------
    // EX/MEM Pipeline Register Outputs (Wires emerging in MEM Stage)
    // ---------------------------------------------------------------------------
    (* keep = "true" *) wire                   MEM_MemRead;      // Origin: EX/MEM_Reg -> Destination: Data_Memory
    (* keep = "true" *) wire                   MEM_MemWrite;     // Origin: EX/MEM_Reg -> Destination: Data_Memory
    (* keep = "true" *) wire                   MEM_RegWrite;     // Origin: EX/MEM_Reg -> Destination: MEM/WB_Reg, Forwarding_Unit(Feedback)
    (* keep = "true" *) wire [1:0]             MEM_MemToReg;     // Origin: EX/MEM_Reg -> Destination: MEM/WB_Reg
    (* keep = "true" *) wire [2:0]             MEM_MemDataType;  // Origin: EX/MEM_Reg -> Destination: Data_Memory
    (* keep = "true" *) wire [PC_WIDTH-1:0]    MEM_PC_Plus_4;    // Origin: EX/MEM_Reg -> Destination: MEM/WB_Reg
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  MEM_ALUResult;    // Origin: EX/MEM_Reg -> Destination: Data_Memory(Address), MEM/WB_Reg, ALU_Input_Selector(Forwarding)
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  MEM_WriteData;    // Origin: EX/MEM_Reg -> Destination: Data_Memory(Data)
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] MEM_RdAddr; // Origin: EX/MEM_Reg -> Destination: MEM/WB_Reg, Forwarding_Unit(Feedback)
    
    // ---------------------------------------------------------------------------
    // MEM Stage Signals
    // ---------------------------------------------------------------------------
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  MEM_ReadData;    // Origin: Data_Memory -> Destination: MEM/WB_Reg
    
    // ---------------------------------------------------------------------------
    // MEM/WB Pipeline Register Outputs (Wires emerging in WB Stage)
    // ---------------------------------------------------------------------------
    (* keep = "true" *) wire                   WB_RegWrite;     // Origin: MEM/WB_Reg -> Destination: Register_File, Forwarding_Unit(Feedback)
    (* keep = "true" *) wire [1:0]             WB_MemToReg;     // Origin: MEM/WB_Reg -> Destination: WriteBack_Mux
    (* keep = "true" *) wire [PC_WIDTH-1:0]    WB_PC_Plus_4;    // Origin: MEM/WB_Reg -> Destination: WriteBack_Mux
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  WB_ALUResult;    // Origin: MEM/WB_Reg -> Destination: WriteBack_Mux
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  WB_ReadData;     // Origin: MEM/WB_Reg -> Destination: WriteBack_Mux
    (* keep = "true" *) wire [$clog2(REG_COUNT)-1:0] WB_RdAddr; // Origin: MEM/WB_Reg -> Destination: Register_File, Forwarding_Unit(Feedback)
    
    // ---------------------------------------------------------------------------
    // WB Stage Signals
    // ---------------------------------------------------------------------------
    (* keep = "true" *) wire [DATA_WIDTH-1:0]  WB_FinalWriteData; // Origin: WriteBack_Mux -> Destination: Register_File, ALU_Input_Selector(Forwarding)

    


    // ===========================================================================
    // Stage I : Instruction Fetch
    // ===========================================================================
    
    // 1. Program Counter
    (* dont_touch = "true" *)
    Program_Counter #(.PC_WIDTH(PC_WIDTH), .PC_STEP(PC_STEP))
    CPU_ProgCount (
        .IF_PC_Next(PC_Next_IF),
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        .IF_PCWrite(PC_Write),      // Controlled by Hazard Unit
        .IF_PC(PC_Current)
    );
    
    // 2. Instruction Memory
    (* dont_touch = "true" *)
    Instruction_Memory #(.PC_WIDTH(PC_WIDTH), .INSTR_WIDTH(INSTR_WIDTH), .IMEM_DEPTH(IMEM_DEPTH))
    CPU_IMEM (
        .PC(PC_Current),
        .Instr_RV32IM(Instr_IF)
    );
    
    // 3. PC Incrementer
    (* dont_touch = "true" *)
    PC_Incrementer #(.PC_WIDTH(PC_WIDTH), .PC_STEP(PC_STEP))
    CPU_PCAdd (
        .PC(PC_Current),
        .PC_Plus_4(PC_Plus_4_IF)
    );
    
    // 4. Next PC Mux (Feedback from EX Stage)
    (* dont_touch = "true" *)
    PC_Next_Mux #(.PC_WIDTH(PC_WIDTH), .WIDTH(DATA_WIDTH))
    CPU_NextPCMux (
        .IF_PC_Plus_4(PC_Plus_4_IF),
        .EX_BranchTarget(EX_BranchTarget),
        .EX_JumpTarget(EX_JumpTarget),
        .EX_PCSrc(EX_PCSrc),     // From Target Controller (EX)
        .IF_PC_Next(PC_Next_IF)
    );



    // ===========================================================================
    // I -> II : IF/ID Pipeline Register
    // ===========================================================================
    
    (* dont_touch = "true" *)
    IF_ID_reg #(.WIDTH(INSTR_WIDTH), .PC_WIDTH(PC_WIDTH))
    CPU_IF_ID_Reg (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        .IF_ID_Flush(IF_ID_Flush), // From Hazard Unit
        .IF_ID_Write(IF_ID_Write), // From Hazard Unit
        .IF_PC(PC_Current),
        .IF_PC_Plus_4(PC_Plus_4_IF),
        .IF_Instruction(Instr_IF),
        .ID_PC(ID_PC),
        .ID_PC_Plus_4(ID_PC_Plus_4),
        .ID_Instruction(ID_Instr)
    );



    // ===========================================================================
    // Stage II : Instruction Decode
    // ===========================================================================

    // 5. Instruction Splitter
    (* dont_touch = "true" *)
    Instruction_Splitter #(.WIDTH(INSTR_WIDTH), .REG_COUNT(REG_COUNT))
    CPU_Splitter (
        .ID_Instruction(ID_Instr),
        .ID_Opcode(ID_Opcode),
        .ID_RdAddr(ID_RdAddr),
        .ID_Funct3(ID_Funct3),
        .ID_Rs1Addr(ID_Rs1Addr),
        .ID_Rs2Addr(ID_Rs2Addr),
        .ID_Funct7(ID_Funct7)
    );

    // 6. Hazard Detection Unit
    (* dont_touch = "true" *)
    Hazard_Detection_Unit #(.REG_COUNT(REG_COUNT))
    CPU_HazardUnit (
        .ID_Rs1Addr(ID_Rs1Addr),
        .ID_Rs2Addr(ID_Rs2Addr),
        .ID_Rs3Addr(ID_RdAddr),    // Accumulator Source is Rd
        .ID_MACSel(ID_MACSel),     // Check if current is MAC
        .EX_MemRead(EX_MemRead),   // Check Load-Use
        .EX_RdAddr(EX_RdAddr),     
        .EX_PCSrc(EX_PCSrc),       // Check Control Hazard
        .EX_ALU_Stall(EX_Stall_M), // Check Divider Stall
        .PC_Write(PC_Write),
        .IF_ID_Write(IF_ID_Write),
        .ID_EX_Write(ID_EX_Write),
        .IF_ID_Flush(IF_ID_Flush),
        .ID_EX_Flush(ID_EX_Flush)
    );

    // 7. Register File (3-Port Read)
    (* dont_touch = "true" *)
    Register_File #(.WIDTH(DATA_WIDTH), .REG_COUNT(REG_COUNT))
    CPU_RegFile (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        .RegWrite(WB_RegWrite),    // From WB Stage
        .WriteAddr(WB_RdAddr),     // From WB Stage
        .WriteData(WB_FinalWriteData), // From WB Stage
        .ReadAddr1(ID_Rs1Addr),
        .ReadAddr2(ID_Rs2Addr),
        .ReadAddr3(ID_RdAddr),     // Port 3: Read Accumulator
        .ReadData1(ID_Rs1Data),
        .ReadData2(ID_Rs2Data),
        .ReadData3(ID_Rs3Data)     // Accumulator Value
    );

    // 8. Immediate Generator
    (* dont_touch = "true" *)
    Imm_Gen #(.WIDTH(DATA_WIDTH), .INSTR_WIDTH(INSTR_WIDTH))
    CPU_ImmGen (
        .ID_Instruction(ID_Instr),
        .ID_ImmediateSrc(ID_ImmediateSrc),
        .ID_Immediate(ID_Immediate)
    );

    // 9. Control Unit
    (* dont_touch = "true" *)
    Control_Unit #(.WIDTH(DATA_WIDTH), .INSTR_WIDTH(INSTR_WIDTH))
    CPU_Control (
        .ID_Opcode(ID_Opcode),
        .ID_Funct3(ID_Funct3),
        .ID_Funct7(ID_Funct7),
        .ID_ALUOp(ID_ALUOp),
        .ID_MDSel(ID_MDSel),
        .ID_MACSel(ID_MACSel),
        .ID_TargetSel(ID_TargetSel),
        .ID_ALUSrc1(ID_ALUSrc1),
        .ID_ALUSrc2(ID_ALUSrc2),
        .ID_MemRead(ID_MemRead),
        .ID_MemWrite(ID_MemWrite),
        .ID_MemDataType(ID_MemDataType),
        .ID_RegWrite(ID_RegWrite),
        .ID_MemToReg(ID_MemToReg),
        .ID_ImmediateSrc(ID_ImmediateSrc)
    );



    // ===========================================================================
    // II -> III : ID/EX Pipeline Register
    // ===========================================================================
    
    (* dont_touch = "true" *)
    ID_EX_reg #(.WIDTH(DATA_WIDTH), .PC_WIDTH(PC_WIDTH), .REG_COUNT(REG_COUNT))
    CPU_ID_EX_Reg (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        .ID_EX_Flush(ID_EX_Flush),
        .ID_EX_Write(ID_EX_Write),
        // Inputs
        .ID_ALUOp(ID_ALUOp), .ID_MDSel(ID_MDSel), .ID_MACSel(ID_MACSel),
        .ID_TargetSel(ID_TargetSel), .ID_ALUSrc1(ID_ALUSrc1), .ID_ALUSrc2(ID_ALUSrc2),
        .ID_MemRead(ID_MemRead), .ID_MemWrite(ID_MemWrite), .ID_MemDataType(ID_MemDataType),
        .ID_RegWrite(ID_RegWrite), .ID_MemToReg(ID_MemToReg),
        .ID_PC(ID_PC), .ID_PC_Plus_4(ID_PC_Plus_4),
        .ID_Rs1Data(ID_Rs1Data), .ID_Rs2Data(ID_Rs2Data), .ID_RdData(ID_Rs3Data), .ID_Immediate(ID_Immediate),
        .ID_Rs1Addr(ID_Rs1Addr), .ID_Rs2Addr(ID_Rs2Addr), .ID_Rs3Addr(ID_RdAddr), .ID_RdAddr(ID_RdAddr),
        .ID_Funct3(ID_Funct3), .ID_Funct7(ID_Funct7), .ID_Opcode(ID_Opcode),
        // Outputs
        .EX_ALUOp(EX_ALUOp), .EX_MDSel(EX_MDSel), .EX_MACSel(EX_MACSel),
        .EX_TargetSel(EX_TargetSel), .EX_ALUSrc1(EX_ALUSrc1), .EX_ALUSrc2(EX_ALUSrc2),
        .EX_MemRead(EX_MemRead), .EX_MemWrite(EX_MemWrite), .EX_MemDataType(EX_MemDataType),
        .EX_RegWrite(EX_RegWrite), .EX_MemToReg(EX_MemToReg),
        .EX_PC(EX_PC), .EX_PC_Plus_4(EX_PC_Plus_4),
        .EX_Rs1Data(EX_Rs1Data), .EX_Rs2Data(EX_Rs2Data), .EX_RdData(EX_Rs3Data), .EX_Immediate(EX_Immediate),
        .EX_Rs1Addr(EX_Rs1Addr), .EX_Rs2Addr(EX_Rs2Addr), .EX_Rs3Addr(EX_Rs3Addr), .EX_RdAddr(EX_RdAddr),
        .EX_Funct3(EX_Funct3), .EX_Funct7(EX_Funct7), .EX_Opcode(EX_Opcode)
    );



    // ===========================================================================
    // Stage III : Execute
    // ===========================================================================

    // 10. ALU Control Generator
    (* dont_touch = "true" *)
    ALUControl_Gen 
    CPU_ALUCtrlGen (
        .EX_ALUOp(EX_ALUOp),
        .EX_MACSel(EX_MACSel),
        .EX_Funct3(EX_Funct3),
        .EX_Funct7(EX_Funct7),
        .EX_Opcode(EX_Opcode),
        .EX_ALUControl(EX_ALUControl)
    );

    // 11. Forwarding Unit
    (* dont_touch = "true" *)
    Forwarding_Unit #(.REG_COUNT(REG_COUNT))
    CPU_Forwarding (
        .EX_Rs1Addr(EX_Rs1Addr),
        .EX_Rs2Addr(EX_Rs2Addr),
        .EX_Rs3Addr(EX_Rs3Addr),
        .EX_MACSel(EX_MACSel),
        .MEM_RegWrite(MEM_RegWrite), // From EX/MEM
        .MEM_RdAddr(MEM_RdAddr),     // From EX/MEM
        .WB_RegWrite(WB_RegWrite),   // From MEM/WB
        .WB_RdAddr(WB_RdAddr),       // From MEM/WB
        .EX_ForwardA(EX_ForwardA),
        .EX_ForwardB(EX_ForwardB),
        .EX_ForwardC(EX_ForwardC)
    );

    // 12. ALU Input Selector (Muxes & Forwarding)
    (* dont_touch = "true" *)
    ALU_Input_Selector #(.WIDTH(DATA_WIDTH), .PC_WIDTH(PC_WIDTH))
    CPU_ALUInputSel (
        .EX_Rs1Data(EX_Rs1Data),
        .EX_Rs2Data(EX_Rs2Data),
        .EX_PC(EX_PC),
        .EX_Imm(EX_Immediate),
        .EX_RdData_MAC(EX_Rs3Data),
        .MEM_ForwardData(MEM_ALUResult),     // Forward from MEM
        .WB_ForwardData(WB_FinalWriteData),  // Forward from WB
        .EX_ALUSrc1(EX_ALUSrc1),
        .EX_ALUSrc2(EX_ALUSrc2),
        .EX_ForwardA(EX_ForwardA),
        .EX_ForwardB(EX_ForwardB),
        .EX_ForwardC(EX_ForwardC),
        .EX_Op1(EX_Op1),
        .EX_Op2(EX_Op2),
        .EX_Op3(EX_Op3),      // Forwarded Accumulator
        .EX_StoreData(EX_StoreData) // Forwarded Store Data
    );

    // 13. ALU RV32I
    (* dont_touch = "true" *)
    ALU_RV32I #(.WIDTH(DATA_WIDTH))
    CPU_ALU_I (
        .EX_Op1(EX_Op1),
        .EX_Op2(EX_Op2),
        .EX_ALUControl(EX_ALUControl),
        .EX_MDSel(EX_MDSel),
        .EX_ALUResult_I(Result_I),
        .EX_Zero_I(Zero_I)
    );

    // 14. ALU RV32M
    (* dont_touch = "true" *)
    ALU_RV32M #(.WIDTH(DATA_WIDTH))
    CPU_ALU_M (
        .clk(CPU_clk),
        .rst_n(CPU_rst_n),
        .EX_Op1(EX_Op1),
        .EX_Op2(EX_Op2),
        .EX_ALUControl(EX_ALUControl),
        .EX_MDSel(EX_MDSel),
        .EX_ALUResult_M(Result_M), // Product or Quotient
        .EX_Zero_M(Zero_M),
        .EX_Stall_M(EX_Stall_M)
    );

    // 15. MAC Accumulator
    (* dont_touch = "true" *)
    Accumulator #(.WIDTH(DATA_WIDTH))
    CPU_Accumulator (
        .Product(Result_M),
        .Accumulator_Val(EX_Op3),
        .MAC_Result(MACResult)
    );

    // 16. ALU Select Mux (Final EX Result)
    (* dont_touch = "true" *)
    ALUSelect_Mux #(.WIDTH(DATA_WIDTH))
    CPU_ALUSelMux (
        .EX_ALUResult_I(Result_I),
        .EX_ALUResult_M(Result_M),
        .EX_MACResult(MACResult),
        .EX_Zero_I(Zero_I),
        .EX_Zero_M(Zero_M),
        .EX_MDSel(EX_MDSel),
        .EX_MACSel(EX_MACSel),
        .EX_ALUResult(EX_ALUResult),
        .EX_Zero(EX_Zero)
    );

    // 17. Target Controller (Branch Decision)
    (* dont_touch = "true" *)
    Target_Controller 
    CPU_TrCtrl (
        .EX_TargetSel(EX_TargetSel),
        .EX_Zero(EX_Zero),
        .EX_PCSrc(EX_PCSrc)
    );

    // 18. Branch Target Generator
    (* dont_touch = "true" *)
    Branch_Target_Gen #(.WIDTH(DATA_WIDTH), .PC_WIDTH(PC_WIDTH))
    CPU_BrTargetGen (
        .EX_Immediate(EX_Immediate),
        .EX_PC(EX_PC),
        .EX_BranchTarget(EX_BranchTarget)
    );

    // 19. Jump Target Generator
    (* dont_touch = "true" *)
    Jump_Target_Gen #(.WIDTH(DATA_WIDTH), .PC_WIDTH(PC_WIDTH))
    CPU_JumpTargetGen (
        .EX_ALUResult(EX_ALUResult),
        .EX_TargetSel(EX_TargetSel),
        .EX_PC_Plus_4(EX_PC_Plus_4),
        .EX_JumpTarget(EX_JumpTarget)
    );



    // ===========================================================================
    // III -> IV : EX/MEM Pipeline Register
    // ===========================================================================

    (* dont_touch = "true" *)
    EX_MEM_reg #(.WIDTH(DATA_WIDTH), .PC_WIDTH(PC_WIDTH), .REG_COUNT(REG_COUNT))
    CPU_EX_MEM_Reg (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        // Inputs
        .EX_MemRead(EX_MemRead), .EX_MemWrite(EX_MemWrite), .EX_MemDataType(EX_MemDataType),
        .EX_RegWrite(EX_RegWrite), .EX_MemToReg(EX_MemToReg),
        .EX_PC_Plus_4(EX_PC_Plus_4),
        .EX_ALUResult(EX_ALUResult),
        .EX_Rs2Data(EX_StoreData), // Forwarded store data
        .EX_RdAddr(EX_RdAddr),
        // Outputs
        .MEM_MemRead(MEM_MemRead), .MEM_MemWrite(MEM_MemWrite), .MEM_MemDataType(MEM_MemDataType),
        .MEM_RegWrite(MEM_RegWrite), .MEM_MemToReg(MEM_MemToReg),
        .MEM_PC_Plus_4(MEM_PC_Plus_4),
        .MEM_ALUResult(MEM_ALUResult),
        .MEM_WriteData(MEM_WriteData),
        .MEM_RdAddr(MEM_RdAddr)
    );



    // ===========================================================================
    // Stage IV : Memory Access
    // ===========================================================================

    // 20. Data Memory
    (* dont_touch = "true" *)
    Data_Memory #(.WIDTH(DATA_WIDTH), .DMEM_DEPTH(DMEM_DEPTH))
    CPU_DMEM (
        .CPU_clk(CPU_clk),
        .MEM_MemWrite(MEM_MemWrite),
        .MEM_MemRead(MEM_MemRead),
        .MEM_MemDataType(MEM_MemDataType),
        .MEM_ALUResult(MEM_ALUResult),
        .MEM_WriteData(MEM_WriteData),
        .MEM_ReadData(MEM_ReadData)
    );



    // ===========================================================================
    // IV -> V : MEM/WB Pipeline Register
    // ===========================================================================

    (* dont_touch = "true" *)
    MEM_WB_reg #(.WIDTH(DATA_WIDTH), .PC_WIDTH(PC_WIDTH), .REG_COUNT(REG_COUNT))
    CPU_MEM_WB_Reg (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        // Inputs
        .MEM_RegWrite(MEM_RegWrite), .MEM_MemToReg(MEM_MemToReg),
        .MEM_PC_Plus_4(MEM_PC_Plus_4),
        .MEM_ALUResult(MEM_ALUResult),
        .MEM_ReadData(MEM_ReadData),
        .MEM_RdAddr(MEM_RdAddr),
        // Outputs
        .WB_RegWrite(WB_RegWrite), .WB_MemToReg(WB_MemToReg),
        .WB_PC_Plus_4(WB_PC_Plus_4),
        .WB_ALUResult(WB_ALUResult),
        .WB_ReadData(WB_ReadData),
        .WB_RdAddr(WB_RdAddr)
    );



    // ===========================================================================
    // Stage V : Writeback
    // ===========================================================================

    // 21. WriteBack Mux
    (* dont_touch = "true" *)
    WriteBack_Mux #(.WIDTH(DATA_WIDTH), .PC_WIDTH(PC_WIDTH))
    CPU_WrBackMux (
        .WB_ALUResult(WB_ALUResult),
        .WB_ReadData(WB_ReadData),
        .WB_PC_Plus_4(WB_PC_Plus_4),
        .WB_MemToReg(WB_MemToReg),
        .WB_WriteData(WB_FinalWriteData)
    );

    // ===========================================================================
    // Debug Output Assignments (Pipeline Mapping)
    // ===========================================================================
    
    // --- Data Path States ---
    assign CPU_PC            = PC_Current;      // IF Stage: What are we fetching now?
    assign CPU_Instr_RV32IM  = ID_Instr;        // ID Stage: What are we decoding?
    assign CPU_Immediate     = ID_Immediate;    // ID Stage: What is the immediate?
    
    assign CPU_ALUResult     = EX_ALUResult;    // EX Stage: What did we just calculate?
    assign CPU_ALUControl    = EX_ALUControl;   // EX Stage: What op is the ALU doing?
    assign CPU_Zero          = EX_Zero;         // EX Stage: Did we hit zero?
    
    assign CPU_ReadData      = MEM_ReadData;    // MEM Stage: What came out of memory?
    assign CPU_WriteDataReg  = WB_FinalWriteData; // WB Stage: What is finally written to RegFile?
    
    // --- Control Signals (Visualizing the Control Unit in ID) ---
    assign CPU_ALUOp         = ID_ALUOp;
    assign CPU_MDSel         = ID_MDSel;
    assign CPU_ImmediateSrc  = ID_ImmediateSrc;
    assign CPU_TargetSel     = ID_TargetSel;
    assign CPU_RegWrite      = ID_RegWrite;
    assign CPU_MemRead       = ID_MemRead;
    assign CPU_MemWrite      = ID_MemWrite;
    assign CPU_MemToReg      = ID_MemToReg;
    assign CPU_MemDataType   = ID_MemDataType;
    assign CPU_ALUSrc1       = ID_ALUSrc1;
    assign CPU_ALUSrc2       = ID_ALUSrc2;
    
    // Exception: PCSrc is calculated in EX, not ID
    assign CPU_PCSrc         = EX_PCSrc;  

    // MAC Debug: Verify the 3rd Operand path
    assign CPU_MAC_Accumulator = EX_Op3;      // Verify this matches the previous instruction's result!
    assign CPU_MAC_Active      = EX_MACSel;
    
    // Stall Debug: Differentiate between "Load-Use" and "Divider" stalls
    assign CPU_Stall_Divider   = EX_Stall_M;  // High during multi-cycle divide
    assign CPU_Stall_FrontEnd  = ~PC_Write;   // High if PC is frozen for ANY reason
    assign CPU_Flush_Event     = ID_EX_Flush; // High if we are killing the EX instruction
    
    // Forwarding Debug: Verify Rs3 (Accumulator) forwarding logic
    assign CPU_FwdC_Sel        = EX_ForwardC; // Should be non-zero during back-to-back MACs
    
    // Timing Check
    assign TIMING_CHECK_LED  = ^EX_ALUResult ^ ^MEM_ReadData ^ ^WB_FinalWriteData;

endmodule  