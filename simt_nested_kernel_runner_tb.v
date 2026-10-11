
`timescale 1ns/1ps

module simt_nested_kernel_runner_tb;

    reg clk;
    reg reset;

    wire [31:0] current_pc;
    wire [31:0] instruction;
    wire [7:0] thread_mask;
    wire [7:0] predicate_mask;

    wire branch_instr;
    wire divergence;
    wire split;
    wire stack_push;
    wire stack_pop;

    wire [63:0] total_cycles;
    wire [63:0] useful_lane_cycles;
    wire [63:0] masked_lane_cycles;
    wire [31:0] efficiency_percent;

    integer errors;

    simt_top dut (
        .clk(clk),
        .reset(reset),
        .current_pc(current_pc),
        .instruction(instruction),
        .thread_mask(thread_mask),
        .predicate_mask(predicate_mask),
        .branch_instr(branch_instr),
        .divergence(divergence),
        .split(split),
        .stack_push(stack_push),
        .stack_pop(stack_pop),
        .total_cycles(total_cycles),
        .useful_lane_cycles(useful_lane_cycles),
        .masked_lane_cycles(masked_lane_cycles),
        .efficiency_percent(efficiency_percent)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check;
        input condition;
        input [8*100-1:0] message;
        begin
            if (condition)
                $display("PASS: %0s", message);
            else begin
                $display("FAIL: %0s", message);
                errors = errors + 1;
            end
        end
    endtask

    task advance_cycle;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        reset = 1'b1;
        errors = 0;

        $display("");
        $display("========================================");
        $display(" ASSEMBLED NESTED SIMT KERNEL TEST");
        $display("========================================");

        // ----------------------------------------------------
        // LOAD ACTUAL ASSEMBLER OUTPUT
        // Keep reset asserted while loading the program.
        // ----------------------------------------------------

        $readmemh(
            "simt_nested_kernel.hex",
            dut.frontend.instruction_memory.memory
        );

        // Allow the PC and datapath to complete reset.
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // ----------------------------------------------------
        // IMPORTANT: INITIALIZE REGISTERS AFTER RESET.
        // Reset clears lane registers on the reset clock edges.
        //
        // Outer BEQ: taken lanes 0,1,4,5.
        // Expected predicate: 00110011.
        // ----------------------------------------------------

        dut.core.LANES[0].lane_unit.registers[1] = 10;
        dut.core.LANES[0].lane_unit.registers[2] = 10;

        dut.core.LANES[1].lane_unit.registers[1] = 20;
        dut.core.LANES[1].lane_unit.registers[2] = 20;

        dut.core.LANES[2].lane_unit.registers[1] = 30;
        dut.core.LANES[2].lane_unit.registers[2] = 99;

        dut.core.LANES[3].lane_unit.registers[1] = 40;
        dut.core.LANES[3].lane_unit.registers[2] = 99;

        dut.core.LANES[4].lane_unit.registers[1] = 50;
        dut.core.LANES[4].lane_unit.registers[2] = 50;

        dut.core.LANES[5].lane_unit.registers[1] = 60;
        dut.core.LANES[5].lane_unit.registers[2] = 60;

        dut.core.LANES[6].lane_unit.registers[1] = 70;
        dut.core.LANES[6].lane_unit.registers[2] = 99;

        dut.core.LANES[7].lane_unit.registers[1] = 80;
        dut.core.LANES[7].lane_unit.registers[2] = 99;

        // Inner BEQ compares x3 and x4.
        // Expected predicate among all lanes: 00010001.
        // The active outer-taken lanes are 0,1,4,5.

        dut.core.LANES[0].lane_unit.registers[3] = 10;
        dut.core.LANES[0].lane_unit.registers[4] = 10;

        dut.core.LANES[1].lane_unit.registers[3] = 20;
        dut.core.LANES[1].lane_unit.registers[4] = 99;

        dut.core.LANES[2].lane_unit.registers[3] = 30;
        dut.core.LANES[2].lane_unit.registers[4] = 99;

        dut.core.LANES[3].lane_unit.registers[3] = 40;
        dut.core.LANES[3].lane_unit.registers[4] = 99;

        dut.core.LANES[4].lane_unit.registers[3] = 50;
        dut.core.LANES[4].lane_unit.registers[4] = 50;

        dut.core.LANES[5].lane_unit.registers[3] = 60;
        dut.core.LANES[5].lane_unit.registers[4] = 99;

        dut.core.LANES[6].lane_unit.registers[3] = 70;
        dut.core.LANES[6].lane_unit.registers[4] = 99;

        dut.core.LANES[7].lane_unit.registers[3] = 80;
        dut.core.LANES[7].lane_unit.registers[4] = 99;

        #1;

        // ====================================================
        // 1. VERIFY ASSEMBLED HEX
        // ====================================================

        $display("");
        $display("1. ASSEMBLED HEX VERIFICATION");

        check(
            dut.frontend.instruction_memory.memory[0] ===
                32'h02208063,
            "Outer BEQ loaded from HEX at 0x00"
        );

        check(
            dut.frontend.instruction_memory.memory[8] ===
                32'h00418863,
            "Inner BEQ loaded from HEX at 0x20"
        );

        check(
            dut.frontend.instruction_memory.memory[3] ===
                32'h0000200B,
            "Outer JOIN loaded from HEX at 0x0C"
        );

        check(
            dut.frontend.instruction_memory.memory[10] ===
                32'h0000200B,
            "Inner JOIN loaded from HEX at 0x28"
        );

        check(
            dut.frontend.instruction_memory.memory[12] ===
                32'h0000200B,
            "Inner JOIN loaded from HEX at 0x30"
        );

        check(
            dut.frontend.instruction_memory.memory[15] ===
                32'h0000200B,
            "Outer JOIN loaded from HEX at 0x3C"
        );

        // ====================================================
        // 2. OUTER SPLIT
        // ====================================================

        $display("");
        $display("2. OUTER SPLIT");

        $display(
            "PC=%08h predicate=%08b next_pc=%08h",
            current_pc, predicate_mask, dut.next_pc
        );

        check(current_pc === 32'h00000000,
              "Outer branch PC is 0x00");

        check(instruction === 32'h02208063,
              "Outer BEQ fetched");

        check(predicate_mask === 8'b00110011,
              "Outer predicate mask is correct");

        check(divergence === 1'b1,
              "Outer divergence detected");

        check(split === 1'b1,
              "Outer split asserted");

        check(dut.metadata_found === 1'b1,
              "Outer IPDOM metadata found");

        check(dut.reconvergence_pc === 32'h00000040,
              "Outer reconvergence PC is 0x40");

        check(dut.next_pc === 32'h00000020,
              "Outer taken target is 0x20");

        check(stack_push === 1'b1,
              "Outer stack push asserted");

        advance_cycle();

        check(current_pc === 32'h00000020,
              "Outer taken path reached");

        check(thread_mask === 8'b00110011,
              "Outer taken mask applied");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Outer stack entry pushed");

        // ====================================================
        // 3. INNER SPLIT
        // ====================================================

        $display("");
        $display("3. INNER SPLIT");

        $display(
            "PC=%08h predicate=%08b next_pc=%08h",
            current_pc, predicate_mask, dut.next_pc
        );

        check(current_pc === 32'h00000020,
              "Inner branch PC is 0x20");

        check(instruction === 32'h00418863,
              "Inner BEQ fetched from assembled HEX");

        check(predicate_mask === 8'b00010001,
              "Inner predicate mask is correct");

        check(divergence === 1'b1,
              "Inner divergence detected");

        check(split === 1'b1,
              "Inner split asserted");

        check(dut.metadata_found === 1'b1,
              "Inner IPDOM metadata found");

        check(dut.reconvergence_pc === 32'h00000034,
              "Inner reconvergence PC is 0x34");

        check(dut.next_pc === 32'h00000030,
              "Inner taken target is 0x30");

        check(stack_push === 1'b1,
              "Inner stack push asserted");

        advance_cycle();

        check(current_pc === 32'h00000030,
              "Inner taken path reached");

        check(thread_mask === 8'b00010001,
              "Inner taken mask applied");

        check(dut.divergence_controller.ipdom.stack_pointer == 2,
              "Nested stack depth is two");

        // ====================================================
        // 4. INNER JOIN #1
        // ====================================================

        $display("");
        $display("4. INNER JOIN #1");

        check(current_pc === 32'h00000030,
              "Inner JOIN #1 PC is 0x30");

        check(instruction === 32'h0000200B,
              "Inner JOIN #1 fetched");

        check(dut.next_pc === 32'h00000024,
              "Inner deferred PC selected");

        check(stack_pop === 1'b0,
              "Inner JOIN #1 does not pop");

        advance_cycle();

        check(current_pc === 32'h00000024,
              "Inner deferred path reached");

        check(thread_mask === 8'b00100010,
              "Inner deferred mask applied");

        check(dut.divergence_controller.ipdom.stack_pointer == 2,
              "Both IPDOM entries remain");

        check(instruction === 32'h00000013,
              "Inner deferred NOP fetched");

        advance_cycle();

        check(current_pc === 32'h00000028,
              "Inner JOIN #2 address reached");

        // ====================================================
        // 5. INNER JOIN #2
        // ====================================================

        $display("");
        $display("5. INNER JOIN #2");

        check(instruction === 32'h0000200B,
              "Inner JOIN #2 fetched");

        check(dut.next_pc === 32'h00000034,
              "Inner reconvergence target selected");

        check(stack_pop === 1'b1,
              "Inner JOIN #2 pops top entry");

        advance_cycle();

        check(current_pc === 32'h00000034,
              "Inner reconvergence reached");

        check(thread_mask === 8'b00110011,
              "Outer taken mask restored");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Outer stack entry preserved");

        // Execute NOPs at 0x34 and 0x38.
        advance_cycle();

        check(current_pc === 32'h00000038,
              "NOP at 0x34 executed");

        advance_cycle();

        check(current_pc === 32'h0000003C,
              "Outer JOIN #1 address reached");

        // ====================================================
        // 6. OUTER JOIN #1
        // ====================================================

        $display("");
        $display("6. OUTER JOIN #1");

        check(instruction === 32'h0000200B,
              "Outer JOIN #1 fetched");

        check(dut.next_pc === 32'h00000004,
              "Outer deferred PC selected");

        check(stack_pop === 1'b0,
              "Outer JOIN #1 does not pop");

        advance_cycle();

        check(current_pc === 32'h00000004,
              "Outer deferred path reached");

        check(thread_mask === 8'b11001100,
              "Outer deferred mask applied");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Outer stack entry remains");

        // Execute NOPs at 0x04 and 0x08.
        check(instruction === 32'h00000013,
              "Outer deferred NOP fetched");

        advance_cycle();

        check(current_pc === 32'h00000008,
              "Outer deferred NOP at 0x04 executed");

        advance_cycle();

        check(current_pc === 32'h0000000C,
              "Outer JOIN #2 address reached");

        // ====================================================
        // 7. OUTER JOIN #2
        // ====================================================

        $display("");
        $display("7. OUTER JOIN #2");

        check(instruction === 32'h0000200B,
              "Outer JOIN #2 fetched");

        check(dut.next_pc === 32'h00000040,
              "Outer reconvergence target selected");

        check(stack_pop === 1'b1,
              "Outer JOIN #2 pops final entry");

        advance_cycle();

        check(current_pc === 32'h00000040,
              "Outer reconvergence reached");

        check(thread_mask === 8'hFF,
              "All lanes restored");

        check(dut.divergence_controller.ipdom.stack_pointer == 0,
              "IPDOM stack is empty");

        // ====================================================
        // FINAL SUMMARY
        // ====================================================

        $display("");
        $display("========================================");
        $display(" ASSEMBLED NESTED KERNEL SUMMARY");
        $display("========================================");

        $display("Final PC             : 0x%08h", current_pc);
        $display("Final thread mask    : %08b", thread_mask);
        $display("Sampled cycles       : %0d", total_cycles);
        $display("Useful lane-cycles   : %0d", useful_lane_cycles);
        $display("Masked lane-cycles   : %0d", masked_lane_cycles);
        $display("Lane efficiency      : %0d%%", efficiency_percent);

        if (errors == 0)
            $display("ALL ASSEMBLED NESTED KERNEL CHECKS PASSED");
        else
            $display("ASSEMBLED NESTED KERNEL FAILURES: %0d", errors);

        $display("========================================");

        $finish;
    end

endmodule
