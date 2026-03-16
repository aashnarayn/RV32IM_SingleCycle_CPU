/*
* Module: EX_ALUControl_Gen.v
* Description: Generates ALUcontrol signals based on ALUop and split 
* instruction fields. Updated to support MAC/MACI. Branch operations 
* resolve to ALU_NOP here because the dedicated comparator in the ID 
* stage handles them. MAC instructions resolve to ALU_MUL to pipeline 
* the product into the MAC Adder.
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module EX_ALUControl_Gen (
    input  wire [2:0] EX_ALUOp,         // Origin: ID_EX_Reg
    input  wire       EX_MACSel,        // Origin: ID_EX_Reg
    input  wire [2:0] EX_Funct3,        // Origin: ID/EX_Reg
    input  wire [6:0] EX_Funct7,        // Origin: ID/EX_Reg
    input  wire [6:0] EX_Opcode,        // Origin: ID/EX_Reg
    output reg  [5:0] EX_ALUControl     // Destination: EX_ALU_RV32I, EX_LU_RV32M
    );
  
    always @(*) begin
        case (EX_ALUOp)
    
            // Load/Store: ALU does ADD for Memory Address calculation
            `ALUOP_MEM: begin
                EX_ALUControl = `ALU_ADD;
            end
        
            // Branches: Unified Comparison Strategy
            `ALUOP_BRANCH: begin
                // Branch resolution is fully handled in ID stage by the dedicated comparator.
                EX_ALUControl = `ALU_NOP;
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
                    // to feed the Product into the MAC Accumulator.
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
                // Jump targets are computed in ID. ALU does nothing.
                EX_ALUControl = `ALU_NOP;
            end
    
            default: EX_ALUControl = `ALU_NOP;
    
        endcase
    end

endmodule