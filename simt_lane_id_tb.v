`timescale 1ns/1ps

module simt_lane_id_tb;

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
        clk = 1'b0;
        reset = 1'b1;
        errors = 0;

        // laneid x5 = CUSTOM-0, funct3=011, rd=x5, rs1=rs2=0.
        dut.frontend.instruction_memory.memory[0] = 32'h0000328B;

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        #1;
        check(instruction == 32'h0000328B,
              "LANEID instruction fetched");
        check(dut.lane_id_instr === 1'b1,
              "Decoder recognizes LANEID");
        check(dut.illegal === 1'b0,
              "LANEID is not illegal");
        check(thread_mask == 8'hFF,
              "All lanes active before execution");

        @(posedge clk);
        #1;

        check(current_pc == 32'h00000004,
              "PC advances after LANEID");
        check(!halted && !illegal_instruction,
              "LANEID does not halt the core");

        check(dut.core.LANES[0].lane_unit.registers[5] == 32'd0,
              "Lane 0 writes ID 0");
        check(dut.core.LANES[1].lane_unit.registers[5] == 32'd1,
              "Lane 1 writes ID 1");
        check(dut.core.LANES[2].lane_unit.registers[5] == 32'd2,
              "Lane 2 writes ID 2");
        check(dut.core.LANES[3].lane_unit.registers[5] == 32'd3,
              "Lane 3 writes ID 3");
        check(dut.core.LANES[4].lane_unit.registers[5] == 32'd4,
              "Lane 4 writes ID 4");
        check(dut.core.LANES[5].lane_unit.registers[5] == 32'd5,
              "Lane 5 writes ID 5");
        check(dut.core.LANES[6].lane_unit.registers[5] == 32'd6,
              "Lane 6 writes ID 6");
        check(dut.core.LANES[7].lane_unit.registers[5] == 32'd7,
              "Lane 7 writes ID 7");

        // Reset, then verify reserved source fields make LANEID illegal.
        @(negedge clk);
        reset = 1'b1;
        dut.frontend.instruction_memory.memory[0] = 32'h0000B28B;
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        @(posedge clk);
        #1;
        check(illegal_instruction === 1'b1,
              "Nonzero reserved rs1 makes LANEID illegal");
        check(halted === 1'b1,
              "Malformed LANEID halts the core");

        if (errors == 0)
            $display("ALL LANE ID TESTS PASSED");
        else
            $display("LANE ID TEST FAILURES: %0d", errors);

        $finish;
    end

endmodule
