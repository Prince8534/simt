
`timescale 1ns/1ps

module simt_masked_execution_tb;

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

    // 10 ns clock period
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
        $display(" SIMT MASKED EXECUTION TEST");
        $display("========================================");

        #12;
        reset = 1'b0;

        // ----------------------------------------------------
        // PROGRAM
        // ----------------------------------------------------
        //
        // 0x00: ADDI x3,x1,5
        // 0x04: BEQ  x1,x2,+28 -> 0x20
        // 0x08: ADDI x4,x1,7       [deferred path]
        // 0x0C: JOIN                [reconverge]
        //
        // 0x20: ADDI x5,x1,9       [taken path]
        // 0x24: JOIN                [switch to deferred path]
        //
        // 0x40: NOP
        //
        // Taken mask:    00110011
        // Deferred mask: 11001100
        // ----------------------------------------------------

        dut.frontend.instruction_memory.memory[0] =
            32'h00508193; // ADDI x3,x1,5

        dut.frontend.instruction_memory.memory[1] =
            32'h00208E63; // BEQ x1,x2,+28

        dut.frontend.instruction_memory.memory[2] =
            32'h00708213; // ADDI x4,x1,7

        dut.frontend.instruction_memory.memory[3] =
            32'h0000200B; // JOIN

        dut.frontend.instruction_memory.memory[8] =
            32'h00908293; // ADDI x5,x1,9

        dut.frontend.instruction_memory.memory[9] =
            32'h0000200B; // JOIN

        dut.frontend.instruction_memory.memory[16] =
            32'h00000013; // NOP

        // ----------------------------------------------------
        // INITIALIZE LANE REGISTERS
        // ----------------------------------------------------

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

        // Sentinel values let us prove that masked lanes
        // retain their previous register values.
        dut.core.LANES[0].lane_unit.registers[4] = 32'd200;
        dut.core.LANES[1].lane_unit.registers[4] = 32'd201;
        dut.core.LANES[2].lane_unit.registers[4] = 32'd202;
        dut.core.LANES[3].lane_unit.registers[4] = 32'd203;
        dut.core.LANES[4].lane_unit.registers[4] = 32'd204;
        dut.core.LANES[5].lane_unit.registers[4] = 32'd205;
        dut.core.LANES[6].lane_unit.registers[4] = 32'd206;
        dut.core.LANES[7].lane_unit.registers[4] = 32'd207;

        dut.core.LANES[0].lane_unit.registers[5] = 32'd100;
        dut.core.LANES[1].lane_unit.registers[5] = 32'd101;
        dut.core.LANES[2].lane_unit.registers[5] = 32'd102;
        dut.core.LANES[3].lane_unit.registers[5] = 32'd103;
        dut.core.LANES[4].lane_unit.registers[5] = 32'd104;
        dut.core.LANES[5].lane_unit.registers[5] = 32'd105;
        dut.core.LANES[6].lane_unit.registers[5] = 32'd106;
        dut.core.LANES[7].lane_unit.registers[5] = 32'd107;

        #1;

        // ====================================================
        // STAGE 1: INITIAL UNIFORM EXECUTION
        // ====================================================

        $display("");
        $display("STAGE 1: INITIAL ADDI");
        $display("--------------------");

        check(current_pc === 32'h00000000, "Initial PC is zero");
        check(thread_mask === 8'b11111111, "All lanes initially enabled");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000004, "PC advances to branch");

        check(dut.core.LANES[0].lane_unit.registers[3] === 32'd15,
              "Initial ADDI writes lane 0");
        check(dut.core.LANES[7].lane_unit.registers[3] === 32'd85,
              "Initial ADDI writes lane 7");

        // ====================================================
        // STAGE 2: DIVERGENCE
        // ====================================================

        $display("");
        $display("STAGE 2: DIVERGENT BRANCH");
        $display("-------------------------");

        check(predicate_mask === 8'b00110011,
              "Branch predicate is 00110011");
        check(divergence === 1'b1,
              "Branch divergence detected");
        check(dut.next_pc === 32'h00000020,
              "Branch selects taken target");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000020,
              "Taken path begins at 0x20");
        check(thread_mask === 8'b00110011,
              "Taken-path mask is 00110011");

        // ====================================================
        // STAGE 3: MASKED ARITHMETIC ON TAKEN PATH
        // ====================================================

        $display("");
        $display("STAGE 3: ADDI x5,x1,9 ON TAKEN PATH");
        $display("-----------------------------------");
        $display("Before execution: PC=%08h mask=%08b",
                 current_pc, thread_mask);

        check(instruction === 32'h00908293,
              "Taken-path ADDI fetched");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000024,
              "Taken-path ADDI advances PC");

        // Enabled lanes 0,1,4,5 should write x5 = x1 + 9.
        check(dut.core.LANES[0].lane_unit.registers[5] === 32'd19,
              "Lane 0 commits taken-path result");
        check(dut.core.LANES[1].lane_unit.registers[5] === 32'd29,
              "Lane 1 commits taken-path result");
        check(dut.core.LANES[4].lane_unit.registers[5] === 32'd59,
              "Lane 4 commits taken-path result");
        check(dut.core.LANES[5].lane_unit.registers[5] === 32'd69,
              "Lane 5 commits taken-path result");

        // Masked lanes 2,3,6,7 must retain their sentinels.
        check(dut.core.LANES[2].lane_unit.registers[5] === 32'd102,
              "Masked lane 2 preserves x5");
        check(dut.core.LANES[3].lane_unit.registers[5] === 32'd103,
              "Masked lane 3 preserves x5");
        check(dut.core.LANES[6].lane_unit.registers[5] === 32'd106,
              "Masked lane 6 preserves x5");
        check(dut.core.LANES[7].lane_unit.registers[5] === 32'd107,
              "Masked lane 7 preserves x5");

        // ====================================================
        // STAGE 4: FIRST JOIN
        // ====================================================

        $display("");
        $display("STAGE 4: SWITCH TO DEFERRED PATH");
        $display("--------------------------------");

        check(instruction === 32'h0000200B,
              "JOIN fetched at 0x24");
        check(dut.next_pc === 32'h00000008,
              "JOIN selects deferred PC 0x08");
        check(stack_pop === 1'b0,
              "First JOIN preserves stack entry");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000008,
              "Deferred path begins at 0x08");
        check(thread_mask === 8'b11001100,
              "Deferred mask is 11001100");

        // ====================================================
        // STAGE 5: MASKED ARITHMETIC ON DEFERRED PATH
        // ====================================================

        $display("");
        $display("STAGE 5: ADDI x4,x1,7 ON DEFERRED PATH");
        $display("---------------------------------------");

        check(instruction === 32'h00708213,
              "Deferred-path ADDI fetched");

        @(posedge clk);
        #1;

        check(current_pc === 32'h0000000C,
              "Deferred-path ADDI advances PC");

        // Enabled lanes 2,3,6,7 should write x4 = x1 + 7.
        check(dut.core.LANES[2].lane_unit.registers[4] === 32'd37,
              "Lane 2 commits deferred-path result");
        check(dut.core.LANES[3].lane_unit.registers[4] === 32'd47,
              "Lane 3 commits deferred-path result");
        check(dut.core.LANES[6].lane_unit.registers[4] === 32'd77,
              "Lane 6 commits deferred-path result");
        check(dut.core.LANES[7].lane_unit.registers[4] === 32'd87,
              "Lane 7 commits deferred-path result");

        // Masked lanes 0,1,4,5 must retain their sentinels.
        check(dut.core.LANES[0].lane_unit.registers[4] === 32'd200,
              "Masked lane 0 preserves x4");
        check(dut.core.LANES[1].lane_unit.registers[4] === 32'd201,
              "Masked lane 1 preserves x4");
        check(dut.core.LANES[4].lane_unit.registers[4] === 32'd204,
              "Masked lane 4 preserves x4");
        check(dut.core.LANES[5].lane_unit.registers[4] === 32'd205,
              "Masked lane 5 preserves x4");

        // ====================================================
        // STAGE 6: RECONVERGENCE
        // ====================================================

        $display("");
        $display("STAGE 6: RECONVERGENCE");
        $display("----------------------");

        check(instruction === 32'h0000200B,
              "JOIN fetched at 0x0C");
        check(dut.next_pc === 32'h00000040,
              "Reconvergence PC selected");
        check(stack_pop === 1'b1,
              "Second JOIN pops stack entry");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000040,
              "Reconvergence reaches PC 0x40");
        check(thread_mask === 8'b11111111,
              "All lanes restored after reconvergence");

        // ====================================================
        // SUMMARY
        // ====================================================

        $display("");
        $display("========================================");

        if (errors == 0)
            $display("ALL MASKED EXECUTION CHECKS PASSED");
        else
            $display("MASKED EXECUTION FAILURES: %0d", errors);

        $display("========================================");

        $finish;
    end

endmodule
