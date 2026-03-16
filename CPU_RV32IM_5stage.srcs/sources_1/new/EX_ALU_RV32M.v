/*
* Module: EX_ALU_RV32M.v
* Description: Multi-cycle implementation of RV32M operations.
* - Multiplication: Pipelined (2-cycle) using DSP registers.
* - Division: Multi-cycle (32-34 clocks) shift-subtract.
* Leaves RV32I instructions for EX_ALU_RV32I.v
* Status: 100MHz OPTIMIZED (Multiplier Pipelined, Branch Flags Gutted)
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module EX_ALU_RV32M #(parameter WIDTH = 32)(
    input  wire             clk,             
    input  wire             rst_n,           
    
    // --- Data Inputs ---
    input  wire [WIDTH-1:0] EX_Op1,          // Origin: EX_ALU_Input_Sel
    input  wire [WIDTH-1:0] EX_Op2,          // Origin: EX_ALU_Input_Sel
    
    // --- Control Inputs ---
    input  wire [5:0]       EX_ALUControl,   // Origin: EX_ALUControl_Gen
    input  wire             EX_MDSel,        // Origin: ID_EX_Reg
    
    // --- Outputs ---
    output reg  [WIDTH-1:0] EX_ALUResult_M,  // Destination: EX_ALUSelect_Mux
    // unified stall requests for Div and Mul
    output wire             EX_Stall_M       // Destination: ID_Hazard_Detector & EX_MEM_Reg
    );

    // Operation Decoders
    wire is_mul_op = EX_MDSel && ((EX_ALUControl == `ALU_MUL)  || (EX_ALUControl == `ALU_MULH) ||
                                  (EX_ALUControl == `ALU_MULHU)|| (EX_ALUControl == `ALU_MULHSU));
                                  
    wire is_div_op = EX_MDSel && ((EX_ALUControl == `ALU_DIV)  || (EX_ALUControl == `ALU_DIVU) ||
                                  (EX_ALUControl == `ALU_REM)  || (EX_ALUControl == `ALU_REMU));

    // ========================================================================
    // 1. MULTIPLIER (Pipelined - 2 Cycle)
    // ========================================================================
    reg op1_signed_mul, op2_signed_mul;
    
    always @(*) begin
        case (EX_ALUControl)
            `ALU_MUL, `ALU_MULH: begin op1_signed_mul = 1; op2_signed_mul = 1; end
            `ALU_MULHSU:         begin op1_signed_mul = 1; op2_signed_mul = 0; end
            default:             begin op1_signed_mul = 0; op2_signed_mul = 0; end
        endcase
    end

    // 33-bit operands
    wire signed [WIDTH:0] op1_33 = {op1_signed_mul & EX_Op1[WIDTH-1], EX_Op1};
    wire signed [WIDTH:0] op2_33 = {op2_signed_mul & EX_Op2[WIDTH-1], EX_Op2};
    
    reg signed [2*WIDTH-1:0] product_full;  // registered for DSP inference
    reg mul_valid; // 1-cycle delay state
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_full <= 0;
            mul_valid     <= 0;
        end else begin
            if (is_mul_op && !mul_valid) begin
                // Cycle 1: Capture inputs, start math, assert stall
                product_full <= op1_33 * op2_33;
                mul_valid     <= 1'b1;
            end else if (mul_valid) begin
                // Cycle 2: Math is done, release stall
                mul_valid     <= 1'b0;
            end
        end
    end

    // ========================================================================
    // 2. DIVIDER FSM & DATAPATH (Unchanged, already optimized)
    // ========================================================================
    localparam IDLE  = 2'b00;
    localparam WORK  = 2'b01;
    localparam DONE  = 2'b10;
    
    reg [1:0] state, next_state;
    reg [5:0] count;            
    
    reg [2*WIDTH:0] working_reg; 
    reg [WIDTH-1:0] divisor_abs;
    reg             sign_q, sign_r;
    reg             is_div, is_rem; 
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end
    
    always @(*) begin
        case (state)
            IDLE: next_state = (is_div_op) ? WORK : IDLE;
            WORK: next_state = (count == 1) ? DONE : WORK;
            DONE: next_state = IDLE; 
            default: next_state = IDLE;
        endcase
    end
    
    // Combinational subtraction
    wire [WIDTH:0] sub_result = working_reg[2*WIDTH:WIDTH] - {1'b0, divisor_abs};
    wire do_sub = ~sub_result[WIDTH]; 
    wire [WIDTH:0] next_upper = do_sub ? sub_result : working_reg[2*WIDTH:WIDTH];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count       <= 0;
            working_reg <= 0;
            divisor_abs <= 0;
            sign_q      <= 0;
            sign_r      <= 0;
            is_div      <= 0;
            is_rem      <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (is_div_op) begin
                        count <= WIDTH; 
                        is_div <= (EX_ALUControl == `ALU_DIV || EX_ALUControl == `ALU_DIVU);
                        is_rem <= (EX_ALUControl == `ALU_REM || EX_ALUControl == `ALU_REMU);
                        
                        if (EX_ALUControl == `ALU_DIV || EX_ALUControl == `ALU_REM) begin
                            sign_q <= EX_Op1[WIDTH-1] ^ EX_Op2[WIDTH-1];
                            sign_r <= EX_Op1[WIDTH-1];
                            working_reg <= {{WIDTH{1'b0}}, (EX_Op1[WIDTH-1] ? -EX_Op1 : EX_Op1), 1'b0}; 
                            divisor_abs <= (EX_Op2[WIDTH-1] ? -EX_Op2 : EX_Op2);
                        end else begin
                            sign_q <= 0;
                            sign_r <= 0;
                            working_reg <= {{WIDTH{1'b0}}, EX_Op1, 1'b0};
                            divisor_abs <= EX_Op2;
                        end
                    end
                end
                
                WORK: begin
                    if (count > 1) begin
                        working_reg <= {next_upper[WIDTH-1:0], working_reg[WIDTH-1:1], do_sub, 1'b0};
                    end else begin
                        working_reg <= {next_upper, working_reg[WIDTH-1:1], do_sub};
                    end
                    count <= count - 1;
                end
                
                DONE: begin end
                default: begin
                    count       <= 0;
                    working_reg <= 0;
                    divisor_abs <= 0;
                    sign_q      <= 0;
                    sign_r      <= 0;
                    is_div      <= 0;
                    is_rem      <= 0;
                end
            endcase
        end
    end

    // ========================================================================
    // 3. UNIFIED STALL LOGIC
    // ========================================================================
    // The Hazard Unit must stall the pipeline if EITHER unit is busy calculating.
    wire div_busy = ((state == IDLE && is_div_op) || state == WORK);
    assign EX_Stall_M = (div_busy || (is_mul_op && !mul_valid));

    // ========================================================================
    // 4. OUTPUT MUX
    // ========================================================================
    reg [WIDTH-1:0] quot_tmp;
    reg [WIDTH-1:0] rem_tmp;

    always @(*) begin
        EX_ALUResult_M = 0;
        quot_tmp = working_reg[WIDTH-1:0];
        rem_tmp  = working_reg[2*WIDTH-1:WIDTH];
        
        if (EX_MDSel) begin
            if (is_div_op) begin
                if (state == DONE) begin
                    if (is_div) EX_ALUResult_M = (sign_q) ? -quot_tmp : quot_tmp;
                    else        EX_ALUResult_M = (sign_r) ? -rem_tmp : rem_tmp;
                    
                    if (EX_Op2 == 0) EX_ALUResult_M = is_rem ? EX_Op1 : {WIDTH{1'b1}};  
                end 
            end 
            else if (is_mul_op) begin
                // Waiting for the DSP register to clock in the valid result.
                if (mul_valid) begin
                    case (EX_ALUControl)
                        `ALU_MUL:    EX_ALUResult_M = product_full[WIDTH-1:0];
                        `ALU_MULH, `ALU_MULHU, `ALU_MULHSU: 
                                     EX_ALUResult_M = product_full[2*WIDTH-1:WIDTH];
                        default:     EX_ALUResult_M = 0;
                    endcase
                end
            end
        end
    end

endmodule