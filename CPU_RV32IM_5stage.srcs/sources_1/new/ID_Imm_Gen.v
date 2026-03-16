/*
* Module: ID_Imm_Gen.v
* Description: Generates 32-bit sign-extended immediate based on 
* RV32IM instruction format. Left shifts immediates by 1 for 
* Branch and Jump immediates.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module ID_Imm_Gen #(
    parameter WIDTH       = 32,
    parameter INSTR_WIDTH = 32
    )(
    input  wire [INSTR_WIDTH-1:0] ID_Instr_RV32IM,  // Origin: IF_ID_Reg
    input  wire [2:0]             ID_ImmediateSrc,  // Origin: ID_Control_Unit 
    output reg  [WIDTH-1:0]       ID_Immediate      // Destination: ID_Branch_Target_Gen, ID_Jump_Target_Gen, ID_EX_Reg
    );

    // to silence linter warnings about unused instruction bits.
    wire ImmGen_unused = |{ID_Instr_RV32IM[24:20], ID_Instr_RV32IM[14:12], ID_Instr_RV32IM[6:0]};
                                           
    always @(*) begin
        case (ID_ImmediateSrc)
            `IMM_I: begin       // I-type arithmetic, logical instructions + LW & JALR
                ID_Immediate  = {{(WIDTH-12){ID_Instr_RV32IM[31]}}, ID_Instr_RV32IM[31:20]};
            end
            `IMM_S: begin       // S-type instructions (SW)
                ID_Immediate  = {{(WIDTH-12){ID_Instr_RV32IM[31]}}, ID_Instr_RV32IM[31:25], ID_Instr_RV32IM[11:7]}; 
            end
            `IMM_B: begin       // B-type instructions (All)
                ID_Immediate  = {{(WIDTH-12){ID_Instr_RV32IM[31]}}, ID_Instr_RV32IM[7], ID_Instr_RV32IM[30:25], ID_Instr_RV32IM[11:8], 1'b0};
            end
            `IMM_U: begin       // U-type instructions (LUI & AUIPC)
                ID_Immediate  = {ID_Instr_RV32IM[31:12], {(WIDTH-20){1'b0}}};
            end
            `IMM_J: begin       // J-type instructions (JAL only)
                ID_Immediate  = {{(WIDTH-20){ID_Instr_RV32IM[31]}}, ID_Instr_RV32IM[19:12], ID_Instr_RV32IM[20], ID_Instr_RV32IM[30:21], 1'b0};
            end
            `IMM_NONE: begin    // R-Type or Invalid ImmediateSrc, default Imm 0
                ID_Immediate  = {WIDTH{1'b0}};
            end
            default:   begin    // default fallback, default Imm 0
                ID_Immediate  = {WIDTH{1'b0}};
            end
        endcase
    end
       
endmodule