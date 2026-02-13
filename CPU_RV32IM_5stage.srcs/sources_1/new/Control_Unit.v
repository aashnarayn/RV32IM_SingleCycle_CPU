/*
* Module: Control_Unit.v
* Description: Decodes the opcode of the current instruction and generates all necessary control signals 
* required to drive the datapath components. Resides in the ID stage.
* Signals generated here are "bundled" and passed to EX, MEM, and WB stages.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

//(* dont_touch = "true" *)
module Control_Unit #(
    parameter WIDTH       = 32,
    parameter INSTR_WIDTH = 32
    )(
    input  wire [INSTR_WIDTH-1:0] ID_Instr_RV32IM,  // Origin: IF/ID Pipeline Register
    
    // Execution Control (To be used in EX Stage)
    output reg [2:0]              ID_ALUOp,         // Destination: ID/EX Pipeline Register
    output reg                    ID_MDSel,         // Destination: ID/EX Pipeline Register
    //output reg                  ID_MACSel,        // Reserved for future MAC (Dest: ID/EX Pipeline Reg)
    output reg [3:0]              ID_TargetSel,     // Destination: ID/EX Pipeline Register (Branch Unit)
    output reg                    ID_ALUSrc1,       // Destination: ID/EX Pipeline Register (0=Rs1, 1=PC)
    output reg                    ID_ALUSrc2,       // Destination: ID/EX Pipeline Register (0=Rs2, 1=Imm)
    
    // Memory Control (To be used in MEM Stage)
    output reg                    ID_MemRead,       // Destination: ID/EX Pipeline Register -> EX/MEM Pipeline Register
    output reg                    ID_MemWrite,      // Destination: ID/EX Pipeline Register -> EX/MEM Pipeline Register
    output reg [2:0]              ID_MemDataType,   // Destination: ID/EX Pipeline Register -> EX/MEM Pipeline Register
    
    // Write-Back Control (To be used in WB Stage)
    output reg                    ID_RegWrite,      // Destination: ID/EX -> EX/MEM -> MEM/WB Pipeline Register
    output reg [1:0]              ID_MemToReg,      // Destination: ID/EX -> EX/MEM -> MEM/WB Pipeline Register
    
    // Local Decode Control (Used immediately in ID Stage)
    output reg [2:0]              ID_ImmediateSrc   // Destination: Imm_Gen (ID Stage)
    );
    
    wire [6:0] Opcode = ID_Instr_RV32IM[6:0];      
    wire [6:0] funct7 = ID_Instr_RV32IM[31:25];    
    wire [2:0] funct3 = ID_Instr_RV32IM[14:12];    
    
    wire [14:0] Control_unused = {ID_Instr_RV32IM[24:15], ID_Instr_RV32IM[11:7]};
    
    always @(*) begin
        case (Opcode)
        
            `OPCODE_RTYPE:  begin            //R-type Instructions
                // Note: Logic allows for future MAC expansion here
                case (funct7)
                    7'b0000000,
                    7'b0100000: begin
                        ID_ALUOp = `ALUOP_RTYPE;                           
                        ID_MDSel = 1'b0;                                   
                    end
                    
                    7'b0000001: begin
                        ID_ALUOp = `ALUOP_RMUL;                            
                        ID_MDSel = 1'b1;                                   
                    end
                    
                    default:    begin
                        ID_ALUOp = `ALUOP_NOP;                             
                        ID_MDSel = 1'b0;
                    end
                endcase
                
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
            
            `OPCODE_ITYPE:  begin            //I-type Arithmetic
                ID_ALUOp        = `ALUOP_ITYPE;
                ID_MDSel        = 1'b0;
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
            
            `OPCODE_LOAD:   begin            //Load Instructions
                ID_ALUOp        = `ALUOP_LSJ;
                ID_MDSel        = 1'b0;
                ID_ImmediateSrc = `IMM_I;
                ID_TargetSel    = `TR_NOP; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b1;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b01;
                
                case(funct3)
                    `MEM_BYTE_SIGNED,                                   
                    `MEM_HALF_SIGNED,                                   
                    `MEM_WORD,                                          
                    `MEM_BYTE_UNSIGNED,                                 
                    `MEM_HALF_UNSIGNED:  ID_MemDataType  = funct3;                           
                    default:             ID_MemDataType  = `MEM_INVALID;   
                endcase
                
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b1;
            end
            
            `OPCODE_STORE:  begin            //SW
                ID_ALUOp        = `ALUOP_LSJ;
                ID_MDSel        = 1'b0;
                ID_ImmediateSrc = `IMM_S;
                ID_TargetSel    = `TR_NOP; 
                ID_RegWrite     = 1'b0;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b1;
                ID_MemToReg     = 2'bxx;
                
                case(funct3)
                    `MEM_BYTE_SIGNED,                                   
                    `MEM_HALF_SIGNED,                                   
                    `MEM_WORD:           ID_MemDataType  = funct3;                          
                    default:             ID_MemDataType  = `MEM_INVALID;   
                endcase
                
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b1;
            end
            
            `OPCODE_BRANCH: begin            //B-type
                ID_ALUOp        = `ALUOP_BRANCH;
                ID_MDSel        = 1'b0;
                ID_ImmediateSrc = `IMM_B;
                
                case ({1'b0,funct3})
                    `BR_EQ, `BR_NE, `BR_LT,
                    `BR_GE, `BR_LTU, `BR_GEU: ID_TargetSel = {1'b0,funct3}; 
                    default:                  ID_TargetSel = `TR_NOP;
                endcase
                
                ID_RegWrite     = 1'b0;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'bxx;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b0;
            end
            
            `OPCODE_LUI:    begin            //LUI
                ID_ALUOp        = `ALUOP_UTYPE;
                ID_MDSel        = 1'b0;
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
            
            `OPCODE_AUIPC:  begin            //AUIPC
                ID_ALUOp        = `ALUOP_UTYPE;
                ID_MDSel        = 1'b0;
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
                
            `OPCODE_JAL:    begin            //JAL
                ID_ALUOp        = `ALUOP_JUMP;
                ID_MDSel        = 1'b0;
                ID_ImmediateSrc = `IMM_J;
                ID_TargetSel    = `UJ_AL; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b10;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b1;            //PC
                ID_ALUSrc2      = 1'b1;            //Imm
            end
            
            `OPCODE_JALR:   begin            //JALR
                ID_ALUOp        = `ALUOP_LSJ;
                ID_MDSel        = 1'b0;
                ID_ImmediateSrc = `IMM_I;
                ID_TargetSel    = `UJ_ALR; 
                ID_RegWrite     = 1'b1;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b10;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b0;            //Rs1
                ID_ALUSrc2      = 1'b1;            //Imm
            end
            
            default:        begin            //Default
                ID_ALUOp        = `ALUOP_NOP;
                ID_MDSel        = 1'b0;
                ID_ImmediateSrc = `IMM_NONE;
                ID_TargetSel    = `TR_NOP;
                ID_RegWrite     = 1'b0;
                ID_MemRead      = 1'b0;
                ID_MemWrite     = 1'b0;
                ID_MemToReg     = 2'b00;
                ID_MemDataType  = `MEM_INVALID; 
                ID_ALUSrc1      = 1'b0;
                ID_ALUSrc2      = 1'b0;
            end
        endcase
    end
    
endmodule