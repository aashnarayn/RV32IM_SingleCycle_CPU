/*
* Module: ALU_RV32M.v
* Description: Multi-cycle implementation of RV32M operations.
* - Multiplication: Single-cycle (DSP Slice).
* - Division: Multi-cycle (32-34 clocks) with Stall Logic to optimize Critical Path.
* Stage: EX
* Author: Aashrith S Narayn
* Date: 14/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module ALU_RV32M #(parameter WIDTH = 32)(
    input  wire             clk,             // Origin: System Clock
    input  wire             rst_n,           // Origin: System Reset
    
    // --- Data Inputs (From ALU Input Selector) ---
    input  wire [WIDTH-1:0] EX_Op1,          // Origin: ALU_Input_Selector (Dividend / Multiplicand)
    input  wire [WIDTH-1:0] EX_Op2,          // Origin: ALU_Input_Selector (Divisor / Multiplier)
    
    // --- Control Inputs (From Control Logic) ---
    input  wire [5:0]       EX_ALUControl,   // Origin: ALUControl_Gen (Opcode Decoded)
    input  wire             EX_MDSel,        // Origin: ID_EX_reg (Enable Signal for M-Ext)
    
    // --- Outputs (To Selection Logic & Hazard Unit) ---
    output reg  [WIDTH-1:0] EX_ALUResult_M,  // Destination: ALUSelect_Mux & MAC_Adder
    output wire             EX_Zero_M,       // Destination: ALUSelect_Mux
    output reg              EX_Stall_M       // Destination: Hazard_Detection_Unit (Stall Request for Divider)
    );

    // ========================================================================
    // 1. MULTIPLIER (Combinational - Single Cycle)
    // ========================================================================
    // (Same logic as before - DSP slices are fast enough for 1 cycle)
    reg op1_signed_mul, op2_signed_mul;
    
    always @(*) begin
        case (EX_ALUControl)
            `ALU_MUL, `ALU_MULH: begin op1_signed_mul = 1; op2_signed_mul = 1; end
            `ALU_MULHSU:         begin op1_signed_mul = 1; op2_signed_mul = 0; end
            default:             begin op1_signed_mul = 0; op2_signed_mul = 0; end
        endcase
    end

    wire signed [WIDTH:0] op1_33 = {op1_signed_mul & EX_Op1[WIDTH-1], EX_Op1};
    wire signed [WIDTH:0] op2_33 = {op2_signed_mul & EX_Op2[WIDTH-1], EX_Op2};
    wire signed [2*WIDTH-1:0] product_full = op1_33 * op2_33;


    // ========================================================================
    // 2. DIVIDER FSM & DATAPATH
    // ========================================================================
    
    // FSM States
    localparam IDLE  = 2'b00;
    localparam WORK  = 2'b01;
    localparam DONE  = 2'b10;
    
    reg [1:0] state, next_state;
    reg [5:0] count;            // Counter for 32 iterations
    
    // Internal Registers for Shift-Subtract
    reg [2*WIDTH:0] working_reg; // 65-bit register: {Remainder, Quotient}
    reg [WIDTH-1:0] divisor_abs;
    reg             sign_q, sign_r;
    reg             is_div, is_rem; // To latch the operation type
    
    reg [WIDTH:0] diff; // 33-bit for carry
    
    // Logic to detect if current op is Division
    wire is_div_op = EX_MDSel && ((EX_ALUControl == `ALU_DIV)  || (EX_ALUControl == `ALU_DIVU) ||
                                  (EX_ALUControl == `ALU_REM)  || (EX_ALUControl == `ALU_REMU));

    // A. FSM Control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end
    
    always @(*) begin
        case (state)
            IDLE: next_state = (is_div_op) ? WORK : IDLE;
            WORK: next_state = (count == 0) ? DONE : WORK;
            DONE: next_state = IDLE; // Handshake complete, return to IDLE
            default: next_state = IDLE;
        endcase
    end
    
    // B. Stall Signal Generation
    // We stall during WORK state. In DONE, we release stall so result is captured.
    always @(*) begin
        if ((state == IDLE && is_div_op) || state == WORK) 
            EX_Stall_M = 1'b1;
        else 
            EX_Stall_M = 1'b0;
    end

    // C. Divider Datapath (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count       <= 0;
            working_reg <= 0;
            divisor_abs <= 0;
            sign_q      <= 0;
            sign_r      <= 0;
            is_div      <= 0;
            is_rem      <= 0;
            diff        <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (is_div_op) begin
                        // 1. Initialize for new operation
                        count <= WIDTH; // Load counter (32)
                        
                        // Latch Op type
                        is_div <= (EX_ALUControl == `ALU_DIV || EX_ALUControl == `ALU_DIVU);
                        is_rem <= (EX_ALUControl == `ALU_REM || EX_ALUControl == `ALU_REMU);
                        
                        // Handle Signs
                        if (EX_ALUControl == `ALU_DIV || EX_ALUControl == `ALU_REM) begin
                            sign_q <= EX_Op1[WIDTH-1] ^ EX_Op2[WIDTH-1];
                            sign_r <= EX_Op1[WIDTH-1];
                            // Load Absolute Values
                            working_reg <= {{WIDTH{1'b0}}, (EX_Op1[WIDTH-1] ? -EX_Op1 : EX_Op1), 1'b0}; // Shift left by 1 init
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
                    // 2. Iterative Calculation (Shift & Subtract)
                    // working_reg structure: | Remainder (32) | Quotient (32) | (Implicit Shift)
                    
                    // We look at the top 32+1 bits after the shift
                    diff = working_reg[2*WIDTH:WIDTH] - {1'b0, divisor_abs};
                    
                    if (!diff[WIDTH]) begin // No borrow (Result positive)
                        working_reg[2*WIDTH:WIDTH] <= diff[WIDTH-1:0];
                        working_reg[0] <= 1'b1; // Set Quotient bit
                    end
                    
                    count <= count - 1;
                    
                    if (count > 1) 
                        working_reg <= {working_reg[2*WIDTH-1:0], 1'b0}; // Shift for next bit
                    // else: Don't shift on the very last step, just subtract
                end
                
                DONE: begin
                    // 3. Cleanup (Nothing to do, results are stable in register)
                end
            endcase
        end
    end

    // ========================================================================
    // 3. OUTPUT MUX
    // ========================================================================
    // Logic to select between Multiplier result or Divider result
    
    // Helper regs declared outside the always block to fix Synth 8-10632
    reg [WIDTH-1:0] quot_tmp;
    reg [WIDTH-1:0] rem_tmp;

    always @(*) begin
        // Defaults to prevent latches
        EX_ALUResult_M = 0;
        quot_tmp = working_reg[WIDTH-1:0];
        rem_tmp  = working_reg[2*WIDTH:WIDTH+1];
        
        if (EX_MDSel) begin
            if (is_div_op) begin
                // --- Divider Result ---
                // Wait for DONE state to output valid result
                if (state == DONE) begin
                    // Apply Signs
                    if (is_div) EX_ALUResult_M = (sign_q) ? -quot_tmp : quot_tmp;
                    else        EX_ALUResult_M = (sign_r) ? -rem_tmp : rem_tmp;
                    
                    // Handle Divide By Zero (Corner Case)
                    if (EX_Op2 == 0) EX_ALUResult_M = -1; // Simplified spec compliance
                end else begin
                    EX_ALUResult_M = 0; // Invalid during calculation
                end
            end else begin
                // --- Multiplier Result (Same as before) ---
                case (EX_ALUControl)
                    `ALU_MUL:    EX_ALUResult_M = product_full[WIDTH-1:0];
                    `ALU_MULH, `ALU_MULHU, `ALU_MULHSU: 
                                 EX_ALUResult_M = product_full[2*WIDTH-1:WIDTH];
                    default:     EX_ALUResult_M = 0;
                endcase
            end
        end
    end

    assign EX_Zero_M = (EX_ALUResult_M == 0);

endmodule