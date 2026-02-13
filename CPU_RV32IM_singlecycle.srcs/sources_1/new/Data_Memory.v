/*
* Module: Data_Memory.v
* Description: Implements 32-bit data memory for RV32IM single-cycle CPU. 
* Supports Load and Store operations with synchronous write and 
* combinational read access. Implements variable width read and write.
* Supported operations - LW, LH, LB, LHU, LBU, SW, SH, SB
* Author: Aashrith S Narayn
* Date: 07/07/2025
*/

`timescale 1ns / 1ps
`include "CPU_Control_Codes.vh"


//NOTE - MODULE UPDATE FOR STORE INVALID USE CASES
//(* dont_touch = "true" *)
module Data_Memory #(
    parameter WIDTH      = 32,
    parameter DMEM_DEPTH = 4096
    )(
    input  wire             CPU_clk,
    input  wire             CPU_rst_n,
    input  wire             MemWrite,
    input  wire             MemRead,
    input  wire [2:0]       MemDataType,
    input  wire [WIDTH-1:0] ALUResult_Addr,
    input  wire [WIDTH-1:0] WriteData,
    output reg  [WIDTH-1:0] ReadData
    );
    
    //Data Memory Array - byte wise mem access
    (* ram_style = "distributed" *)                         //block ram cannot be inferred due to the always @(*) block - limitation of BRAM hardware
    reg     [WIDTH-1:0] DataMem [0:DMEM_DEPTH-1];           //word-wise memory
    integer             i;                                  //used for resetting DataMem Array
    
    wire    [1:0]       Byte_Offset = ALUResult_Addr[1:0];  //For byte addressing
    reg     [WIDTH-1:0] WordTempRd;                         //WordTempWr removed as Read-Modify-Write is replaced
    
    localparam BYTE_RANGE = $clog2(4*DMEM_DEPTH);
    localparam DATA_ZERO  = {WIDTH{1'b0}};
    localparam ADDR_ZERO  = {BYTE_RANGE{1'b0}};
    
    //Read Logic (Combinational)
    always @(*) begin    
        if(MemRead && !MemWrite) begin 
        
            case(MemDataType)
                3'b000:  begin
                    WordTempRd = (DataMem[ALUResult_Addr[BYTE_RANGE-1:2]] >> (Byte_Offset * 8));                //Reading shifted Data for LB
                    ReadData = { {24{WordTempRd[7]}}, WordTempRd[7:0] };                                        //Sign extending
                end
                                                  
                3'b001:  begin
                    WordTempRd = (DataMem[ALUResult_Addr[BYTE_RANGE-1:2]] >> (Byte_Offset * 8));                //Reading shifted Data for LH
                    ReadData = { {16{WordTempRd[15]}}, WordTempRd[15:0] };                                      //Sign extending
                end    
                                                                  
                3'b010:  ReadData =  DataMem[ALUResult_Addr[BYTE_RANGE-1:2]];                                   //Reading Data for LW
                
                3'b100:  ReadData =  (DataMem[ALUResult_Addr[BYTE_RANGE-1:2]] >> (Byte_Offset * 8)) & 8'hFF;    //Reading Data for LBU
                                    
                3'b101:  ReadData =  (DataMem[ALUResult_Addr[BYTE_RANGE-1:2]] >> (Byte_Offset * 8)) & 16'hFFFF; //Reading Data for LHU
                
                default: ReadData =  DATA_ZERO;                                                                 //Default Fallback
                                                                                
            endcase
            
        end else begin
            ReadData = DATA_ZERO;                    //useful for simulation purposes
        end    
    end
    
    //Write Logic (Sequential)
    always @(posedge CPU_clk) begin                  //Reset removed from sensitivity list to enable BRAM inference
        if (MemWrite && !MemRead) begin
        
            case(MemDataType)
            
                3'b000:  begin
                    
                    case (Byte_Offset)    //Directly writing to target Byte Slices
                                          //More timing adherent and easier implementation than Read-Modify-Write 
                                          //because that infers Dual-Port BRAM which is logically complex to infer                                                  
                         2'b00:   DataMem[ALUResult_Addr[BYTE_RANGE-1:2]][7:0]   <= WriteData[7:0]; 
                         2'b01:   DataMem[ALUResult_Addr[BYTE_RANGE-1:2]][15:8]  <= WriteData[7:0];
                         2'b10:   DataMem[ALUResult_Addr[BYTE_RANGE-1:2]][23:16] <= WriteData[7:0];
                         2'b11:   DataMem[ALUResult_Addr[BYTE_RANGE-1:2]][31:24] <= WriteData[7:0];
                         default: ;                                                         //NOP
                    endcase

                end
                
                3'b001:  begin
                    
                    case (Byte_Offset)                                                      //Directly writing to target Half-Word Slices 
                         2'b00:   DataMem[ALUResult_Addr[BYTE_RANGE-1:2]][15:0]  <= WriteData[15:0];
                         2'b10:   DataMem[ALUResult_Addr[BYTE_RANGE-1:2]][31:16] <= WriteData[15:0];
                         default: ;                                                         //NOP
                    endcase
                
                end
                
                3'b010:  DataMem[ALUResult_Addr[BYTE_RANGE-1:2]] <= WriteData;              //Writing Data for SW
                
                default: ;               //Default Fallback (NOP)
                
            endcase
            
        end
    end
    
    wire [WIDTH-BYTE_RANGE-1:0] DMEM_unused = ALUResult_Addr[WIDTH-1:BYTE_RANGE];    //to avoid linter violations
    
    //initialising DataMem with block of hex data for simulation
    //No pragmas as synthesis tool is required to see this preload
    initial begin
        $readmemh(`DMEM_HEX_BLOCK, DataMem);
    end
        
    
    //pragma synthesis off
    /*
    initial begin
        //waiting for simulation to end
        #(`SIM_TIME);

        //data memory dump
        $writememh(`DMEM_HEX_DUMP, CPU_DataPath.CPU_DMEM.DataMem);
    end  
    */
    
    //pragma synthesis on
        
endmodule