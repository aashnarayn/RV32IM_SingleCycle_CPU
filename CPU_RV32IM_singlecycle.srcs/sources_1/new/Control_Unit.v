/*
* Module: Control_Unit.v
* Description: Decodes instruction opcodes to generate control signals for the Datapath.
* Supports RV32IM Standard ISA + Custom MAC/MACI extensions.
* Refined for Zero Latches and clean logic separation.
* Author: Aashrith S Narayn
* Date: 10/09/2025
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module Control_Unit #(
    parameter WIDTH       = 32,
    parameter INSTR_WIDTH = 32
)(
    input  wire [INSTR_WIDTH-1:0] Instr_RV32IM,  
    
    // ALU Controls
    output reg [2:0]              ALUOp,
    output reg                    MDSel,         // Selects M-Extension ALU (Mul/Div/MAC)
    output reg                    MACSel,        // Selects Accumulator Result
    output reg [2:0]              ImmediateSrc,
    output reg [3:0]              TargetSel,     // Branch/Jump Target Logic
    output reg                    ALUSrc1,       // 0: Rs1, 1: PC
    output reg                    ALUSrc2,       // 0: Rs2, 1: Imm
    
    // Memory & Writeback Controls
    output reg                    RegWrite,
    output reg                    MemRead,
    output reg                    MemWrite,
    output reg [1:0]              MemToReg,
    output reg [2:0]              MemDataType
);
    
    // Instruction Decoding
    wire [6:0] Opcode = Instr_RV32IM[6:0];      
    wire [6:0] funct7 = Instr_RV32IM[31:25];    
    wire [2:0] funct3 = Instr_RV32IM[14:12];    
    
    // Unused bits sink (prevents linter warnings)
    wire [14:0] Control_unused = {Instr_RV32IM[24:15], Instr_RV32IM[11:7]}; 
    
    always @(*) begin
        // ===========================================================================
        // 1. DEFAULT ASSIGNMENTS (CRITICAL FOR TIMING)
        // ===========================================================================
        // Initialize ALL signals to 0/NOP here. 
        // This ensures synthesis never infers a Latch for any missing case path.
        ALUOp        = `ALUOP_NOP;
        MDSel        = 1'b0;
        MACSel       = 1'b0;         
        ImmediateSrc = `IMM_NONE;
        TargetSel    = `TR_NOP;
        RegWrite     = 1'b0;
        MemRead      = 1'b0;
        MemWrite     = 1'b0;
        MemToReg     = 2'b00;
        MemDataType  = `MEM_INVALID;
        ALUSrc1      = 1'b0;
        ALUSrc2      = 1'b0;

        // ===========================================================================
        // 2. OPCODE DECODING
        // ===========================================================================
        case (Opcode)
             
            // -----------------------------------------------------------------------
            // R-TYPE (Standard ALU + Multiply/Divide)
            // -----------------------------------------------------------------------
            `OPCODE_RTYPE:  begin            
                RegWrite = 1'b1;
                
                // Differentiate between Standard ALU and M-Extension
                case (funct7)
                    7'b0000000, 7'b0100000: begin
                        ALUOp = `ALUOP_RTYPE;       // ADD, SUB, AND, OR, etc.
                    end
                    
                    7'b0000001: begin
                        ALUOp = `ALUOP_RMUL;        // MUL, DIV, REM
                        MDSel = 1'b1;               // Enable M-ALU
                    end
                        
                    default: ALUOp = `ALUOP_NOP;
                endcase
            end
            
            // -----------------------------------------------------------------------
            // I-TYPE (Arithmetic/Logical Immediate)
            // -----------------------------------------------------------------------
            `OPCODE_ITYPE:  begin            
                ALUOp        = `ALUOP_ITYPE;
                ImmediateSrc = `IMM_I;
                RegWrite     = 1'b1;
                ALUSrc2      = 1'b1;         // Use Immediate
                // NOTE: No MAC logic here. That belongs in OPCODE_MAC.
            end
            
            // -----------------------------------------------------------------------
            // LOAD (Load Word/Half/Byte)
            // -----------------------------------------------------------------------
            `OPCODE_LOAD:   begin            
                ALUOp        = `ALUOP_LSJ;   // Addr Calc
                ImmediateSrc = `IMM_I;
                RegWrite     = 1'b1;
                MemRead      = 1'b1;
                MemToReg     = 2'b01;        // Select ReadData
                ALUSrc2      = 1'b1;
                
                case(funct3)
                    `MEM_BYTE_SIGNED, `MEM_HALF_SIGNED, `MEM_WORD, 
                    `MEM_BYTE_UNSIGNED, `MEM_HALF_UNSIGNED: 
                        MemDataType = funct3;                  
                    default: 
                        MemDataType = `MEM_INVALID;   
                endcase
            end
            
            // -----------------------------------------------------------------------
            // STORE (Store Word/Half/Byte)
            // -----------------------------------------------------------------------
            `OPCODE_STORE:  begin            
                ALUOp        = `ALUOP_LSJ;
                ImmediateSrc = `IMM_S;       // S-Type Immediate
                MemWrite     = 1'b1;
                ALUSrc2      = 1'b1;
                
                case(funct3)
                    `MEM_BYTE_SIGNED, `MEM_HALF_SIGNED, `MEM_WORD: 
                        MemDataType = funct3;                  
                    default: 
                        MemDataType = `MEM_INVALID;   
                endcase
            end
            
            // -----------------------------------------------------------------------
            // BRANCH (Conditional Jumps)
            // -----------------------------------------------------------------------
            `OPCODE_BRANCH: begin            
                ALUOp        = `ALUOP_BRANCH;
                ImmediateSrc = `IMM_B;       // B-Type Immediate
                // Pass funct3 to Target Controller for EQ/NE/LT/etc logic
                TargetSel    = {1'b0, funct3}; 
            end
            
            // -----------------------------------------------------------------------
            // LUI (Load Upper Immediate)
            // -----------------------------------------------------------------------
            `OPCODE_LUI:    begin            
                ALUOp        = `ALUOP_UTYPE; // Pass Op2 through
                ImmediateSrc = `IMM_U;
                RegWrite     = 1'b1;
                ALUSrc2      = 1'b1;         // Op2 is Immediate
            end
            
            // -----------------------------------------------------------------------
            // AUIPC (Add Upper Immediate to PC)
            // -----------------------------------------------------------------------
            `OPCODE_AUIPC:  begin            
                ALUOp        = `ALUOP_UTYPE; // Add Op1 + Op2
                ImmediateSrc = `IMM_U;
                RegWrite     = 1'b1;
                ALUSrc1      = 1'b1;         // Op1 is PC
                ALUSrc2      = 1'b1;         // Op2 is Immediate
            end
                
            // -----------------------------------------------------------------------
            // JAL (Jump and Link)
            // -----------------------------------------------------------------------
            `OPCODE_JAL:    begin            
                ALUOp        = `ALUOP_JUMP;
                ImmediateSrc = `IMM_J;
                TargetSel    = `UJ_AL; 
                RegWrite     = 1'b1;
                MemToReg     = 2'b10;        // Write PC+4 to Reg
                ALUSrc1      = 1'b1;         // PC
                ALUSrc2      = 1'b1;         // Imm
            end
            
            // -----------------------------------------------------------------------
            // JALR (Jump and Link Register)
            // -----------------------------------------------------------------------
            `OPCODE_JALR:   begin            
                ALUOp        = `ALUOP_LSJ;   // Add (Rs1 + Imm)
                ImmediateSrc = `IMM_I;
                TargetSel    = `UJ_ALR; 
                RegWrite     = 1'b1;
                MemToReg     = 2'b10;        // Write PC+4 to Reg
                ALUSrc2      = 1'b1;         // Imm
            end
            
            // -----------------------------------------------------------------------
            // CUSTOM EXTENSION: MAC / MACI
            // -----------------------------------------------------------------------
            `OPCODE_MAC: begin
                MACSel   = 1'b1;             // Select Accumulator Mux Path
                MDSel    = 1'b1;             // Enable Multiplier ALU
                ALUOp    = `ALUOP_RMUL;      // Set ALU to Mult Mode
                RegWrite = 1'b1;             // Write result back to Rd
            
                // Determine Mode based on funct3
                if (funct3 == 3'b000) begin
                    // REGISTER MODE (mac rd, rs1, rs2)
                    ImmediateSrc = `IMM_NONE;
                    ALUSrc2      = 1'b0;     // Use Rs2
                end else if (funct3 == 3'b001) begin
                    // IMMEDIATE MODE (maci rd, rs1, imm)
                    ImmediateSrc = `IMM_I;   // Extract Immediate
                    ALUSrc2      = 1'b1;     // Use Immediate
                end
            end 
        
            // -----------------------------------------------------------------------
            // DEFAULT SAFETY NET
            // -----------------------------------------------------------------------
            default: begin                   
                // Signals already set to 0 at the top. 
                // Explicit NOP assignment here for simulation clarity.
                ALUOp = `ALUOP_NOP;
            end
        endcase
    end
    
endmodule