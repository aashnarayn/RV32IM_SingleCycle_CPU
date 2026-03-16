`timescale 1ns / 1ps

// --- Mock Control Codes --- 
// (Comment these out if your CPU_Control_Codes.vh is properly linked in Vivado)
`define ALU_ADD    6'd0
`define ALU_SUB    6'd1
`define ALU_AND    6'd2
`define ALU_OR     6'd3
`define ALU_XOR    6'd4
`define ALU_SLL    6'd5
`define ALU_SRL    6'd6
`define ALU_SRA    6'd7
`define ALU_SLT    6'd8
`define ALU_SLTU   6'd9
`define ALU_PASS_B 6'd10
`define ALU_NOP    6'd63

module tb_EX_ALU_RV32I;

    // --- Parameters ---
    parameter WIDTH = 32;

    // --- Testbench Signals ---
    reg  signed [WIDTH-1:0] EX_Op1;
    reg  signed [WIDTH-1:0] EX_Op2;
    reg         [5:0]       EX_ALUControl;
    reg                     EX_MDSel;
    wire        [WIDTH-1:0] EX_ALUResult_I;

    // --- Instantiate the ALU ---
    EX_ALU_RV32I #(
        .WIDTH(WIDTH)
    ) uut (
        .EX_Op1(EX_Op1),
        .EX_Op2(EX_Op2),
        .EX_ALUControl(EX_ALUControl),
        .EX_MDSel(EX_MDSel),
        .EX_ALUResult_I(EX_ALUResult_I)
    );

    // --- String for displaying the current operation in console ---
    reg [159:0] op_name; 

    // --- Test Sequence ---
    initial begin
        // ====================================================================
        // THE "NO RED LINES" FIX:
        // Force every single input to a known state at exactly time 0.
        // ====================================================================
        EX_Op1        = 32'b0;
        EX_Op2        = 32'b0;
        EX_ALUControl = `ALU_NOP;
        EX_MDSel      = 1'b0;
        op_name       = "INIT";
        
        $display("=========================================================================");
        $display(" Operation |   Op1 (Hex)  |   Op2 (Hex)  |  Result (Hex) |  Result (Dec) ");
        $display("=========================================================================");
        
        $monitor(" %-9s |   %8h   |   %8h   |    %8h   |  %11d", 
                 op_name, EX_Op1, EX_Op2, EX_ALUResult_I, $signed(EX_ALUResult_I));

        // Wait 10ns to show a clean start on the waveform
        #10;

        // 1. Basic Arithmetic (ADD/SUB)
        op_name = "ADD"; EX_ALUControl = `ALU_ADD; EX_Op1 = 32'd15; EX_Op2 = 32'd25; #10;
        op_name = "SUB (Pos)"; EX_ALUControl = `ALU_SUB; EX_Op1 = 32'd50; EX_Op2 = 32'd20; #10;
        op_name = "SUB (Neg)"; EX_ALUControl = `ALU_SUB; EX_Op1 = 32'd10; EX_Op2 = 32'd30; #10;

        // 2. Logical Operations (AND/OR/XOR)
        op_name = "AND"; EX_ALUControl = `ALU_AND; EX_Op1 = 32'h00FF00FF; EX_Op2 = 32'h0F0F0F0F; #10;
        op_name = "OR";  EX_ALUControl = `ALU_OR;  EX_Op1 = 32'hAA00AA00; EX_Op2 = 32'h00550055; #10;
        op_name = "XOR"; EX_ALUControl = `ALU_XOR; EX_Op1 = 32'hFFFFFFFF; EX_Op2 = 32'h12345678; #10;

        // 3. Shift Operations (SLL/SRL/SRA)
        op_name = "SLL"; EX_ALUControl = `ALU_SLL; EX_Op1 = 32'h00000001; EX_Op2 = 32'd4; #10;
        op_name = "SRL"; EX_ALUControl = `ALU_SRL; EX_Op1 = 32'h80000000; EX_Op2 = 32'd4; #10;
        
        // SRA copies the sign bit (1), so 0x80000000 becomes 0xF8000000
        op_name = "SRA"; EX_ALUControl = `ALU_SRA; EX_Op1 = 32'h80000000; EX_Op2 = 32'd4; #10;

        // 4. Set Less Than (Signed vs Unsigned)
        // Signed: -5 is less than 10 (Result = 1)
        op_name = "SLT"; EX_ALUControl = `ALU_SLT; EX_Op1 = -32'd5; EX_Op2 = 32'd10; #10;
        
        // Unsigned: -5 is cast to 0xFFFFFFFB, which is NOT less than 10 (Result = 0)
        op_name = "SLTU"; EX_ALUControl = `ALU_SLTU; EX_Op1 = -32'd5; EX_Op2 = 32'd10; #10;

        // 5. Bypass & NOP
        op_name = "PASS_B"; EX_ALUControl = `ALU_PASS_B; EX_Op1 = 32'hDEADBEEF; EX_Op2 = 32'hCAFEBABE; #10;
        op_name = "NOP";    EX_ALUControl = `ALU_NOP;    EX_Op1 = 32'h12345678; EX_Op2 = 32'h87654321; #10;

        // 6. M-Extension Priority Check
        // If MDSel is 1, the Integer ALU MUST output 0, even if the control says ADD
        op_name = "MD_BYPASS"; EX_ALUControl = `ALU_ADD; EX_Op1 = 32'd100; EX_Op2 = 32'd200; EX_MDSel = 1'b1; #10;

        $display("=========================================================================");
        $display("Integer ALU Simulation Complete.");
        $finish;
    end

    // --- Waveform Generation ---
    initial begin
        $dumpfile("ALU_RV32I_Trace.vcd");
        $dumpvars(0, tb_EX_ALU_RV32I);
    end

endmodule