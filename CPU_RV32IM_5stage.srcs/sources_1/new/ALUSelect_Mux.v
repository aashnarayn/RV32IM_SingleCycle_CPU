/*
* Module: ALUSelect_Mux.v
* Description: Selects the final ALU result and Zero flag based on MDSel.
* This Mux separates critical paths and ensures only one ALU contributes to the 
* output per instruction.
* Updated for 5-stage pipeline (and MAC implementation) //TODO.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps

//(* dont_touch = "true" *)
module ALUSelect_Mux #(parameter WIDTH = 32)(
    input  wire [WIDTH-1:0] EX_ALUResult_I, // Origin: ALU_RV32I (EX Stage)
    input  wire [WIDTH-1:0] EX_ALUResult_M, // Origin: ALU_RV32M (EX Stage)
    //input wire [WIDTH-1:0] EX_MACResult,  // Future: Output from MAC Adder
    input  wire             EX_Zero_I,      // Origin: ALU_RV32I (EX Stage)
    input  wire             EX_Zero_M,      // Origin: ALU_RV32M (EX Stage)
    input  wire             EX_MDSel,       // Origin: ID/EX Pipeline Register
    //input wire            EX_MACSel,      // Future: Control signal for MAC
    output reg  [WIDTH-1:0] EX_ALUResult,   // Destination: EX/MEM Pipeline Register & Forwarding Unit
    output reg              EX_Zero         // Destination: Branch Control Logic (EX Stage)
    );
    
    always @(*) begin
        // Future logic will likely expand to:
        // if (EX_MACSel) Result = MACResult;
        // else if (EX_MDSel) ...
        
        if (EX_MDSel) begin                //Takes forward value from RV32M ALU
            EX_ALUResult = EX_ALUResult_M;
            EX_Zero      = EX_Zero_M; 
        end else begin                  //Takes forward value from RV32I ALU
            EX_ALUResult = EX_ALUResult_I;
            EX_Zero      = EX_Zero_I;
        end
    end
    
endmodule