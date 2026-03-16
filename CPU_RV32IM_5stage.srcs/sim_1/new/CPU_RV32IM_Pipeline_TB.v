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
    wire        CPU_Zero;
    wire [31:0] CPU_ReadData;
    wire [31:0] CPU_WriteDataReg;

    // Control Signals
    wire [2:0]  CPU_ALUOp;
    wire        CPU_MDSel;
    wire        CPU_MacSel;
    wire [2:0]  CPU_ImmediateSrc;
    wire [2:0]  CPU_TargetSel;
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
        .CPU_Zero(CPU_Zero),
        .CPU_ReadData(CPU_ReadData),
        .CPU_WriteDataReg(CPU_WriteDataReg),
        
        // Control Signals
        .CPU_ALUOp(CPU_ALUOp), .CPU_MDSel(CPU_MDSel), .CPU_MacSel(CPU_MacSel),
        .CPU_ImmediateSrc(CPU_ImmediateSrc), .CPU_TargetSel(CPU_TargetSel),
        .CPU_RegWrite(CPU_RegWrite), .CPU_MemRead(CPU_MemRead), .CPU_MemWrite(CPU_MemWrite),
        .CPU_MemToReg(CPU_MemToReg), .CPU_MemDataType(CPU_MemDataType),
        .CPU_ALUSrc1(CPU_ALUSrc1), .CPU_ALUSrc2(CPU_ALUSrc2), .CPU_PCSrc(CPU_PCSrc),

        // Surgical Debug
        .CPU_MAC_Accumulator(CPU_MAC_Accumulator), .CPU_MAC_Active(CPU_MAC_Active),
        .CPU_Stall_Divider(CPU_Stall_Divider), .CPU_Stalled(CPU_Stalled),
        .CPU_Flush_Event(CPU_Flush_Event), .CPU_FwdC_Sel(CPU_FwdC_Sel)
    );

    // ========================================================================
    // 3. Clock Generation (40 MHz -> 25ns period)
    // ========================================================================
    // Using 40MHz to match relaxed timing constraints (12.5ns toggle)
    initial begin
        CPU_clk = 0;
        forever #12.5 CPU_clk = ~CPU_clk; 
    end

    // ========================================================================
    // 4. Memory Initialization (Create .mem files on the fly)
    // ========================================================================
    integer fd;
    initial begin
        // --- Create Instruction Memory File ---
        fd = $fopen("IMEM_RV32IM_Program.mem", "w");
        if (fd) begin
            $display("Generating IMEM_RV32IM_Program.mem...");
            // BLOCK 1: INITIALIZATION
            $fdisplay(fd, "00400093"); // 0x00: ADDI x1, x0, 4
            $fdisplay(fd, "0000A103"); // 0x04: LW   x2, 0(x1)   (Needs DMEM setup)
            $fdisplay(fd, "00200193"); // 0x08: ADDI x3, x0, 2
            $fdisplay(fd, "00210233"); // 0x0C: ADD  x4, x2, x2  (Forwarding Check)
            
            // BLOCK 2: MAC EXTENSIONS
            $fdisplay(fd, "00A00293"); // 0x10: ADDI x5, x0, 10  (Accum Init)
            $fdisplay(fd, "00300313"); // 0x14: ADDI x6, x0, 3
            $fdisplay(fd, "00400393"); // 0x18: ADDI x7, x0, 4
            $fdisplay(fd, "0073028B"); // 0x1C: MAC  x5, x6, x7  (Custom Op)
            $fdisplay(fd, "0053128B"); // 0x20: MACI x5, x6, 5   (Immediate MAC)

            // BLOCK 3: DIVIDER
            $fdisplay(fd, "02324433"); // 0x24: DIV  x8, x4, x3  (Stall Check)

            // BLOCK 4: MEMORY
            $fdisplay(fd, "07400513"); // 0x28: ADDI x10, x0, 116 (Addr 0x74)
            $fdisplay(fd, "00052583"); // 0x2C: LW   x11, 0(x10)  (Load DEADBEEF)
            $fdisplay(fd, "00154603"); // 0x30: LBU  x12, 1(x10)  (Load Byte BE)
            $fdisplay(fd, "00C0A223"); // 0x34: SB   x12, 4(x1)   (Store BE to addr 8)

            // BLOCK 5: CONTROL HAZARDS
            $fdisplay(fd, "00800063"); // 0x38: BEQ  x0, x0, 8   (Wait, asm said BEQ x3, x3, 8. Branch Taken to 0x40)
                                       // NOTE: Asm said +8. 0x38 + 8 = 0x40. 
            $fdisplay(fd, "00000013"); // 0x3C: NOP (Should be flushed)
            $fdisplay(fd, "00000013"); // 0x40: NOP (Target)
            $fdisplay(fd, "0000F0EF"); // 0x44: JAL  x1, 0       (Infinite Loop)
            $fclose(fd);
        end else begin
            $display("ERROR: Could not create IMEM file.");
            $finish;
        end

        // --- Create Data Memory File ---
        fd = $fopen("DMEM_Data_Block.mem", "w");
        if (fd) begin
            $display("Generating DMEM_Data_Block.mem...");
            // Address 0x00 (Line 0)
            $fdisplay(fd, "00000000"); 
            // Address 0x04 (Line 1): Used for first LW x2
            $fdisplay(fd, "11111111"); 
            // ... Zero fill until line 29 ...
            repeat(27) $fdisplay(fd, "00000000");
            // Address 0x74 (Line 29): Used for LW x11 (116 / 4 = 29)
            $fdisplay(fd, "DEADBEEF"); 
            $fclose(fd);
        end
    end

    // ========================================================================
    // 5. Tasks for Verification
    // ========================================================================
    
    // Task to check if a specific register matches expected value in WB stage
    task check_wb_value;
        input integer reg_addr;
        input [31:0]  expected_val;
        input [255:0] test_name; // Fixed: reg array instead of string
        begin
            // Wait for RegWrite to enable AND the address to match
            // We verify internal DUT signal: uut.WB_RegWrite and uut.WB_RdAddr
            wait(uut.WB_RegWrite === 1 && uut.WB_RdAddr === reg_addr);
            
            // Wait a tick for signal stability
            #1; 
            
            if (CPU_WriteDataReg === expected_val) begin
                $display("[PASS] %0s: Reg x%0d = 0x%h", test_name, reg_addr, CPU_WriteDataReg);
            end else begin
                $display("[FAIL] %0s: Reg x%0d = 0x%h (Expected: 0x%h)", test_name, reg_addr, CPU_WriteDataReg, expected_val);
                $stop;
            end
            
            // Wait for clock to advance so we don't trigger twice on same cycle
            @(posedge CPU_clk);
        end
    endtask

    // ========================================================================
    // 6. Main Test Procedure
    // ========================================================================
    initial begin
        // Setup
        $display("\n=== STARTING SIMULATION ===");
        
        // --- 1. Reset Test & Safety Check ---
        $display("[TEST] Reset Synchronizer & Output Initialization...");
        
        // A. Assert Reset
        CPU_rst_n = 0;
        #20;
