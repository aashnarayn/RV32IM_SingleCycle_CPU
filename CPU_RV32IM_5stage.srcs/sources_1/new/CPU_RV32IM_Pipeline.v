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

/* 
 * ===================================================================================
 * ARCHITECTURE OVERVIEW
 * ===================================================================================
 * ISA:             RISC-V RV32IM + Custom MAC/MACI Extensions
 * Pipeline Depth:  5 Stages (IF, ID, EX, MEM, WB)
 * Target Fabric:   Xilinx Artix-7
 * Max Frequency:   70 MHz (Fmax bounded by IF_BRAM T_co + ID_Comparator Logic)
 * IPC Baseline:    ~1.0 (approaching 1.0 for linear execution, degraded by stalls)
 * * ===================================================================================
 * PERFORMANCE & TIMING MATRIX
 * ===================================================================================
 * The CPU achieves timing closure at 70 MHz (14.28ns period) through aggressive 
 * datapath pruning. The Fmax is strictly hard-capped by the critical path: 
 * [BRAM Clock-to-Out -> Instruction Decode -> Fast-Path Forwarding Mux -> 
 * 32-bit Magnitude Comparator -> Hazard Decision Matrix -> ID_PCSrc_Reg].
 * * To hit >100MHz, the IF BRAM output must be registered, forcing a 6-stage 
 * pipeline design, which was deliberately avoided here to maintain true 5-stage 
 * RISC-V semantics and minimal IPC penalty.
 *
 * Branch Penalty:      2 Cycles (Branch decisions are registered to break synth loops)
 * Load-Use Penalty:    1 Cycle Stall
 * M-Ext Mul Penalty:   2 Cycles (Pipelined)
 * M-Ext Div Penalty:   Multi-cycle (Stalls entire pipeline via EX_Stall_M)
 *
 * ===================================================================================
 * CORE MICROARCHITECTURAL DECISIONS
 * ===================================================================================
 * 1. SYNCHRONOUS BRAM BOUNDARIES (The "Fake" IF/ID Register)
 * The Instruction Memory acts as the IF/ID register. It uses a synchronous read, 
 * meaning the address is provided in IF, and the data physically emerges during 
 * the ID cycle. To prevent synthesis tools from inferring combinational loops 
 * (Synth 8-295/326), hazard flush/stall logic is derived from "Raw Taps" 
 * directly off the BRAM output, isolating control generation from its own effects.
 *
 * 2. EXTERNAL "FAST-PATH" FORWARDING (ID STAGE)
 * Standard architectures place forwarding muxes inside the Register File. 
 * This design extracts them. WB-to-ID forwarding happens via external muxes 
 * (ID_Rs1_Fast, ID_Rs2_Fast) placed immediately before the Branch Comparator. 
 * This bypasses LUTRAM read-port delays, shaving ~4ns off the critical path.
 *
 * 3. DYNAMIC CARRY-CHAIN TRUNCATION (TARGET GENERATION)
 * Jump and Branch target adders do not compute 32 bits. They calculate their 
 * width dynamically using `$clog2(IMEM_DEPTH * 4)`. For a 256-word IMEM, 
 * the 32-bit adders are violently amputated down to 10 bits. This removes 
 * 22 bits of ripple-carry propagation delay and prevents the synthesizer 
 * from wasting routing resources on dead logic. Unused bits are sunk logically 
 * to satisfy linter constraints without generating silicon.
 *
 * 4. LATE-MUXING
 * Target addresses (JAL vs JALR) are computed in parallel immediately upon 
 * instruction fetch. The multiplexer sits at the output of the adders rather 
 * than the input. This hides the mux routing delay behind the adder latency.
 *
 * 5. HARDENED DECISION REGISTERS
 * Branch taken flags and target addresses are latched at the end of the ID stage 
 * into `ID_PCSrc_Reg` and `ID_Target_Reg`. This breaks the massive cross-stage 
 * combinational loop that naturally forms when early branch resolution is tied 
 * to synchronous memory fetches.
 *
 * ===================================================================================
 * CUSTOM MAC EXTENSION (Multiply-Accumulate)
 * ===================================================================================
 * Hardware Support for DSP-like operations. 
 * - Opcodes: MAC (Register-Register), MACI (Register-Immediate)
 * - Data Path: Uses the RV32M pipelined multiplier. The 3rd read port of the 
 * Register File (Rs3Addr implicitly mapped) pulls the current accumulator value.
 * EX_Forwarding_Unit provides a dedicated 3rd forwarding path (EX_ForwardC) 
 * to ensure the accumulator is continuously fed back without structural hazards 
 * during tight DSP loops.
 * * ===================================================================================
 * KNOWN LIMITATIONS / BOTTLENECKS
 * ===================================================================================
 * - ID_Branch_Comparator: The 32-bit equality/magnitude comparator in the ID 
 * stage is the heaviest logic block remaining. 
 * - Routing Congestion: Due to the high fanout of the forwarded signals, Net Delay 
 * constitutes >50% of the critical path delay. Floorplanning or `ExtraTimingOpt` 
 * directives are mandatory for stable implementation.
 * ===================================================================================
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
    output wire                   CPU_Eq,           // Comparison sigal
    output wire                   CPU_Lt,           // Comparison sigal
    output wire                   CPU_Ltu,          // Comparison sigal
    output wire [DATA_WIDTH-1:0]  CPU_ReadData,     // Memory Read Data (MEM)
    output wire [DATA_WIDTH-1:0]  CPU_WriteDataReg, // Final WriteBack Data (WB)
    
    // --- Control Signals (From ID Stage - Decode Verification) ---
    output wire [2:0]             CPU_ALUOp,
    output wire                   CPU_MDSel,
    output wire                   CPU_MacSel,
    output wire [2:0]             CPU_ImmediateSrc,
    output wire [3:0]             CPU_TargetSel,
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
    output wire                   CPU_Stalled,         // Is the Hazard Unit stopping PC/Fetch?
    output wire                   CPU_Flush_Event,     // Are we flushing due to branch/jump?
    
    // Forwarding Debug
    output wire [1:0]             CPU_FwdC_Sel         // Critical: Are we forwarding the Accumulator?
    );

    
    
    // ===========================================================================
    // Reset Synchronization
    // ===========================================================================
    
    wire CPU_sync_rst_n; // Use THIS wire for all 24 modules below
    
    Reset_Synchronizer CPU_RstSync (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),      // Connect to the raw input port
        .CPU_sync_rst_n(CPU_sync_rst_n) // Connect to the internal wire
    );



    // ===========================================================================
    // Internal Wires (Grouped by Stage)
    // ===========================================================================
    
    // ---------------------------------------------------------------------------
    // IF Stage Signals
    // ---------------------------------------------------------------------------
    wire [PC_WIDTH-1:0]    IF_PC_Next;      // Origin: IF_PC_Next_Mux         -> Dest: IF_Program_Counter
    wire [PC_WIDTH-1:0]    IF_PC_Current;   // Origin: IF_Program_Counter     -> Dest: IF_Instruction_Memory, IF_PC_Incrementer, IF_ID_Reg
    wire [PC_WIDTH-1:0]    IF_PC_Plus_4;    // Origin: IF_PC_Incrementer      -> Dest: IF_PC_Next_Mux, IF_ID_Reg
    wire [INSTR_WIDTH-1:0] IF_Instr;        // Origin: IF_Instruction_Memory  -> Dest: IF_ID_Reg (Bypass wire)
    wire                   IF_PCWrite;      // Origin: ID_Hazard_Detector     -> Dest: IF_Program_Counter (Enable)
    
    // ---------------------------------------------------------------------------
    // ID Stage Signals (Emerging from IF/ID_Reg and local logic)
    // ---------------------------------------------------------------------------
    wire [PC_WIDTH-1:0]    ID_PC;           // Origin: IF_ID_Reg               -> Dest: ID_Branch_Target_Gen, ID_Jump_Target_Gen, ID_EX_Reg
    wire [PC_WIDTH-1:0]    ID_PC_Plus_4;    // Origin: IF_ID_Reg               -> Dest: ID_Jump_Target_Gen, ID_EX_Reg
    wire [INSTR_WIDTH-1:0] ID_Instr;        // Origin: IF_ID_Reg (Bypass)      -> Dest: ID_Instruction_Splitter                             


    // Splitter Outputs
    // Control and Function Fields
    wire [6:0]                   ID_Opcode;       // Origin: ID_Instruction_Splitter -> Destination: ID_Control_Unit, ID_Hazard_Detector, ID_EX_Reg
    wire [6:0]                   ID_Funct7;       // Origin: ID_Instruction_Splitter -> Destination: ID_Control_Unit, ID_EX_Reg
    wire [2:0]                   ID_Funct3;       // Origin: ID_Instruction_Splitter -> Destination: ID_Control_Unit, ID_Branch_Comparator, ID_EX_Reg
    
    // Register Address Fields
    wire [$clog2(REG_COUNT)-1:0] ID_Rs1Addr;      // Origin: ID_Instruction_Splitter -> Destination: ID_Register_File (Port 1), ID_Hazard_Detector, ID_EX_Reg
    wire [$clog2(REG_COUNT)-1:0] ID_Rs2Addr;      // Origin: ID_Instruction_Splitter -> Destination: ID_Register_File (Port 2), ID_Hazard_Detector, ID_EX_Reg
    
    // MAC Accumulator Source (Physical tap on Instr[11:7])
    wire [$clog2(REG_COUNT)-1:0] ID_Rs3Addr;      // Origin: ID_Instruction_Splitter -> Destination: ID_Register_File (Port 3), ID_Hazard_Detector, ID_EX_Reg
    
    // Write-Back Destination (Physical tap on Instr[11:7])
    wire [$clog2(REG_COUNT)-1:0] ID_RdAddr;       // Origin: ID_Instruction_Splitter -> Destination: ID_EX_Reg (for WB Propagation)
    
    // Control Unit Outputs
    wire [2:0]             ID_ALUOp;        // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg
    wire                   ID_MDSel;        // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg
    wire                   ID_MACSel;       // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg, ID_Hazard_Detector
    wire [2:0]             ID_ImmediateSrc; // Origin: ID_Control_Unit         -> Dest: ID_Imm_Gen
    wire [3:0]             ID_TargetSel;    // Origin: ID_Control_Unit         -> Dest: ID_Target_Controller, ID_Jump_Target_Gen
    wire                   ID_RegWrite;     // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg
    wire                   ID_MemRead;      // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg
    wire                   ID_MemWrite;     // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg
    wire [1:0]             ID_MemToReg;     // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg
    wire [2:0]             ID_MemDataType;  // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg
    wire                   ID_ALUSrc1;      // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg
    wire                   ID_ALUSrc2;      // Origin: ID_Control_Unit         -> Dest: ID_EX_Reg

    // Data Path & Comparator
    wire [DATA_WIDTH-1:0]  ID_Rs1Data;      // Origin: ID_Register_File        -> Dest: ID_Branch_Comparator, ID_Jump_Target_Gen, ID_EX_Reg
    wire [DATA_WIDTH-1:0]  ID_Rs2Data;      // Origin: ID_Register_File        -> Dest: ID_Branch_Comparator, ID_EX_Reg
    wire [DATA_WIDTH-1:0]  ID_RdData;       // Origin: ID_Register_File        -> Dest: ID_EX_Reg
    wire [DATA_WIDTH-1:0]  ID_Immediate;    // Origin: ID_Imm_Gen              -> Dest: ID_Branch_Target_Gen, ID_Jump_Target_Gen, ID_EX_Reg
    wire                   ID_Eq, ID_Lt, ID_Ltu; // Origin: ID_Branch_Comparator -> Dest: ID_Target_Controller

    // Early Target Resolution (ID Stage)
    wire [1:0]             ID_PCSrc;        // Origin: ID_Target_Controller    -> Dest: IF_PC_Next_Mux, ID_Hazard_Detector
    wire [PC_WIDTH-1:0]    ID_BranchTarget; // Origin: ID_Branch_Target_Gen    -> Dest: IF_PC_Next_Mux
    wire [PC_WIDTH-1:0]    ID_JumpTarget;   // Origin: ID_Jump_Target_Gen      -> Dest: IF_PC_Next_Mux

    // Hazard Unit Outputs
    wire                   IF_ID_Write;     // Origin: ID_Hazard_Detector      -> Dest: IF_ID_Reg, IF_Instruction_Memory
    wire                   IF_ID_Flush;     // Origin: ID_Hazard_Detector      -> Dest: IF_ID_Reg
    wire                   ID_EX_Write;     // Origin: ID_Hazard_Detector      -> Dest: ID_EX_Reg
    wire                   ID_EX_Flush;     // Origin: ID_Hazard_Detector      -> Dest: ID_EX_Reg
    
    // ---------------------------------------------------------------------------
    // EX Stage Signals (Emerging from ID/EX_Reg)
    // ---------------------------------------------------------------------------
    wire [2:0]             EX_ALUOp;        
    wire                   EX_MDSel, EX_MACSel, EX_ALUSrc1, EX_ALUSrc2;
    wire                   EX_MemRead, EX_MemWrite; // Dest: MEM_Data_Memory (Bypasses EX_MEM_Reg)
    wire [2:0]             EX_MemDataType;          // Dest: MEM_Data_Memory (Bypasses EX_MEM_Reg)
    wire                   EX_RegWrite;     
    wire [1:0]             EX_MemToReg;     
    wire [PC_WIDTH-1:0]    EX_PC, EX_PC_Plus_4;    
    wire [DATA_WIDTH-1:0]  EX_Rs1Data, EX_Rs2Data, EX_RdData, EX_Immediate;    
    wire [$clog2(REG_COUNT)-1:0] EX_Rs1Addr, EX_Rs2Addr, EX_Rs3Addr, EX_RdAddr;
    wire [2:0]             EX_Funct3;
    wire [6:0]             EX_Funct7, EX_Opcode;
    
    // Forwarding Control
    wire [1:0]             EX_ForwardA, EX_ForwardB, EX_ForwardC; // Origin: EX_Forwarding_Unit -> Dest: EX_ALU_Input_Sel
    
    // ALU Input/Output
    wire [5:0]             EX_ALUControl;   // Origin: EX_ALU_Control
    wire [DATA_WIDTH-1:0]  EX_Op1, EX_Op2, EX_Op3, EX_StoreData; 
    wire [DATA_WIDTH-1:0]  Result_I, Result_M, MACResult, EX_ALUResult;
    wire                   EX_Stall_M;      // Origin: EX_ALU_RV32M -> Dest: ID_Hazard_Detector, EX_MEM_Reg

    // ---------------------------------------------------------------------------
    // MEM Stage Signals (Emerging from EX/MEM_Reg and BRAM)
    // ---------------------------------------------------------------------------
    wire                   MEM_RegWrite;     
    wire [1:0]             MEM_MemToReg;     
    wire [PC_WIDTH-1:0]    MEM_PC_Plus_4;    
    wire [DATA_WIDTH-1:0]  MEM_ALUResult;    // Origin: EX_MEM_Reg -> Dest: MEM_WB_Reg
    wire [$clog2(REG_COUNT)-1:0] MEM_RdAddr;
    wire [DATA_WIDTH-1:0]  MEM_ReadData;    // Origin: MEM_Data_Memory -> Dest: MEM_WB_Reg
    
    // ---------------------------------------------------------------------------
    // WB Stage Signals (Emerging from MEM/WB_Reg and Mux)
    // ---------------------------------------------------------------------------
    wire                   WB_RegWrite;     
    wire [1:0]             WB_MemToReg;     
    wire [PC_WIDTH-1:0]    WB_PC_Plus_4;    
    wire [DATA_WIDTH-1:0]  WB_ALUResult, WB_ReadData;
    wire [$clog2(REG_COUNT)-1:0] WB_RdAddr;       
    wire [DATA_WIDTH-1:0]  WB_FinalWriteData; // Origin: WB_WriteBack_Mux -> Dest: ID_Register_File, EX_ALU_Input_Sel



    // ===========================================================================
    // Stage I : Instruction Fetch (IF)
    // ===========================================================================
    
    // 1. Program Counter
    // Holds the address of the current instruction. 
    // Synchronous update is controlled by the Hazard Unit (IF_PCWrite).
    IF_Program_Counter #(
        .PC_WIDTH(PC_WIDTH), 
        .PC_STEP(PC_STEP)
    ) CPU_ProgCount (
        .IF_PC_Next     (IF_PC_Next),       // Feedback from ID Stage Mux
        .CPU_clk        (CPU_clk),
        .CPU_rst_n      (CPU_sync_rst_n),
        .IF_PCWrite     (IF_PCWrite),       // Origin: ID_Hazard_Detector
        .IF_PC          (IF_PC_Current)     // Current Instruction Address
    );
    
    // 2. Instruction Memory (Synchronous BRAM)
    // Inferred as Block RAM. The 1-cycle latency means the instruction 
    // physically emerges during the ID clock cycle.
    IF_Instruction_Memory #(
        .PC_WIDTH(PC_WIDTH), 
        .INSTR_WIDTH(INSTR_WIDTH), 
        .IMEM_DEPTH(IMEM_DEPTH)
    ) CPU_IMEM (
        .CPU_clk        (CPU_clk),
        .IF_ID_Write    (IF_ID_Write),     // Acts as BRAM Enable (Stall Control)
        .IF_PC          (IF_PC_Current),   // Address provided in IF stage
        .IF_Instr_RV32IM(IF_Instr)         // Output physically appears in ID
    );
    
    // 3. PC Incrementer
    // Purely combinational +4 adder for sequential execution.
    IF_PC_Incrementer #(
        .PC_WIDTH(PC_WIDTH), 
        .PC_STEP(PC_STEP)
    ) CPU_PCAdd (
        .IF_PC          (IF_PC_Current),
        .IF_PC_Plus_4   (IF_PC_Plus_4)
    );

    // IMPORTANT: Registering the Branch Decision
    reg [1:0] ID_PCSrc_Reg;
    reg [PC_WIDTH-1:0] ID_BTarget_Reg;
    reg [PC_WIDTH-1:0] ID_JTarget_Reg;

    always @(posedge CPU_clk or negedge CPU_sync_rst_n) begin
        if (!CPU_sync_rst_n) begin
            ID_PCSrc_Reg  <= 2'b00;
            ID_BTarget_Reg <= 0;
            ID_JTarget_Reg <= 0;
        end else if (IF_ID_Write) begin // Hold decision if pipe stalls
            ID_PCSrc_Reg  <= ID_PCSrc;
            // Select which target to latch based on PCSrc
            ID_BTarget_Reg <= ID_BranchTarget;
            ID_JTarget_Reg <= ID_JumpTarget;
        end else begin
            ID_PCSrc_Reg  <= 2'b00; // Inject NOP-decision if stalled
        end
    end
    
    // 4. Next PC Mux 
    // Micro-arch Fix: Feedback inputs are sourced from ID Stage logic 
    // to implement 1-cycle early branch resolution.
    IF_PC_Next_Mux #(
        .PC_WIDTH(PC_WIDTH), 
        .WIDTH(DATA_WIDTH)
    ) CPU_NextPCMux (
        .IF_PC_Plus_4   (IF_PC_Plus_4),    // Sequential
        .ID_BranchTarget(ID_BTarget_Reg),  // From top-level register connection
        .ID_JumpTarget  (ID_JTarget_Reg),  // From top-level register connection
        .ID_PCSrc       (ID_PCSrc_Reg),    // From top-level register connection
        .IF_PC_Next     (IF_PC_Next)
    );


    // ===========================================================================
    // I -> II : IF/ID Pipeline Register (Module 5)
    // ===========================================================================
    
    // The instruction wire 'IF_Instr' bypasses the sequential logic in this 
    // register to compensate for the BRAM's internal 1-cycle latency.
    IF_ID_Reg #(
        .WIDTH(INSTR_WIDTH), 
        .PC_WIDTH(PC_WIDTH)
    ) CPU_IF_ID_Reg (
        .CPU_clk        (CPU_clk),
        .CPU_rst_n      (CPU_sync_rst_n),
        .IF_ID_Flush    (IF_ID_Flush),     // High on Branch/Jump Taken
        .IF_ID_Write    (IF_ID_Write),     // Low on Load-Use / Divider Stall
        .IF_PC          (IF_PC_Current),
        .IF_PC_Plus_4   (IF_PC_Plus_4),
        .IF_Instr       (IF_Instr),        // Raw BRAM output
        .ID_PC          (ID_PC),           // Latched PC metadata
        .ID_PC_Plus_4   (ID_PC_Plus_4),    // Latched PC+4 metadata
        .ID_Instr       (ID_Instr)         // NOP-masked instruction wire
    );

        
    // ===========================================================================
    // ID Stage: Structural Extractions (Replaces ID_Instruction_Splitter)
    // ===========================================================================

    // Hazard Unit Inputs 
    // We bypass the Splitter/Reg combination for the Hazard Unit
    wire [4:0] hz_Rs1 = IF_Instr[19:15];        // Origin: IF_Instruction_Memory   -> Dest: ID_Hazard_Detector 
    wire [4:0] hz_Rs2 = IF_Instr[24:20];        // Origin: IF_Instruction_Memory   -> Dest: ID_Hazard_Detector 
    wire [4:0] hz_Rs3 = IF_Instr[11:7];         // Origin: IF_Instruction_Memory   -> Dest: ID_Hazard_Detector 
    wire [6:0] hz_Op  = IF_Instr[6:0];          // Origin: IF_Instruction_Memory   -> Dest: ID_Hazard_Detector 

    wire hz_MACSel = (hz_Op == `OPCODE_MAC);    // Origin: IF_Instruction_Memory   -> Dest: ID_Hazard_Detector

    // REGISTERED TAPS (From IF/ID_Reg - Used for Control Unit and Datapath)
    // These use the 'ID_Instr' wire which is correctly masked/flushed.
    assign ID_Opcode  = ID_Instr[6:0];
    assign ID_Funct3  = ID_Instr[14:12];
    assign ID_Funct7  = ID_Instr[31:25];
    assign ID_Rs1Addr = ID_Instr[19:15];
    assign ID_Rs2Addr = ID_Instr[24:20];
    assign ID_Rs3Addr = ID_Instr[11:7]; // MAC Accumulator Source
    assign ID_RdAddr  = ID_Instr[11:7]; // Destination for WB


    // ===========================================================================
    // Stage II : Instruction Decode (ID)
    // ===========================================================================


    // 6. Control Unit
    // Generates all pipeline signals. Local signals (ImmSrc, TargetSel) stay in ID.
    ID_Control_Unit #(
        .WIDTH(DATA_WIDTH), 
        .INSTR_WIDTH(INSTR_WIDTH)
    ) CPU_Control (
        .ID_Opcode      (ID_Opcode),
        .ID_Funct3      (ID_Funct3),
        .ID_Funct7      (ID_Funct7),
        .ID_ALUOp       (ID_ALUOp),
        .ID_MDSel       (ID_MDSel),
        .ID_MACSel      (ID_MACSel),
        .ID_TargetSel   (ID_TargetSel),
        .ID_ALUSrc1     (ID_ALUSrc1),
        .ID_ALUSrc2     (ID_ALUSrc2),
        .ID_MemRead     (ID_MemRead),
        .ID_MemWrite    (ID_MemWrite),
        .ID_MemDataType (ID_MemDataType),
        .ID_RegWrite    (ID_RegWrite),
        .ID_MemToReg    (ID_MemToReg),
        .ID_ImmediateSrc(ID_ImmediateSrc)
    );

    // 7. Register File (3-Port Read)
    // Micro-arch Fix: Includes internal WB-to-Read forwarding logic.
    ID_Register_File #(
        .WIDTH(DATA_WIDTH), 
        .REG_COUNT(REG_COUNT)
    ) CPU_RegFile (
        .CPU_clk        (CPU_clk),
        .WB_RegWrite    (WB_RegWrite),        // Feedback from WB Stage
        .WB_RdAddr      (WB_RdAddr),         // Feedback from WB Stage
        .WB_WriteData   (WB_FinalWriteData), // Feedback from WB Stage
        .ID_Rs1Addr     (ID_Rs1Addr),
        .ID_Rs2Addr     (ID_Rs2Addr),
        .ID_RdAddr      (ID_Rs3Addr),         // Port 3: Accumulator Read
        .ID_Rs1Data     (ID_Rs1Data),
        .ID_Rs2Data     (ID_Rs2Data),
        .ID_RdData      (ID_RdData)           // Raw Accumulator Value
    );

    // 8. Immediate Generator
    ID_Imm_Gen #(
        .WIDTH(DATA_WIDTH), 
        .INSTR_WIDTH(INSTR_WIDTH)
    ) CPU_ImmGen (
        .ID_Instr_RV32IM(ID_Instr),
        .ID_ImmediateSrc(ID_ImmediateSrc),
        .ID_Immediate   (ID_Immediate)
    );

    // External Branch Forwarding (for Branch Comparator)
    // We bypass the Register File's internal bypass logic to save ~3-4ns.
    // If WB is writing to the same register ID is reading, use WB data directly.
    
    wire [DATA_WIDTH-1:0] ID_Rs1_Fast = (WB_RegWrite && (WB_RdAddr != 0) && (WB_RdAddr == ID_Rs1Addr)) 
                                       ? WB_FinalWriteData 
                                       : ID_Rs1Data;
                                       
    wire [DATA_WIDTH-1:0] ID_Rs2_Fast = (WB_RegWrite && (WB_RdAddr != 0) && (WB_RdAddr == ID_Rs2Addr)) 
                                       ? WB_FinalWriteData 
                                       : ID_Rs2Data;

    // 9. Branch Comparator
    // Lightweight combinational logic for early resolution.
    ID_Branch_Comparator #(
        .WIDTH(DATA_WIDTH)
    ) CPU_BranchComp (
        .ID_Rs1Data     (ID_Rs1_Fast),
        .ID_Rs2Data     (ID_Rs2_Fast),
        .ID_Eq          (ID_Eq),
        .ID_Lt          (ID_Lt),
        .ID_Ltu         (ID_Ltu)
    );

    // 10. Target Controller
    // Finalizes the ID_PCSrc decision (Next, Branch, or Jump).
    ID_Target_Controller CPU_TargetCtrl (
        .ID_TargetSel   (ID_TargetSel),
        .ID_Eq          (ID_Eq),
        .ID_Lt          (ID_Lt),
        .ID_Ltu         (ID_Ltu),
        .ID_PCSrc       (ID_PCSrc)           // Feeds PC_Next_Mux and Hazard Unit
    );

    // 11. Branch Target Generator
    ID_Branch_Target_Gen #(
        .WIDTH(DATA_WIDTH), 
        .PC_WIDTH(PC_WIDTH),
        .IMEM_DEPTH(IMEM_DEPTH)
    ) CPU_BTG (
        .ID_Immediate   (ID_Immediate),
        .ID_PC          (ID_PC),
        .ID_BranchTarget(ID_BranchTarget)
    );

    // 12. Jump Target Generator
    // Dedicated adders to bypass the main EX ALU.
    ID_Jump_Target_Gen #(
        .WIDTH(DATA_WIDTH), 
        .PC_WIDTH(PC_WIDTH),
        .IMEM_DEPTH(IMEM_DEPTH)
    ) CPU_JTG (
        .ID_PC          (ID_PC),
        .ID_Rs1Data     (ID_Rs1_Fast),
        .ID_Immediate   (ID_Immediate),
        .ID_TargetSel   (ID_TargetSel),
        .ID_PC_Plus_4   (ID_PC_Plus_4),
        .ID_JumpTarget  (ID_JumpTarget)
    );

    // 13. Hazard Detection Unit
    // Implements the aggressive 2-cycle stall for branch data hazards.
    ID_Hazard_Detector #(
        .REG_COUNT(REG_COUNT)
    ) CPU_HazardUnit (
        
        // using IF_Instr bits and Opcode directly to avoid timing loop
        .ID_Rs1Addr     (hz_Rs1),
        .ID_Rs2Addr     (hz_Rs2),
        .ID_Rs3Addr     (hz_Rs3),
        .ID_Opcode      (hz_Op),
        .ID_MACSel      (hz_MACSel),   

        // Regular assignment
        .ID_PCSrc       (ID_PCSrc_Reg),      // Control hazard detection (from top-level register)
        .EX_MemRead     (EX_MemRead),        // Load-Use detection
        .EX_RdAddr      (EX_RdAddr),
        .EX_RegWrite    (EX_RegWrite),
        .EX_ALU_Stall   (EX_Stall_M),        // Multi-cycle Divider stall
        .MEM_RegWrite   (MEM_RegWrite),      // Branch Data Hazard (MEM stage)
        .MEM_RdAddr     (MEM_RdAddr),
        .PCWrite        (IF_PCWrite),
        .IF_ID_Write    (IF_ID_Write),  // Wire used for unoptimised loop warning
        .ID_EX_Write    (ID_EX_Write),
        .IF_ID_Flush    (IF_ID_Flush),
        .ID_EX_Flush    (ID_EX_Flush)
    );


    // ===========================================================================
    // II -> III : ID/EX Pipeline Register (Module 14)
    // ===========================================================================
    
    // This register captures the decoded instruction state.
    // The "Flush" signal here is triggered by Load-Use hazards or 
    // branch mispredicts to inject a NOP into the Execution stage.
    ID_EX_Reg #(
        .WIDTH        (DATA_WIDTH), 
        .PC_WIDTH     (PC_WIDTH), 
        .REG_COUNT    (REG_COUNT)
    ) CPU_ID_EX_Reg (
        .CPU_clk        (CPU_clk),
        .CPU_rst_n      (CPU_sync_rst_n),
        .ID_EX_Flush    (ID_EX_Flush),     // Origin: ID_Hazard_Detector
        .ID_EX_Write    (ID_EX_Write),     // Origin: ID_Hazard_Detector (Stall)
        
        // --- Control Signals (Input from ID_Control_Unit) ---
        .ID_ALUOp        (ID_ALUOp), 
        .ID_MDSel        (ID_MDSel), 
        .ID_MACSel       (ID_MACSel),
        .ID_ALUSrc1      (ID_ALUSrc1), 
        .ID_ALUSrc2      (ID_ALUSrc2),
        .ID_MemRead      (ID_MemRead), 
        .ID_MemWrite     (ID_MemWrite), 
        .ID_MemDataType  (ID_MemDataType),
        .ID_RegWrite     (ID_RegWrite), 
        .ID_MemToReg     (ID_MemToReg),
        
        // --- Data Path Signals (Input from ID Stage) ---
        .ID_PC           (ID_PC), 
        .ID_PC_Plus_4    (ID_PC_Plus_4),
        .ID_Rs1Data      (ID_Rs1Data), 
        .ID_Rs2Data      (ID_Rs2Data), 
        .ID_RdData       (ID_RdData),      // Accumulator source
        .ID_Immediate    (ID_Immediate),
        
        // --- Split Instruction Fields (Input from ID_Instruction_Splitter) ---
        .ID_Rs1Addr      (ID_Rs1Addr), 
        .ID_Rs2Addr      (ID_Rs2Addr), 
        .ID_Rs3Addr      (ID_Rs3Addr), 
        .ID_RdAddr       (ID_RdAddr),
        .ID_Funct3       (ID_Funct3), 
        .ID_Funct7       (ID_Funct7), 
        .ID_Opcode       (ID_Opcode),
        
        // ================= OUTPUTS (To EX Stage) =================
        
        // --- Control Signals ---
        .EX_ALUOp       (EX_ALUOp), 
        .EX_MDSel       (EX_MDSel), 
        .EX_MACSel      (EX_MACSel),
        .EX_ALUSrc1      (EX_ALUSrc1), 
        .EX_ALUSrc2      (EX_ALUSrc2),
        .EX_MemRead      (EX_MemRead),     // Routes to MEM_Data_Memory bypass
        .EX_MemWrite     (EX_MemWrite),    // Routes to MEM_Data_Memory bypass
        .EX_MemDataType  (EX_MemDataType), // Routes to MEM_Data_Memory bypass
        .EX_RegWrite     (EX_RegWrite), 
        .EX_MemToReg     (EX_MemToReg),
        
        // --- Data Path Signals ---
        .EX_PC           (EX_PC), 
        .EX_PC_Plus_4    (EX_PC_Plus_4),
        .EX_Rs1Data      (EX_Rs1Data), 
        .EX_Rs2Data      (EX_Rs2Data), 
        .EX_RdData       (EX_RdData), 
        .EX_Immediate    (EX_Immediate),
        
        // --- Split Instruction Fields ---
        .EX_Rs1Addr      (EX_Rs1Addr), 
        .EX_Rs2Addr      (EX_Rs2Addr), 
        .EX_Rs3Addr      (EX_Rs3Addr), 
        .EX_RdAddr       (EX_RdAddr),
        .EX_Funct3       (EX_Funct3), 
        .EX_Funct7       (EX_Funct7), 
        .EX_Opcode       (EX_Opcode)
    );


    // ===========================================================================
    // Stage III : Execute (EX)
    // ===========================================================================

    // 15. ALU Control Generator
    // Decodes the Funct3/7 fields into specific ALU operation codes.
    EX_ALUControl_Gen CPU_ALUCtrlGen (
        .EX_ALUOp       (EX_ALUOp),
        .EX_MACSel      (EX_MACSel),
        .EX_Funct3      (EX_Funct3),
        .EX_Funct7      (EX_Funct7),
        .EX_Opcode      (EX_Opcode),
        .EX_ALUControl  (EX_ALUControl)
    );

    // 16. Forwarding Unit
    // Detects hazards and controls the 3-to-1 Muxes in the input selector.
    EX_Forwarding_Unit #(.REG_COUNT(REG_COUNT))
    CPU_Forwarding (
        .EX_Rs1Addr     (EX_Rs1Addr),
        .EX_Rs2Addr     (EX_Rs2Addr),
        .EX_Rs3Addr     (EX_Rs3Addr),     // MAC Accumulator support
        .EX_MACSel      (EX_MACSel),
        .MEM_RegWrite   (MEM_RegWrite),   // From EX/MEM_Reg
        .MEM_RdAddr     (MEM_RdAddr),     // From EX/MEM_Reg
        .WB_RegWrite    (WB_RegWrite),    // From MEM_WB_Reg
        .WB_RdAddr      (WB_RdAddr),      // From MEM_WB_Reg
        .EX_ForwardA    (EX_ForwardA),
        .EX_ForwardB    (EX_ForwardB),
        .EX_ForwardC    (EX_ForwardC)     // Control for Accumulator path
    );

    // 17. ALU Input Selector
    // Physically houses the Forwarding Muxes and Source Muxes.
    EX_ALU_Input_Sel #(
        .WIDTH          (DATA_WIDTH), 
        .PC_WIDTH       (PC_WIDTH)
    ) CPU_ALUInputSel (
        .EX_Rs1Data     (EX_Rs1Data),
        .EX_Rs2Data     (EX_Rs2Data),
        .EX_RdData_MAC  (EX_RdData),         // Accumulator value from ID/EX
        .EX_PC          (EX_PC),
        .EX_Imm         (EX_Immediate),
        .MEM_ForwardData(MEM_ALUResult),     // Feedback from MEM stage (Direct bypass)
        .WB_ForwardData (WB_FinalWriteData), // Feedback from WB stage (WriteBack Mux)
        .EX_ALUSrc1     (EX_ALUSrc1),
        .EX_ALUSrc2     (EX_ALUSrc2),
        .EX_ForwardA    (EX_ForwardA),
        .EX_ForwardB    (EX_ForwardB),
        .EX_ForwardC    (EX_ForwardC),
        .EX_Op1         (EX_Op1),            // To ALU
        .EX_Op2         (EX_Op2),            // To ALU
        .EX_Op3         (EX_Op3),            // To MAC Accumulator
        .EX_StoreData   (EX_StoreData)       // To Data Memory Bypass
    );

    // 18. Integer ALU (ALU_RV32I)
    // Combinational core for standard arithmetic and logic.
    EX_ALU_RV32I #(.WIDTH(DATA_WIDTH))
    CPU_ALU_I (
        .EX_Op1         (EX_Op1),
        .EX_Op2         (EX_Op2),
        .EX_ALUControl  (EX_ALUControl),
        .EX_MDSel       (EX_MDSel),
        .EX_ALUResult_I (Result_I)          // Note: Zero_I port eradicated
    );

    // 19. M-Extension ALU (ALU_RV32M)
    // Pipelined Multiplier (2-cycle) and Multi-cycle Divider.
    EX_ALU_RV32M #(.WIDTH(DATA_WIDTH))
    CPU_ALU_M (
        .clk            (CPU_clk),
        .rst_n          (CPU_sync_rst_n),
        .EX_Op1         (EX_Op1),
        .EX_Op2         (EX_Op2),
        .EX_ALUControl  (EX_ALUControl),
        .EX_MDSel       (EX_MDSel),
        .EX_ALUResult_M (Result_M),         // Product or Quotient
        .EX_Stall_M     (EX_Stall_M)        // Note: Zero_M port eradicated
    );

    // 20. MAC Accumulator
    // Adds the product from the M-unit to the forwarded accumulator source.
    EX_Accumulator #(.WIDTH(DATA_WIDTH))
    CPU_Accumulator (
        .EX_ALUResult_M (Result_M),         // Product from M-Unit
        .EX_RdData      (EX_Op3),           // Forwarded Accumulator (Op3)
        .MAC_Result     (MACResult)
    );

    // 21. ALU Select Mux
    // Final result selection before the EX/MEM boundary.
    EX_ALUSelect_Mux #(.WIDTH(DATA_WIDTH))
    CPU_ALUSelMux (
        .EX_ALUResult_I (Result_I),
        .EX_ALUResult_M (Result_M),         // Raw Product/Quotient
        .EX_MACResult   (MACResult),        // Accumulator Result
        .EX_MDSel       (EX_MDSel),
        .EX_MACSel      (EX_MACSel),
        .EX_ALUResult   (EX_ALUResult)      // Destination: EX_MEM_Reg & MEM_Data_Memory
    );

    
    // ===========================================================================
    // III -> IV : EX/MEM Pipeline Register (Module 22)
    // ===========================================================================
    
    // Micro-arch Fix: This register is now "Memory-Light". 
    // It only carries metadata for the Write-Back stage.
    EX_MEM_Reg #(
        .WIDTH        (DATA_WIDTH), 
        .PC_WIDTH     (PC_WIDTH), 
        .REG_COUNT    (REG_COUNT)
    ) CPU_EX_MEM_Reg (
        .CPU_clk        (CPU_clk),
        .CPU_rst_n      (CPU_sync_rst_n),
        .EX_Stall       (EX_Stall_M),       // Stall from Divider
        
        // --- Control Signals (Input from EX Stage) ---
        .EX_RegWrite    (EX_RegWrite), 
        .EX_MemToReg    (EX_MemToReg),
        
        // --- Data Path Signals (Input from EX Stage) ---
        .EX_PC_Plus_4   (EX_PC_Plus_4),
        .EX_ALUResult   (EX_ALUResult),
        .EX_RdAddr      (EX_RdAddr),
        
        // --- Outputs (To MEM Stage metadata) ---
        .MEM_RegWrite   (MEM_RegWrite),     // To MEM/WB_Reg & Hazard Unit
        .MEM_MemToReg   (MEM_MemToReg),     // To MEM/WB_Reg
        .MEM_PC_Plus_4  (MEM_PC_Plus_4),
        .MEM_ALUResult  (MEM_ALUResult),    // Used for WB, not BRAM address
        .MEM_RdAddr     (MEM_RdAddr)
    );


    // ===========================================================================
    // Stage IV : Memory Access (MEM)
    // ===========================================================================

    // 23. Data Memory (DMEM)
    // Inputs BYPASS EX_MEM_Reg and come directly from EX Stage.
    // This allows the BRAM to latch the address and data on the same clock edge
    // the EX stage completes, keeping the pipeline at 5 stages.
    MEM_Data_Memory #(
        .WIDTH          (DATA_WIDTH), 
        .DMEM_DEPTH     (DMEM_DEPTH)
    ) CPU_DMEM (
        .CPU_clk        (CPU_clk),
        
        // Inputs directly from EX stage (Bypassing pipeline register)
        .EX_MemWrite    (EX_MemWrite),      // Origin: ID_EX_Reg
        .EX_MemRead     (EX_MemRead),       // Origin: ID_EX_Reg
        .EX_MemDataType (EX_MemDataType),   // Origin: ID_EX_Reg
        .EX_ALUResult   (EX_ALUResult),     // Address
        .EX_WriteData   (EX_StoreData),     // Data (Forwarding-aware)
        
        // Output emerges in the MEM Stage
        .MEM_ReadData   (MEM_ReadData)      // Destination: MEM_WB_Reg
    );


    // ===========================================================================
    // IV -> V : MEM/WB Pipeline Register (Module 24)
    // ===========================================================================

    MEM_WB_Reg #(
        .WIDTH        (DATA_WIDTH), 
        .PC_WIDTH     (PC_WIDTH), 
        .REG_COUNT    (REG_COUNT)
    ) CPU_MEM_WB_Reg (
        .CPU_clk        (CPU_clk),
        .CPU_rst_n      (CPU_sync_rst_n),
        
        // --- Inputs from MEM Stage metadata ---
        .MEM_RegWrite   (MEM_RegWrite), 
        .MEM_MemToReg   (MEM_MemToReg),
        .MEM_PC_Plus_4  (MEM_PC_Plus_4),
        .MEM_ALUResult  (MEM_ALUResult),
        .MEM_ReadData   (MEM_ReadData),     // From BRAM Output
        .MEM_RdAddr     (MEM_RdAddr),
        
        // --- Outputs (To WB Stage) ---
        .WB_RegWrite    (WB_RegWrite), 
        .WB_MemToReg    (WB_MemToReg),
        .WB_PC_Plus_4   (WB_PC_Plus_4),
        .WB_ALUResult   (WB_ALUResult),
        .WB_ReadData    (WB_ReadData),
        .WB_RdAddr      (WB_RdAddr)
    );


    // ===========================================================================
    // Stage V : Writeback (WB)
    // ===========================================================================

    // 25. WriteBack Mux
    // Final multiplexer selects the data to retire into the Register File.
    WB_WriteBack_Mux #(
        .WIDTH          (DATA_WIDTH), 
        .PC_WIDTH       (PC_WIDTH)
    ) CPU_WrBackMux (
        .WB_ALUResult   (WB_ALUResult),
        .WB_ReadData    (WB_ReadData),
        .WB_PC_Plus_4   (WB_PC_Plus_4),
        .WB_MemToReg    (WB_MemToReg),
        .WB_WriteData   (WB_FinalWriteData) // Routes back to ID_Register_File
    );



    // ===========================================================================
    // Debug Output Assignments (Pipeline Mapping)
    // ===========================================================================
    
    // --- Data Path States ---
    assign CPU_PC            = IF_PC_Current;   // IF: Current fetch address
    assign CPU_Instr_RV32IM  = ID_Instr;        // ID: Instruction currently being decoded
    assign CPU_Immediate     = ID_Immediate;    // ID: Decoded immediate
    assign CPU_Eq            = ID_Eq;           // ID: Comparison flags
    assign CPU_Lt            = ID_Lt;           // ID: Comparison flags
    assign CPU_Ltu           = ID_Ltu;          // ID: Comparison flags
    
    assign CPU_ALUResult     = EX_ALUResult;    // EX: Final result (Integer, M-Ext, or MAC)
    assign CPU_ALUControl    = EX_ALUControl;   // EX: Internal ALU opcode
    
    assign CPU_ReadData      = MEM_ReadData;    // MEM: BRAM output (latched)
    assign CPU_WriteDataReg  = WB_FinalWriteData; // WB: Final retirement data
    
    // --- Control Signals (ID Stage Decode Verification) ---
    assign CPU_ALUOp         = ID_ALUOp;
    assign CPU_MDSel         = ID_MDSel;
    assign CPU_MacSel        = ID_MACSel;
    assign CPU_ImmediateSrc  = ID_ImmediateSrc;
    assign CPU_TargetSel     = ID_TargetSel;
    assign CPU_RegWrite      = ID_RegWrite;
    assign CPU_MemRead       = ID_MemRead;
    assign CPU_MemWrite      = ID_MemWrite;
    assign CPU_MemToReg      = ID_MemToReg;
    assign CPU_MemDataType   = ID_MemDataType;
    assign CPU_ALUSrc1       = ID_ALUSrc1;
    assign CPU_ALUSrc2       = ID_ALUSrc2;

    // --- Branch/Jump Decision (ID Stage) ---
    // Correction: In the 100MHz design, this is no longer an "EX" exception.
    assign CPU_PCSrc         = ID_PCSrc;        // Verified: Branch/Jump resolves in ID

    // --- MAC Extension Debug ---
    assign CPU_MAC_Accumulator = EX_Op3;        // Verify Rs3 forwarding/accumulator stability
    assign CPU_MAC_Active      = EX_MACSel;
    
    // --- Hazard & Stall Debug ---
    assign CPU_Stall_Divider   = EX_Stall_M;    // Multi-cycle Divider active
    assign CPU_Stalled         = ~IF_PCWrite;   // PC is frozen (Stall)
    assign CPU_Flush_Event     = IF_ID_Flush;   // Pipe is killing IF instruction (Control Hazard)
    
    // --- Forwarding Debug ---
    assign CPU_FwdC_Sel        = EX_ForwardC;   // 01: WB, 10: MEM, 00: ID/EX

endmodule


/*
* Module: Reset_Synchronizer
* Description: Hardened Two-stage Flip-Flop Synchronizer for Active-Low Reset.
* - Assertion: Immediate (Asynchronous)
* - De-assertion: Synchronous (Prevents metastability)
* Status: 100MHz PRODUCTION READY
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

module Reset_Synchronizer (
    input  wire CPU_clk,          
    input  wire CPU_rst_n,        
    output wire CPU_sync_rst_n    // Changed to wire to support the internal buffer
    );

    // Using Vivado Synthesis attibutes for optimisation
    // ASYNC_REG: Forces FFs into the same slice for metastability protection.
    // DONT_TOUCH: Prevents the synthesizer from "optimizing away" the second stage.
    (* ASYNC_REG = "TRUE" *)(* dont_touch = "true" *) 
    reg [1:0] sync_regs;

    always @(posedge CPU_clk or negedge CPU_rst_n) begin
        if (!CPU_rst_n) begin
            sync_regs <= 2'b00;
        end else begin
            sync_regs <= {sync_regs[0], 1'b1};
        end
    end

    // Use the second stage as the global reset.
    // For very large designs, you would instantiate a BUFG here to handle the fanout,
    // but for an RV32IM core, the tool will usually handle the buffering if 
    // you leave this as a simple assignment.
    assign CPU_sync_rst_n = sync_regs[1];

endmodule