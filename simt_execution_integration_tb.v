
`timescale 1ns/1ps

module simt_execution_integration_tb;

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
        $display(" SIMT EXECUTION + CONTROL-FLOW TEST");
        $display("========================================");

        #12;
        reset = 1'b0;

        // Program:
        // 0x00: ADDI x3,x1,5
        // 0x04: BEQ  x1,x2,+28 -> 0x20
        // 0x08: JOIN -> 0x40
        // 0x20: JOIN -> deferred path 0x08
        // 0x40: NOP

        dut.frontend.instruction_memory.memory[0]  = 32'h00508193;
        dut.frontend.instruction_memory.memory[1]  = 32'h00208E63;
        dut.frontend.instruction_memory.memory[2]  = 32'h0000200B;
        dut.frontend.instruction_memory.memory[8]  = 32'h0000200B;
        dut.frontend.instruction_memory.memory[16] = 32'h00000013;

        // Initialize each lane's source registers explicitly.
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

        #1;

        // ====================================================
        // STAGE 1: ADDI
        // ====================================================

        $display("");
        $display("STAGE 1: ADDI x3,x1,5");
        $display("PC=%08h instruction=%08h mask=%08b",
                 current_pc, instruction, thread_mask);

        check(current_pc === 32'h00000000, "Initial PC is zero");
        check(instruction === 32'h00508193, "ADDI fetched");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000004, "PC advances after ADDI");

        $display("x3 results: L0=%0d L1=%0d L2=%0d L3=%0d",
                 dut.core.LANES[0].lane_unit.registers[3],
                 dut.core.LANES[1].lane_unit.registers[3],
                 dut.core.LANES[2].lane_unit.registers[3],
                 dut.core.LANES[3].lane_unit.registers[3]);

        $display("            L4=%0d L5=%0d L6=%0d L7=%0d",
                 dut.core.LANES[4].lane_unit.registers[3],
                 dut.core.LANES[5].lane_unit.registers[3],
                 dut.core.LANES[6].lane_unit.registers[3],
                 dut.core.LANES[7].lane_unit.registers[3]);

        check(dut.core.LANES[0].lane_unit.registers[3] === 32'd15,
              "Lane 0 ADDI writeback");
        check(dut.core.LANES[1].lane_unit.registers[3] === 32'd25,
              "Lane 1 ADDI writeback");
        check(dut.core.LANES[2].lane_unit.registers[3] === 32'd35,
              "Lane 2 ADDI writeback");
        check(dut.core.LANES[3].lane_unit.registers[3] === 32'd45,
              "Lane 3 ADDI writeback");
        check(dut.core.LANES[4].lane_unit.registers[3] === 32'd55,
              "Lane 4 ADDI writeback");
        check(dut.core.LANES[5].lane_unit.registers[3] === 32'd65,
              "Lane 5 ADDI writeback");
        check(dut.core.LANES[6].lane_unit.registers[3] === 32'd75,
              "Lane 6 ADDI writeback");
        check(dut.core.LANES[7].lane_unit.registers[3] === 32'd85,
              "Lane 7 ADDI writeback");

        // ====================================================
        // STAGE 2: DIVERGENT BEQ
        // ====================================================

        $display("");
        $display("STAGE 2: DIVERGENT BEQ");
        $display("PC=%08h instruction=%08h predicate=%08b",
                 current_pc, instruction, predicate_mask);
        $display("divergence=%b next_pc=%08h",
                 divergence, dut.next_pc);

        check(instruction === 32'h00208E63, "BEQ fetched");
        check(predicate_mask === 8'b00110011, "BEQ predicate correct");
        check(divergence === 1'b1, "Divergence detected");
        check(dut.next_pc === 32'h00000020, "Taken PC is 0x20");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000020, "Taken path PC reached");
        check(thread_mask === 8'b00110011, "Taken thread mask applied");

        // ====================================================
        // STAGE 3: JOIN #1
        // ====================================================

        #1;

        $display("");
        $display("JOIN #1: PC=%08h next_pc=%08h mask=%08b pop=%b",
                 current_pc, dut.next_pc, thread_mask, stack_pop);

        check(instruction === 32'h0000200B, "JOIN fetched at 0x20");
        check(dut.next_pc === 32'h00000008, "Deferred PC selected");
        check(stack_pop === 1'b0, "JOIN #1 retains stack entry");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000008, "Deferred path PC reached");
        check(thread_mask === 8'b11001100, "Deferred mask applied");

        // ====================================================
        // STAGE 4: JOIN #2
        // ====================================================

        #1;

        $display("");
        $display("JOIN #2: PC=%08h next_pc=%08h mask=%08b pop=%b",
                 current_pc, dut.next_pc, thread_mask, stack_pop);

        check(instruction === 32'h0000200B, "JOIN fetched at 0x08");
        check(dut.next_pc === 32'h00000040, "Reconvergence PC selected");
        check(stack_pop === 1'b1, "JOIN #2 pops stack");

        @(posedge clk);
        #1;

        check(current_pc === 32'h00000040, "Reconvergence PC reached");
        check(thread_mask === 8'b11111111, "All lanes reconverged");

        $display("");
        $display("========================================");
        if (errors == 0)
            $display("ALL EXECUTION INTEGRATION CHECKS PASSED");
        else
            $display("EXECUTION INTEGRATION FAILURES: %0d", errors);
        $display("========================================");

        $finish;
    end

endmodule
