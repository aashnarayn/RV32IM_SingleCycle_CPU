/*
* Module: ALU_RV32I.v
* Description: Performs combinational operations as required
* by the RV32I instruction set and sends result.
* Leaves RV32M instructions for ALU_RV32M.v
* Updated for 5-stage pipeline.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

//NOTE: This ALU can be scaled from 32 bit to any instruction length using the parameter WIDTH
//(* dont_touch = "true" *)
module ALU_RV32I #(parameter WIDTH = 32)(       
    input  wire signed [WIDTH-1:0] EX_Op1,          // Origin: ALU_Input_Selector (EX Stage)
    input  wire signed [WIDTH-1:0] EX_Op2,          // Origin: ALU_Input_Selector (EX Stage)
    input  wire        [5:0]       EX_ALUControl,   // Origin: ALUControl_Gen (EX Stage)
    input  wire                    EX_MDSel,        // Origin: ID/EX Pipeline Register
    output reg         [WIDTH-1:0] EX_ALUResult_I,  // Destination: EX/MEM Pipeline Register & Forwarding Unit
    output wire                    EX_Zero_I        // Destination: Branch Control Logic (EX Stage)
    );
    
    //0 and 1 notation for width-parametrized ALU use
    localparam [WIDTH-1:0] ZERO      = {WIDTH{1'b0}};
    localparam [WIDTH-1:0] ONE       = {{WIDTH-1{1'b0}}, 1'b1}; 
    
    //NOTE: operations that require signed inputs need the inputs to be declared as signed at the module definition
    //This means unsigned operations within the ALU logic need to be explicitly casted using temp variables
    //Output ALUResult_I need not be casted as signed within module definition
    
    //unsigned temps
    wire [WIDTH-1:0] uOp1 = $unsigned(EX_Op1);
    wire [WIDTH-1:0] uOp2 = $unsigned(EX_Op2);

    
    always @(*) begin
        
        if (EX_MDSel) begin
            EX_ALUResult_I = ZERO;  //Zero default for when MDSel is asserted in this ALU
        end else begin
            case (EX_ALUControl) 
            
                //Arithmetic and Logical Ops (R and I type, Load and Store) & Some Branches
                `ALU_ADD,
                `ALU_AUIPC,
                `ALU_JAL:    EX_ALUResult_I = EX_Op1 + EX_Op2;                           //ADD, ADDI, LW, SW, JALR - Rs1 + Imm, (JAL, AUIPC} - PC + Imm
                `ALU_SUB:    EX_ALUResult_I = EX_Op1 - EX_Op2;                           //SUB
                `ALU_AND:    EX_ALUResult_I = EX_Op1 & EX_Op2;                           //AND, ANDI
                `ALU_OR:     EX_ALUResult_I = EX_Op1 | EX_Op2;                           //OR, ORI
                `ALU_XOR:    EX_ALUResult_I = EX_Op1 ^ EX_Op2;                           //XOR, XORI
                `ALU_SLL:    EX_ALUResult_I = EX_Op1 << EX_Op2[$clog2(WIDTH)-1:0];       //SLL, SLLI
                `ALU_SRL:    EX_ALUResult_I = EX_Op1 >> EX_Op2[$clog2(WIDTH)-1:0];       //SRL, SRLI
                `ALU_SRA:    EX_ALUResult_I = EX_Op1 >>> EX_Op2[$clog2(WIDTH)-1:0];      //SRA, SRAI
                `ALU_SLT,
                `ALU_BLT,
                `ALU_BGE:    EX_ALUResult_I = (EX_Op1 < EX_Op2) ? ONE : ZERO;            //SLT, SLTI, BLT, BGE
                `ALU_SLTU,
                `ALU_BLTU,
                `ALU_BGEU:   EX_ALUResult_I = (uOp1 < uOp2) ? ONE : ZERO;                //SLTU, SLTIU, BGEU
                `ALU_BEQ,
                `ALU_BNE:    EX_ALUResult_I = ((EX_Op1 - EX_Op2) == 0) ? ZERO : ONE;     //BEQ, BNE
                `ALU_LUI:    EX_ALUResult_I = EX_Op2;                                    //LUI - Result = Imm
                        
                //default cases
                `ALU_NOP:    EX_ALUResult_I = ZERO;                                      //NOP
                default:     EX_ALUResult_I = ZERO;                                      //Unknown ALUControl, default to NOP
                
            endcase
             
        end
        
    end
    
    assign EX_Zero_I = (EX_ALUResult_I == ZERO);  // Destination: Branch Control Logic
    
endmodule