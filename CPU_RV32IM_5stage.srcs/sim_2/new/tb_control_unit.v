`timescale 1ns / 1ps
// Only include if not already added to the project global defines
`include "CPU_Control_Codes.vh" 

module tb_ID_Control_Unit();

    // --- Inputs ---
    reg [6:0] ID_Opcode;
    reg [2:0] ID_Funct3;
    reg [6:0] ID_Funct7;

    // --- Outputs ---
    wire [2:0] ID_ALUOp;
    wire       ID_MDSel, ID_MACSel, ID_ALUSrc1, ID_ALUSrc2;
    wire       ID_MemRead, ID_MemWrite, ID_RegWrite;
    wire [1:0] ID_MemToReg;
    wire [2:0] ID_MemDataType;
    wire [2:0] ID_ImmediateSrc;
    wire [3:0] ID_TargetSel;

    // --- Manual Port Mapping (Fixes the Syntax Error) ---
    ID_Control_Unit uut (
        .ID_Opcode(ID_Opcode),
        .ID_Funct3(ID_Funct3),
        .ID_Funct7(ID_Funct7),
        .ID_ALUOp(ID_ALUOp),
        .ID_MDSel(ID_MDSel),
        .ID_MACSel(ID_MACSel),
        .ID_ALUSrc1(ID_ALUSrc1),
        .ID_ALUSrc2(ID_ALUSrc2),
        .ID_MemRead(ID_MemRead),
        .ID_MemWrite(ID_MemWrite),
        .ID_MemDataType(ID_MemDataType),
        .ID_RegWrite(ID_RegWrite),
        .ID_MemToReg(ID_MemToReg),
        .ID_ImmediateSrc(ID_ImmediateSrc),
        .ID_TargetSel(ID_TargetSel)
    );

    initial begin
        // --- T=0 Initialization to prevent Red Lines ---
        ID_Opcode = 0; ID_Funct3 = 0; ID_Funct7 = 0;

        $display("\nLegend: RW:RegWrite | MR:MemRead | MW:MemWrite | AS1:ALUSrc1 | AS2:ALUSrc2 | MD:MDSel");
        $display("============================================================================================================");
        $display(" Instruction | RW | MR | MW | AS1 | AS2 | MD | MAC | ImmSrc | TargetSel | ALUOp");
        $display("============================================================================================================");

        #10;

        // 1. R-Type ADD
        ID_Opcode = `OPCODE_RTYPE; ID_Funct7 = 7'b0000000; ID_Funct3 = 3'b000; #10;
        $display(" R-ADD       | %b  | %b  | %b  |  %b  |  %b  | %b  |  %b  |   %d    |    %d      |  %d", 
                 ID_RegWrite, ID_MemRead, ID_MemWrite, ID_ALUSrc1, ID_ALUSrc2, ID_MDSel, ID_MACSel, ID_ImmediateSrc, ID_TargetSel, ID_ALUOp);

        // 2. M-Extension MUL
        ID_Opcode = `OPCODE_RTYPE; ID_Funct7 = 7'b0000001; ID_Funct3 = 3'b000; #10;
        $display(" M-MUL       | %b  | %b  | %b  |  %b  |  %b  | %b  |  %b  |   %d    |    %d      |  %d", 
                 ID_RegWrite, ID_MemRead, ID_MemWrite, ID_ALUSrc1, ID_ALUSrc2, ID_MDSel, ID_MACSel, ID_ImmediateSrc, ID_TargetSel, ID_ALUOp);

        // 3. Custom MAC (Register)
        ID_Opcode = `OPCODE_MAC; ID_Funct3 = 3'b000; #10;
        $display(" MAC-REG     | %b  | %b  | %b  |  %b  |  %b  | %b  |  %b  |   %d    |    %d      |  %d", 
                 ID_RegWrite, ID_MemRead, ID_MemWrite, ID_ALUSrc1, ID_ALUSrc2, ID_MDSel, ID_MACSel, ID_ImmediateSrc, ID_TargetSel, ID_ALUOp);

        $display("============================================================================================================");
        $finish;
    end
endmodule