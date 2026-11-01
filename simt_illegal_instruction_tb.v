`timescale 1ns/1ps

module simt_illegal_instruction_tb;

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
    integer test_count;

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
            if (condition !== 1'b1) begin
                $display("FAIL: %0s", message);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s", message);
            end
        end
    endtask

    task run_illegal_case;
        input [31:0] bad_instruction;
        input [8*100-1:0] case_name;
        reg [7:0] saved_mask;
        begin
            $display("");
            $display("Testing %0s", case_name);

            // Reset the core and install the malformed instruction.
            reset = 1'b1;
            @(posedge clk);
            #1;
            reset = 1'b0;

            dut.frontend.instruction_memory.memory[0] = bad_instruction;
            dut.frontend.instruction_memory.memory[1] = 32'h00900213;
            dut.core.LANES[0].lane_unit.registers[3] = 32'd1234;

            saved_mask = thread_mask;

            // Allow combinational decode to settle, then sample the
            // faulting instruction before its active clock edge.
            #1;
            check(dut.illegal === 1'b1, "Illegal instruction detected");
            check(dut.reg_write === 1'b0, "Illegal register write suppressed");
            check(dut.mem_read === 1'b0, "Illegal memory read suppressed");
            check(dut.mem_write === 1'b0, "Illegal memory write suppressed");
            check(dut.branch === 1'b0, "Illegal branch suppressed");
            check(dut.jump === 1'b0, "Illegal jump suppressed");
            check(dut.jalr === 1'b0, "Illegal JALR suppressed");
            check(dut.tmc === 1'b0, "Illegal TMC suppressed");
            check(dut.split_instr === 1'b0, "Illegal SPLIT suppressed");
            check(dut.join_instr === 1'b0, "Illegal JOIN suppressed");

            @(posedge clk);
            #1;
            check(halted === 1'b1, "Core halted on illegal instruction");
            check(illegal_instruction === 1'b1, "Sticky illegal fault asserted");
            check(current_pc === 32'h00000000, "PC held at faulting instruction");
            check(thread_mask === saved_mask, "Thread mask preserved");
            check(dut.core.LANES[0].lane_unit.registers[3] === 32'd1234,
                  "Lane register unchanged");

            // A later clock must not advance the PC or clear the fault.
            @(posedge clk);
            #1;
            check(current_pc === 32'h00000000, "PC remains frozen after fault");
            check(illegal_instruction === 1'b1, "Illegal fault remains asserted");
            test_count = test_count + 1;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        errors = 0;
        test_count = 0;

        // Keep reset active across a rising edge.
        @(posedge clk);
        #1;
        reset = 1'b0;

        // Malformed R-type: funct7=0000001 for ADD/SUB encoding.
        run_illegal_case(32'h020081B3, "BAD_RTYPE");

        // Malformed LOAD: funct3=011 is not a supported load.
        run_illegal_case(32'h0000B183, "BAD_LOAD");

        // Malformed STORE: funct3=011 is not a supported store.
        run_illegal_case(32'h0030B023, "BAD_STORE");

        // Malformed BRANCH: funct3=010 is reserved.
        run_illegal_case(32'h0020A063, "BAD_BRANCH");

        // Malformed JALR: funct3=001 is invalid.
        run_illegal_case(32'h000090E7, "BAD_JALR");

        // Malformed SYSTEM: funct3=001 is unsupported.
        run_illegal_case(32'h00001073, "BAD_SYSTEM");

        // Malformed CUSTOM-0: funct3=111 is not defined.
        run_illegal_case(32'h0000700B, "BAD_CUSTOM0");

        // SLLI requires funct7=0000000.
        run_illegal_case(32'h02009193, "BAD_SLLI");

        // SRLI/SRAI accepts only funct7=0000000 or 0100000.
        run_illegal_case(32'h4200D193, "BAD_SRLI_SRAI");

        // FENCE requires rd=0, rs1=0, and fm=0000 here.
        run_illegal_case(32'h0000800F, "BAD_FENCE_RS1");
        run_illegal_case(32'h0000008F, "BAD_FENCE_RD");
        run_illegal_case(32'h1000000F, "BAD_FENCE_FM");

        // ECALL and EBREAK require rd=0.
        run_illegal_case(32'h000001F3, "BAD_ECALL_RD");
        run_illegal_case(32'h001001F3, "BAD_EBREAK_RD");

        // Reset must clear both halt and the sticky fault.
        reset = 1'b1;
        @(posedge clk);
        #1;
        check(halted === 1'b0, "reset clears halted");
        check(illegal_instruction === 1'b0, "reset clears illegal fault");
        check(current_pc === 32'h00000000, "reset returns PC to zero");
        check(thread_mask === 8'hFF, "reset restores all active lanes");

        if (errors == 0) begin
            $display("");
            $display("ALL ILLEGAL INSTRUCTION TESTS PASSED (%0d cases)", test_count);
            $finish;
        end
        else begin
            $display("");
            $display("ILLEGAL INSTRUCTION TESTS FAILED: %0d errors", errors);
            $fatal(1);
        end
    end

endmodule
