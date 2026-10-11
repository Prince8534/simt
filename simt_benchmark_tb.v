
`timescale 1ns/1ps

module simt_benchmark_tb;

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

    reg [63:0] uniform_cycles, uniform_useful, uniform_masked;
    reg [31:0] uniform_efficiency;

    reg [63:0] divergent_cycles, divergent_useful, divergent_masked;
    reg [31:0] divergent_efficiency;

    reg [63:0] nested_cycles, nested_useful, nested_masked;
    reg [31:0] nested_efficiency;

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

    task reset_device;
        begin
            @(negedge clk);
            reset = 1'b1;
            repeat (2) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
            #1;
        end
    endtask

    task initialize_outer_branch_registers;
        begin
            // Lane 0
            dut.core.LANES[0].lane_unit.registers[1] = 10;
            dut.core.LANES[0].lane_unit.registers[2] = 10;

            // Lane 1
            dut.core.LANES[1].lane_unit.registers[1] = 11;
            dut.core.LANES[1].lane_unit.registers[2] = 11;

            // Lane 2
            dut.core.LANES[2].lane_unit.registers[1] = 12;
            dut.core.LANES[2].lane_unit.registers[2] = 99;

            // Lane 3
            dut.core.LANES[3].lane_unit.registers[1] = 13;
            dut.core.LANES[3].lane_unit.registers[2] = 99;

            // Lane 4
            dut.core.LANES[4].lane_unit.registers[1] = 14;
            dut.core.LANES[4].lane_unit.registers[2] = 14;

            // Lane 5
            dut.core.LANES[5].lane_unit.registers[1] = 15;
            dut.core.LANES[5].lane_unit.registers[2] = 15;

            // Lane 6
            dut.core.LANES[6].lane_unit.registers[1] = 16;
            dut.core.LANES[6].lane_unit.registers[2] = 99;

            // Lane 7
            dut.core.LANES[7].lane_unit.registers[1] = 17;
            dut.core.LANES[7].lane_unit.registers[2] = 99;
        end
    endtask

    task initialize_nested_registers;
        begin
            // Outer branch: lanes 0,1,4,5 take the branch.
            initialize_outer_branch_registers;

            // Inner branch compares x3 and x4.
            // Set x3 equal to x4 only for lanes 0 and 4.
            dut.core.LANES[0].lane_unit.registers[3] = 20;
            dut.core.LANES[0].lane_unit.registers[4] = 20;

            dut.core.LANES[1].lane_unit.registers[3] = 21;
            dut.core.LANES[1].lane_unit.registers[4] = 99;

            dut.core.LANES[2].lane_unit.registers[3] = 22;
            dut.core.LANES[2].lane_unit.registers[4] = 99;

            dut.core.LANES[3].lane_unit.registers[3] = 23;
            dut.core.LANES[3].lane_unit.registers[4] = 99;

            dut.core.LANES[4].lane_unit.registers[3] = 24;
            dut.core.LANES[4].lane_unit.registers[4] = 24;

            dut.core.LANES[5].lane_unit.registers[3] = 25;
            dut.core.LANES[5].lane_unit.registers[4] = 99;

            dut.core.LANES[6].lane_unit.registers[3] = 26;
            dut.core.LANES[6].lane_unit.registers[4] = 99;

            dut.core.LANES[7].lane_unit.registers[3] = 27;
            dut.core.LANES[7].lane_unit.registers[4] = 99;
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        errors = 0;

        uniform_cycles = 0;
        uniform_useful = 0;
        uniform_masked = 0;
        uniform_efficiency = 0;

        divergent_cycles = 0;
        divergent_useful = 0;
        divergent_masked = 0;
        divergent_efficiency = 0;

        nested_cycles = 0;
        nested_useful = 0;
        nested_masked = 0;
        nested_efficiency = 0;

        $display("");
        $display("========================================");
        $display(" SIMT KERNEL BENCHMARK");
        $display("========================================");

        // ====================================================
        // BENCHMARK 1: UNIFORM EXECUTION
        // ====================================================

        $display("");
        $display("BENCHMARK 1: UNIFORM EXECUTION");

        reset_device;

        dut.frontend.instruction_memory.memory[0] = 32'h00508193;
        dut.frontend.instruction_memory.memory[1] = 32'h00508193;
        dut.frontend.instruction_memory.memory[2] = 32'h00508193;
        dut.frontend.instruction_memory.memory[3] = 32'h00508193;

        repeat (4) begin
            @(posedge clk);
            #1;
        end

        uniform_cycles = total_cycles;
        uniform_useful = useful_lane_cycles;
        uniform_masked = masked_lane_cycles;
        uniform_efficiency = efficiency_percent;

        $display("Cycles=%0d Useful=%0d Masked=%0d Efficiency=%0d%%",
                 uniform_cycles, uniform_useful,
                 uniform_masked, uniform_efficiency);

        check(uniform_cycles == 4, "Uniform: 4 sampled cycles");
        check(uniform_useful == 32, "Uniform: 32 useful lane-cycles");
        check(uniform_masked == 0, "Uniform: zero masked lane-cycles");
        check(uniform_efficiency == 100, "Uniform: 100 percent efficiency");

        // ====================================================
        // BENCHMARK 2: DIVERGENT EXECUTION
        // ====================================================

        $display("");
        $display("BENCHMARK 2: DIVERGENT EXECUTION");

        reset_device;

        dut.frontend.instruction_memory.memory[0]  = 32'h00508193;
        dut.frontend.instruction_memory.memory[1]  = 32'h00208E63;
        dut.frontend.instruction_memory.memory[2]  = 32'h0000200B;
        dut.frontend.instruction_memory.memory[8]  = 32'h0000200B;
        dut.frontend.instruction_memory.memory[16] = 32'h00000013;

        initialize_outer_branch_registers;

        repeat (4) begin
            @(posedge clk);
            #1;
        end

        divergent_cycles = total_cycles;
        divergent_useful = useful_lane_cycles;
        divergent_masked = masked_lane_cycles;
        divergent_efficiency = efficiency_percent;

        $display("Cycles=%0d Useful=%0d Masked=%0d Efficiency=%0d%%",
                 divergent_cycles, divergent_useful,
                 divergent_masked, divergent_efficiency);

        check(divergent_cycles == 4, "Divergent: 4 sampled cycles");
        check(divergent_useful == 24, "Divergent: 24 useful lane-cycles");
        check(divergent_masked == 8, "Divergent: 8 masked lane-cycles");
        check(divergent_efficiency == 75, "Divergent: 75 percent efficiency");
        check(thread_mask == 8'hFF, "Divergent: all lanes reconverged");

        // ====================================================
        // BENCHMARK 3: NESTED DIVERGENCE
        // ====================================================

        $display("");
        $display("BENCHMARK 3: NESTED DIVERGENCE");

        reset_device;

        // 0x00: Outer BEQ -> 0x20
        // 0x04: NOP
        // 0x08: NOP
        // 0x0C: Outer JOIN #2
        // 0x20: Inner BEQ -> 0x30
        // 0x24: NOP
        // 0x28: Inner JOIN #2
        // 0x30: Inner JOIN #1
        // 0x34: NOP
        // 0x38: NOP
        // 0x3C: Outer JOIN #1
        // 0x40: NOP

        dut.frontend.instruction_memory.memory[0]  = 32'h02208063;
        dut.frontend.instruction_memory.memory[1]  = 32'h00000013;
        dut.frontend.instruction_memory.memory[2]  = 32'h00000013;
        dut.frontend.instruction_memory.memory[3]  = 32'h0000200B;

        dut.frontend.instruction_memory.memory[8]  = 32'h00418863;
        dut.frontend.instruction_memory.memory[9]  = 32'h00000013;
        dut.frontend.instruction_memory.memory[10] = 32'h0000200B;

        dut.frontend.instruction_memory.memory[12] = 32'h0000200B;
        dut.frontend.instruction_memory.memory[13] = 32'h00000013;
        dut.frontend.instruction_memory.memory[14] = 32'h00000013;
        dut.frontend.instruction_memory.memory[15] = 32'h0000200B;
        dut.frontend.instruction_memory.memory[16] = 32'h00000013;

        initialize_nested_registers;

        repeat (12) begin
            @(posedge clk);
            #1;
        end

        nested_cycles = total_cycles;
        nested_useful = useful_lane_cycles;
        nested_masked = masked_lane_cycles;
        nested_efficiency = efficiency_percent;

        $display("Cycles=%0d Useful=%0d Masked=%0d Efficiency=%0d%%",
                 nested_cycles, nested_useful,
                 nested_masked, nested_efficiency);

        check(nested_cycles == 12, "Nested: 12 sampled cycles");
        check(nested_useful == 50, "Nested: 50 useful lane-cycles");
        check(nested_masked == 46, "Nested: 46 masked lane-cycles");
        check(nested_efficiency == 52, "Nested: 52 percent efficiency");
        check(current_pc == 32'h00000044, "Nested: completed final sampled cycle");
        check(thread_mask == 8'hFF, "Nested: all lanes reconverged");

        // ====================================================
        // SUMMARY
        // ====================================================

        $display("");
        $display("========================================");
        $display(" SIMT BENCHMARK SUMMARY");
        $display("========================================");
        $display("Workload       Cycles  Useful  Masked  Efficiency");
        $display("----------------------------------------");

        $display("Uniform        %0d       %0d      %0d       %0d%%",
                 uniform_cycles, uniform_useful,
                 uniform_masked, uniform_efficiency);

        $display("Divergent      %0d       %0d      %0d        %0d%%",
                 divergent_cycles, divergent_useful,
                 divergent_masked, divergent_efficiency);

        $display("Nested         %0d      %0d     %0d        %0d%%",
                 nested_cycles, nested_useful,
                 nested_masked, nested_efficiency);

        $display("----------------------------------------");

        if (errors == 0)
            $display("ALL SIMT BENCHMARK CHECKS PASSED");
        else
            $display("SIMT BENCHMARK FAILURES: %0d", errors);

        $display("========================================");
        $finish;
    end

endmodule
