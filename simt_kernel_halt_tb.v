
`timescale 1ns/1ps

module simt_kernel_halt_tb;

    reg clk = 0;
    reg reset = 1;

    wire [31:0] current_pc;
    wire [31:0] instruction;
    wire [7:0] thread_mask;
    wire [7:0] predicate_mask;
    wire branch_instr, divergence, split, stack_push, stack_pop;
    wire [63:0] total_cycles, useful_lane_cycles, masked_lane_cycles;
    wire [31:0] efficiency_percent;
    wire halted;

    integer lane;
    integer errors = 0;

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
        .stack_pop(stack_pop),
        .total_cycles(total_cycles),
        .useful_lane_cycles(useful_lane_cycles),
        .masked_lane_cycles(masked_lane_cycles),
        .efficiency_percent(efficiency_percent),
        .halted(halted)
    );

    always #5 clk = ~clk;

    initial begin
        // Reset the core.
        repeat (2) @(posedge clk);
        @(negedge clk);

        // Program:
        // 0x00: ADDI x3, x0, 5
        // 0x04: EBREAK
        // 0x08: ADDI x4, x0, 9 (must not execute)
        dut.frontend.instruction_memory.memory[0] = 32'h00500193;
        dut.frontend.instruction_memory.memory[1] = 32'h00100073;
        dut.frontend.instruction_memory.memory[2] = 32'h00900213;

        reset = 0;
        #1;

        if (current_pc !== 0 || halted !== 0) begin
            $display("FAIL: Initial state");
            errors = errors + 1;
        end else $display("PASS: Initial state");

        // Execute ADDI.
        @(posedge clk);
        #1;

        if (current_pc !== 4) begin
            $display("FAIL: PC did not advance to EBREAK");
            errors = errors + 1;
        end else $display("PASS: PC advanced to EBREAK");

        if (dut.core.LANES[0].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 0 x3");
            errors = errors + 1;
        end
        if (dut.core.LANES[1].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 1 x3");
            errors = errors + 1;
        end
        if (dut.core.LANES[2].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 2 x3");
            errors = errors + 1;
        end
        if (dut.core.LANES[3].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 3 x3");
            errors = errors + 1;
        end
        if (dut.core.LANES[4].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 4 x3");
            errors = errors + 1;
        end
        if (dut.core.LANES[5].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 5 x3");
            errors = errors + 1;
        end
        if (dut.core.LANES[6].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 6 x3");
            errors = errors + 1;
        end
        if (dut.core.LANES[7].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 7 x3");
            errors = errors + 1;
        end

        // Execute EBREAK.
        @(posedge clk);
        #1;

        if (halted !== 1) begin
            $display("FAIL: EBREAK did not assert halted");
            errors = errors + 1;
        end else $display("PASS: EBREAK asserted halted");

        if (current_pc !== 4) begin
            $display("FAIL: PC did not hold at EBREAK");
            errors = errors + 1;
        end else $display("PASS: PC held at 0x04");

        // Check that subsequent clocks do not execute ADDI x4.
        repeat (4) begin
            @(posedge clk);
            #1;
        end

        if (current_pc !== 4) begin
            $display("FAIL: PC changed after halt");
            errors = errors + 1;
        end else $display("PASS: PC remains frozen");

        if (thread_mask !== 8'hFF) begin
            $display("FAIL: Thread mask changed");
            errors = errors + 1;
        end else $display("PASS: Thread mask preserved");

        if (dut.core.LANES[0].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 0 x3 changed");
            errors = errors + 1;
        end
        if (dut.core.LANES[0].lane_unit.registers[4] !== 32'd0) begin
            $display("FAIL: Lane 0 executed after EBREAK");
            errors = errors + 1;
        end
        if (dut.core.LANES[1].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 1 x3 changed");
            errors = errors + 1;
        end
        if (dut.core.LANES[1].lane_unit.registers[4] !== 32'd0) begin
            $display("FAIL: Lane 1 executed after EBREAK");
            errors = errors + 1;
        end
        if (dut.core.LANES[2].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 2 x3 changed");
            errors = errors + 1;
        end
        if (dut.core.LANES[2].lane_unit.registers[4] !== 32'd0) begin
            $display("FAIL: Lane 2 executed after EBREAK");
            errors = errors + 1;
        end
        if (dut.core.LANES[3].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 3 x3 changed");
            errors = errors + 1;
        end
        if (dut.core.LANES[3].lane_unit.registers[4] !== 32'd0) begin
            $display("FAIL: Lane 3 executed after EBREAK");
            errors = errors + 1;
        end
        if (dut.core.LANES[4].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 4 x3 changed");
            errors = errors + 1;
        end
        if (dut.core.LANES[4].lane_unit.registers[4] !== 32'd0) begin
            $display("FAIL: Lane 4 executed after EBREAK");
            errors = errors + 1;
        end
        if (dut.core.LANES[5].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 5 x3 changed");
            errors = errors + 1;
        end
        if (dut.core.LANES[5].lane_unit.registers[4] !== 32'd0) begin
            $display("FAIL: Lane 5 executed after EBREAK");
            errors = errors + 1;
        end
        if (dut.core.LANES[6].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 6 x3 changed");
            errors = errors + 1;
        end
        if (dut.core.LANES[6].lane_unit.registers[4] !== 32'd0) begin
            $display("FAIL: Lane 6 executed after EBREAK");
            errors = errors + 1;
        end
        if (dut.core.LANES[7].lane_unit.registers[3] !== 32'd5) begin
            $display("FAIL: Lane 7 x3 changed");
            errors = errors + 1;
        end
        if (dut.core.LANES[7].lane_unit.registers[4] !== 32'd0) begin
            $display("FAIL: Lane 7 executed after EBREAK");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: No instruction executed after EBREAK");

        // Reset must clear halted and restart the PC.
        @(negedge clk);
        reset = 1;
        @(posedge clk);
        #1;

        if (halted !== 0 || current_pc !== 0) begin
            $display("FAIL: Reset did not clear halt state");
            errors = errors + 1;
        end else $display("PASS: Reset clears halted and restarts PC");

        if (errors != 0)
            $fatal(1, "KERNEL HALT TEST FAILED: %0d error(s)", errors);

        $display("");
        $display("ALL KERNEL HALT TESTS PASSED");
        $finish;
    end

endmodule