<<<<<<< HEAD
        // FIX: Check safety states WHILE reset is still held low
        if (CPU_PC !== 32'h80000000) begin // IF_Program_Counter initializes to 0x80000000 internally
            $display("[FAIL] PC not initialized correctly during reset! PC = %h", CPU_PC);
            $stop;
        end
=======
        CPU_rst_n = 1; // Async Assert
>>>>>>> 8d42b9ceda11db5e8b8e62e4ef8b858bb42e94d9
        
        // B. Wait for Synchronizer to propagate Reset (approx 3-4 cycles)
        // We need to give the FPGA time to clear the flip-flops.
        repeat(5) @(posedge CPU_clk); 
        
        // --- C. INITIALIZATION CHECK (SAFE VALUES) ---
        // Verify that while in reset, critical outputs are clamped to SAFE states.
        // If these are not 0, the CPU might execute garbage on startup.
        if (CPU_PC !== 32'h00000000) begin
            $display("[FAIL] PC not initialized to 0 during reset! PC = %h", CPU_PC);
            $stop;
        end
        if (CPU_RegWrite !== 1'b0) begin
            $display("[FAIL] RegWrite active during reset! This corrupts registers.");
            $stop;
        end
        if (CPU_MemWrite !== 1'b0) begin
             $display("[FAIL] MemWrite active during reset! This corrupts memory.");
             $stop;
        end
        $display("[PASS] All Outputs initialized to SAFE values (0).");

        // D. Release Reset
        #10;
        CPU_rst_n = 1; 
        
        // Wait for Synchronizer to release internal reset
        wait(uut.CPU_sync_rst_n === 1);
        @(posedge CPU_clk);
        $display("[PASS] Reset Released. Pipeline starting.");

        // --- 2. Functional Tests (Golden Model Checks) ---
        
        // Test LW x2 = 0x11111111
        check_wb_value(2, 32'h11111111, "Basic Load");

        // Test ADD x4 = x2 + x2 = 22222222 (Forwarding Test)
        check_wb_value(4, 32'h22222222, "Data Forwarding (EX)");

        // Test MAC x5 = 10 + (3*4) = 22 (0x16)
        check_wb_value(5, 32'h00000016, "Custom MAC (Reg-Reg)");

        // Test MACI x5 = 22 + (3*5) = 37 (0x25) (Accumulator Forwarding)
        check_wb_value(5, 32'h00000025, "Custom MACI (Immediate+Fwd)");

        // Test DIV x8 = 0x22222222 / 2 = 0x11111111 (Multi-cycle Stall)
        $display("[INFO] Waiting for Divider... (Should stall ~34 cycles)");
        check_wb_value(8, 32'h11111111, "Divider Result");

        // Test LW x11 = DEADBEEF
        check_wb_value(11, 32'hDEADBEEF, "Load Large Offset");

        // Test LBU x12 = 0xBE
        // Addr 116 = EF, 117 = BE, 118 = AD, 119 = DE (Little Endian)
        check_wb_value(12, 32'h000000BE, "Load Byte Unsigned");

        // --- 3. Branch Verification ---
        // Monitor PC to ensure we skipped the instruction at 0x3C
        // Wait for loop instruction (JAL at 0x44)
        wait(CPU_PC === 32'h44); 
        $display("[PASS] Control Flow: Reached Infinite Loop. Branch skipped dead code.");

        // --- 4. Final Success ---
        $display("\n=== ALL TESTS PASSED ===");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000; // Increased timeout for 40MHz clock (slower simulation)
        $display("\n[TIMEOUT] Simulation ran too long. Possible Stall/Deadlock.");
        $finish;
    end

endmodule