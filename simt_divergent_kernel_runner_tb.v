`timescale 1ns/1ps

module simt_divergent_kernel_runner_tb;

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

    task advance_cycle;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        errors = 0;

        $display("");
        $display("========================================");
        $display(" ASSEMBLED DIVERGENT SIMT KERNEL");
        $display("========================================");

        $readmemh(
            "simt_divergent_kernel.hex",
            dut.frontend.instruction_memory.memory
        );

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Initialize source operands for all eight lanes.
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

        // Inactive-lane sentinels.
        dut.core.LANES[0].lane_unit.registers[4] = 104;
        dut.core.LANES[1].lane_unit.registers[4] = 204;
        dut.core.LANES[4].lane_unit.registers[4] = 504;
        dut.core.LANES[5].lane_unit.registers[4] = 604;

        dut.core.LANES[2].lane_unit.registers[5] = 302;
        dut.core.LANES[3].lane_unit.registers[5] = 403;
        dut.core.LANES[6].lane_unit.registers[5] = 706;
        dut.core.LANES[7].lane_unit.registers[5] = 807;

        #1;

        $display("");
        $display("1. VERIFY ASSEMBLED INSTRUCTIONS");

        check(dut.frontend.instruction_memory.memory[0] === 32'h00508193,
              "ADDI x3 loaded at PC 0x00");
        check(dut.frontend.instruction_memory.memory[1] === 32'h00208663,
              "BEQ loaded at PC 0x04");
        check(dut.frontend.instruction_memory.memory[2] === 32'h00708213,
              "Deferred ADDI loaded at PC 0x08");
        check(dut.frontend.instruction_memory.memory[3] === 32'h0000200B,
              "Deferred JOIN loaded at PC 0x0C");
        check(dut.frontend.instruction_memory.memory[4] === 32'h00908293,
              "Taken ADDI loaded at PC 0x10");
        check(dut.frontend.instruction_memory.memory[5] === 32'h0000200B,
              "Taken JOIN loaded at PC 0x14");

        $display("");
        $display("2. OUTER DIVERGENT BRANCH");

        advance_cycle;

        check(current_pc == 32'h00000004, "Reached branch PC 0x04");
        check(branch_instr, "BEQ decoded");
        check(predicate_mask == 8'b00110011, "Predicate mask is 00110011");
        check(divergence, "Divergence detected");
        check(split, "Split asserted");
        check(stack_push, "IPDOM stack push asserted");
        check(dut.reconvergence_pc == 32'h00000018,
              "Generated IPDOM reconvergence PC is 0x18");

        advance_cycle;

        check(current_pc == 32'h00000010, "Taken path reached at PC 0x10");
        check(thread_mask == 8'b00110011, "Taken mask applied");

        $display("");
        $display("3. TAKEN PATH AND FIRST JOIN");

        advance_cycle;

        check(current_pc == 32'h00000014, "Reached taken JOIN at PC 0x14");
        check(dut.join_instr, "Taken-path JOIN decoded");

        // Check first JOIN behavior before its clock edge.
        check(!stack_pop, "First JOIN does not pop IPDOM stack");

        advance_cycle;

        check(current_pc == 32'h00000008, "Deferred path selected at PC 0x08");
        check(thread_mask == 8'b11001100, "Deferred mask applied");

        $display("");
        $display("4. DEFERRED PATH AND RECONVERGENCE");

        advance_cycle;

        check(current_pc == 32'h0000000C, "Reached deferred JOIN at PC 0x0C");
        check(dut.join_instr, "Deferred-path JOIN decoded");

        // IMPORTANT: inspect the combinational pop while JOIN is decoded,
        // before the rising edge changes the PC and stack state.
        #1;
        check(stack_pop, "Final JOIN asserts IPDOM stack pop");

        // Now execute the deferred JOIN.
        advance_cycle;

        check(current_pc == 32'h00000018, "Reconverged at PC 0x18");
        check(thread_mask == 8'hFF, "All lanes restored");

        // After the edge, the stack should be empty and pop should deassert.
        check(!stack_pop, "Stack pop deasserts after JOIN execution");

        $display("");
        $display("5. REGISTER MASKING CHECKS");

        check(dut.core.LANES[0].lane_unit.registers[3] == 15, "Lane 0 x3 correct");
        check(dut.core.LANES[1].lane_unit.registers[3] == 25, "Lane 1 x3 correct");
        check(dut.core.LANES[2].lane_unit.registers[3] == 35, "Lane 2 x3 correct");
        check(dut.core.LANES[3].lane_unit.registers[3] == 45, "Lane 3 x3 correct");
        check(dut.core.LANES[4].lane_unit.registers[3] == 55, "Lane 4 x3 correct");
        check(dut.core.LANES[5].lane_unit.registers[3] == 65, "Lane 5 x3 correct");
        check(dut.core.LANES[6].lane_unit.registers[3] == 75, "Lane 6 x3 correct");
        check(dut.core.LANES[7].lane_unit.registers[3] == 85, "Lane 7 x3 correct");

        check(dut.core.LANES[2].lane_unit.registers[4] == 37, "Lane 2 deferred x4 correct");
        check(dut.core.LANES[3].lane_unit.registers[4] == 47, "Lane 3 deferred x4 correct");
        check(dut.core.LANES[6].lane_unit.registers[4] == 77, "Lane 6 deferred x4 correct");
        check(dut.core.LANES[7].lane_unit.registers[4] == 87, "Lane 7 deferred x4 correct");

        check(dut.core.LANES[0].lane_unit.registers[4] == 104, "Lane 0 masked x4 preserved");
        check(dut.core.LANES[1].lane_unit.registers[4] == 204, "Lane 1 masked x4 preserved");
        check(dut.core.LANES[4].lane_unit.registers[4] == 504, "Lane 4 masked x4 preserved");
        check(dut.core.LANES[5].lane_unit.registers[4] == 604, "Lane 5 masked x4 preserved");

        check(dut.core.LANES[0].lane_unit.registers[5] == 19, "Lane 0 taken x5 correct");
        check(dut.core.LANES[1].lane_unit.registers[5] == 29, "Lane 1 taken x5 correct");
        check(dut.core.LANES[4].lane_unit.registers[5] == 59, "Lane 4 taken x5 correct");
        check(dut.core.LANES[5].lane_unit.registers[5] == 69, "Lane 5 taken x5 correct");

        check(dut.core.LANES[2].lane_unit.registers[5] == 302, "Lane 2 masked x5 preserved");
        check(dut.core.LANES[3].lane_unit.registers[5] == 403, "Lane 3 masked x5 preserved");
        check(dut.core.LANES[6].lane_unit.registers[5] == 706, "Lane 6 masked x5 preserved");
        check(dut.core.LANES[7].lane_unit.registers[5] == 807, "Lane 7 masked x5 preserved");

        $display("");
        $display("DIVERGENT KERNEL METRICS");
        $display("------------------------");
        $display("Final PC             : 0x%08h", current_pc);
        $display("Final thread mask    : %08b", thread_mask);
        $display("Sampled cycles       : %0d", total_cycles);
        $display("Useful lane-cycles   : %0d", useful_lane_cycles);
        $display("Masked lane-cycles   : %0d", masked_lane_cycles);
        $display("Lane efficiency      : %0d%%", efficiency_percent);

        check(total_cycles == 6, "Six sampled cycles");
        check(useful_lane_cycles == 32, "32 useful lane-cycles");
        check(masked_lane_cycles == 16, "16 masked lane-cycles");
        check(efficiency_percent == 66, "66 percent lane efficiency");

        $display("");
        if (errors == 0)
            $display("ALL ASSEMBLED DIVERGENT KERNEL CHECKS PASSED");
        else
            $display("DIVERGENT KERNEL FAILURES: %0d", errors);

        $display("========================================");
        $finish;
    end

endmodule
