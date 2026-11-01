`timescale 1ns/1ps

module simt_masked_execute_tb;

    reg clk;
    reg reset;

    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;

    reg [4:0] alu_control;
    reg alu_src_imm;
    reg [31:0] immediate;
    reg reg_write;

    reg split;
    reg join_instr;
    reg [7:0] predicate_mask;

    reg [31:0] taken_pc;
    reg [31:0] deferred_pc;
    reg [31:0] reconvergence_pc;

    wire [7:0] thread_mask;
    wire [31:0] next_pc;

    wire [31:0] lane_result [0:7];

    wire stack_push;
    wire stack_pop;

    simt_masked_execute dut (
        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_control(alu_control),
        .alu_src_imm(alu_src_imm),
        .immediate(immediate),
        .reg_write(reg_write),

        .split(split),
        .join_instr(join_instr),
        .predicate_mask(predicate_mask),

        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),
        .reconvergence_pc(reconvergence_pc),

        .thread_mask(thread_mask),
        .next_pc(next_pc),

        .lane_result(lane_result),

        .stack_push(stack_push),
        .stack_pop(stack_pop)
    );

    always #5 clk = ~clk;


    initial begin

        clk = 0;
        reset = 1;

        rs1 = 0;
        rs2 = 0;
        rd = 0;

        alu_control = 0;
        alu_src_imm = 0;
        immediate = 0;
        reg_write = 0;

        split = 0;
        join_instr = 0;
        predicate_mask = 0;

        taken_pc = 32'h00000020;
        deferred_pc = 32'h00000040;
        reconvergence_pc = 32'h00000060;


        // =================================================
        // RESET
        // =================================================

        #10;
        reset = 0;

        // =================================================
        // PRELOAD DIFFERENT REGISTER VALUES
        // =================================================
        //
        // Lane 0: R1=10,  R2=1
        // Lane 1: R1=20,  R2=2
        // Lane 2: R1=30,  R2=3
        // Lane 3: R1=40,  R2=4
        // Lane 4: R1=50,  R2=5
        // Lane 5: R1=60,  R2=6
        // Lane 6: R1=70,  R2=7
        // Lane 7: R1=80,  R2=8
        //
        // Expected ADD results:
        // L0 = 11
        // L1 = 22
        // L2 = 33
        // L3 = 44
        // L4 = 55
        // L5 = 66
        // L6 = 77
        // L7 = 88
        // =================================================

        dut.execute_stage.core.LANES[0].lane_unit.registers[1] = 32'd10;
        dut.execute_stage.core.LANES[0].lane_unit.registers[2] = 32'd1;

        dut.execute_stage.core.LANES[1].lane_unit.registers[1] = 32'd20;
        dut.execute_stage.core.LANES[1].lane_unit.registers[2] = 32'd2;

        dut.execute_stage.core.LANES[2].lane_unit.registers[1] = 32'd30;
        dut.execute_stage.core.LANES[2].lane_unit.registers[2] = 32'd3;

        dut.execute_stage.core.LANES[3].lane_unit.registers[1] = 32'd40;
        dut.execute_stage.core.LANES[3].lane_unit.registers[2] = 32'd4;

        dut.execute_stage.core.LANES[4].lane_unit.registers[1] = 32'd50;
        dut.execute_stage.core.LANES[4].lane_unit.registers[2] = 32'd5;

        dut.execute_stage.core.LANES[5].lane_unit.registers[1] = 32'd60;
        dut.execute_stage.core.LANES[5].lane_unit.registers[2] = 32'd6;

        dut.execute_stage.core.LANES[6].lane_unit.registers[1] = 32'd70;
        dut.execute_stage.core.LANES[6].lane_unit.registers[2] = 32'd7;

        dut.execute_stage.core.LANES[7].lane_unit.registers[1] = 32'd80;
        dut.execute_stage.core.LANES[7].lane_unit.registers[2] = 32'd8;


        // =================================================
        // INITIAL STATE
        // =================================================

        #2;

        $display("");
        $display("========================================");
        $display(" SIMT MASKED EXECUTION TEST");
        $display("========================================");

        $display("");
        $display("INITIAL THREAD MASK");
        $display("-------------------");
        $display("thread_mask = %b", thread_mask);

        if (thread_mask == 8'b11111111)
            $display("PASS: All lanes active after reset");
        else
            $display("FAIL: Initial thread mask");


        // =================================================
        // DIVERGENT SPLIT
        // =================================================
        //
        // Predicate:
        // 11001100
        //
        // Taken:
        // 11001100
        //
        // Deferred:
        // 00110011
        // =================================================

        predicate_mask = 8'b11001100;
        split = 1'b1;

        #2;

        $display("");
        $display("DIVERGENT SPLIT");
        $display("----------------");
        $display("thread_mask before = %b", thread_mask);
        $display("predicate_mask     = %b", predicate_mask);
        $display("stack_push         = %b", stack_push);

        if (stack_push == 1'b1)
            $display("PASS: SPLIT pushed stack");
        else
            $display("FAIL: SPLIT push");

        #6;

        split = 1'b0;

        #1;

        $display("thread_mask after  = %b", thread_mask);

        if (thread_mask == 8'b11001100)
            $display("PASS: Taken thread mask");
        else
            $display("FAIL: Taken thread mask");


        // =================================================
        // EXECUTE ADD UNDER TAKEN MASK
        // =================================================
        //
        // Active lanes:
        // L2, L3, L6, L7
        //
        // Expected results:
        // L2 = 33
        // L3 = 44
        // L6 = 77
        // L7 = 88
        // =================================================

        rs1 = 5'd1;
        rs2 = 5'd2;
        rd = 5'd3;

        alu_control = 5'd0;       // ADD
        alu_src_imm = 1'b0;
        immediate = 32'b0;
        reg_write = 1'b1;

        #2;

        $display("");
        $display("ADD UNDER TAKEN MASK");
        $display("--------------------");
        $display("thread_mask = %b", thread_mask);

        $display("Lane 0 result = %d", lane_result[0]);
        $display("Lane 1 result = %d", lane_result[1]);
        $display("Lane 2 result = %d", lane_result[2]);
        $display("Lane 3 result = %d", lane_result[3]);
        $display("Lane 4 result = %d", lane_result[4]);
        $display("Lane 5 result = %d", lane_result[5]);
        $display("Lane 6 result = %d", lane_result[6]);
        $display("Lane 7 result = %d", lane_result[7]);

        if (lane_result[0] == 32'd11)
            $display("PASS: Lane 0 computes correctly");
        else
            $display("FAIL: Lane 0 computation");

        if (lane_result[2] == 32'd33)
            $display("PASS: Lane 2 computes correctly");
        else
            $display("FAIL: Lane 2 computation");

        if (lane_result[3] == 32'd44)
            $display("PASS: Lane 3 computes correctly");
        else
            $display("FAIL: Lane 3 computation");

        if (lane_result[6] == 32'd77)
            $display("PASS: Lane 6 computes correctly");
        else
            $display("FAIL: Lane 6 computation");

        if (lane_result[7] == 32'd88)
            $display("PASS: Lane 7 computes correctly");
        else
            $display("FAIL: Lane 7 computation");


        // =================================================
        // COMMIT ADD
        // =================================================

        #8;

        // Check registers after clock edge.
        //
        // Only active lanes should have written R3.
        //

        $display("");
        $display("REGISTER WRITEBACK");
        $display("------------------");

        $display("Lane 0 R3 = %d",
            dut.execute_stage.core.LANES[0].lane_unit.registers[3]);

        $display("Lane 1 R3 = %d",
            dut.execute_stage.core.LANES[1].lane_unit.registers[3]);

        $display("Lane 2 R3 = %d",
            dut.execute_stage.core.LANES[2].lane_unit.registers[3]);

        $display("Lane 3 R3 = %d",
            dut.execute_stage.core.LANES[3].lane_unit.registers[3]);

        $display("Lane 4 R3 = %d",
            dut.execute_stage.core.LANES[4].lane_unit.registers[3]);

        $display("Lane 5 R3 = %d",
            dut.execute_stage.core.LANES[5].lane_unit.registers[3]);

        $display("Lane 6 R3 = %d",
            dut.execute_stage.core.LANES[6].lane_unit.registers[3]);

        $display("Lane 7 R3 = %d",
            dut.execute_stage.core.LANES[7].lane_unit.registers[3]);


        if (dut.execute_stage.core.LANES[2].lane_unit.registers[3] == 32'd33)
            $display("PASS: Lane 2 committed");
        else
            $display("FAIL: Lane 2 commit");

        if (dut.execute_stage.core.LANES[3].lane_unit.registers[3] == 32'd44)
            $display("PASS: Lane 3 committed");
        else
            $display("FAIL: Lane 3 commit");

        if (dut.execute_stage.core.LANES[6].lane_unit.registers[3] == 32'd77)
            $display("PASS: Lane 6 committed");
        else
            $display("FAIL: Lane 6 commit");

        if (dut.execute_stage.core.LANES[7].lane_unit.registers[3] == 32'd88)
            $display("PASS: Lane 7 committed");
        else
            $display("FAIL: Lane 7 commit");

        if (dut.execute_stage.core.LANES[0].lane_unit.registers[3] == 32'd0)
            $display("PASS: Lane 0 masked from writeback");
        else
            $display("FAIL: Lane 0 writeback");

        if (dut.execute_stage.core.LANES[1].lane_unit.registers[3] == 32'd0)
            $display("PASS: Lane 1 masked from writeback");
        else
            $display("FAIL: Lane 1 writeback");

        if (dut.execute_stage.core.LANES[4].lane_unit.registers[3] == 32'd0)
            $display("PASS: Lane 4 masked from writeback");
        else
            $display("FAIL: Lane 4 writeback");

        if (dut.execute_stage.core.LANES[5].lane_unit.registers[3] == 32'd0)
            $display("PASS: Lane 5 masked from writeback");
        else
            $display("FAIL: Lane 5 writeback");


        // =================================================
        // JOIN #1
        // =================================================
        //
        // Switch from taken mask to deferred mask.
        // No stack pop yet.
        // =================================================

        reg_write = 1'b0;
        join_instr = 1'b1;

        #2;

        $display("");
        $display("JOIN #1");
        $display("-------");
        $display("next mask = %b", dut.controller_next_mask);
        $display("stack_pop = %b", stack_pop);

        if (stack_pop == 1'b0)
            $display("PASS: JOIN #1 does not pop");
        else
            $display("FAIL: JOIN #1 pop");

        #6;

        join_instr = 1'b0;

        #1;

        $display("thread_mask after JOIN #1 = %b", thread_mask);

        if (thread_mask == 8'b00110011)
            $display("PASS: Deferred thread mask");
        else
            $display("FAIL: Deferred thread mask");


        // =================================================
        // JOIN #2
        // =================================================
        //
        // Restore reconvergence mask.
        // Pop stack entry.
        // =================================================

        join_instr = 1'b1;

        #2;

        $display("");
        $display("JOIN #2");
        $display("-------");
        $display("stack_pop = %b", stack_pop);

        if (stack_pop == 1'b1)
            $display("PASS: JOIN #2 pops");
        else
            $display("FAIL: JOIN #2 pop");

        #6;

        join_instr = 1'b0;

        #1;

        $display("thread_mask after JOIN #2 = %b", thread_mask);

        if (thread_mask == 8'b11111111)
            $display("PASS: Reconverged thread mask");
        else
            $display("FAIL: Reconverged thread mask");


        // =================================================
        // FINAL
        // =================================================

        $display("");
        $display("========================================");
        $display(" MASKED EXECUTION TEST COMPLETE");
        $display("========================================");

        $finish;

    end

endmodule
