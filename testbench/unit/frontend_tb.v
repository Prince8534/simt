`timescale 1ns/1ps

module simt_frontend_tb;

    reg        clk;
    reg        reset;

    reg [31:0] next_pc;

    wire [31:0] current_pc;
    wire [31:0] instruction;

    simt_frontend dut (
        .clk(clk),
        .reset(reset),

        .next_pc(next_pc),

        .current_pc(current_pc),
        .instruction(instruction)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 0;
        reset = 1;
        next_pc = 32'h00000000;

        // =================================================
        // Put known instructions in shared memory
        // =================================================

        dut.instruction_memory.memory[0] =
            32'h11111111;

        dut.instruction_memory.memory[1] =
            32'h22222222;

        dut.instruction_memory.memory[2] =
            32'h33333333;

        // =================================================
        // RESET
        // =================================================

        @(posedge clk);
        #1;

        if (current_pc !== 32'h00000000)
            $display("FAIL: frontend PC reset");
        else
            $display("PASS: frontend PC reset");

        reset = 0;

        // =================================================
        // PC = 0x00000000
        // =================================================

        next_pc = 32'h00000000;

        #1;

        if (instruction !== 32'h11111111)
            $display("FAIL: instruction at PC 0");
        else
            $display("PASS: instruction at PC 0");

        // =================================================
        // PC = 0x00000004
        // =================================================

        next_pc = 32'h00000004;

        @(posedge clk);
        #1;

        $display("");
        $display("PC          = %h", current_pc);
        $display("Instruction = %h", instruction);

        if (current_pc !== 32'h00000004)
            $display("FAIL: PC update to 4");
        else
            $display("PASS: PC update to 4");

        if (instruction !== 32'h22222222)
            $display("FAIL: instruction at PC 4");
        else
            $display("PASS: instruction at PC 4");

        // =================================================
        // PC = 0x00000008
        // =================================================

        next_pc = 32'h00000008;

        @(posedge clk);
        #1;

        $display("");
        $display("PC          = %h", current_pc);
        $display("Instruction = %h", instruction);

        if (current_pc !== 32'h00000008)
            $display("FAIL: PC update to 8");
        else
            $display("PASS: PC update to 8");

        if (instruction !== 32'h33333333)
            $display("FAIL: instruction at PC 8");
        else
            $display("PASS: instruction at PC 8");

        // =================================================
        // COMPLETE
        // =================================================

        $display("");
        $display("====================================");
        $display("       SIMT FRONTEND TEST           ");
        $display("====================================");

        $finish;

    end

endmodule
