/*
* Module: ALU_RV32M.v
* Description: Performs combinational operations as required
* by the RV32M instruction set and sends result.
* Leaves RV32I instructions for ALU_RV32I.v
* Updated for EX stage signal naming in 5-stage pipeline.
* Author: Aashrith S Narayn
* Date: 13/02/2026
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"

//NOTE: This ALU can be scaled from 32 bit to any instruction length using the parameter WIDTH
//(* dont_touch = "true" *)
module ALU_RV32M #(parameter WIDTH = 32)(       
    input  wire signed [WIDTH-1:0] EX_Op1,          // Origin: ALU_Input_Selector (EX Stage)
    input  wire signed [WIDTH-1:0] EX_Op2,          // Origin: ALU_Input_Selector (EX Stage)
    input  wire        [5:0]       EX_ALUControl,   // Origin: ALUControl_Gen (EX Stage)
    input  wire                    EX_MDSel,        // Origin: ID/EX Pipeline Register
    output reg         [WIDTH-1:0] EX_ALUResult_M,  // Destination: EX/MEM Pipeline Register (via Output Mux)
    output wire                    EX_Zero_M        // Destination: Branch Control Logic (Unused for M-ext usually)
    );
    
    //0, 1 , -1 and Minimum Integer notation for width-parametrized ALU use
    localparam        [WIDTH-1:0] ZERO      = {WIDTH{1'b0}};
    localparam        [WIDTH-1:0] ONE       = {{WIDTH-1{1'b0}}, 1'b1}; 
    localparam signed [WIDTH-1:0] MINUS_ONE = {WIDTH{1'b1}};   //for division by 0
    localparam signed [WIDTH-1:0] MIN_INT = 1 << (WIDTH-1);

    
    //temporary 64 bit register to store products
    reg signed [2*WIDTH-1:0] mul_temp;
    
    //unsigned temps
    wire [WIDTH-1:0] uOp1 = $unsigned(EX_Op1);
    wire [WIDTH-1:0] uOp2 = $unsigned(EX_Op2);
    
    
    always @(*) begin
        
        //avoiding latch inference
        mul_temp    = 0;
        EX_ALUResult_M = ZERO;
        
        if (EX_MDSel) begin
            case (EX_ALUControl) 

                //Multiply Operations
                `ALU_MUL:    begin
                    mul_temp    = EX_Op1 * EX_Op2;
                    EX_ALUResult_M = mul_temp[WIDTH-1:0];
                end
                `ALU_MULH:   begin
                    mul_temp    = EX_Op1 * EX_Op2;
                    EX_ALUResult_M = mul_temp[2*WIDTH-1:WIDTH]; 
                end
                `ALU_MULHU:  begin
                    mul_temp    = uOp1 * uOp2;
                    EX_ALUResult_M = mul_temp[2*WIDTH-1:WIDTH];
                 end
                `ALU_MULHSU: begin
                    mul_temp    = $signed(EX_Op1) * $signed({1'b0, uOp2});  
                    EX_ALUResult_M = mul_temp[2*WIDTH-1:WIDTH];             
                end
                
                //Divide Operations with appropriate checks
                `ALU_DIV:   begin
                    if (EX_Op2 == 0) EX_ALUResult_M = MINUS_ONE;   
                    else if (EX_Op1 == MIN_INT && EX_Op2 == MINUS_ONE)         
                    begin                                                
                                  EX_ALUResult_M = MIN_INT;                      
                    end                                     
                    else          EX_ALUResult_M = EX_Op1 / EX_Op2;
                end
                `ALU_DIVU:  begin
                    if (EX_Op2 != 0) EX_ALUResult_M = uOp1 / uOp2;
                    else             EX_ALUResult_M = MINUS_ONE;
                end
                `ALU_REM:   begin
                    if (EX_Op2 != 0) EX_ALUResult_M = EX_Op1 % EX_Op2;
                    else if (EX_Op1 == MIN_INT && EX_Op2 == MINUS_ONE)        
                    begin                                                     
                                  EX_ALUResult_M = ZERO;                      
                    end
                    else          EX_ALUResult_M = EX_Op1;                     
                end
                `ALU_REMU:  begin
                    if (EX_Op2 != 0) EX_ALUResult_M = uOp1 % uOp2;
                    else             EX_ALUResult_M = EX_Op1;                     
                end
                
                //No Operation (default case)
                `ALU_NOP:         EX_ALUResult_M = ZERO;
                
                default:          EX_ALUResult_M = ZERO;                    
                
            endcase
            
        end else begin
            
            EX_ALUResult_M = ZERO;                
            
        end
        
    end
    
    assign EX_Zero_M = (EX_ALUResult_M == ZERO);     
    
endmodule