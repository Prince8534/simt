`timescale 1ns/1ps

module simt_control_top_tb;

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


    // ============================================================
    // DUT
    // ============================================================

    simt_control_top dut (
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


    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;


    // ============================================================
    // TEST
    // ============================================================

    initial begin

        clk = 0;
        reset = 1;


        // ========================================================
        // PROGRAM
        //
        // 0x00 : BEQ x1, x2, +0x20
        //
        // 0x04 : JOIN
        //
        // 0x20 : JOIN
        //
        // 0x40 : NOP
        // ========================================================

        dut.frontend.instruction_memory.memory[0] =
            32'h02208063;

        dut.frontend.instruction_memory.memory[1] =
            32'h0000200B;

        dut.frontend.instruction_memory.memory[8] =
            32'h0000200B;

        dut.frontend.instruction_memory.memory[16] =
            32'h00000013;


        // ========================================================
        // RESET
        //
        // Hold reset through a clock edge.
        // ========================================================

        #12;

        reset = 0;


        // ========================================================
        // INITIALIZE LANE REGISTERS
        //
        // Reset is now RELEASED.
        //
        // Do NOT wait for another clock before checking BEQ,
        // because that clock would execute the BEQ and advance PC.
        // ========================================================

        dut.divergence_unit.core.LANES[0].lane_unit.registers[1] = 32'd10;
        dut.divergence_unit.core.LANES[0].lane_unit.registers[2] = 32'd10;

        dut.divergence_unit.core.LANES[1].lane_unit.registers[1] = 32'd20;
        dut.divergence_unit.core.LANES[1].lane_unit.registers[2] = 32'd20;

        dut.divergence_unit.core.LANES[2].lane_unit.registers[1] = 32'd30;
        dut.divergence_unit.core.LANES[2].lane_unit.registers[2] = 32'd99;

        dut.divergence_unit.core.LANES[3].lane_unit.registers[1] = 32'd40;
        dut.divergence_unit.core.LANES[3].lane_unit.registers[2] = 32'd99;

        dut.divergence_unit.core.LANES[4].lane_unit.registers[1] = 32'd50;
        dut.divergence_unit.core.LANES[4].lane_unit.registers[2] = 32'd50;

        dut.divergence_unit.core.LANES[5].lane_unit.registers[1] = 32'd60;
        dut.divergence_unit.core.LANES[5].lane_unit.registers[2] = 32'd60;

        dut.divergence_unit.core.LANES[6].lane_unit.registers[1] = 32'd70;
        dut.divergence_unit.core.LANES[6].lane_unit.registers[2] = 32'd99;

        dut.divergence_unit.core.LANES[7].lane_unit.registers[1] = 32'd80;
        dut.divergence_unit.core.LANES[7].lane_unit.registers[2] = 32'd99;


        // Give combinational logic time to settle.
        #1;


        // ========================================================
        // HEADER
        // ========================================================

        $display("");
        $display("========================================");
        $display(" FETCH-DRIVEN SIMT CONTROL TEST");
        $display("========================================");


        // ========================================================
        // BEQ @ PC = 0
        //
        // IMPORTANT:
        // This is BEFORE the clock edge.
        // ========================================================

        $display("");
        $display("FETCH: BEQ - BEFORE CLOCK");
        $display("-------------------------");

        $display("PC           = %08h", current_pc);
        $display("instruction  = %08h", instruction);
        $display("predicate    = %08b", predicate_mask);
        $display("divergence   = %b", divergence);
        $display("split        = %b", split);
        $display("next_pc      = %08h", dut.next_pc);
        $display("stack_push   = %b", stack_push);

        if (current_pc == 32'h00000000)
            $display("PASS: PC = 0");
        else
            $display("FAIL: PC");

        if (instruction == 32'h02208063)
            $display("PASS: BEQ fetched from instruction memory");
        else
            $display("FAIL: BEQ fetch");

        if (branch_instr)
            $display("PASS: BEQ decoded");
        else
            $display("FAIL: BEQ decode");

        if (predicate_mask == 8'b00110011)
            $display("PASS: predicate mask = 00110011");
        else
            $display("FAIL: predicate mask");

        if (divergence)
            $display("PASS: divergence detected");
        else
            $display("FAIL: divergence");

        if (split)
            $display("PASS: SPLIT asserted");
        else
            $display("FAIL: SPLIT");

        if (dut.next_pc == 32'h00000020)
            $display("PASS: taken PC = 0x20");
        else
            $display("FAIL: taken PC");

        if (stack_push)
            $display("PASS: IPDOM stack push");
        else
            $display("FAIL: IPDOM stack push");


        // ========================================================
        // COMMIT BEQ / SPLIT
        //
        // Wait for the next rising edge.
        // ========================================================

        #9;

        $display("");
        $display("AFTER BEQ / SPLIT");
        $display("-----------------");

        $display("PC           = %08h", current_pc);
        $display("instruction  = %08h", instruction);
        $display("thread_mask  = %08b", thread_mask);

        if (current_pc == 32'h00000020)
            $display("PASS: PC moved to taken path");
        else
            $display("FAIL: taken PC");

        if (thread_mask == 8'b00110011)
            $display("PASS: taken thread mask");
        else
            $display("FAIL: taken thread mask");

        if (instruction == 32'h0000200B)
            $display("PASS: JOIN fetched at taken path");
        else
            $display("FAIL: JOIN fetch");


        // ========================================================
        // JOIN #1 @ PC = 0x20
        //
        // BEFORE CLOCK
        //
        // This JOIN switches:
        //
        //   mask 00110011
        //        ↓
        //   mask 11001100
        //
        // and:
        //
        //   PC 0x20
        //        ↓
        //   PC 0x04
        // ========================================================

        #1;

        $display("");
        $display("JOIN #1 - BEFORE CLOCK");
        $display("---------------------");

        $display("PC           = %08h", current_pc);
        $display("instruction  = %08h", instruction);
        $display("thread_mask  = %08b", thread_mask);
        $display("next_pc      = %08h", dut.next_pc);
        $display("stack_pop    = %b", stack_pop);

        if (current_pc == 32'h00000020)
            $display("PASS: JOIN #1 at taken path");
        else
            $display("FAIL: JOIN #1 PC");

        if (dut.next_pc == 32'h00000004)
            $display("PASS: deferred PC selected");
        else
            $display("FAIL: deferred PC");

        if (!stack_pop)
            $display("PASS: stack preserved");
        else
            $display("FAIL: premature stack pop");


        // ========================================================
        // COMMIT JOIN #1
        // ========================================================

        #9;

        $display("");
        $display("AFTER JOIN #1");
        $display("-------------");

        $display("PC           = %08h", current_pc);
        $display("instruction  = %08h", instruction);
        $display("thread_mask  = %08b", thread_mask);

        if (current_pc == 32'h00000004)
            $display("PASS: deferred PC = 0x04");
        else
            $display("FAIL: deferred PC");

        if (thread_mask == 8'b11001100)
            $display("PASS: deferred thread mask");
        else
            $display("FAIL: deferred thread mask");

        if (instruction == 32'h0000200B)
            $display("PASS: JOIN fetched at deferred path");
        else
            $display("FAIL: deferred JOIN fetch");


        // ========================================================
        // JOIN #2 @ PC = 0x04
        //
        // BEFORE CLOCK
        //
        // This JOIN restores:
        //
        //   PC   = 0x40
        //   mask = 11111111
        // ========================================================

        #1;

        $display("");
        $display("JOIN #2 - BEFORE CLOCK");
        $display("---------------------");

        $display("PC           = %08h", current_pc);
        $display("instruction  = %08h", instruction);
        $display("thread_mask  = %08b", thread_mask);
        $display("next_pc      = %08h", dut.next_pc);
        $display("stack_pop    = %b", stack_pop);

        if (current_pc == 32'h00000004)
            $display("PASS: JOIN #2 at deferred path");
        else
            $display("FAIL: JOIN #2 PC");

        if (dut.next_pc == 32'h00000040)
            $display("PASS: reconvergence PC selected");
        else
            $display("FAIL: reconvergence PC");

        if (stack_pop)
            $display("PASS: IPDOM stack pop");
        else
            $display("FAIL: IPDOM stack pop");


        // ========================================================
        // COMMIT JOIN #2
        // ========================================================

        #9;

        $display("");
        $display("AFTER JOIN #2");
        $display("-------------");

        $display("PC           = %08h", current_pc);
        $display("instruction  = %08h", instruction);
        $display("thread_mask  = %08b", thread_mask);

        if (current_pc == 32'h00000040)
            $display("PASS: reconvergence PC = 0x40");
        else
            $display("FAIL: reconvergence PC");

        if (thread_mask == 8'b11111111)
            $display("PASS: all lanes reconverged");
        else
            $display("FAIL: reconvergence mask");

        if (instruction == 32'h00000013)
            $display("PASS: NOP fetched at reconvergence");
        else
            $display("FAIL: reconvergence instruction");


        // ========================================================
        // COMPLETE
        // ========================================================

        $display("");
        $display("========================================");
        $display(" FETCH-DRIVEN TEST COMPLETE");
        $display("========================================");

        $finish;

    end

endmodule
