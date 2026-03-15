/*
* Module: ID_Target_Controller.v
* Description: Decides whether to take a branch or a jump based on
* control signals and condition flags from the ID stage.
* By consuming dedicated Eq/Lt/Ltu flags from the local ID comparator 
* instead of the main EX ALU, we resolve control hazards one cycle 
* earlier, saving considerable flush penalties.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module ID_Target_Controller(
    input  wire [3:0] ID_TargetSel,  // NEW: Origin: ID_Control_Unit (ID Stage)
    
    // Signals must come from local comparator logic in ID stage 
    input  wire       ID_Eq,         // Origin: ID_Branch_Comparator (Rs1 == Rs2)
    input  wire       ID_Lt,         // Origin: ID_Branch_Comparator (Rs1 < Rs2 signed)
    input  wire       ID_Ltu,        // Origin: ID_Branch_Comparator (Rs1 < Rs2 unsigned)
    
    output reg  [1:0] ID_PCSrc       // Destination: IF_PC_Next_Mux (IF Stage) & ID_Hazard_Unit
    );
    
    always @(*) begin
    
        case (ID_TargetSel)
        
            // MUX logic based on branch comparator signals
            `BR_EQ:  ID_PCSrc = {1'b0,  ID_Eq};     //BEQ
            `BR_NE:  ID_PCSrc = {1'b0, !ID_Eq};     //BNE
            `BR_LT:  ID_PCSrc = {1'b0,  ID_Lt};     //BLT
            `BR_GE:  ID_PCSrc = {1'b0, !ID_Lt};     //BGE
            `BR_LTU: ID_PCSrc = {1'b0,  ID_Ltu};    //BLTU
            `BR_GEU: ID_PCSrc = {1'b0, !ID_Ltu};    //BGEU
            
            `UJ_AL:  ID_PCSrc = 2'b10;              //JAL 
            `UJ_ALR: ID_PCSrc = 2'b10;              //JALR
            `TR_NOP: ID_PCSrc = 2'b00;              //default fallback for both control signals 0
            
            default: ID_PCSrc = 2'b00;              //default fallback for incorrect funct3    
             
        endcase
        
    end
    
endmodule