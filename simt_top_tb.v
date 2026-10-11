
`timescale 1ns/1ps

module simt_top_tb;

    reg clk;
    reg reset;

    wire [31:0] current_pc;
    wire [31:0] instruction;
    wire [7:0]  thread_mask;

    wire [7:0]  predicate_mask;
    wire        branch_instr;
    wire        divergence;
    wire        split;
    wire        stack_push;
    wire        stack_pop;

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

    // Clock: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Diagnostic trace at every rising edge
    always @(posedge clk) begin
        #0.1;
        $display(
            "TRACE t=%0t reset=%b PC=%08h instruction=%08h next_pc=%08h control_next_pc=%08h mask=%08b next_mask=%08b push=%b pop=%b join=%b split=%b",
            $time,
            reset,
            current_pc,
            instruction,
            dut.next_pc,
            dut.control_next_pc,
            thread_mask,
            dut.control_next_mask,
            stack_push,
            stack_pop,
            dut.join_instr,
            split
        );
    end

    integer errors;

    initial begin
        errors = 0;
        reset = 1'b1;

        $display("");
        $display("========================================");
        $display(" SIMT TOP-LEVEL INTEGRATION TEST");
        $display("========================================");

        // Hold reset across a rising edge.
        #12;
        reset = 1'b0;

        // Initialize instruction memory.
        dut.frontend.instruction_memory.memory[0]  = 32'h02208063; // BEQ x1,x2,+0x20
        dut.frontend.instruction_memory.memory[1]  = 32'h0000200B; // JOIN at 0x04
        dut.frontend.instruction_memory.memory[8]  = 32'h0000200B; // JOIN at 0x20
        dut.frontend.instruction_memory.memory[16] = 32'h00000013; // NOP at 0x40

        // Lane 0: equal
        dut.core.LANES[0].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[0].lane_unit.registers[2] = 32'd10;

        // Lane 1: equal
        dut.core.LANES[1].lane_unit.registers[1] = 32'd20;
        dut.core.LANES[1].lane_unit.registers[2] = 32'd20;

        // Lane 2: not equal
        dut.core.LANES[2].lane_unit.registers[1] = 32'd30;
        dut.core.LANES[2].lane_unit.registers[2] = 32'd99;

        // Lane 3: not equal
        dut.core.LANES[3].lane_unit.registers[1] = 32'd40;
        dut.core.LANES[3].lane_unit.registers[2] = 32'd99;

        // Lane 4: equal
        dut.core.LANES[4].lane_unit.registers[1] = 32'd50;
        dut.core.LANES[4].lane_unit.registers[2] = 32'd50;

        // Lane 5: equal
        dut.core.LANES[5].lane_unit.registers[1] = 32'd60;
        dut.core.LANES[5].lane_unit.registers[2] = 32'd60;

        // Lane 6: not equal
        dut.core.LANES[6].lane_unit.registers[1] = 32'd70;
        dut.core.LANES[6].lane_unit.registers[2] = 32'd99;

        // Lane 7: not equal
        dut.core.LANES[7].lane_unit.registers[1] = 32'd80;
        dut.core.LANES[7].lane_unit.registers[2] = 32'd99;

        // Allow combinational logic to settle.
        #1;

        $display("");
        $display("BEFORE BEQ");
        $display("PC=%08h instruction=%08h mask=%08b predicate=%08b",
                 current_pc, instruction, thread_mask, predicate_mask);
        $display("divergence=%b split=%b push=%b next_pc=%08h",
                 divergence, split, stack_push, dut.next_pc);

        if (current_pc !== 32'h00000000) begin
            $display("FAIL: initial PC");
            errors = errors + 1;
        end

        if (predicate_mask !== 8'b00110011) begin
            $display("FAIL: branch predicate");
            errors = errors + 1;
        end

        if (split !== 1'b1 || stack_push !== 1'b1) begin
            $display("FAIL: divergent branch was not pushed");
            errors = errors + 1;
        end

        if (dut.next_pc !== 32'h00000020) begin
            $display("FAIL: taken PC before edge");
            errors = errors + 1;
        end

        // Execute BEQ/SPLIT on a rising edge.
        @(posedge clk);
        #1;

        $display("");
        $display("AFTER BEQ / SPLIT");
        $display("PC=%08h mask=%08b", current_pc, thread_mask);

        if (current_pc !== 32'h00000020) begin
            $display("FAIL: PC should be 0x20");
            errors = errors + 1;
        end

        if (thread_mask !== 8'b00110011) begin
            $display("FAIL: taken mask should be 00110011");
            errors = errors + 1;
        end

        // Allow the JOIN at PC 0x20 to settle.
        #1;

        $display("");
        $display("JOIN #1 — EXPECT DEFERRED PATH");
        $display("PC=%08h instruction=%08h mask=%08b next_pc=%08h pop=%b",
                 current_pc, instruction, thread_mask, dut.next_pc, stack_pop);

        if (dut.join_instr !== 1'b1) begin
            $display("FAIL: expected JOIN instruction at 0x20");
            errors = errors + 1;
        end

        if (dut.next_pc !== 32'h00000004) begin
            $display("FAIL: JOIN #1 next PC should be 0x04");
            errors = errors + 1;
        end

        if (stack_pop !== 1'b0) begin
            $display("FAIL: JOIN #1 must retain stack entry");
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        $display("");
        $display("AFTER JOIN #1");
        $display("PC=%08h mask=%08b", current_pc, thread_mask);

        if (current_pc !== 32'h00000004) begin
            $display("FAIL: deferred PC should be 0x04");
            errors = errors + 1;
        end

        if (thread_mask !== 8'b11001100) begin
            $display("FAIL: deferred mask should be 11001100");
            errors = errors + 1;
        end

        // At PC 0x04, the second JOIN should reconverge.
        #1;

        $display("");
        $display("JOIN #2 — EXPECT RECONVERGENCE");
        $display("PC=%08h instruction=%08h mask=%08b next_pc=%08h pop=%b",
                 current_pc, instruction, thread_mask, dut.next_pc, stack_pop);

        if (dut.join_instr !== 1'b1) begin
            $display("FAIL: expected JOIN instruction at 0x04");
            errors = errors + 1;
        end

        if (dut.next_pc !== 32'h00000040) begin
            $display("FAIL: JOIN #2 next PC should be 0x40");
            errors = errors + 1;
        end

        if (stack_pop !== 1'b1) begin
            $display("FAIL: JOIN #2 should pop stack");
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        $display("");
        $display("AFTER JOIN #2");
        $display("PC=%08h mask=%08b", current_pc, thread_mask);

        if (current_pc !== 32'h00000040) begin
            $display("FAIL: reconvergence PC should be 0x40");
            errors = errors + 1;
        end

        if (thread_mask !== 8'b11111111) begin
            $display("FAIL: reconvergence mask should be 11111111");
            errors = errors + 1;
        end

        $display("");
        $display("========================================");

        if (errors == 0)
            $display("ALL TOP-LEVEL CHECKS PASSED");
        else
            $display("TOP-LEVEL CHECKS FAILED: %0d errors", errors);

        $display("========================================");

        $finish;
    end

endmodule
