
`timescale 1ns/1ps

module simt_kernel_runner_tb;

    reg clk;
    reg reset;

    wire [31:0] current_pc;
    wire [31:0] instruction;
    wire [7:0] thread_mask;
    wire [7:0] predicate_mask;
    wire branch_instr;
    wire divergence;
    wire split;
    wire stack_push;
    wire stack_pop;

    wire [63:0] total_cycles;
    wire [63:0] useful_lane_cycles;
    wire [63:0] masked_lane_cycles;
    wire [31:0] efficiency_percent;

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
        .stack_pop(stack_pop),
        .total_cycles(total_cycles),
        .useful_lane_cycles(useful_lane_cycles),
        .masked_lane_cycles(masked_lane_cycles),
        .efficiency_percent(efficiency_percent)
    );

    always #5 clk = ~clk;

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
        clk = 0;
        reset = 1;
        errors = 0;

        $display("");
        $display("========================================");
        $display(" ASSEMBLED SIMT KERNEL RUNNER");
        $display("========================================");

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        $readmemh(
            "simt_kernel.hex",
            dut.frontend.instruction_memory.memory
        );

        // Initialize source registers.
        dut.core.LANES[0].lane_unit.registers[1] = 10;
        dut.core.LANES[0].lane_unit.registers[2] = 10;

        dut.core.LANES[1].lane_unit.registers[1] = 20;
        dut.core.LANES[1].lane_unit.registers[2] = 20;

        dut.core.LANES[2].lane_unit.registers[1] = 30;
        dut.core.LANES[2].lane_unit.registers[2] = 99;

        dut.core.LANES[3].lane_unit.registers[1] = 40;
        dut.core.LANES[3].lane_unit.registers[2] = 99;

        dut.core.LANES[4].lane_unit.registers[1] = 50;
        dut.core.LANES[4].lane_unit.registers[2] = 50;

        dut.core.LANES[5].lane_unit.registers[1] = 60;
        dut.core.LANES[5].lane_unit.registers[2] = 60;

        dut.core.LANES[6].lane_unit.registers[1] = 70;
        dut.core.LANES[6].lane_unit.registers[2] = 99;

        dut.core.LANES[7].lane_unit.registers[1] = 80;
        dut.core.LANES[7].lane_unit.registers[2] = 99;

        // Sentinel values prove masked lanes preserve x5.
        dut.core.LANES[2].lane_unit.registers[5] = 32'd222;
        dut.core.LANES[3].lane_unit.registers[5] = 32'd333;
        dut.core.LANES[6].lane_unit.registers[5] = 32'd666;
        dut.core.LANES[7].lane_unit.registers[5] = 32'd777;

        #1;

        check(
            dut.frontend.instruction_memory.memory[0] === 32'h00508193,
            "HEX instruction 0 loaded"
        );

        check(
            dut.frontend.instruction_memory.memory[1] === 32'h00208663,
            "HEX branch instruction loaded"
        );

        check(
            dut.frontend.instruction_memory.memory[4] === 32'h00908293,
            "HEX taken-path instruction loaded"
        );

        // Execute through reconvergence.
        repeat (6) begin
            @(posedge clk);
            #1;
        end

        $display("");
        $display("RUN SUMMARY");
        $display("-----------");
        $display("PC                 : 0x%08h", current_pc);
        $display("Thread mask        : %08b", thread_mask);
        $display("Sampled cycles     : %0d", total_cycles);
        $display("Useful lane-cycles : %0d", useful_lane_cycles);
        $display("Masked lane-cycles : %0d", masked_lane_cycles);
        $display("Lane efficiency    : %0d%%", efficiency_percent);

        check(current_pc == 32'h00000040,
              "Reached reconvergence PC");

        check(thread_mask == 8'hFF,
              "All lanes restored");

        // All lanes execute the first ADDI.
        check(dut.core.LANES[0].lane_unit.registers[3] == 15,
              "Lane 0 initial ADDI");
        check(dut.core.LANES[7].lane_unit.registers[3] == 85,
              "Lane 7 initial ADDI");

        // Taken path: lanes 0, 1, 4, 5 update x5.
        check(dut.core.LANES[0].lane_unit.registers[5] == 19,
              "Lane 0 taken-path ADDI");
        check(dut.core.LANES[1].lane_unit.registers[5] == 29,
              "Lane 1 taken-path ADDI");
        check(dut.core.LANES[4].lane_unit.registers[5] == 59,
              "Lane 4 taken-path ADDI");
        check(dut.core.LANES[5].lane_unit.registers[5] == 69,
              "Lane 5 taken-path ADDI");

        // Deferred path: lanes 2, 3, 6, 7 update x4.
        check(dut.core.LANES[2].lane_unit.registers[4] == 37,
              "Lane 2 deferred-path ADDI");
        check(dut.core.LANES[3].lane_unit.registers[4] == 47,
              "Lane 3 deferred-path ADDI");
        check(dut.core.LANES[6].lane_unit.registers[4] == 77,
              "Lane 6 deferred-path ADDI");
        check(dut.core.LANES[7].lane_unit.registers[4] == 87,
              "Lane 7 deferred-path ADDI");

        // Deferred lanes must preserve x5 sentinels.
        check(dut.core.LANES[2].lane_unit.registers[5] == 222,
              "Masked lane 2 preserves x5");
        check(dut.core.LANES[3].lane_unit.registers[5] == 333,
              "Masked lane 3 preserves x5");
        check(dut.core.LANES[6].lane_unit.registers[5] == 666,
              "Masked lane 6 preserves x5");
        check(dut.core.LANES[7].lane_unit.registers[5] == 777,
              "Masked lane 7 preserves x5");

        if (errors == 0)
            $display("ALL ASSEMBLED KERNEL CHECKS PASSED");
        else
            $display("ASSEMBLED KERNEL FAILURES: %0d", errors);

        $finish;
    end

endmodule
