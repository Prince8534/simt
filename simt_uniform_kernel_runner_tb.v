`timescale 1ns/1ps

module simt_uniform_kernel_runner_tb;

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
        $display(" ASSEMBLED UNIFORM SIMT KERNEL");
        $display("========================================");

        $readmemh(
            "simt_uniform_kernel.hex",
            dut.frontend.instruction_memory.memory
        );

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Initialize lane registers after reset.
        dut.core.LANES[0].lane_unit.registers[1] = 10;
        dut.core.LANES[1].lane_unit.registers[1] = 20;
        dut.core.LANES[2].lane_unit.registers[1] = 30;
        dut.core.LANES[3].lane_unit.registers[1] = 40;
        dut.core.LANES[4].lane_unit.registers[1] = 50;
        dut.core.LANES[5].lane_unit.registers[1] = 60;
        dut.core.LANES[6].lane_unit.registers[1] = 70;
        dut.core.LANES[7].lane_unit.registers[1] = 80;

        #1;

        check(
            dut.frontend.instruction_memory.memory[0] === 32'h00508193,
            "ADDI x3 loaded from HEX"
        );
        check(
            dut.frontend.instruction_memory.memory[1] === 32'h00708213,
            "ADDI x4 loaded from HEX"
        );
        check(
            dut.frontend.instruction_memory.memory[2] === 32'h00908293,
            "ADDI x5 loaded from HEX"
        );

        repeat (4) begin
            @(posedge clk);
            #1;
        end

        $display("");
        $display("UNIFORM KERNEL RESULTS");
        $display("----------------------");
        $display("Final PC             : 0x%08h", current_pc);
        $display("Thread mask          : %08b", thread_mask);
        $display("Sampled cycles       : %0d", total_cycles);
        $display("Useful lane-cycles   : %0d", useful_lane_cycles);
        $display("Masked lane-cycles   : %0d", masked_lane_cycles);
        $display("Lane efficiency      : %0d%%", efficiency_percent);

        check(current_pc == 32'h00000010, "Reached PC 0x10");
        check(thread_mask == 8'hFF, "All eight lanes active");
        check(total_cycles == 4, "Four sampled cycles");
        check(useful_lane_cycles == 32, "32 useful lane-cycles");
        check(masked_lane_cycles == 0, "Zero masked lane-cycles");
        check(efficiency_percent == 100, "100 percent efficiency");

        check(dut.core.LANES[0].lane_unit.registers[3] == 15, "Lane 0 x3 correct");
        check(dut.core.LANES[1].lane_unit.registers[3] == 25, "Lane 1 x3 correct");
        check(dut.core.LANES[2].lane_unit.registers[3] == 35, "Lane 2 x3 correct");
        check(dut.core.LANES[3].lane_unit.registers[3] == 45, "Lane 3 x3 correct");
        check(dut.core.LANES[4].lane_unit.registers[3] == 55, "Lane 4 x3 correct");
        check(dut.core.LANES[5].lane_unit.registers[3] == 65, "Lane 5 x3 correct");
        check(dut.core.LANES[6].lane_unit.registers[3] == 75, "Lane 6 x3 correct");
        check(dut.core.LANES[7].lane_unit.registers[3] == 85, "Lane 7 x3 correct");

        check(dut.core.LANES[0].lane_unit.registers[4] == 17, "Lane 0 x4 correct");
        check(dut.core.LANES[1].lane_unit.registers[4] == 27, "Lane 1 x4 correct");
        check(dut.core.LANES[2].lane_unit.registers[4] == 37, "Lane 2 x4 correct");
        check(dut.core.LANES[3].lane_unit.registers[4] == 47, "Lane 3 x4 correct");
        check(dut.core.LANES[4].lane_unit.registers[4] == 57, "Lane 4 x4 correct");
        check(dut.core.LANES[5].lane_unit.registers[4] == 67, "Lane 5 x4 correct");
        check(dut.core.LANES[6].lane_unit.registers[4] == 77, "Lane 6 x4 correct");
        check(dut.core.LANES[7].lane_unit.registers[4] == 87, "Lane 7 x4 correct");

        check(dut.core.LANES[0].lane_unit.registers[5] == 19, "Lane 0 x5 correct");
        check(dut.core.LANES[1].lane_unit.registers[5] == 29, "Lane 1 x5 correct");
        check(dut.core.LANES[2].lane_unit.registers[5] == 39, "Lane 2 x5 correct");
        check(dut.core.LANES[3].lane_unit.registers[5] == 49, "Lane 3 x5 correct");
        check(dut.core.LANES[4].lane_unit.registers[5] == 59, "Lane 4 x5 correct");
        check(dut.core.LANES[5].lane_unit.registers[5] == 69, "Lane 5 x5 correct");
        check(dut.core.LANES[6].lane_unit.registers[5] == 79, "Lane 6 x5 correct");
        check(dut.core.LANES[7].lane_unit.registers[5] == 89, "Lane 7 x5 correct");

        $display("");
        if (errors == 0)
            $display("ALL ASSEMBLED UNIFORM KERNEL CHECKS PASSED");
        else
            $display("UNIFORM KERNEL FAILURES: %0d", errors);

        $display("========================================");
        $finish;
    end

endmodule
