/*
* Module: ALUControl_Gen.v
* Description: Generates ALUcontrol signals based on ALUop and split 
* instruction fields. Updated to support MAC/MACI by identifying 
* the multiplication requirement for the MAC_Adder path.
* Stage: EX
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module ALUControl_Gen (
    input  wire [2:0] EX_ALUOp,         // Origin: ID_EX Pipeline Register
    input  wire       EX_MACSel,        // NEW: Origin: ID_EX Pipeline Register
    input  wire [2:0] EX_Funct3,        // Origin: ID/EX Pipeline Register
    input  wire [6:0] EX_Funct7,        // Origin: ID/EX Pipeline Register
    input  wire [6:0] EX_Opcode,        // Origin: ID/EX Pipeline Register
    output reg  [5:0] EX_ALUControl     // Destination: ALU_RV32I, ALU_RV32M
    );
  
    always @(*) begin
        case (EX_ALUOp)
    
            // Load/Store/JALR: ALU does ADD
            `ALUOP_LSJ: begin
                EX_ALUControl = `ALU_ADD;
            end
        
            // Branches: Unified Comparison Strategy
            `ALUOP_BRANCH: begin
                case ({1'b0, EX_Funct3})
                    `BR_EQ:   EX_ALUControl = `ALU_BEQ;
                    `BR_NE:   EX_ALUControl = `ALU_BNE;
                    `BR_LT:   EX_ALUControl = `ALU_BLT;
                    `BR_GE:   EX_ALUControl = `ALU_BGE;
                    `BR_LTU:  EX_ALUControl = `ALU_BLTU;
                    `BR_GEU:  EX_ALUControl = `ALU_BGEU;
                    default:  EX_ALUControl = `ALU_NOP;
                endcase
            end
    
            // R-Type Integer
            `ALUOP_RTYPE: begin
                case (EX_Funct3)
                    3'b000:  EX_ALUControl = (EX_Funct7 == 7'b0100000) ? `ALU_SUB : `ALU_ADD;
                    3'b001:  EX_ALUControl = `ALU_SLL;
                    3'b010:  EX_ALUControl = `ALU_SLT;
                    3'b011:  EX_ALUControl = `ALU_SLTU;
                    3'b100:  EX_ALUControl = `ALU_XOR;
                    3'b101:  EX_ALUControl = (EX_Funct7 == 7'b0100000) ? `ALU_SRA : `ALU_SRL;
                    3'b110:  EX_ALUControl = `ALU_OR;
                    3'b111:  EX_ALUControl = `ALU_AND;
                    default: EX_ALUControl = `ALU_NOP;
                endcase
            end
    
            // I-Type Integer
            `ALUOP_ITYPE: begin
                case (EX_Funct3)
                    3'b000:  EX_ALUControl = `ALU_ADD;   
                    3'b001:  EX_ALUControl = `ALU_SLL;   
                    3'b010:  EX_ALUControl = `ALU_SLT;   
                    3'b011:  EX_ALUControl = `ALU_SLTU;  
                    3'b100:  EX_ALUControl = `ALU_XOR;   
                    3'b101:  EX_ALUControl = (EX_Funct7 == 7'b0100000) ? `ALU_SRA : `ALU_SRL; 
                    3'b110:  EX_ALUControl = `ALU_OR;    
                    3'b111:  EX_ALUControl = `ALU_AND;   
                    default: EX_ALUControl = `ALU_NOP;
                endcase
            end
    
            // RV32M (Multiply & Divide) + MAC Product Generation
            `ALUOP_RMUL: begin
                if (EX_MACSel) begin
                    // For MAC/MACI, we need a standard 32-bit signed multiply 
                    // to feed the Product into the MAC_Adder.
                    EX_ALUControl = `ALU_MUL;
                end else begin
                    case (EX_Funct3)
                        3'b000:  EX_ALUControl = `ALU_MUL;
                        3'b001:  EX_ALUControl = `ALU_MULH;
                        3'b010:  EX_ALUControl = `ALU_MULHSU;
                        3'b011:  EX_ALUControl = `ALU_MULHU;
                        3'b100:  EX_ALUControl = `ALU_DIV;
                        3'b101:  EX_ALUControl = `ALU_DIVU;
                        3'b110:  EX_ALUControl = `ALU_REM;
                        3'b111:  EX_ALUControl = `ALU_REMU;
                        default: EX_ALUControl = `ALU_NOP;
                    endcase
                end
            end
    
            // U-Type
            `ALUOP_UTYPE: begin
                EX_ALUControl = (EX_Opcode == `OPCODE_LUI) ? `ALU_LUI : `ALU_AUIPC;
            end
    
            // Jump
            `ALUOP_JUMP: begin
                EX_ALUControl = `ALU_JAL;
            end
    
            default: EX_ALUControl = `ALU_NOP;
    
        endcase
    end

endmodule