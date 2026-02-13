/*
* Module: Control_Unit.v
* Description: Decodes instruction opcodes to generate control signals for the Datapath.
* Supports RV32IM Standard ISA + Custom MAC/MACI extensions.
* Maintains "Ordered Bundle" formatting for explicit signal tracking.
* Stage: ID
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module Control_Unit #(
    parameter WIDTH       = 32,
    parameter INSTR_WIDTH = 32
    )(
    // Inputs from Instruction Splitter (ID Stage)
    input  wire [6:0]             ID_Opcode,        // Origin: Instruction Splitter
    input  wire [2:0]             ID_Funct3,        // Origin: Instruction Splitter
    input  wire [6:0]             ID_Funct7,        // Origin: Instruction Splitter
    
    // Execution Control (To be used in EX Stage)
    output reg [2:0]              ID_ALUOp,         // Destination: ID/EX Pipeline Register
    output reg                    ID_MDSel,         // Destination: ID/EX Pipeline Register (M-Extension Enable)
    output reg                    ID_MACSel,        // Destination: ID/EX Pipeline Register (Accumulator Enable)
    output reg [3:0]              ID_TargetSel,     // Destination: ID/EX Pipeline Register (Branch Unit)
    output reg                    ID_ALUSrc1,       // Destination: ID/EX Pipeline Register (0:Rs1, 1:PC)
    output reg                    ID_ALUSrc2,       // Destination: ID/EX Pipeline Register (0:Rs2, 1:Imm)
    
    // Memory Control (To be used in MEM Stage)
    output reg                    ID_MemRead,       // Destination: ID/EX Pipeline Register
    output reg                    ID_MemWrite,      // Destination: ID/EX Pipeline Register
    output reg [2:0]              ID_MemDataType,   // Destination: ID/EX Pipeline Register
    
    // Write-Back Control (To be used in WB Stage)
    output reg                    ID_RegWrite,      // Destination: ID/EX Pipeline Register
    output reg [1:0]              ID_MemToReg,      // Destination: ID/EX Pipeline Register (00:ALU, 01:Mem, 10:PC+4)
    
    // Local Decode Control (Used immediately in ID Stage)
    output reg [2:0]              ID_ImmediateSrc   // Destination: Imm_Gen (ID Stage)
    );
    
    always @(*) begin
        // Safety Defaults (Zeroing out to prevent latches, but overridden in bundles below)
        ID_ALUOp        = `ALUOP_NOP;
        ID_MDSel        = 1'b0;
        ID_MACSel       = 1'b0;
        ID_ImmediateSrc = `IMM_NONE;
        ID_TargetSel    = `TR_NOP;
        ID_RegWrite     = 1'b0;
        ID_MemRead      = 1'b0;
        ID_MemWrite     = 1'b0;
        ID_MemToReg     = 2'b00;
        ID_MemDataType  = `MEM_INVALID;
        ID_ALUSrc1      = 1'b0;
        ID_ALUSrc2      = 1'b0;

        case (ID_Opcode)
        
            `OPCODE_RTYPE:  begin            
                case (ID_Funct7)
                    7'b0000000,
                    7'b0100000: begin
                        ID_ALUOp = `ALUOP_RTYPE;                           
                        ID_MDSel = 1'b0;                                   
                    end
                    7'b0000001: begin
                        ID_ALUOp = `ALUOP_RMUL;                            
                        ID_MDSel = 1'b1;                                   
                    end
                    default: begin
                        ID_ALUOp = `ALUOP_NOP;                             
                        ID_MDSel = 1'b0;
                    end
                endcase
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_NONE;
                ID_TargetSel    = `TR_NOP; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b00;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b0;
            end
            
            `OPCODE_ITYPE:  begin            
                ID_ALUOp        = `ALUOP_ITYPE;
                ID_MDSel        = 1'b0;
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_I;
                ID_TargetSel    = `TR_NOP; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b00;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b1;
            end
            
            `OPCODE_LOAD:   begin            
                ID_ALUOp        = `ALUOP_LSJ;
                ID_MDSel        = 1'b0;
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_I;
                ID_TargetSel    = `TR_NOP; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b1;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b01;
                case(ID_Funct3)
                    `MEM_BYTE_SIGNED, `MEM_HALF_SIGNED, `MEM_WORD,                                          
                    `MEM_BYTE_UNSIGNED, `MEM_HALF_UNSIGNED: ID_MemDataType = ID_Funct3;                           
                    default: ID_MemDataType = `MEM_INVALID;   
                endcase
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b1;
            end
            
            `OPCODE_STORE:  begin            
                ID_ALUOp        = `ALUOP_LSJ;
                ID_MDSel        = 1'b0;
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_S;
                ID_TargetSel    = `TR_NOP; 
                ID_RegWrite     = 1'b0;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b1;
                ID_MemToReg     = 2'bxx;
                case(ID_Funct3)
                    `MEM_BYTE_SIGNED, `MEM_HALF_SIGNED, `MEM_WORD: ID_MemDataType = ID_Funct3;                          
                    default: ID_MemDataType = `MEM_INVALID;   
                endcase
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b1;
            end
            
            `OPCODE_BRANCH: begin            
                ID_ALUOp        = `ALUOP_BRANCH;
                ID_MDSel        = 1'b0;
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_B;
                case ({1'b0, ID_Funct3})
                    `BR_EQ, `BR_NE, `BR_LT,
                    `BR_GE, `BR_LTU, `BR_GEU: ID_TargetSel = {1'b0, ID_Funct3}; 
                    default: ID_TargetSel = `TR_NOP;
                endcase
                ID_RegWrite     = 1'b0;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'bxx;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b0;
            end
            
            `OPCODE_LUI:    begin            
                ID_ALUOp        = `ALUOP_UTYPE;
                ID_MDSel        = 1'b0;
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_U;
                ID_TargetSel    = `TR_NOP; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b00;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b0;     
                ID_ALUSrc2      = 1'b1;
            end
            
            `OPCODE_AUIPC:  begin            
                ID_ALUOp        = `ALUOP_UTYPE;
                ID_MDSel        = 1'b0;
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_U;
                ID_TargetSel    = `TR_NOP; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b00;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b1;
                ID_ALUSrc2      = 1'b1;
            end
                
            `OPCODE_JAL:    begin            
                ID_ALUOp        = `ALUOP_JUMP;
                ID_MDSel        = 1'b0;
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_J;
                ID_TargetSel    = `UJ_AL; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b10;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b1;
                ID_ALUSrc2      = 1'b1;
            end
            
            `OPCODE_JALR:   begin            
                ID_ALUOp        = `ALUOP_LSJ;
                ID_MDSel        = 1'b0;
                ID_MACSel       = 1'b0;
                ID_ImmediateSrc = `IMM_I;
                ID_TargetSel    = `UJ_ALR; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b10;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b1;
            end

            `OPCODE_MAC: begin                         // Custom MAC and MACI instruction decoding
                ID_ALUOp        = `ALUOP_RMUL; 
                ID_MDSel         = 1'b1;
                ID_MACSel        = 1'b1;
                ID_TargetSel     = `TR_NOP;
                ID_RegWrite      = 1'b1;
                ID_MemRead       = 1'b0;
                ID_MemWrite      = 1'b0;
                ID_MemToReg      = 2'b00;
                ID_MemDataType   = `MEM_INVALID;
                ID_ALUSrc1       = 1'b0;
                if (ID_Funct3 == 3'b000) begin          // Register Mode (MAC)
                    ID_ImmediateSrc = `IMM_NONE;
                    ID_ALUSrc2      = 1'b0;
                end 
                else if (ID_Funct3 == 3'b001) begin     // Immediate Mode (MACI)
                    ID_ImmediateSrc = `IMM_I;
                    ID_ALUSrc2      = 1'b1;
                end
            end
            
            default: ; 
        endcase
    end
endmodule