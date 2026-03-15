/*
* Module: ID_EX_Reg.v
* Description: Pipeline register between Instruction Decode (ID) and 
* Execute (EX) stages. Updated to support 3-operand datapath for MAC/MACI.
* Carries Control Signals, Data, and Split Instruction Fields.
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps

module ID_EX_Reg #(
    parameter WIDTH       = 32,
    parameter PC_WIDTH    = 32,
    parameter REG_COUNT   = 32
    )(
    input  wire             CPU_clk,
    input  wire             CPU_rst_n,
    input  wire             ID_EX_Flush,    // Origin: Hazard Unit (Flush on Branch Taken / Load-Use)
    input  wire             ID_EX_Write,    // Origin: Hazard Unit (Freeze on ALU Multi-cycle Stall)
    
    // --- Control Signals (Input from Control Unit) ---
    input  wire [2:0]       ID_ALUOp,       // Origin: Control Unit
    input  wire             ID_MDSel,       // Origin: Control Unit (Enable M-Ext ALU)
    input  wire             ID_MACSel,      // Origin: Control Unit (Enable Accumulator)
    input  wire [3:0]       ID_TargetSel,   // Origin: Control Unit
    input  wire             ID_ALUSrc1,     // Origin: Control Unit
    input  wire             ID_ALUSrc2,     // Origin: Control Unit
    
    input  wire             ID_MemRead,     // Origin: Control Unit
    input  wire             ID_MemWrite,    // Origin: Control Unit
    input  wire [2:0]       ID_MemDataType, // Origin: Control Unit
    
    input  wire             ID_RegWrite,    // Origin: Control Unit
    input  wire [1:0]       ID_MemToReg,    // Origin: Control Unit
    
    // --- Data Path Signals (Input from ID Stage) ---
    input  wire [PC_WIDTH-1:0]          ID_PC,          // Origin: IF_ID_reg
    input  wire [PC_WIDTH-1:0]          ID_PC_Plus_4,   // Origin: IF_ID_reg
    input  wire [WIDTH-1:0]             ID_Rs1Data,     // Origin: Register File
    input  wire [WIDTH-1:0]             ID_Rs2Data,     // Origin: Register File
    input  wire [WIDTH-1:0]             ID_RdData,      // Origin: Register File (Accumulator value)
    input  wire [WIDTH-1:0]             ID_Immediate,   // Origin: Imm_Gen
    
    // --- Split Instruction Fields (Input from Instruction Splitter) ---
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs1Addr,     // Origin: Instruction Splitter
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs2Addr,     // Origin: Instruction Splitter
    input  wire [$clog2(REG_COUNT)-1:0] ID_Rs3Addr,     // Origin: Instruction Splitter
    input  wire [$clog2(REG_COUNT)-1:0] ID_RdAddr,      // Origin: Instruction Splitter
    input  wire [2:0]                   ID_Funct3,      // Origin: Instruction Splitter
    input  wire [6:0]                   ID_Funct7,      // Origin: Instruction Splitter
    input  wire [6:0]                   ID_Opcode,      // Origin: Instruction Splitter
    
    // ================= OUTPUTS (To EX Stage) =================
    
    // --- Control Signals ---
    output reg [2:0]        EX_ALUOp,       // Destination: ALUControl_Gen
    output reg              EX_MDSel,       // Destination: ALU_RV32M, ALUSelect_Mux
    output reg              EX_MACSel,      // Destination: ALUSelect_Mux / MAC_Adder
    output reg [3:0]        EX_TargetSel,   // Destination: Target_Controller
    output reg              EX_ALUSrc1,     // Destination: ALU_Input_Selector
    output reg              EX_ALUSrc2,     // Destination: ALU_Input_Selector
    
    output reg              EX_MemRead,     // Destination: EX_MEM_reg (Propagates to MEM)
    output reg              EX_MemWrite,    // Destination: EX_MEM_reg (Propagates to MEM)
    output reg [2:0]        EX_MemDataType, // Destination: EX_MEM_reg (Propagates to MEM)
    
    output reg              EX_RegWrite,    // Destination: EX_MEM_reg (Propagates to WB)
    output reg [1:0]        EX_MemToReg,    // Destination: EX_MEM_reg (Propagates to WB)
    
    // --- Data Path Signals ---
    output reg [PC_WIDTH-1:0]          EX_PC,           // Destination: ALU_Input_Selector
    output reg [PC_WIDTH-1:0]          EX_PC_Plus_4,    // Destination: EX_MEM_reg
    output reg [WIDTH-1:0]             EX_Rs1Data,      // Destination: Forwarding Mux
    output reg [WIDTH-1:0]             EX_Rs2Data,      // Destination: Forwarding Mux
    output reg [WIDTH-1:0]             EX_RdData,       // Destination: Forwarding Mux (Accumulator)
    output reg [WIDTH-1:0]             EX_Immediate,    // Destination: ALU_Input_Selector
    
    // --- Split Instruction Fields ---
    output reg [$clog2(REG_COUNT)-1:0] EX_Rs1Addr,      // Destination: Forwarding Unit
    output reg [$clog2(REG_COUNT)-1:0] EX_Rs2Addr,      // Destination: Forwarding Unit
    output reg [$clog2(REG_COUNT)-1:0] EX_Rs3Addr,      // Destination: Forwarding Unit
    output reg [$clog2(REG_COUNT)-1:0] EX_RdAddr,       // Destination: EX_MEM_reg
    output reg [2:0]                   EX_Funct3,       // Destination: ALUControl_Gen
    output reg [6:0]                   EX_Funct7,       // Destination: ALUControl_Gen
    output reg [6:0]                   EX_Opcode        // Destination: ALUControl_Gen
    );

    always @(posedge CPU_clk or negedge CPU_rst_n) begin
        if (!CPU_rst_n) begin
            // Clear all Control Outputs
            EX_ALUOp       <= 3'b0;
            EX_MDSel       <= 1'b0;
            EX_MACSel      <= 1'b0;
            EX_TargetSel   <= 4'b0; 
            EX_ALUSrc1     <= 1'b0;
            EX_ALUSrc2     <= 1'b0;
            EX_MemRead     <= 1'b0;
            EX_MemWrite    <= 1'b0;
            EX_MemDataType <= 3'b111; // MEM_INVALID
            EX_RegWrite    <= 1'b0;
            EX_MemToReg    <= 2'b00;
            
            // Clear all Data Outputs
            EX_PC          <= 0;
            EX_PC_Plus_4   <= 0;
            EX_Rs1Data     <= 0;
            EX_Rs2Data     <= 0;
            EX_RdData      <= 0;
            EX_Immediate   <= 0;
            
            // Clear all Address/Field Outputs
            EX_Rs1Addr     <= 0;
            EX_Rs2Addr     <= 0;
            EX_Rs3Addr     <= 0;
            EX_RdAddr      <= 0;
            EX_Funct3      <= 3'b0;
            EX_Funct7      <= 7'b0;
            EX_Opcode      <= 7'b0;
        end 
        else if (ID_EX_Flush) begin      // Kept as separate case to infer asynchronous reset properly
            // Clear all Control Outputs
            EX_ALUOp       <= 3'b0;
            EX_MDSel       <= 1'b0;
            EX_MACSel      <= 1'b0;
            EX_TargetSel   <= 4'b0; 
            EX_ALUSrc1     <= 1'b0;
            EX_ALUSrc2     <= 1'b0;
            EX_MemRead     <= 1'b0;
            EX_MemWrite    <= 1'b0;
            EX_MemDataType <= 3'b111; // MEM_INVALID
            EX_RegWrite    <= 1'b0;
            EX_MemToReg    <= 2'b00;
            
            // Clear all Data Outputs
            EX_PC          <= 0;
            EX_PC_Plus_4   <= 0;
            EX_Rs1Data     <= 0;
            EX_Rs2Data     <= 0;
            EX_RdData      <= 0;
            EX_Immediate   <= 0;
            
            // Clear all Address/Field Outputs
            EX_Rs1Addr     <= 0;
            EX_Rs2Addr     <= 0;
            EX_Rs3Addr     <= 0;
            EX_RdAddr      <= 0;
            EX_Funct3      <= 3'b0;
            EX_Funct7      <= 7'b0;
            EX_Opcode      <= 7'b0;
        end 
        else if (ID_EX_Write) begin
            // Pass Control Bundle
            EX_ALUOp       <= ID_ALUOp;
            EX_MDSel       <= ID_MDSel;
            EX_MACSel      <= ID_MACSel;
            EX_TargetSel   <= ID_TargetSel;
            EX_ALUSrc1     <= ID_ALUSrc1;
            EX_ALUSrc2     <= ID_ALUSrc2;
            EX_MemRead     <= ID_MemRead;
            EX_MemWrite    <= ID_MemWrite;
            EX_MemDataType <= ID_MemDataType;
            EX_RegWrite    <= ID_RegWrite;
            EX_MemToReg    <= ID_MemToReg;
            
            // Pass Data Bundle
            EX_PC          <= ID_PC;
            EX_PC_Plus_4   <= ID_PC_Plus_4;
            EX_Rs1Data     <= ID_Rs1Data;
            EX_Rs2Data     <= ID_Rs2Data;
            EX_RdData      <= ID_RdData;
            EX_Immediate   <= ID_Immediate;
            
            // Pass Address/Field Bundle
            EX_Rs1Addr     <= ID_Rs1Addr;
            EX_Rs2Addr     <= ID_Rs2Addr;
            EX_Rs3Addr     <= ID_Rs3Addr;
            EX_RdAddr      <= ID_RdAddr;
            EX_Funct3      <= ID_Funct3;
            EX_Funct7      <= ID_Funct7;
            EX_Opcode      <= ID_Opcode;
        end
        // Implicit Else: Freeze state on !ID_EX_Write
    end

endmodule