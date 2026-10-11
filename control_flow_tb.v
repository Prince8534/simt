`timescale 1ns/1ps

module simt_control_flow_tb;

    reg clk;
    reg reset;

    reg branch_instr;
    reg join_instr;

    reg [31:0] branch_immediate;
    reg [7:0] predicate_mask;

    reg [31:0] reconvergence_pc;

    wire [31:0] current_pc;
    wire [31:0] next_pc;

    wire [7:0] thread_mask;

    wire divergence;
    wire split;

    wire stack_push;
    wire stack_pop;


    simt_control_flow dut (
        .clk(clk),
        .reset(reset),

        .branch_instr(branch_instr),
        .join_instr(join_instr),

        .branch_immediate(branch_immediate),
        .predicate_mask(predicate_mask),

        .reconvergence_pc(reconvergence_pc),

        .current_pc(current_pc),
        .next_pc(next_pc),

        .thread_mask(thread_mask),

        .divergence(divergence),
        .split(split),

        .stack_push(stack_push),
        .stack_pop(stack_pop)
    );


    // --------------------------------------------------
    // Clock
    // --------------------------------------------------

    initial begin
        clk = 0;

        forever #5 clk = ~clk;
    end


    // --------------------------------------------------
    // Test
    // --------------------------------------------------

    initial begin

        $display("========================================");
        $display(" SIMT CONTROL FLOW INTEGRATION TEST");
        $display("========================================");


        // ------------------------------------------------
        // Reset
        // ------------------------------------------------

        reset = 1;

        branch_instr = 0;
        join_instr = 0;

        branch_immediate = 32'h0;
        predicate_mask = 8'hFF;

        reconvergence_pc = 32'h140;

        #12;

        reset = 0;

        #1;

        $display("");
        $display("RESET");
        $display("-----");

        $display("current_pc  = %h", current_pc);
        $display("thread_mask = %b", thread_mask);

        if (current_pc != 32'h00000000)
            $display("FAIL: PC reset");

        else if (thread_mask != 8'b11111111)
            $display("FAIL: thread mask reset");

        else
            $display("PASS: reset");


        // ------------------------------------------------
        // Divergent branch at 0x0
        //
        // taken     = 0x20
        // fallthrough = 0x4
        // reconvergence = 0x40
        // ------------------------------------------------

        branch_instr = 1;
        join_instr = 0;

        branch_immediate = 32'h20;

        predicate_mask = 8'b11001100;

        reconvergence_pc = 32'h40;

        #1;

        $display("");
        $display("DIVERGENT BRANCH");
        $display("----------------");

        $display("current_pc     = %h", current_pc);
        $display("next_pc        = %h", next_pc);
        $display("thread_mask    = %b", thread_mask);
        $display("predicate_mask = %b", predicate_mask);
        $display("divergence     = %b", divergence);
        $display("split          = %b", split);

        if (!divergence)
            $display("FAIL: divergence not detected");

        else if (!split)
            $display("FAIL: split not asserted");

        else
            $display("PASS: divergence detected");


        // Clock edge commits SPLIT
        #9;

        $display("");
        $display("AFTER SPLIT");
        $display("-----------");

        $display("current_pc  = %h", current_pc);
        $display("thread_mask = %b", thread_mask);

        if (thread_mask != 8'b11001100)
            $display("FAIL: taken thread mask");

        else
            $display("PASS: taken thread mask");


        // ------------------------------------------------
        // The taken path should now execute.
        // Move forward to simulate reaching JOIN #1.
        // ------------------------------------------------

        branch_instr = 0;

        // Current test directly asserts JOIN.
        join_instr = 1;

        #1;

        $display("");
        $display("JOIN #1");
        $display("-------");

        $display("current_pc  = %h", current_pc);
        $display("next_pc     = %h", next_pc);
        $display("thread_mask = %b", thread_mask);

        #9;

        join_instr = 0;

        $display("");
        $display("AFTER JOIN #1");
        $display("------------");

        $display("current_pc  = %h", current_pc);
        $display("thread_mask = %b", thread_mask);


        // ------------------------------------------------
        // JOIN #2
        // ------------------------------------------------

        join_instr = 1;

        #1;

        $display("");
        $display("JOIN #2");
        $display("-------");

        $display("current_pc  = %h", current_pc);
        $display("next_pc     = %h", next_pc);
        $display("thread_mask = %b", thread_mask);

        #9;

        join_instr = 0;

        $display("");
        $display("AFTER JOIN #2");
        $display("------------");

        $display("current_pc  = %h", current_pc);
        $display("thread_mask = %b", thread_mask);

        if (thread_mask != 8'b11111111)
            $display("FAIL: reconvergence mask");

        else
            $display("PASS: reconverged thread mask");


        $display("");
        $display("========================================");
        $display(" CONTROL FLOW TEST COMPLETE");
        $display("========================================");

        $finish;

    end

endmodule
