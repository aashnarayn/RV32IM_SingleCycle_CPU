/*
* Module: ID_Branch_Target_Gen.v
* Description: Computes the branch target address by adding the 
* already-aligned Immediate (from Imm_Gen) to the current PC.
* Unconditionally evaluated to keep routing logic shallow.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

module ID_Branch_Target_Gen #(
    parameter WIDTH = 32,       //NOTE: PC_WIDTH AND WIDTH SHOULD BE THE SAME
    parameter PC_WIDTH = 32,
    parameter IMEM_DEPTH = 256
    )(
    // Inputs are now sourced directly from the ID stage.
    input  wire [WIDTH-1:0]    ID_Immediate,    // Origin: ID_Imm_Gen
    input  wire [PC_WIDTH-1:0] ID_PC,           // Origin: IF_ID_Reg
    output wire [PC_WIDTH-1:0] ID_BranchTarget  // Destination: Top-Level Register (ID_BTarget_Reg)
    );
    
    // Calculate exact bits needed for byte-addressed memory
    localparam ACTIVE_BITS = $clog2(IMEM_DEPTH * 4);

    // Truncated adder: Only calculate the bits that actually route to IMEM
    wire [ACTIVE_BITS-1:0] active_target = ID_PC[ACTIVE_BITS-1:0] + ID_Immediate[ACTIVE_BITS-1:0];

    // Pad the upper dead bits with zeros
    assign ID_BranchTarget = { {(PC_WIDTH - ACTIVE_BITS){1'b0}}, active_target };

    // Linter Violation Avoidance (The "Bit Sink")
    wire _unused_ok = &{
        1'b0,
        ID_PC[PC_WIDTH-1 : ACTIVE_BITS],
        ID_Immediate[WIDTH-1 : ACTIVE_BITS]
    };
    
endmodule