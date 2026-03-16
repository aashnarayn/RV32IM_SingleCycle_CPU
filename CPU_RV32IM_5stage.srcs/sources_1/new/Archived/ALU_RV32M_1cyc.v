/*
* Module: ALU_RV32M.v
* Description: Performs RV32M operations using shared resources to 
* optimize critical path timing for 5-stage pipeline.
* Collapses 4 Multipliers -> 1 DSP Slice (33-bit).
* Collapses 4 Dividers -> 1 Unsigned Divider.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module ALU_RV32M #(parameter WIDTH = 32)(       
    input  wire [WIDTH-1:0] EX_Op1,          // Origin: ALU_Input_Selector
    input  wire [WIDTH-1:0] EX_Op2,          // Origin: ALU_Input_Selector
    input  wire [5:0]       EX_ALUControl,   // Origin: ALUControl_Gen
    input  wire             EX_MDSel,        // Origin: ID/EX Pipeline Register
    output reg  [WIDTH-1:0] EX_ALUResult_M,  // Destination: EX/MEM Pipeline Register
    output wire             EX_Zero_M        // Destination: Branch Logic
    );

    // ========================================================================
    // 1. UNIFIED MULTIPLIER LOGIC (33-bit Signed)
    // ========================================================================
    // We extend operands to 33 bits.
    // - For Signed ops:   Bit 33 is the sign bit (Op[31]).
    // - For Unsigned ops: Bit 33 is 0.
    // This allows one DSP block to handle signed, unsigned, and mixed modes.
    
    reg         op1_signed_mul, op2_signed_mul;
    
    always @(*) begin
        case (EX_ALUControl)
            `ALU_MUL, `ALU_MULH: begin 
                op1_signed_mul = 1'b1; 
                op2_signed_mul = 1'b1; 
            end
            `ALU_MULHSU: begin 
                op1_signed_mul = 1'b1; 
                op2_signed_mul = 1'b0; 
            end
            default: begin // MULHU
                op1_signed_mul = 1'b0; 
                op2_signed_mul = 1'b0; 
            end
        endcase
    end

    wire signed [WIDTH:0] op1_33 = {op1_signed_mul & EX_Op1[WIDTH-1], EX_Op1};
    wire signed [WIDTH:0] op2_33 = {op2_signed_mul & EX_Op2[WIDTH-1], EX_Op2};
    
    // The Single Shared Multiplier
    wire signed [2*WIDTH+1:0] product_full = op1_33 * op2_33;


    // ========================================================================
    // 2. UNIFIED DIVIDER LOGIC (Unsigned w/ Pre-Post Processing)
    // ========================================================================
    // Converting everything to unsigned division saves massive area.
    
    // A. Detect Sign Mode
    wire is_signed_div = (EX_ALUControl == `ALU_DIV) || (EX_ALUControl == `ALU_REM);
    
    // B. Calculate Absolute Values (Magnitude)
    wire op1_sign = EX_Op1[WIDTH-1];
    wire op2_sign = EX_Op2[WIDTH-1];
    
    wire [WIDTH-1:0] op1_abs = (is_signed_div && op1_sign) ? -EX_Op1 : EX_Op1;
    wire [WIDTH-1:0] op2_abs = (is_signed_div && op2_sign) ? -EX_Op2 : EX_Op2;
    
    // C. The Single Shared Divider
    // Note: Division by zero usually returns 'All Ones' in hardware before checks
    wire [WIDTH-1:0] u_quotient  = op1_abs / op2_abs;
    wire [WIDTH-1:0] u_remainder = op1_abs % op2_abs;
    
    // D. Sign Correction for Results
    // Quotient is negative if signs differ. Remainder takes sign of Dividend (Op1).
    wire [WIDTH-1:0] div_res_signed = (op1_sign ^ op2_sign) ? -u_quotient : u_quotient;
    wire [WIDTH-1:0] rem_res_signed = (op1_sign)            ? -u_remainder : u_remainder;


    // ========================================================================
    // 3. FINAL RESULT SELECTION
    // ========================================================================
    
    always @(*) begin
        EX_ALUResult_M = {WIDTH{1'b0}};
        
        if (EX_MDSel) begin
            case (EX_ALUControl)
                // --- Multiplier Outputs ---
                `ALU_MUL:    EX_ALUResult_M = product_full[WIDTH-1:0];      // Lower 32
                `ALU_MULH,
                `ALU_MULHU,
                `ALU_MULHSU: EX_ALUResult_M = product_full[2*WIDTH-1:WIDTH];// Upper 32
                
                // --- Divider Outputs (With Overflow/Zero Checks) ---
                `ALU_DIV: begin
                    if (EX_Op2 == 0)             EX_ALUResult_M = -1; // Div By Zero
                    else if (EX_Op1 == {1'b1, {WIDTH-1{1'b0}}} && EX_Op2 == -1) 
                                                 EX_ALUResult_M = {1'b1, {WIDTH-1{1'b0}}}; // Overflow
                    else                         EX_ALUResult_M = div_res_signed;
                end
                
                `ALU_DIVU: begin
                    if (EX_Op2 == 0)             EX_ALUResult_M = -1; // Div By Zero
                    else                         EX_ALUResult_M = u_quotient;
                end
                
                `ALU_REM: begin
                    if (EX_Op2 == 0)             EX_ALUResult_M = EX_Op1; // Rem By Zero
                    else if (EX_Op1 == {1'b1, {WIDTH-1{1'b0}}} && EX_Op2 == -1) 
                                                 EX_ALUResult_M = 0; // Overflow
                    else                         EX_ALUResult_M = rem_res_signed;
                end
                
                `ALU_REMU: begin
                    if (EX_Op2 == 0)             EX_ALUResult_M = EX_Op1; // Rem By Zero
                    else                         EX_ALUResult_M = u_remainder;
                end
                
                default: EX_ALUResult_M = {WIDTH{1'b0}};
            endcase
        end
    end

    assign EX_Zero_M = (EX_ALUResult_M == 0);

endmodule