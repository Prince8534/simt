
module simt_missing_ipdom_tb;

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

    initial begin
        reset = 1'b1;

        $display("");
        $display("========================================");
        $display(" SIMT MISSING IPDOM METADATA TEST");
        $display("========================================");

        // Hold reset long enough to initialize the PC.
        #12;
        reset = 1'b0;

        // PC 0x00: NOP.
        dut.frontend.instruction_memory.memory[0] =
            32'h00000013;

        // PC 0x04: BEQ x1,x2,+16.
        // This branch PC is deliberately absent from
        // simt_ipdom_lookup.v.
        dut.frontend.instruction_memory.memory[1] =
            32'h00208863;

        // Create divergent BEQ results across the lanes.
        dut.core.LANES[0].lane_unit.registers[1] = 10;
        dut.core.LANES[0].lane_unit.registers[2] = 10;

        dut.core.LANES[1].lane_unit.registers[1] = 20;
        dut.core.LANES[1].lane_unit.registers[2] = 99;

        dut.core.LANES[2].lane_unit.registers[1] = 30;
        dut.core.LANES[2].lane_unit.registers[2] = 30;

        dut.core.LANES[3].lane_unit.registers[1] = 40;
        dut.core.LANES[3].lane_unit.registers[2] = 99;

        dut.core.LANES[4].lane_unit.registers[1] = 50;
        dut.core.LANES[4].lane_unit.registers[2] = 50;

        dut.core.LANES[5].lane_unit.registers[1] = 60;
        dut.core.LANES[5].lane_unit.registers[2] = 99;

        dut.core.LANES[6].lane_unit.registers[1] = 70;
        dut.core.LANES[6].lane_unit.registers[2] = 70;

        dut.core.LANES[7].lane_unit.registers[1] = 80;
        dut.core.LANES[7].lane_unit.registers[2] = 99;

        #1;

        $display("Lookup intentionally has no entry for PC 0x04.");
        $display("Waiting for the missing-metadata assertion.");

        // The assertion in simt_top must terminate simulation
        // when the divergent branch at PC 0x04 is reached.
        repeat (6) begin
            @(posedge clk);
            #1;
        end

        // Reaching this point means the safety check failed.
        $display("");
        $display("FAIL: Missing IPDOM metadata was not detected.");
        $fatal(1, "Negative test failed: expected assertion did not fire");
    end

endmodule
