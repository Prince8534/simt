
`timescale 1ns/1ps

module simt_uniform_branch_tb;

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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check;
        input condition;
        input [8*100-1:0] description;
        begin
            if (condition) begin
                $display("[PASS] %0s", description);
            end
            else begin
                $display("[FAIL] %0s", description);
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

    task reset_system;
        begin
            @(negedge clk);
            reset = 1'b1;

            repeat (2) advance_cycle;

            @(negedge clk);
            reset = 1'b0;

            #1;
        end
    endtask

    task set_outer_uniform_taken;
        begin
            dut.core.LANES[0].lane_unit.registers[1] = 10;
            dut.core.LANES[1].lane_unit.registers[1] = 10;
            dut.core.LANES[2].lane_unit.registers[1] = 10;
            dut.core.LANES[3].lane_unit.registers[1] = 10;
            dut.core.LANES[4].lane_unit.registers[1] = 10;
            dut.core.LANES[5].lane_unit.registers[1] = 10;
            dut.core.LANES[6].lane_unit.registers[1] = 10;
            dut.core.LANES[7].lane_unit.registers[1] = 10;

            dut.core.LANES[0].lane_unit.registers[2] = 10;
            dut.core.LANES[1].lane_unit.registers[2] = 10;
            dut.core.LANES[2].lane_unit.registers[2] = 10;
            dut.core.LANES[3].lane_unit.registers[2] = 10;
            dut.core.LANES[4].lane_unit.registers[2] = 10;
            dut.core.LANES[5].lane_unit.registers[2] = 10;
            dut.core.LANES[6].lane_unit.registers[2] = 10;
            dut.core.LANES[7].lane_unit.registers[2] = 10;
        end
    endtask

    task set_outer_uniform_not_taken;
        begin
            dut.core.LANES[0].lane_unit.registers[1] = 10;
            dut.core.LANES[1].lane_unit.registers[1] = 10;
            dut.core.LANES[2].lane_unit.registers[1] = 10;
            dut.core.LANES[3].lane_unit.registers[1] = 10;
            dut.core.LANES[4].lane_unit.registers[1] = 10;
            dut.core.LANES[5].lane_unit.registers[1] = 10;
            dut.core.LANES[6].lane_unit.registers[1] = 10;
            dut.core.LANES[7].lane_unit.registers[1] = 10;

            dut.core.LANES[0].lane_unit.registers[2] = 20;
            dut.core.LANES[1].lane_unit.registers[2] = 20;
            dut.core.LANES[2].lane_unit.registers[2] = 20;
            dut.core.LANES[3].lane_unit.registers[2] = 20;
            dut.core.LANES[4].lane_unit.registers[2] = 20;
            dut.core.LANES[5].lane_unit.registers[2] = 20;
            dut.core.LANES[6].lane_unit.registers[2] = 20;
            dut.core.LANES[7].lane_unit.registers[2] = 20;
        end
    endtask

    task set_outer_divergent_inner_uniform;
        begin
            // Outer branch: lanes 0, 1, 4, 5 take the branch.
            dut.core.LANES[0].lane_unit.registers[1] = 10;
            dut.core.LANES[1].lane_unit.registers[1] = 10;
            dut.core.LANES[2].lane_unit.registers[1] = 10;
            dut.core.LANES[3].lane_unit.registers[1] = 10;
            dut.core.LANES[4].lane_unit.registers[1] = 10;
            dut.core.LANES[5].lane_unit.registers[1] = 10;
            dut.core.LANES[6].lane_unit.registers[1] = 10;
            dut.core.LANES[7].lane_unit.registers[1] = 10;

            dut.core.LANES[0].lane_unit.registers[2] = 10;
            dut.core.LANES[1].lane_unit.registers[2] = 10;
            dut.core.LANES[2].lane_unit.registers[2] = 20;
            dut.core.LANES[3].lane_unit.registers[2] = 20;
            dut.core.LANES[4].lane_unit.registers[2] = 10;
            dut.core.LANES[5].lane_unit.registers[2] = 10;
            dut.core.LANES[6].lane_unit.registers[2] = 20;
            dut.core.LANES[7].lane_unit.registers[2] = 20;

            // Inner branch: all lanes have equal x3 and x4.
            // It is therefore uniform among active lanes.
            dut.core.LANES[0].lane_unit.registers[3] = 30;
            dut.core.LANES[1].lane_unit.registers[3] = 30;
            dut.core.LANES[2].lane_unit.registers[3] = 30;
            dut.core.LANES[3].lane_unit.registers[3] = 30;
            dut.core.LANES[4].lane_unit.registers[3] = 30;
            dut.core.LANES[5].lane_unit.registers[3] = 30;
            dut.core.LANES[6].lane_unit.registers[3] = 30;
            dut.core.LANES[7].lane_unit.registers[3] = 30;

            dut.core.LANES[0].lane_unit.registers[4] = 30;
            dut.core.LANES[1].lane_unit.registers[4] = 30;
            dut.core.LANES[2].lane_unit.registers[4] = 30;
            dut.core.LANES[3].lane_unit.registers[4] = 30;
            dut.core.LANES[4].lane_unit.registers[4] = 30;
            dut.core.LANES[5].lane_unit.registers[4] = 30;
            dut.core.LANES[6].lane_unit.registers[4] = 30;
            dut.core.LANES[7].lane_unit.registers[4] = 30;
        end
    endtask

    initial begin
        errors = 0;
        reset = 1'b1;

        // Use the compiler-generated nested-kernel instructions
        // and its matching IPDOM/JOIN metadata.
        $readmemh(
            "simt_nested_kernel.hex",
            dut.frontend.instruction_memory.memory
        );

        // ====================================================
        // TEST 1: UNIFORM BRANCH TAKEN
        // ====================================================

        $display("");
        $display("========================================");
        $display("TEST 1: UNIFORM BRANCH TAKEN");
        $display("========================================");

        reset_system;
        set_outer_uniform_taken;

        #1;

        check(current_pc == 32'h00000000,
              "Execution starts at PC 0");

        check(branch_instr,
              "Instruction at PC 0 is a branch");

        check(predicate_mask == 8'hFF,
              "All eight lanes satisfy the branch");

        check(dut.branch_taken && !dut.cfg_split,
              "Branch is uniform and taken");

        check(!stack_push,
              "Uniform branch does not push stack");

        advance_cycle;

        check(current_pc == 32'h00000020,
              "Uniform taken branch jumps to target 0x20");

        check(dut.divergence_controller.ipdom.stack_pointer == 0,
              "Stack remains empty after uniform taken branch");

        // ====================================================
        // TEST 2: UNIFORM BRANCH NOT TAKEN
        // ====================================================

        $display("");
        $display("========================================");
        $display("TEST 2: UNIFORM BRANCH NOT TAKEN");
        $display("========================================");

        reset_system;
        set_outer_uniform_not_taken;

        #1;

        check(current_pc == 32'h00000000,
              "Execution starts at PC 0");

        check(predicate_mask == 8'h00,
              "No lane satisfies the branch");

        check(dut.branch_fallthrough && !dut.cfg_split,
              "Branch is uniform and not taken");

        check(!stack_push,
              "Uniform not-taken branch does not push stack");

        advance_cycle;

        check(current_pc == 32'h00000004,
              "Uniform not-taken branch continues to PC 0x04");

        check(dut.divergence_controller.ipdom.stack_pointer == 0,
              "Stack remains empty after uniform not-taken branch");

        // ====================================================
        // TEST 3: UNIFORM INNER BRANCH INSIDE DIVERGENCE
        // ====================================================

        $display("");
        $display("========================================");
        $display("TEST 3: UNIFORM INNER BRANCH");
        $display("INSIDE OUTER DIVERGENCE");
        $display("========================================");

        reset_system;
        set_outer_divergent_inner_uniform;

        #1;

        check(predicate_mask == 8'b00110011,
              "Outer branch selects lanes 0, 1, 4, 5");

        check(divergence && split && stack_push,
              "Outer branch activates divergent split");

        advance_cycle;

        check(current_pc == 32'h00000020,
              "Outer taken path begins at PC 0x20");

        check(thread_mask == 8'b00110011,
              "Only outer taken lanes are active");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Outer divergence creates one stack entry");

        // Inner branch at PC 0x20.
        #1;

        check(current_pc == 32'h00000020,
              "Execution reaches inner branch at PC 0x20");

        check(predicate_mask == 8'hFF,
              "Inner branch predicate is uniform");

        check(dut.branch_taken && !dut.cfg_split,
              "Inner branch is uniform and taken");

        check(!stack_push,
              "Uniform inner branch does not push another entry");

        advance_cycle;

        check(current_pc == 32'h00000030,
              "Uniform inner branch jumps to PC 0x30");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Stack still contains only the outer entry");

        // JOIN at PC 0x30 belongs to inner branch PC 0x20.
        #1;

        check(instruction == 32'h0000200B,
              "Instruction at PC 0x30 is the inner JOIN");

        check(dut.join_metadata_found,
              "Inner JOIN ownership metadata is available");

        check(dut.join_owner_branch_pc == 32'h00000020,
              "Inner JOIN identifies branch PC 0x20");

        check(dut.divergence_controller.ipdom.top_branch_pc
                  == 32'h00000000,
              "Top stack entry belongs to outer branch PC 0");

        check(!dut.divergence_controller.join_matches_top,
              "Inner JOIN does not match outer stack entry");

        check(!stack_pop,
              "Inner JOIN must not pop outer stack entry");

        check(dut.next_pc == 32'h00000034,
              "Inner JOIN routes execution to its reconvergence PC");

        check(thread_mask == 8'b00110011,
              "Inner JOIN preserves the active thread mask");

        advance_cycle;

        check(current_pc == 32'h00000034,
              "Execution reaches inner reconvergence PC 0x34");

        check(thread_mask == 8'b00110011,
              "Active mask remains unchanged after inner JOIN");

        check(dut.divergence_controller.ipdom.stack_pointer == 1,
              "Outer divergence entry remains on stack");

        check(dut.divergence_controller.ipdom.top_branch_pc
                  == 32'h00000000,
              "Remaining stack entry still belongs to outer branch");

        // ====================================================
        // FINAL RESULT
        // ====================================================

        $display("");
        $display("========================================");

        if (errors == 0) begin
            $display("ALL UNIFORM BRANCH JOIN TESTS PASSED");
        end
        else begin
            $display("UNIFORM BRANCH JOIN TESTS FAILED");
            $display("Total errors: %0d", errors);
            $fatal(1, "Uniform branch regression failed");
        end

        $display("========================================");
        $finish;
    end

endmodule
