
module simt_nested_divergence_tb;

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
        .stack_pop(stack_pop)
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

    initial begin
        errors = 0;
        reset = 1'b1;

        $display("");
        $display("========================================");
        $display(" SIMT NESTED DIVERGENCE TEST");
        $display("========================================");

        #12;
        reset = 1'b0;

        // Program layout:
        // 0x00: outer BEQ -> 0x20
        // 0x04: outer deferred-path NOP
        // 0x08: outer deferred-path NOP
        // 0x0C: outer JOIN #2 -> 0x40
        //
        // 0x20: inner BEQ -> 0x30
        // 0x24: inner deferred-path NOP
        // 0x28: inner JOIN #2 -> 0x34
        //
        // 0x30: inner JOIN #1 -> 0x24
        // 0x34: inner reconvergence NOP
        // 0x38: NOP
        // 0x3C: outer JOIN #1 -> 0x04
        // 0x40: final NOP

        dut.frontend.instruction_memory.memory[0] =
            32'h02208063; // BEQ x1,x2,+0x20

        dut.frontend.instruction_memory.memory[1] =
            32'h00000013; // NOP

        dut.frontend.instruction_memory.memory[2] =
            32'h00000013; // NOP

        dut.frontend.instruction_memory.memory[3] =
            32'h0000200B; // Outer JOIN #2

        dut.frontend.instruction_memory.memory[8] =
            32'h00418863; // BEQ x3,x4,+0x10

        dut.frontend.instruction_memory.memory[9] =
            32'h00000013; // NOP at 0x24

        dut.frontend.instruction_memory.memory[10] =
            32'h0000200B; // Inner JOIN #2 at 0x28

        dut.frontend.instruction_memory.memory[12] =
            32'h0000200B; // Inner JOIN #1 at 0x30

        dut.frontend.instruction_memory.memory[13] =
            32'h00000013; // NOP at 0x34

        dut.frontend.instruction_memory.memory[14] =
            32'h00000013; // NOP at 0x38

        dut.frontend.instruction_memory.memory[15] =
            32'h0000200B; // Outer JOIN #1 at 0x3C

        dut.frontend.instruction_memory.memory[16] =
            32'h00000013; // NOP at 0x40

        // Outer BEQ: taken lanes 0,1,4,5.
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

        // Inner BEQ: lanes 0 and 4 are equal.
        // The active outer-taken lanes 1 and 5 are not equal.
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
        // 1. OUTER SPLIT
        // ====================================================

        $display("");
        $display("1. OUTER SPLIT");
        $display(
            "PC=%08h predicate=%08b next_pc=%08h",
            current_pc, predicate_mask, dut.next_pc
        );

        check(current_pc === 32'h00000000,
              "Outer branch at 0x00");

        check(predicate_mask === 8'b00110011,
              "Outer predicate mask");

        check(divergence === 1'b1,
              "Outer divergence detected");

        check(dut.next_pc === 32'h00000020,
              "Outer target is 0x20");

        // Verify compiler-generated IPDOM metadata.
        check(dut.metadata_found === 1'b1,
              "Outer branch IPDOM metadata found");

        check(dut.reconvergence_pc === 32'h00000040,
              "Outer IPDOM reconvergence is 0x40");

        check(
            !(dut.cfg_split && !dut.metadata_found),
            "Outer split has valid IPDOM metadata"
        );

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000020,
              "Outer taken path reached");

        check(thread_mask === 8'b00110011,
              "Outer taken mask applied");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Outer stack entry pushed");

        // ====================================================
        // 2. INNER SPLIT
        // ====================================================

        #1;

        $display("");
        $display("2. INNER SPLIT");
        $display(
            "PC=%08h predicate=%08b next_pc=%08h",
            current_pc, predicate_mask, dut.next_pc
        );

        check(instruction === 32'h00418863,
              "Inner BEQ fetched");

        check(predicate_mask === 8'b00010001,
              "Inner predicate mask");

        check(divergence === 1'b1,
              "Inner divergence detected");

        check(dut.next_pc === 32'h00000030,
              "Inner target is 0x30");

        // Verify compiler-generated IPDOM metadata.
        check(dut.metadata_found === 1'b1,
              "Inner branch IPDOM metadata found");

        check(dut.reconvergence_pc === 32'h00000034,
              "Inner IPDOM reconvergence is 0x34");

        check(
            !(dut.cfg_split && !dut.metadata_found),
            "Inner split has valid IPDOM metadata"
        );

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000030,
              "Inner taken path reached");

        check(thread_mask === 8'b00010001,
              "Inner taken mask applied");

        check(dut.divergence_controller.ipdom.stack_pointer == 2,
              "Nested stack depth is two");

        // ====================================================
        // 3. INNER JOIN #1
        // ====================================================

        #1;

        $display("");
        $display("3. INNER JOIN #1");
        $display(
            "PC=%08h instruction=%08h next_pc=%08h mask=%08b",
            current_pc, instruction, dut.next_pc, thread_mask
        );

        check(instruction === 32'h0000200B,
              "Inner JOIN #1 fetched");

        check(dut.next_pc === 32'h00000024,
              "Inner deferred PC selected");

        check(stack_pop === 1'b0,
              "Inner JOIN #1 does not pop");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000024,
              "Inner deferred path begins");

        check(thread_mask === 8'b00100010,
              "Inner deferred mask applied");

        check(dut.divergence_controller.ipdom.stack_pointer == 2,
              "Both stack entries remain");

        check(instruction === 32'h00000013,
              "NOP fetched at 0x24");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000028,
              "Inner JOIN #2 address reached");

        // ====================================================
        // 4. INNER JOIN #2
        // ====================================================

        #1;

        $display("");
        $display("4. INNER JOIN #2");
        $display(
            "PC=%08h instruction=%08h next_pc=%08h mask=%08b pop=%b",
            current_pc, instruction, dut.next_pc, thread_mask, stack_pop
        );

        check(instruction === 32'h0000200B,
              "Inner JOIN #2 fetched");

        check(dut.next_pc === 32'h00000034,
              "Inner reconvergence PC selected");

        check(stack_pop === 1'b1,
              "Inner JOIN #2 pops top entry");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000034,
              "Inner reconvergence reached");

        check(thread_mask === 8'b00110011,
              "Outer taken mask restored");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Outer stack entry preserved");

        // Execute NOPs at 0x34 and 0x38.
        @(posedge clk);
        #1;

        check(current_pc === 32'h00000038,
              "NOP at 0x34 executed");

        @(posedge clk);
        #1;

        check(current_pc === 32'h0000003C,
              "Outer JOIN #1 address reached");

        // ====================================================
        // 5. OUTER JOIN #1
        // ====================================================

        #1;

        $display("");
        $display("5. OUTER JOIN #1");
        $display(
            "PC=%08h instruction=%08h next_pc=%08h mask=%08b pop=%b",
            current_pc, instruction, dut.next_pc, thread_mask, stack_pop
        );

        check(instruction === 32'h0000200B,
              "Outer JOIN #1 fetched");

        check(dut.next_pc === 32'h00000004,
              "Outer deferred PC selected");

        check(stack_pop === 1'b0,
              "Outer JOIN #1 does not pop");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000004,
              "Outer deferred path reached");

        check(thread_mask === 8'b11001100,
              "Outer deferred mask applied");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Outer stack entry remains");

        // Execute NOPs at 0x04 and 0x08.
        @(posedge clk);
        #1;

        check(current_pc === 32'h00000008,
              "Outer deferred NOP at 0x04 executed");

        @(posedge clk);
        #1;

        check(current_pc === 32'h0000000C,
              "Outer JOIN #2 address reached");

        // ====================================================
        // 6. OUTER JOIN #2
        // ====================================================

        #1;

        $display("");
        $display("6. OUTER JOIN #2");
        $display(
            "PC=%08h instruction=%08h next_pc=%08h mask=%08b pop=%b",
            current_pc, instruction, dut.next_pc, thread_mask, stack_pop
        );

        check(instruction === 32'h0000200B,
              "Outer JOIN #2 fetched");

        check(dut.next_pc === 32'h00000040,
              "Outer reconvergence PC selected");

        check(stack_pop === 1'b1,
              "Outer JOIN #2 pops final entry");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000040,
              "Outer reconvergence reached");

        check(thread_mask === 8'b11111111,
              "All lanes restored");

        check(dut.divergence_controller.ipdom.stack_pointer == 0,
              "IPDOM stack is empty");

        // ====================================================
        // FINAL RESULT
        // ====================================================

        $display("");
        $display("========================================");

        if (errors == 0)
            $display("ALL NESTED DIVERGENCE CHECKS PASSED");
        else
            $display("NESTED DIVERGENCE FAILURES: %0d", errors);

        $display("========================================");

        $finish;
    end

endmodule
