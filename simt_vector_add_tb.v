`timescale 1ns/1ps

module simt_vector_add_tb;

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
    wire halted;
    wire illegal_instruction;

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
        .efficiency_percent(efficiency_percent),
        .halted(halted),
        .illegal_instruction(illegal_instruction)
    );

    always #5 clk = ~clk;

    task check;
        input condition;
        input [8*120-1:0] message;
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
        clk = 1'b0;
        reset = 1'b1;
        errors = 0;

        $readmemh("simt_vector_add.hex",
                  dut.frontend.instruction_memory.memory);

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        #1;
        check(current_pc == 32'h00000000,
              "Kernel starts at PC 0");
        check(instruction == 32'h0000328B,
              "LANEID instruction fetched from assembled kernel");
        check(thread_mask == 8'hFF,
              "All eight lanes active at kernel start");

        // Execute LANEID: x5 = lane index.
        @(posedge clk);
        #1;
        check(current_pc == 32'h00000004,
              "PC advances after LANEID");
        check(dut.core.LANES[0].lane_unit.registers[5] == 0 &&
              dut.core.LANES[1].lane_unit.registers[5] == 1 &&
              dut.core.LANES[2].lane_unit.registers[5] == 2 &&
              dut.core.LANES[3].lane_unit.registers[5] == 3 &&
              dut.core.LANES[4].lane_unit.registers[5] == 4 &&
              dut.core.LANES[5].lane_unit.registers[5] == 5 &&
              dut.core.LANES[6].lane_unit.registers[5] == 6 &&
              dut.core.LANES[7].lane_unit.registers[5] == 7,
              "Each lane receives its unique lane ID");

        // Execute ADDI x6, x5, 1: A[i] = i + 1.
        @(posedge clk);
        #1;
        check(current_pc == 32'h00000008,
              "PC advances after first vector initialization");
        check(dut.core.LANES[0].lane_unit.registers[6] == 1 &&
              dut.core.LANES[1].lane_unit.registers[6] == 2 &&
              dut.core.LANES[2].lane_unit.registers[6] == 3 &&
              dut.core.LANES[3].lane_unit.registers[6] == 4 &&
              dut.core.LANES[4].lane_unit.registers[6] == 5 &&
              dut.core.LANES[5].lane_unit.registers[6] == 6 &&
              dut.core.LANES[6].lane_unit.registers[6] == 7 &&
              dut.core.LANES[7].lane_unit.registers[6] == 8,
              "Vector A values are correct in all lanes");

        // Execute ADDI x7, x5, 11: B[i] = i + 11.
        @(posedge clk);
        #1;
        check(current_pc == 32'h0000000C,
              "PC advances after second vector initialization");
        check(dut.core.LANES[0].lane_unit.registers[7] == 11 &&
              dut.core.LANES[1].lane_unit.registers[7] == 12 &&
              dut.core.LANES[2].lane_unit.registers[7] == 13 &&
              dut.core.LANES[3].lane_unit.registers[7] == 14 &&
              dut.core.LANES[4].lane_unit.registers[7] == 15 &&
              dut.core.LANES[5].lane_unit.registers[7] == 16 &&
              dut.core.LANES[6].lane_unit.registers[7] == 17 &&
              dut.core.LANES[7].lane_unit.registers[7] == 18,
              "Vector B values are correct in all lanes");

        // Execute ADD x8, x6, x7: C[i] = A[i] + B[i].
        @(posedge clk);
        #1;
        check(current_pc == 32'h00000010,
              "PC advances after vector addition");
        check(dut.core.LANES[0].lane_unit.registers[8] == 12 &&
              dut.core.LANES[1].lane_unit.registers[8] == 14 &&
              dut.core.LANES[2].lane_unit.registers[8] == 16 &&
              dut.core.LANES[3].lane_unit.registers[8] == 18 &&
              dut.core.LANES[4].lane_unit.registers[8] == 20 &&
              dut.core.LANES[5].lane_unit.registers[8] == 22 &&
              dut.core.LANES[6].lane_unit.registers[8] == 24 &&
              dut.core.LANES[7].lane_unit.registers[8] == 26,
              "Vector C equals A plus B in all eight lanes");

        // EBREAK terminates the kernel after the result is committed.
        @(posedge clk);
        #1;
        check(halted === 1'b1,
              "EBREAK halts the vector-add kernel");
        check(illegal_instruction === 1'b0,
              "Vector-add kernel has no illegal instruction");
        check(current_pc == 32'h00000010,
              "PC remains on the EBREAK instruction");
        check(thread_mask == 8'hFF,
              "All lanes remain active through kernel completion");

        check(total_cycles == 64'd5,
              "Five instruction cycles sampled");
        check(useful_lane_cycles == 64'd40,
              "Forty useful lane-cycles counted");
        check(masked_lane_cycles == 64'd0,
              "No masked lane-cycles");
        check(efficiency_percent == 32'd100,
              "Vector-add lane efficiency is 100 percent");

        // Emit the same metric summary format used by the other kernel tests.
        $display("Sampled cycles       : %0d", total_cycles);
        $display("Useful lane-cycles   : %0d", useful_lane_cycles);
        $display("Masked lane-cycles   : %0d", masked_lane_cycles);
        $display("Lane efficiency      : %0d%%", efficiency_percent);

        if (errors == 0)
            $display("ALL VECTOR ADD TESTS PASSED");
        else
            $display("VECTOR ADD TEST FAILURES: %0d", errors);

        $finish;
    end

endmodule
