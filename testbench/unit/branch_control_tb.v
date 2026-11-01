`timescale 1ns/1ps

module simt_branch_control_tb;

    reg clk;
    reg reset;

    reg [31:0] current_pc;
    reg [31:0] instruction;
    reg [31:0] reconvergence_pc;

    wire [31:0] next_pc;
    wire [7:0] predicate_mask;

    wire branch_instr;
    wire divergence;
    wire split;


    // ==================================================
    // DUT
    // ==================================================

    simt_branch_control dut (
        .clk(clk),
        .reset(reset),

        .current_pc(current_pc),
        .instruction(instruction),

        .reconvergence_pc(reconvergence_pc),

        .next_pc(next_pc),
        .predicate_mask(predicate_mask),

        .branch_instr(branch_instr),
        .divergence(divergence),
        .split(split)
    );


    // ==================================================
    // Clock
    // ==================================================

    initial begin
        clk = 0;

        forever #5 clk = ~clk;
    end


    // ==================================================
    // Test
    // ==================================================

    initial begin

        $display("========================================");
        $display(" REAL-LANE DIVERGENT BRANCH TEST");
        $display("========================================");


        // ------------------------------------------------
        // Reset
        // ------------------------------------------------

        reset = 1;

        current_pc = 32'h00000100;

        // BEQ x1, x2, +0x20
        instruction = 32'h02208063;

        reconvergence_pc = 32'h00000140;

        #12;

        reset = 0;

        #1;


        // ------------------------------------------------
        // Initialize lane-local registers
        //
        // We want:
        //
        // Lane 0: x1 == x2  -> taken
        // Lane 1: x1 == x2  -> taken
        // Lane 2: x1 != x2  -> deferred
        // Lane 3: x1 != x2  -> deferred
        // Lane 4: x1 == x2  -> taken
        // Lane 5: x1 == x2  -> taken
        // Lane 6: x1 != x2  -> deferred
        // Lane 7: x1 != x2  -> deferred
        //
        // Expected:
        //
        // predicate_mask = 00110011
        //
        // ------------------------------------------------

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


        // ------------------------------------------------
        // Display register state
        // ------------------------------------------------

        $display("");
        $display("LANE REGISTER STATE");
        $display("-------------------");

        $display("Lane 0: x1=%0d x2=%0d",
            dut.core.LANES[0].lane_unit.registers[1],
            dut.core.LANES[0].lane_unit.registers[2]);

        $display("Lane 1: x1=%0d x2=%0d",
            dut.core.LANES[1].lane_unit.registers[1],
            dut.core.LANES[1].lane_unit.registers[2]);

        $display("Lane 2: x1=%0d x2=%0d",
            dut.core.LANES[2].lane_unit.registers[1],
            dut.core.LANES[2].lane_unit.registers[2]);

        $display("Lane 3: x1=%0d x2=%0d",
            dut.core.LANES[3].lane_unit.registers[1],
            dut.core.LANES[3].lane_unit.registers[2]);

        $display("Lane 4: x1=%0d x2=%0d",
            dut.core.LANES[4].lane_unit.registers[1],
            dut.core.LANES[4].lane_unit.registers[2]);

        $display("Lane 5: x1=%0d x2=%0d",
            dut.core.LANES[5].lane_unit.registers[1],
            dut.core.LANES[5].lane_unit.registers[2]);

        $display("Lane 6: x1=%0d x2=%0d",
            dut.core.LANES[6].lane_unit.registers[1],
            dut.core.LANES[6].lane_unit.registers[2]);

        $display("Lane 7: x1=%0d x2=%0d",
            dut.core.LANES[7].lane_unit.registers[1],
            dut.core.LANES[7].lane_unit.registers[2]);


        // ------------------------------------------------
        // Branch
        // ------------------------------------------------

        #1;

        $display("");
        $display("DIVERGENT BEQ");
        $display("-------------");

        $display("instruction      = %h", instruction);
        $display("current_pc       = %h", current_pc);
        $display("branch_instr     = %b", branch_instr);
        $display("predicate_mask   = %b", predicate_mask);
        $display("next_pc          = %h", next_pc);
        $display("divergence       = %b", divergence);
        $display("split            = %b", split);


        // ------------------------------------------------
        // Checks
        // ------------------------------------------------

        if (branch_instr !== 1'b1)
            $display("FAIL: branch not decoded");

        else
            $display("PASS: BEQ decoded");


        if (predicate_mask !== 8'b00110011)
            $display("FAIL: predicate mask expected 00110011");

        else
            $display("PASS: predicate mask = 11001100");


        if (!divergence)
            $display("FAIL: divergence not detected");

        else
            $display("PASS: divergence detected");


        if (!split)
            $display("FAIL: SPLIT not asserted");

        else
            $display("PASS: SPLIT asserted");


        if (next_pc !== 32'h00000120)
            $display("FAIL: taken PC expected 0x120");

        else
            $display("PASS: taken PC = 0x120");


        $display("");
        $display("========================================");
        $display(" DIVERGENT BRANCH TEST COMPLETE");
        $display("========================================");

        $finish;

    end

endmodule
