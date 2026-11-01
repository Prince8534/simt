`timescale 1ns/1ps

module simt_branch_divergence_tb;

    reg clk;
    reg reset;

    reg [31:0] instruction;
    reg [31:0] reconvergence_pc;
    reg join_instr;

    wire [31:0] current_pc;
    wire [31:0] next_pc;

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

    simt_branch_divergence dut (
        .clk(clk),
        .reset(reset),

        .instruction(instruction),
        .reconvergence_pc(reconvergence_pc),
        .join_instr(join_instr),

        .current_pc(current_pc),
        .next_pc(next_pc),

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

        instruction = 32'h00000013;   // NOP
        join_instr = 0;
        reconvergence_pc = 32'h00000040;


        // ========================================================
        // RESET
        // ========================================================

        #2;

        $display("");
        $display("========================================");
        $display(" END-TO-END SIMT DIVERGENCE TEST");
        $display("========================================");

        $display("");
        $display("RESET STATE");
        $display("-----------");
        $display("PC          = %08h", current_pc);
        $display("thread_mask = %08b", thread_mask);

        if (thread_mask == 8'b11111111)
            $display("PASS: all threads active");
        else
            $display("FAIL: initial thread mask");


        // ========================================================
        // RELEASE RESET
        // ========================================================

        #8;
        reset = 0;

        #2;


        // ========================================================
        // INITIALIZE LANE REGISTERS
        //
        // Lane 0: 10 == 10 -> taken
        // Lane 1: 20 == 20 -> taken
        // Lane 2: 30 != 99 -> deferred
        // Lane 3: 40 != 99 -> deferred
        // Lane 4: 50 == 50 -> taken
        // Lane 5: 60 == 60 -> taken
        // Lane 6: 70 != 99 -> deferred
        // Lane 7: 80 != 99 -> deferred
        //
        // predicate_mask = 00110011
        // ========================================================

        dut.core.LANES[0].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[0].lane_unit.registers[2] = 32'd10;

        dut.core.LANES[1].lane_unit.registers[1] = 32'd20;
        dut.core.LANES[1].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[2].lane_unit.registers[1] = 32'd30;
        dut.core.LANES[2].lane_unit.registers[2] = 32'd99;

        dut.core.LANES[3].lane_unit.registers[1] = 32'd40;
        dut.core.LANES[3].lane_unit.registers[2] = 32'd99;

        dut.core.LANES[4].lane_unit.registers[1] = 32'd50;
        dut.core.LANES[4].lane_unit.registers[2] = 32'd50;

        dut.core.LANES[5].lane_unit.registers[1] = 32'd60;
        dut.core.LANES[5].lane_unit.registers[2] = 32'd60;

        dut.core.LANES[6].lane_unit.registers[1] = 32'd70;
        dut.core.LANES[6].lane_unit.registers[2] = 32'd99;

        dut.core.LANES[7].lane_unit.registers[1] = 32'd80;
        dut.core.LANES[7].lane_unit.registers[2] = 32'd99;


        // ========================================================
        // DIVERGENT BEQ
        //
        // BEQ x1, x2, +0x20
        // Encoding = 0x02208063
        //
        // IMPORTANT:
        // We check the combinational branch decision BEFORE
        // the clock edge commits the SPLIT.
        // ========================================================

        instruction = 32'h02208063;
        join_instr = 0;

        #2;

        $display("");
        $display("DIVERGENT BEQ - BEFORE CLOCK");
        $display("---------------------------");
        $display("current PC     = %08h", current_pc);
        $display("instruction    = %08h", instruction);
        $display("branch_instr   = %b", branch_instr);
        $display("predicate_mask = %08b", predicate_mask);
        $display("divergence     = %b", divergence);
        $display("split          = %b", split);
        $display("next_pc        = %08h", next_pc);
        $display("stack_push     = %b", stack_push);

        if (current_pc == 32'h00000000)
            $display("PASS: branch starts at PC 0");
        else
            $display("FAIL: unexpected branch PC");

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
            $display("FAIL: divergence not detected");

        if (split)
            $display("PASS: SPLIT asserted");
        else
            $display("FAIL: SPLIT not asserted");

        if (next_pc == 32'h00000020)
            $display("PASS: taken PC = 0x20");
        else
            $display("FAIL: taken PC");

        if (stack_push)
            $display("PASS: IPDOM stack push");
        else
            $display("FAIL: IPDOM stack push");


        // ========================================================
        // CLOCK EDGE
        // SPLIT COMMITS HERE
        // ========================================================

        #8;

        $display("");
        $display("AFTER SPLIT");
        $display("-----------");
        $display("current PC  = %08h", current_pc);
        $display("thread_mask = %08b", thread_mask);
        $display("stack_push  = %b", stack_push);

        if (current_pc == 32'h00000020)
            $display("PASS: PC moved to taken path");
        else
            $display("FAIL: taken-path PC");

        if (thread_mask == 8'b00110011)
            $display("PASS: taken thread mask");
        else
            $display("FAIL: taken thread mask");


        // ========================================================
        // JOIN #1
        //
        // First JOIN:
        //   taken path -> deferred path
        //
        // Expected:
        //   next PC = 0x04
        //   mask    = 11001100
        //   stack remains
        // ========================================================

        instruction = 32'h00000013;
        join_instr = 1;

        #2;

        $display("");
        $display("JOIN #1 - BEFORE CLOCK");
        $display("---------------------");
        $display("current PC = %08h", current_pc);
        $display("next PC    = %08h", next_pc);
        $display("mask       = %08b", thread_mask);
        $display("stack_pop  = %b", stack_pop);

        if (next_pc == 32'h00000004)
            $display("PASS: deferred PC selected");
        else
            $display("FAIL: deferred PC");

        if (stack_pop == 0)
            $display("PASS: stack preserved");
        else
            $display("FAIL: stack popped too early");


        // Commit JOIN #1

        #8;

        $display("");
        $display("AFTER JOIN #1");
        $display("-------------");
        $display("current PC  = %08h", current_pc);
        $display("thread_mask = %08b", thread_mask);

        if (current_pc == 32'h00000004)
            $display("PASS: deferred PC");
        else
            $display("FAIL: deferred PC");

        if (thread_mask == 8'b11001100)
            $display("PASS: deferred thread mask");
        else
            $display("FAIL: deferred thread mask");


        // ========================================================
        // JOIN #2
        //
        // Second JOIN:
        //   deferred path -> reconvergence
        //
        // Expected:
        //   next PC = 0x40
        //   mask    = 11111111
        //   stack pops
        // ========================================================

        instruction = 32'h00000013;
        join_instr = 1;

        #2;

        $display("");
        $display("JOIN #2 - BEFORE CLOCK");
        $display("---------------------");
        $display("current PC = %08h", current_pc);
        $display("next PC    = %08h", next_pc);
        $display("mask       = %08b", thread_mask);
        $display("stack_pop  = %b", stack_pop);

        if (next_pc == 32'h00000040)
            $display("PASS: reconvergence PC selected");
        else
            $display("FAIL: reconvergence PC");

        if (stack_pop)
            $display("PASS: IPDOM stack pop");
        else
            $display("FAIL: IPDOM stack pop");


        // Commit JOIN #2

        #8;

        $display("");
        $display("AFTER JOIN #2");
        $display("-------------");
        $display("current PC  = %08h", current_pc);
        $display("thread_mask = %08b", thread_mask);

        if (current_pc == 32'h00000040)
            $display("PASS: reconvergence PC");
        else
            $display("FAIL: reconvergence PC");

        if (thread_mask == 8'b11111111)
            $display("PASS: all lanes reconverged");
        else
            $display("FAIL: lanes did not reconverge");


        // ========================================================
        // COMPLETE
        // ========================================================

        $display("");
        $display("========================================");
        $display(" END-TO-END TEST COMPLETE");
        $display("========================================");

        $finish;

    end

endmodule
