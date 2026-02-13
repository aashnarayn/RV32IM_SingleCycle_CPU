/*
* Module: Target_Controller.v
* Description: Decides whether to take a branch or a jump based on
* control signals and condition flags from ALU.
* Implements Zero signal based branching decisions.
* Updated for EX stage signal naming in 5-stage pipeline.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

//(* dont_touch = "true" *)
module Target_Controller(
    input  wire [3:0] EX_TargetSel,  // Origin: ID/EX Pipeline Register (Control Bundle)
    input  wire       EX_Zero,       // Origin: ALUSelect_Mux (EX Stage)
    output reg  [1:0] EX_PCSrc       // Destination: Next-PC Mux (IF Stage) & Hazard/Flush Unit
    );
    
    always @(*) begin
    
        case (EX_TargetSel)
        
            `BR_EQ:  EX_PCSrc = {1'b0,EX_Zero};     //BEQ
            `BR_NE:  EX_PCSrc = {1'b0,!EX_Zero};    //BNE
            `BR_LT:  EX_PCSrc = {1'b0,!EX_Zero};    //BLT
            `BR_GE:  EX_PCSrc = {1'b0,EX_Zero};     //BGE
            `BR_LTU: EX_PCSrc = {1'b0,!EX_Zero};    //BLTU
            `BR_GEU: EX_PCSrc = {1'b0,EX_Zero};     //BGEU
            `UJ_AL:  EX_PCSrc = 2'b10;              //JAL 
            `UJ_ALR: EX_PCSrc = 2'b10;              //JALR
            `TR_NOP: EX_PCSrc = 2'b00;              //default fallback for both control signals 0
            
            default: EX_PCSrc = 2'b00;              //default fallback for incorrect funct3    
             
        endcase
        
    end
    
endmodule