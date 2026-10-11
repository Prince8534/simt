`timescale 1ns/1ps

module cfg_controller_tb;

    reg [31:0] current_pc;
    reg [31:0] branch_immediate;

    reg [7:0] thread_mask;
    reg [7:0] predicate_mask;

    reg branch_instr;

    reg [31:0] reconvergence_pc;

    wire [31:0] taken_pc;
    wire [31:0] deferred_pc;

    wire divergence;
    wire branch_taken;
    wire branch_fallthrough;
    wire split;

    simt_cfg_controller dut (
        .current_pc(current_pc),
        .branch_immediate(branch_immediate),
        .thread_mask(thread_mask),
        .predicate_mask(predicate_mask),
        .branch_instr(branch_instr),
        .reconvergence_pc(reconvergence_pc),

        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),
        .divergence(divergence),
        .branch_taken(branch_taken),
        .branch_fallthrough(branch_fallthrough),
        .split(split)
    );

    initial begin

        $display("====================================");
        $display(" SIMT CFG CONTROLLER TEST");
        $display("====================================");

        // ------------------------------------------------
        // Divergent diamond
        //
        //       0x100
        //         |
        //       branch
        //       /    \
        //   0x120    0x104
        //       \    /
        //        0x140
        // ------------------------------------------------

        current_pc      = 32'h00000100;
        branch_immediate = 32'h00000020;

        thread_mask     = 8'b11111111;
        predicate_mask  = 8'b11001100;

        branch_instr    = 1'b1;

        reconvergence_pc = 32'h00000140;

        #1;

        $display("");
        $display("DIVERGENT BRANCH");
        $display("-----------------");

        $display("current_pc       = %h", current_pc);
        $display("taken_pc         = %h", taken_pc);
        $display("deferred_pc      = %h", deferred_pc);
        $display("reconvergence_pc = %h", reconvergence_pc);
        $display("thread_mask      = %b", thread_mask);
        $display("predicate_mask   = %b", predicate_mask);
        $display("divergence       = %b", divergence);
        $display("split            = %b", split);

        if (taken_pc != 32'h00000120)
            $display("FAIL: taken_pc");

        else if (deferred_pc != 32'h00000104)
            $display("FAIL: deferred_pc");

        else if (!divergence)
            $display("FAIL: divergence");

        else if (!split)
            $display("FAIL: split");

        else
            $display("PASS: divergent branch");


        // ------------------------------------------------
        // Uniform taken
        // ------------------------------------------------

        predicate_mask = 8'b11111111;

        #1;

        $display("");
        $display("UNIFORM TAKEN");
        $display("-------------");

        $display("predicate_mask   = %b", predicate_mask);
        $display("branch_taken     = %b", branch_taken);
        $display("branch_fallthrough = %b", branch_fallthrough);
        $display("divergence       = %b", divergence);

        if (!branch_taken)
            $display("FAIL: uniform taken");

        else if (divergence)
            $display("FAIL: false divergence");

        else
            $display("PASS: uniform taken");


        // ------------------------------------------------
        // Uniform fall-through
        // ------------------------------------------------

        predicate_mask = 8'b00000000;

        #1;

        $display("");
        $display("UNIFORM FALL-THROUGH");
        $display("--------------------");

        $display("predicate_mask   = %b", predicate_mask);
        $display("branch_taken     = %b", branch_taken);
        $display("branch_fallthrough = %b", branch_fallthrough);
        $display("divergence       = %b", divergence);

        if (!branch_fallthrough)
            $display("FAIL: uniform fall-through");

        else if (divergence)
            $display("FAIL: false divergence");

        else
            $display("PASS: uniform fall-through");


        $display("");
        $display("====================================");
        $display(" CFG CONTROLLER TEST COMPLETE");
        $display("====================================");

        $finish;
    end

endmodule
