/*
* Module: ID_Branch_Comparator.v
* Description: Dedicated lightweight comparator for Early Branch Resolution.
* Calculates Equality, Signed Less Than, and Unsigned Less Than combinationally.
* This module relies on the ID_Register_File's internal WB-to-read bypass 
* to guarantee fresh data without external forwarding logic.
* Author: Aashrith S Narayn
* Date: 15/03/2026
*/

`timescale 1ns / 1ps

module ID_Branch_Comparator #(
    parameter WIDTH = 32
    )(
    input  wire [WIDTH-1:0] ID_Rs1Data,  // Origin: Top-Level Fast-Path Muxes (ID_Rs1_Fast, ID_Rs2_Fast)
    input  wire [WIDTH-1:0] ID_Rs2Data,  // Origin: Top-Level Fast-Path Muxes (ID_Rs1_Fast, ID_Rs2_Fast)
    
    output wire             ID_Eq,       // Destination: ID_Target_Controller
    output wire             ID_Lt,       // Destination: ID_Target_Controller
    output wire             ID_Ltu       // Destination: ID_Target_Controller
    );
    
    // -------------------------------------------------------------------------
    // 1. EQUALITY OPTIMIZATION
    // -------------------------------------------------------------------------
    // Instead of (A == B), which is (A - B == 0), we use (A ^ B).
    // If all bits of XOR result are 0, they are equal. 
    // This maps to a wide NOR tree, which is significantly shallower in FPGA LUTs.
    wire [WIDTH-1:0] diff_bits = ID_Rs1Data ^ ID_Rs2Data;
    assign ID_Eq = ~(|diff_bits);

    // -------------------------------------------------------------------------
    // 2. UNSIGNED LESS THAN (Ltu) OPTIMIZATION
    // -------------------------------------------------------------------------
    // We perform a manual subtraction (A - B) but only care about the carry-out.
    // In Verilog, {1'b0, A} - {1'b0, B} high bit represents the borrow.
    wire [WIDTH:0] sub_res_u = {1'b0, ID_Rs1Data} - {1'b0, ID_Rs2Data};
    assign ID_Ltu = sub_res_u[WIDTH];

    // -------------------------------------------------------------------------
    // 3. SIGNED LESS THAN (Lt) OPTIMIZATION
    // -------------------------------------------------------------------------
    // RISC-V Signed Comparison logic:
    // If signs are different: Rs1 is less if Rs1 is negative (1) and Rs2 is positive (0).
    // If signs are same: Use the result of the unsigned subtraction.
    wire s1 = ID_Rs1Data[WIDTH-1];
    wire s2 = ID_Rs2Data[WIDTH-1];
    assign ID_Lt = (s1 ^ s2) ? s1 : sub_res_u[WIDTH];

endmodule