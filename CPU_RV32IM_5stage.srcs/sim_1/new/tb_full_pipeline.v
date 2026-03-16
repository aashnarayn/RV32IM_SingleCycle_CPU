`timescale 1ns / 1ps

module CPU_RV32IM_Pipeline_TB;

    // ========================================================================
    // 1. Inputs & Outputs
    // ========================================================================
    reg CPU_clk;
    reg CPU_rst_n;

    // Debug Outputs from DUT
    wire [31:0] CPU_PC;
    wire [31:0] CPU_Instr_RV32IM;
    wire [31:0] CPU_Immediate;
    wire [5:0]  CPU_ALUControl;
    wire [31:0] CPU_ALUResult;
    
    wire        CPU_Eq;
    wire        CPU_Lt;
    wire        CPU_Ltu;
    
    wire [31:0] CPU_ReadData;
    wire [31:0] CPU_WriteDataReg;

    // Control Signals
    wire [2:0]  CPU_ALUOp;
    wire        CPU_MDSel;
    wire        CPU_MacSel;
    wire [2:0]  CPU_ImmediateSrc;
    wire [3:0]  CPU_TargetSel; 
    wire        CPU_RegWrite;
    wire        CPU_MemRead;
    wire        CPU_MemWrite;
    wire [1:0]  CPU_MemToReg;
    wire [2:0]  CPU_MemDataType;
    wire        CPU_ALUSrc1; 
    wire        CPU_ALUSrc2;
    wire [1:0]  CPU_PCSrc;

    // Surgical Debug
    wire [31:0] CPU_MAC_Accumulator;
    wire        CPU_MAC_Active;
    wire        CPU_Stall_Divider;
    wire        CPU_Stalled;
    wire        CPU_Flush_Event;
    wire [1:0]  CPU_FwdC_Sel;

    // ========================================================================
    // 2. DUT Instantiation
    // ========================================================================
    CPU_RV32IM_Pipeline #(
        .DATA_WIDTH(32),
        .PC_WIDTH(32),
        .PC_STEP(4),
        .INSTR_WIDTH(32),
        .REG_COUNT(32),
        .IMEM_DEPTH(256),
        .DMEM_DEPTH(4096)
    ) uut (
        .CPU_clk(CPU_clk),
        .CPU_rst_n(CPU_rst_n),
        
        .CPU_PC(CPU_PC),
        .CPU_Instr_RV32IM(CPU_Instr_RV32IM),
        .CPU_Immediate(CPU_Immediate),
        .CPU_ALUControl(CPU_ALUControl),
        .CPU_ALUResult(CPU_ALUResult),
        
        .CPU_Eq(CPU_Eq),
        .CPU_Lt(CPU_Lt),
        .CPU_Ltu(CPU_Ltu),
        
        .CPU_ReadData(CPU_ReadData),
        .CPU_WriteDataReg(CPU_WriteDataReg),
        
        .CPU_ALUOp(CPU_ALUOp), .CPU_MDSel(CPU_MDSel), .CPU_MacSel(CPU_MacSel),
        .CPU_ImmediateSrc(CPU_ImmediateSrc), .CPU_TargetSel(CPU_TargetSel),
        .CPU_RegWrite(CPU_RegWrite), .CPU_MemRead(CPU_MemRead), .CPU_MemWrite(CPU_MemWrite),
        .CPU_MemToReg(CPU_MemToReg), .CPU_MemDataType(CPU_MemDataType),
        .CPU_ALUSrc1(CPU_ALUSrc1), .CPU_ALUSrc2(CPU_ALUSrc2), .CPU_PCSrc(CPU_PCSrc),

        .CPU_MAC_Accumulator(CPU_MAC_Accumulator), .CPU_MAC_Active(CPU_MAC_Active),
        .CPU_Stall_Divider(CPU_Stall_Divider), .CPU_Stalled(CPU_Stalled),
        .CPU_Flush_Event(CPU_Flush_Event), .CPU_FwdC_Sel(CPU_FwdC_Sel)
    );

    // ========================================================================
    // 3. Clock Generation (40 MHz -> 25ns period)
    // ========================================================================
    initial begin
        CPU_clk = 0;
        forever #12.5 CPU_clk = ~CPU_clk; 
    end

    // ========================================================================
    // 4. Memory Initialization
    // ========================================================================
    integer fd;
    initial begin
        fd = $fopen("IMEM_RV32IM_Program.mem", "w");
        if (fd) begin
            $display("[INIT] Generating IMEM_RV32IM_Program.mem...");
            $fdisplay(fd, "00400093"); // 0x00: ADDI x1, x0, 4
            $fdisplay(fd, "0000A103"); // 0x04: LW   x2, 0(x1)
            $fdisplay(fd, "00200193"); // 0x08: ADDI x3, x0, 2
            $fdisplay(fd, "00210233"); // 0x0C: ADD  x4, x2, x2
            $fdisplay(fd, "00A00293"); // 0x10: ADDI x5, x0, 10
            $fdisplay(fd, "00300313"); // 0x14: ADDI x6, x0, 3
            $fdisplay(fd, "00400393"); // 0x18: ADDI x7, x0, 4
            $fdisplay(fd, "0073028B"); // 0x1C: MAC  x5, x6, x7
            $fdisplay(fd, "0053128B"); // 0x20: MACI x5, x6, 5
            $fdisplay(fd, "02324433"); // 0x24: DIV  x8, x4, x3
            $fdisplay(fd, "07400513"); // 0x28: ADDI x10, x0, 116
            $fdisplay(fd, "00052583"); // 0x2C: LW   x11, 0(x10)
            $fdisplay(fd, "00154603"); // 0x30: LBU  x12, 1(x10)
            $fdisplay(fd, "00C0A223"); // 0x34: SB   x12, 4(x1)
            $fdisplay(fd, "00800063"); // 0x38: BEQ  x0, x0, 8 (Branch to 0x40)
            $fdisplay(fd, "00000013"); // 0x3C: NOP
            $fdisplay(fd, "00000013"); // 0x40: NOP
            $fdisplay(fd, "0000F0EF"); // 0x44: JAL  x1, 0
            $fclose(fd);
        end

        fd = $fopen("DMEM_Data_Block.mem", "w");
        if (fd) begin
            $display("[INIT] Generating DMEM_Data_Block.mem...");
            $fdisplay(fd, "00000000"); // Addr 0
            $fdisplay(fd, "11111111"); // Addr 4
            repeat(27) $fdisplay(fd, "00000000");
            $fdisplay(fd, "DEADBEEF"); // Addr 116
            $fclose(fd);
        end
        
        $readmemh("IMEM_RV32IM_Program.mem", uut.CPU_IMEM.InstrMem);
        $readmemh("DMEM_Data_Block.mem", uut.CPU_DMEM.DataMem);
    end

    // ========================================================================
    // 5. Tasks for Verification
    // ========================================================================
    task check_wb_value;
        input [31:0]  target_pc;
        input integer reg_addr;
        input [31:0]  expected_val;
        input [255:0] test_name;
        begin
            wait(uut.WB_RegWrite === 1'b1 && uut.WB_RdAddr === reg_addr && uut.WB_PC_Plus_4 === (target_pc + 4));
            
            #1; 
            
            if (CPU_WriteDataReg === expected_val) begin
                $display("[PASS] %0s (PC: 0x%0h): Reg x%0d = 0x%h", test_name, target_pc, reg_addr, CPU_WriteDataReg);
            end else begin
                $display("[FAIL] %0s (PC: 0x%0h): Reg x%0d = 0x%h (Expected: 0x%h)", test_name, target_pc, reg_addr, CPU_WriteDataReg, expected_val);
                $stop;
            end
            
            @(posedge CPU_clk);
        end
    endtask

    // ========================================================================
    // 6. Main Test Procedure
    // ========================================================================
    integer i; // <-- Variable for the array clear loop
    
    initial begin
        $display("\n=== STARTING SIMULATION ===");
        
        // --- NEW: Purge the Register File of 'X' states ---
        $display("[INIT] Forcing all internal registers to 0 to clear waveform 'X's...");
        for (i = 0; i < 32; i = i + 1) begin
            uut.CPU_RegFile.RegArray[i] = 32'h00000000;
        end
        
        $display("[TEST] Reset Synchronizer & Output Initialization...");
        CPU_rst_n = 0;
        #20; 
        
        if (CPU_PC !== 32'h80000000) begin 
            $display("[FAIL] PC not initialized correctly during reset! PC = %h", CPU_PC);
            $stop;
        end
        $display("[PASS] Critical outputs initialized to SAFE values.");

        CPU_rst_n = 1; 
        
        wait(uut.CPU_sync_rst_n === 1);
        @(posedge CPU_clk);
        $display("[PASS] Reset Released. Pipeline starting.\n");

        // --- Functional Tests ---
        check_wb_value(32'h80000004, 2, 32'h11111111, "Basic Load");
        check_wb_value(32'h8000000C, 4, 32'h22222222, "Data Forwarding (EX)");
        
        check_wb_value(32'h8000001C, 5, 32'h00000016, "Custom MAC (Reg-Reg)");
        check_wb_value(32'h80000020, 5, 32'h00000025, "Custom MACI (Immediate+Fwd)");
        
        $display("[INFO] Waiting for Divider... (Pipeline should stall)");
        check_wb_value(32'h80000024, 8, 32'h11111111, "Divider Result");
        
        check_wb_value(32'h8000002C, 11, 32'hDEADBEEF, "Load Large Offset");
        check_wb_value(32'h80000030, 12, 32'h000000BE, "Load Byte Unsigned");

        wait(CPU_PC === 32'h80000044); 
        $display("[PASS] Control Flow: Reached Infinite Loop. Branch skipped dead code.");

        $display("\n=== ALL TESTS PASSED ===");
        $finish;
    end

    // ========================================================================
    // 7. Waveform Dump & Timeout
    // ========================================================================
    initial begin
        $dumpfile("pipeline_trace.vcd");
        $dumpvars(0, CPU_RV32IM_Pipeline_TB);
    end

    initial begin
        #10000; 
        $display("\n[TIMEOUT] Simulation ran too long. Possible Stall/Deadlock.");
        $finish;
    end

endmodule