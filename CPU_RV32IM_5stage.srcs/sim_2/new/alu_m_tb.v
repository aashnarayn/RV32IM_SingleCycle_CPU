`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

module tb_EX_ALU_RV32M;

    // --- Parameters ---
    parameter WIDTH = 32;

    // --- Testbench Signals ---
    reg               clk;
    reg               rst_n;
    reg  [WIDTH-1:0]  EX_Op1;
    reg  [WIDTH-1:0]  EX_Op2;
    reg  [5:0]        EX_ALUControl;
    reg               EX_MDSel;
    
    wire [WIDTH-1:0]  EX_ALUResult_M;
    wire              EX_Stall_M;

    // --- Instantiate the M-Extension ALU ---
    EX_ALU_RV32M #(
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .EX_Op1(EX_Op1),
        .EX_Op2(EX_Op2),
        .EX_ALUControl(EX_ALUControl),
        .EX_MDSel(EX_MDSel),
        .EX_ALUResult_M(EX_ALUResult_M),
        .EX_Stall_M(EX_Stall_M)
    );

    // --- Clock Generation (100MHz) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // --- Task to mimic the Pipeline Stall Logic ---
   task test_m_op;
        input [159:0] op_name;
        input [5:0]   ctrl;
        input [31:0]  op1;
        input [31:0]  op2;
        input [31:0]  expected;
        begin
            @(negedge clk);
            EX_Op1        = op1;
            EX_Op2        = op2;
            EX_ALUControl = ctrl;
            EX_MDSel      = 1'b1;

            // Wait for the hardware to acknowledge the start and assert the stall
            // This takes about 1-2 delta cycles in simulation
            wait(EX_Stall_M === 1'b1);
            
            // Now wait for the hardware to finish and DROP the stall
            wait(EX_Stall_M === 1'b0);
            
            // THE FIX: Sample IMMEDIATELY when the stall drops.
            // In a real pipeline, this is the exact moment the EX/MEM register 
            // would capture the data.
            #1; // Tiny delay to let combinational logic settle
            
            if (EX_ALUResult_M === expected) begin
                $display("[PASS] %-10s: Op1=%d, Op2=%d -> Result=%d", op_name, $signed(op1), $signed(op2), $signed(EX_ALUResult_M));
            end else begin
                $display("[FAIL] %-10s: Op1=%d, Op2=%d | Expected %h, got %h", op_name, $signed(op1), $signed(op2), expected, EX_ALUResult_M);
                $stop;
            end
            
            @(negedge clk);
            EX_ALUControl = `ALU_NOP;
            EX_MDSel      = 1'b0;
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        // ====================================================================
        // INITIALIZATION AT T=0 (No Red Lines)
        // ====================================================================
        rst_n         = 1'b0;
        EX_Op1        = 32'b0;
        EX_Op2        = 32'b0;
        EX_ALUControl = `ALU_NOP;
        EX_MDSel      = 1'b0;
        
        $display("\n=== STARTING M-EXTENSION ALU SIMULATION ===");

        // Hold reset for 5 cycles to clear internal FSM/Pipeline registers
        repeat(5) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        
        $display("[INFO] Reset released.\n");

        // --- 1. Multiplication (2-Cycle Pipelined) ---
        test_m_op("MUL (Pos)",  `ALU_MUL, 32'd10,  32'd5,  32'd50);
        test_m_op("MUL (Neg)",  `ALU_MUL, -32'd10, 32'd5,  -32'd50);
        
        // --- 2. Division (Multi-Cycle FSM) ---
        test_m_op("DIV (Pos)",  `ALU_DIV, 32'd100, 32'd3,  32'd33);
        test_m_op("DIV (Neg)",  `ALU_DIV, -32'd100, 32'd3, -32'd33);
        
        // --- 3. Remainder ---
        test_m_op("REM (Pos)",  `ALU_REM, 32'd100, 32'd3,  32'd1);
        
        // --- 4. RV32M Edge Cases ---
        test_m_op("DIV by 0",   `ALU_DIV, 32'd100, 32'd0,  32'hFFFFFFFF);
        test_m_op("REM by 0",   `ALU_REM, 32'd100, 32'd0,  32'd100);

        $display("\n=== ALL RV32M TESTS PASSED ===");
        $finish;
    end

    // --- Waveform Generation ---
    initial begin
        $dumpfile("ALU_RV32M_Trace.vcd");
        $dumpvars(0, tb_EX_ALU_RV32M);
    end

endmodule