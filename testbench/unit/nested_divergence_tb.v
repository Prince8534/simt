`timescale 1ns/1ps

module nested_divergence_tb;

    reg        clk;
    reg        reset;

    reg        split;
    reg        join_instr;

    reg [7:0]  thread_mask;
    reg [7:0]  predicate_mask;

    reg [31:0] current_pc;
    reg [31:0] taken_pc;
    reg [31:0] deferred_pc;
    reg [31:0] reconvergence_pc;

    wire [7:0]  next_thread_mask;
    wire [31:0] next_pc;

    wire stack_push;
    wire stack_pop;

    // =====================================================
    // DUT
    // =====================================================

    simt_divergence_controller dut (
        .clk(clk),
        .reset(reset),

        .split(split),
        .join_instr(join_instr),

        .thread_mask(thread_mask),
        .predicate_mask(predicate_mask),

        .current_pc(current_pc),
        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),
        .reconvergence_pc(reconvergence_pc),

        .next_thread_mask(next_thread_mask),
        .next_pc(next_pc),

        .stack_push(stack_push),
        .stack_pop(stack_pop)
    );

    // =====================================================
    // CLOCK
    // =====================================================

    always #5 clk = ~clk;

    // =====================================================
    // TEST
    // =====================================================

    initial begin

        clk = 0;
        reset = 1;

        split = 0;
        join_instr = 0;

        thread_mask = 8'b11111111;
        predicate_mask = 8'b11001100;

        current_pc = 32'h00000100;
        taken_pc = 32'h00000200;
        deferred_pc = 32'h00000300;
        reconvergence_pc = 32'h00000400;

        // =================================================
        // RESET
        // =================================================

        @(posedge clk);
        @(posedge clk);

        reset = 0;

        // =================================================
        // OUTER SPLIT
        // =================================================

        split = 1;

        #1;

        $display("");
        $display("====================================");
        $display("          OUTER SPLIT               ");
        $display("====================================");

        $display("thread_mask      = %b", thread_mask);
        $display("predicate_mask   = %b", predicate_mask);
        $display("next_thread_mask = %b", next_thread_mask);
        $display("next_pc          = %h", next_pc);
        $display("stack_push       = %b", stack_push);

        if (next_thread_mask !== 8'b11001100)
            $display("FAIL: outer taken mask");
        else
            $display("PASS: outer taken mask");

        if (next_pc !== 32'h00000200)
            $display("FAIL: outer taken PC");
        else
            $display("PASS: outer taken PC");

        if (!stack_push)
            $display("FAIL: outer stack push");
        else
            $display("PASS: outer stack push");

        @(posedge clk);

        split = 0;

        #1;

        $display("");
        $display("DEBUG AFTER OUTER SPLIT");
        $display("-----------------------");
        $display("stack_empty       = %b", dut.stack_empty);
        $display("top_deferred_mask = %b", dut.top_deferred_mask);
        $display("top_deferred_pc   = %h", dut.top_deferred_pc);
        $display("top_path_state    = %b", dut.top_path_state);

        // =================================================
        // INNER SPLIT
        //
        // Current executing threads:
        // 11001100
        //
        // Predicate:
        // 10100000
        //
        // taken:
        // 10000000
        //
        // deferred:
        // 01000000
        // =================================================

        thread_mask = 8'b11001100;
        predicate_mask = 8'b10100000;

        current_pc = 32'h00000210;
        taken_pc = 32'h00000500;
        deferred_pc = 32'h00000600;
        reconvergence_pc = 32'h00000700;

        split = 1;

        #1;

        $display("");
        $display("====================================");
        $display("          INNER SPLIT               ");
        $display("====================================");

        $display("thread_mask      = %b", thread_mask);
        $display("predicate_mask   = %b", predicate_mask);
        $display("next_thread_mask = %b", next_thread_mask);
        $display("next_pc          = %h", next_pc);
        $display("stack_push       = %b", stack_push);

        if (next_thread_mask !== 8'b10000000)
            $display("FAIL: inner taken mask");
        else
            $display("PASS: inner taken mask");

        if (next_pc !== 32'h00000500)
            $display("FAIL: inner taken PC");
        else
            $display("PASS: inner taken PC");

        if (!stack_push)
            $display("FAIL: inner stack push");
        else
            $display("PASS: inner stack push");

        @(posedge clk);

        split = 0;

        #1;

        // =================================================
        // VERIFY TWO STACK ENTRIES
        // =================================================

        $display("");
        $display("DEBUG AFTER INNER SPLIT");
        $display("-----------------------");
        $display("stack_empty       = %b", dut.stack_empty);
        $display("top_deferred_mask = %b", dut.top_deferred_mask);
        $display("top_deferred_pc   = %h", dut.top_deferred_pc);
        $display("top_path_state    = %b", dut.top_path_state);

        if (dut.top_deferred_mask !== 8'b01001100)
            $display("FAIL: inner entry is not on top");
        else
            $display("PASS: inner entry is on top");

        // =================================================
        // INNER JOIN #1
        // =================================================

        thread_mask = 8'b10000000;
        current_pc = 32'h00000510;

        join_instr = 1;

        #1;

        $display("");
        $display("====================================");
        $display("          INNER JOIN #1             ");
        $display("====================================");

        $display("top_path_state   = %b", dut.top_path_state);
        $display("next_thread_mask = %b", next_thread_mask);
        $display("next_pc          = %h", next_pc);
        $display("stack_pop        = %b", stack_pop);

        if (next_thread_mask !== 8'b01001100)
            $display("FAIL: inner deferred mask");
        else
            $display("PASS: inner deferred mask");

        if (next_pc !== 32'h00000600)
            $display("FAIL: inner deferred PC");
        else
            $display("PASS: inner deferred PC");

        if (stack_pop)
            $display("FAIL: inner JOIN #1 popped stack");
        else
            $display("PASS: inner JOIN #1 retained stack");

        @(posedge clk);

        join_instr = 0;

        #1;

        // =================================================
        // INNER JOIN #2
        // =================================================

        thread_mask = 8'b01000000;
        current_pc = 32'h00000610;

        join_instr = 1;

        #1;

        $display("");
        $display("====================================");
        $display("          INNER JOIN #2             ");
        $display("====================================");

        $display("top_path_state   = %b", dut.top_path_state);
        $display("next_thread_mask = %b", next_thread_mask);
        $display("next_pc          = %h", next_pc);
        $display("stack_pop        = %b", stack_pop);

        if (next_thread_mask !== 8'b11001100)
            $display("FAIL: inner reconvergence mask");
        else
            $display("PASS: inner reconvergence mask");

        if (next_pc !== 32'h00000700)
            $display("FAIL: inner reconvergence PC");
        else
            $display("PASS: inner reconvergence PC");

        if (!stack_pop)
            $display("FAIL: inner JOIN #2 did not pop");
        else
            $display("PASS: inner JOIN #2 popped");

        @(posedge clk);

        join_instr = 0;

        #1;

        // =================================================
        // VERIFY OUTER ENTRY RESTORED
        // =================================================

        $display("");
        $display("DEBUG AFTER INNER RECONVERGENCE");
        $display("--------------------------------");
        $display("stack_empty       = %b", dut.stack_empty);
        $display("top_deferred_mask = %b", dut.top_deferred_mask);
        $display("top_deferred_pc   = %h", dut.top_deferred_pc);
        $display("top_path_state    = %b", dut.top_path_state);

        if (dut.stack_empty)
            $display("FAIL: outer entry was lost");
        else
            $display("PASS: outer entry preserved");

        if (dut.top_deferred_mask !== 8'b00110011)
            $display("FAIL: outer deferred state corrupted");
        else
            $display("PASS: outer deferred state preserved");

        // =================================================
        // OUTER JOIN #1
        // =================================================

        thread_mask = 8'b11001100;
        current_pc = 32'h00000220;

        join_instr = 1;

        #1;

        $display("");
        $display("====================================");
        $display("          OUTER JOIN #1             ");
        $display("====================================");

        $display("top_path_state   = %b", dut.top_path_state);
        $display("next_thread_mask = %b", next_thread_mask);
        $display("next_pc          = %h", next_pc);
        $display("stack_pop        = %b", stack_pop);

        if (next_thread_mask !== 8'b00110011)
            $display("FAIL: outer deferred mask");
        else
            $display("PASS: outer deferred mask");

        if (next_pc !== 32'h00000300)
            $display("FAIL: outer deferred PC");
        else
            $display("PASS: outer deferred PC");

        if (stack_pop)
            $display("FAIL: outer JOIN #1 popped");
        else
            $display("PASS: outer JOIN #1 retained");

        @(posedge clk);

        join_instr = 0;

        #1;

        // =================================================
        // OUTER JOIN #2
        // =================================================

        thread_mask = 8'b00110011;
        current_pc = 32'h00000310;

        join_instr = 1;

        #1;

        $display("");
        $display("====================================");
        $display("          OUTER JOIN #2             ");
        $display("====================================");

        $display("top_path_state   = %b", dut.top_path_state);
        $display("next_thread_mask = %b", next_thread_mask);
        $display("next_pc          = %h", next_pc);
        $display("stack_pop        = %b", stack_pop);

        if (next_thread_mask !== 8'b11111111)
            $display("FAIL: outer reconvergence mask");
        else
            $display("PASS: outer reconvergence mask");

        if (next_pc !== 32'h00000400)
            $display("FAIL: outer reconvergence PC");
        else
            $display("PASS: outer reconvergence PC");

        if (!stack_pop)
            $display("FAIL: outer JOIN #2 did not pop");
        else
            $display("PASS: outer JOIN #2 popped");

        @(posedge clk);

        join_instr = 0;

        #1;

        // =================================================
        // FINAL STACK CHECK
        // =================================================

        $display("");
        $display("====================================");
        $display("       NESTED DIVERGENCE TEST       ");
        $display("====================================");

        $display("stack_empty = %b", dut.stack_empty);

        if (dut.stack_empty !== 1'b1)
            $display("FAIL: stack not empty");
        else
            $display("PASS: stack completely empty");

        $display("");
        $display("====================================");
        $display("       NESTED TEST COMPLETE         ");
        $display("====================================");

        $finish;

    end

endmodule
