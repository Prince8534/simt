`timescale 1ns/1ps

module divergence_controller_tb;

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

        clk = 1'b0;
        reset = 1'b1;

        split = 1'b0;
        join_instr = 1'b0;

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

        reset = 1'b0;

        // =================================================
        // 1. SPLIT
        // =================================================

        split = 1'b1;

        #1;

        $display("");
        $display("====================================");
        $display("            SPLIT TEST              ");
        $display("====================================");

        $display("thread_mask      = %b", thread_mask);
        $display("predicate_mask   = %b", predicate_mask);
        $display("next_thread_mask = %b", next_thread_mask);
        $display("next_pc          = %h", next_pc);
        $display("stack_push       = %b", stack_push);

        if (next_thread_mask !== 8'b11001100)
            $display("FAIL: incorrect taken mask");
        else
            $display("PASS: taken mask");

        if (next_pc !== 32'h00000200)
            $display("FAIL: incorrect taken PC");
        else
            $display("PASS: taken PC");

        if (!stack_push)
            $display("FAIL: stack push not asserted");
        else
            $display("PASS: stack push");

        // Let SPLIT reach the clock edge
        @(posedge clk);

        split = 1'b0;

        #1;

        // =================================================
        // Verify stack after SPLIT
        // =================================================

        $display("");
        $display("DEBUG AFTER SPLIT");
        $display("-----------------");
        $display("stack_empty          = %b", dut.stack_empty);
        $display("top_deferred_mask    = %b",
                 dut.top_deferred_mask);
        $display("top_deferred_pc      = %h",
                 dut.top_deferred_pc);
        $display("top_reconvergence_pc = %h",
                 dut.top_reconvergence_pc);
        $display("top_path_state       = %b",
                 dut.top_path_state);

        // =================================================
        // 2. FIRST JOIN
        // =================================================

        thread_mask = 8'b11001100;
        current_pc = 32'h00000210;

        join_instr = 1'b1;

        #1;

        $display("");
        $display("====================================");
        $display("           JOIN #1 TEST             ");
        $display("====================================");

        $display("top_path_state   = %b", dut.top_path_state);
        $display("next_thread_mask = %b", next_thread_mask);
        $display("next_pc          = %h", next_pc);
        $display("stack_pop        = %b", stack_pop);

        $display("join_path_state       = %b",
                 dut.join_path_state);
        $display("update_top_path_state = %b",
                 dut.update_top_path_state);
        $display("new_path_state        = %b",
                 dut.new_path_state);

        if (next_thread_mask !== 8'b00110011)
            $display("FAIL: incorrect deferred mask");
        else
            $display("PASS: deferred mask");

        if (next_pc !== 32'h00000300)
            $display("FAIL: incorrect deferred PC");
        else
            $display("PASS: deferred PC");

        if (stack_pop)
            $display("FAIL: stack popped on first JOIN");
        else
            $display("PASS: stack retained on first JOIN");

        // IMPORTANT:
        // Keep JOIN asserted until the actual clock edge.
        @(posedge clk);

        join_instr = 1'b0;

        #1;

        // =================================================
        // Verify stack after JOIN #1
        // =================================================

        $display("");
        $display("DEBUG AFTER JOIN #1");
        $display("--------------------");
        $display("top_path_state = %b",
                 dut.top_path_state);
        $display("stack_empty    = %b",
                 dut.stack_empty);

        if (dut.top_path_state !== 1'b1)
            $display("FAIL: path state was not updated");
        else
            $display("PASS: path state updated to 1");

        // =================================================
        // 3. SECOND JOIN
        // =================================================

        thread_mask = 8'b00110011;
        current_pc = 32'h00000310;

        $display("");
        $display("DEBUG BEFORE JOIN #2");
        $display("--------------------");
        $display("top_path_state = %b",
                 dut.top_path_state);
        $display("stack_empty    = %b",
                 dut.stack_empty);

        join_instr = 1'b1;

        #1;

        $display("");
        $display("====================================");
        $display("           JOIN #2 TEST             ");
        $display("====================================");

        $display("top_path_state   = %b",
                 dut.top_path_state);
        $display("next_thread_mask = %b",
                 next_thread_mask);
        $display("next_pc          = %h",
                 next_pc);
        $display("stack_pop        = %b",
                 stack_pop);

        if (next_thread_mask !== 8'b11111111)
            $display("FAIL: incorrect reconvergence mask");
        else
            $display("PASS: reconvergence mask");

        if (next_pc !== 32'h00000400)
            $display("FAIL: incorrect reconvergence PC");
        else
            $display("PASS: reconvergence PC");

        if (!stack_pop)
            $display("FAIL: stack pop not asserted");
        else
            $display("PASS: stack pop");

        // Keep JOIN asserted until clock edge
        @(posedge clk);

        join_instr = 1'b0;

        #1;

        // =================================================
        // Verify stack after JOIN #2
        // =================================================

        $display("");
        $display("DEBUG AFTER JOIN #2");
        $display("--------------------");
        $display("top_path_state = %b",
                 dut.top_path_state);
        $display("stack_empty    = %b",
                 dut.stack_empty);

        if (dut.stack_empty !== 1'b1)
            $display("FAIL: stack was not popped");
        else
            $display("PASS: stack is empty");

        // =================================================
        // FINAL RESULT
        // =================================================

        $display("");
        $display("====================================");
        $display(" ONE-LEVEL DIVERGENCE TEST COMPLETE ");
        $display("====================================");

        $finish;

    end

endmodule
