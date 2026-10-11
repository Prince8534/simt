
`timescale 1ns/1ps

module simt_metrics_integration_tb;

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

        $display("========================================");
        $display(" SIMT METRICS INTEGRATION TEST");
        $display("========================================");

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Same program as the existing integration regression.
        dut.frontend.instruction_memory.memory[0]  = 32'h00508193;
        dut.frontend.instruction_memory.memory[1]  = 32'h00208E63;
        dut.frontend.instruction_memory.memory[2]  = 32'h0000200B;
        dut.frontend.instruction_memory.memory[8]  = 32'h0000200B;
        dut.frontend.instruction_memory.memory[16] = 32'h00000013;

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

        // ADDI, BEQ, JOIN #1, JOIN #2.
        repeat (4) begin
            @(posedge clk);
            #1;
        end

        $display("");
        $display("METRICS SNAPSHOT");
        $display("-----------------");
        $display("Total sampled cycles : %0d", total_cycles);
        $display("Useful lane-cycles   : %0d", useful_lane_cycles);
        $display("Masked lane-cycles   : %0d", masked_lane_cycles);
        $display("Lane efficiency      : %0d%%", efficiency_percent);
        $display("Final PC             : 0x%08h", current_pc);
        $display("Final thread mask    : %08b", thread_mask);

        check(total_cycles == 4,
              "Four execution clocks counted");
        check(useful_lane_cycles == 24,
              "Useful lane-cycles counted");
        check(masked_lane_cycles == 8,
              "Masked lane-cycles counted");
        check(efficiency_percent == 75,
              "Lane efficiency is 75 percent");
        check(current_pc == 32'h00000040,
              "Program reached reconvergence PC");
        check(thread_mask == 8'hFF,
              "All lanes restored after reconvergence");

        check(
            dut.core.LANES[0].lane_unit.registers[3] == 15 &&
            dut.core.LANES[7].lane_unit.registers[3] == 85,
            "Lane-local ADDI results preserved"
        );

        $display("");
        if (errors == 0)
            $display("ALL METRICS INTEGRATION CHECKS PASSED");
        else
            $display("METRICS INTEGRATION FAILURES: %0d", errors);

        $finish;
    end

endmodule
