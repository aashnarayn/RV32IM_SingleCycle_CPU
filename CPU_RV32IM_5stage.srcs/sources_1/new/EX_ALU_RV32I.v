/*
* Module: EX_ALU_RV32I.v
* Description: Performs combinational operations as required
* by the RV32I instruction set and sends result.
* Leaves RV32M instructions for EX_ALU_RV32M.v
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

//NOTE: This ALU can be scaled from 32 bit to any instruction length using the parameter WIDTH
module EX_ALU_RV32I #(parameter WIDTH = 32)(       
    input  wire signed [WIDTH-1:0] EX_Op1,          // Origin: EX_ALU_Input_Sel 
    input  wire signed [WIDTH-1:0] EX_Op2,          // Origin: EX_ALU_Input_Sel 
    input  wire        [5:0]       EX_ALUControl,   // Origin: EX_ALUControl_Gen 
    input  wire                    EX_MDSel,        // Origin: ID_EX_Reg
    output reg         [WIDTH-1:0] EX_ALUResult_I   // Destination: EX_ALUSelect_Mux
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
            // RV32I spec operations (RISBUJ) - core math functions only
            case (EX_ALUControl) 
                `ALU_ADD:    EX_ALUResult_I = EX_Op1 + EX_Op2;
                `ALU_SUB:    EX_ALUResult_I = EX_Op1 - EX_Op2;
                `ALU_AND:    EX_ALUResult_I = EX_Op1 & EX_Op2;
                `ALU_OR:     EX_ALUResult_I = EX_Op1 | EX_Op2;
                `ALU_XOR:    EX_ALUResult_I = EX_Op1 ^ EX_Op2;
                `ALU_SLL:    EX_ALUResult_I = EX_Op1 << EX_Op2[$clog2(WIDTH)-1:0];
                `ALU_SRL:    EX_ALUResult_I = EX_Op1 >> EX_Op2[$clog2(WIDTH)-1:0];
                `ALU_SRA:    EX_ALUResult_I = EX_Op1 >>> EX_Op2[$clog2(WIDTH)-1:0];
                `ALU_SLT:    EX_ALUResult_I = (EX_Op1 < EX_Op2) ? ONE : ZERO;
                `ALU_SLTU:   EX_ALUResult_I = (uOp1 < uOp2) ? ONE : ZERO;
                `ALU_PASS_B: EX_ALUResult_I = EX_Op2;
                        
                // Default cases
                `ALU_NOP:    EX_ALUResult_I = ZERO;
                default:     EX_ALUResult_I = ZERO;
            endcase
             
        end
        
    end
    
    // No ZERO logic needed anymore as Branch decisions are taken using logic in ID
    
endmodule