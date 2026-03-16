/*
* Module: CPU_Control_Codes.vh
* Description: Header file containing all requisite ALUControl, ALUOp,
*              BranchSel, ImmediateSrc labels and Opcodes for the 
*              Control Logic and ALU modules for readability.
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`ifndef CPU_CONTROL_CODES_VH
`define CPU_CONTROL_CODES_VH

//=======================================================
// ALUControl Codes - Core Functions + Instruction Aliases
//=======================================================

//---------------- Core ALU Function Codes ------------------
`define ALU_ADD           6'b000000     
`define ALU_SUB           6'b000001
`define ALU_AND           6'b000010
`define ALU_OR            6'b000011
`define ALU_XOR           6'b000100
`define ALU_SLL           6'b000101
`define ALU_SRL           6'b000110
`define ALU_SRA           6'b000111
`define ALU_SLT           6'b001000     
`define ALU_SLTU          6'b001001  
`define ALU_GE            6'b001010  
`define ALU_GEU           6'b001011
`define ALU_EQ            6'b001100
`define ALU_PASS_B        6'b001101
`define ALU_PC_PLUS_IMM   6'b001110

//----------- RV32M: Multiply / Divide / Remainder -----------
`define ALU_MUL           6'b010000
`define ALU_MULH          6'b010001
`define ALU_MULHU         6'b010010
`define ALU_MULHSU        6'b010011
`define ALU_DIV           6'b010100
`define ALU_DIVU          6'b010101
`define ALU_REM           6'b010110
`define ALU_REMU          6'b010111
`define ALU_MAC           6'b011000    // Internal ALU code for MAC/MACI

//--------------- Instruction Aliases ------------------
// R-type and I-type (Memory and Jump addresses are calculated as ADDs)
`define ALU_ADDI          `ALU_ADD
`define ALU_LW            `ALU_ADD
`define ALU_SW            `ALU_ADD
`define ALU_JAL           `ALU_ADD
`define ALU_JALR          `ALU_ADD

`define ALU_ANDI          `ALU_AND
`define ALU_ORI           `ALU_OR
`define ALU_XORI          `ALU_XOR
`define ALU_SLLI          `ALU_SLL
`define ALU_SRLI          `ALU_SRL
`define ALU_SRAI          `ALU_SRA
`define ALU_SLTI          `ALU_SLT
`define ALU_SLTIU         `ALU_SLTU

`define ALU_MACI          `ALU_MAC

// Note: Branch aliases (ALU_BEQ, etc.) are now removed. 
// Branch math is now exclusively handled by the ID_Branch_Comparator. 
// Main EX ALU receives ALU_NOP during branches.

// Upper Immediate ops
`define ALU_LUI           `ALU_PASS_B // Just pass Op2 (Immediate)
`define ALU_AUIPC         `ALU_ADD    // PC + Immediate

//--------------- Fallback ------------------
`define ALU_NOP           6'b111111


//=======================================================
// ALUOp Codes - to guide ALUControl submodule (ID Stage)
//=======================================================
`define ALUOP_MEM      3'b000   // Base load/store for memory (add)
`define ALUOP_BRANCH   3'b001   // Branch comparisons (NOP for ALU)
`define ALUOP_RTYPE    3'b010   // R-type ops
`define ALUOP_ITYPE    3'b011   // I-type ALU ops
`define ALUOP_RMUL     3'b100   // RV32M (MUL/DIV)
`define ALUOP_UTYPE    3'b101   // LUI, AUIPC
`define ALUOP_JUMP     3'b110   // JAL (NOP for ALU)
`define ALUOP_NOP      3'b111   // Fallback


// ================================================================
// TargetSel Codes - Used by ID_Target_Controller (ID Stage)
// ================================================================
`define BR_EQ    4'b0000   // BEQ
`define BR_NE    4'b0001   // BNE
`define UJ_AL    4'b0010   // JAL (jump always) 
`define TR_NOP   4'b0011   // No branch / default
`define UJ_ALR   4'b1001   // JALR
`define BR_LT    4'b0100   // BLT
`define BR_GE    4'b0101   // BGE
`define BR_LTU   4'b0110   // BLTU
`define BR_GEU   4'b0111   // BGEU


//=======================================================
// ImmediateSrc Codes - (ID Stage)
//=======================================================
`define IMM_NONE 3'b000   // R-type (no immediate)
`define IMM_I    3'b001   // I-type (ADDI, LW, JALR)
`define IMM_S    3'b010   // S-type (SW)
`define IMM_B    3'b011   // B-type (branches)
`define IMM_U    3'b100   // U-type (LUI, AUIPC)
`define IMM_J    3'b101   // J-type (JAL)


//==========================================================================
// MemDataType Codes - Used by ID_Control & MEM_Data_Memory
//==========================================================================
`define MEM_BYTE_SIGNED     3'b000     // LB / SB
`define MEM_HALF_SIGNED     3'b001     // LH / SH
`define MEM_WORD            3'b010     // LW / SW
`define MEM_BYTE_UNSIGNED   3'b100     // LBU
`define MEM_HALF_UNSIGNED   3'b101     // LHU
`define MEM_INVALID         3'b111     // Default


//=======================================================
// Opcodes - Instruction class identifiers (ID Stage)
//=======================================================
`define OPCODE_RTYPE   7'b0110011
`define OPCODE_ITYPE   7'b0010011
`define OPCODE_LOAD    7'b0000011
`define OPCODE_STORE   7'b0100011
`define OPCODE_BRANCH  7'b1100011
`define OPCODE_LUI     7'b0110111
`define OPCODE_AUIPC   7'b0010111
`define OPCODE_JAL     7'b1101111
`define OPCODE_JALR    7'b1100111
`define OPCODE_MAC     7'b0001011


//=======================================================
// Forwarding Mux Codes - (EX Stage)
//=======================================================
`define FWD_NO_FORWARD  2'b00  // Use value from ID/EX Register (No Hazard)
`define FWD_FROM_MEM    2'b10  // Forward from EX/MEM Register (EX Hazard)
`define FWD_FROM_WB     2'b01  // Forward from MEM/WB Register (MEM Hazard)


//===========================================================
// Simulation Aids: Hex Files and Simulation Parameters
//===========================================================
// NOTE: Please update the file paths for when using the files in Vivado
<<<<<<< HEAD
`define IMEM_HEX_PROGRAM "/home/chin/RV32IM_SingleCycle_CPU/CPU_RV32IM_5stage.srcs/sources_1/new/Mem_Hex_Files/IMEM_RV32IM_Program.mem"
`define DMEM_HEX_BLOCK   "/home/chin/RV32IM_SingleCycle_CPU/CPU_RV32IM_5stage.srcs/sources_1/new/Mem_Hex_Files/DMEM_Data_Block.mem"
`define IMEM_HEX_DUMP    "/home/chin/RV32IM_SingleCycle_CPU/CPU_RV32IM_5stage.srcs/sources_1/new/Mem_Hex_Files/IMEM_RV32IM_Dump.mem"
`define DMEM_HEX_DUMP    "/home/chin/RV32IM_SingleCycle_CPU/CPU_RV32IM_5stage.srcs/sources_1/new/Mem_Hex_Files/DMEM_Data_Dump.mem"
=======
`define IMEM_HEX_PROGRAM "/home/iriz/Desktop/Active/Vivado_2024_2/CPU_RV32IM_5stage/CPU_RV32IM_5stage.srcs/sources_1/new/Mem_Hex_Files/IMEM_RV32IM_Program.mem"
`define DMEM_HEX_BLOCK   "/home/iriz/Desktop/Active/Vivado_2024_2/CPU_RV32IM_5stage/CPU_RV32IM_5stage.srcs/sources_1/new/Mem_Hex_Files/DMEM_Data_Block.mem"
`define IMEM_HEX_DUMP    "/home/iriz/Desktop/Active/Vivado_2024_2/CPU_RV32IM_5stage/CPU_RV32IM_5stage.srcs/sources_1/new/Mem_Hex_Files/IMEM_RV32IM_Dump.mem"
`define DMEM_HEX_DUMP    "/home/iriz/Desktop/Active/Vivado_2024_2/CPU_RV32IM_5stage/CPU_RV32IM_5stage.srcs/sources_1/new/Mem_Hex_Files/DMEM_Data_Dump.mem"
>>>>>>> 8d42b9ceda11db5e8b8e62e4ef8b858bb42e94d9
`define SIM_TIME    10000

`endif