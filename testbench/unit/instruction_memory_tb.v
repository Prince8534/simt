`timescale 1ns/1ps

module simt_instruction_memory_tb;

    reg [31:0] address;
    wire [31:0] instruction;

    simt_instruction_memory dut (
        .address(address),
        .instruction(instruction)
    );

    initial begin

        // Put known instructions into memory
        dut.memory[0] = 32'h12345678;
        dut.memory[1] = 32'hABCDEF01;
        dut.memory[2] = 32'hDEADBEEF;

        // =================================================
        // Address 0
        // =================================================

        address = 32'h00000000;

        #1;

        $display("");
        $display("Address      = %h", address);
        $display("Instruction  = %h", instruction);

        if (instruction !== 32'h12345678)
            $display("FAIL: address 0");
        else
            $display("PASS: address 0");

        // =================================================
        // Address 4
        // =================================================

        address = 32'h00000004;

        #1;

        $display("");
        $display("Address      = %h", address);
        $display("Instruction  = %h", instruction);

        if (instruction !== 32'hABCDEF01)
            $display("FAIL: address 4");
        else
            $display("PASS: address 4");

        // =================================================
        // Address 8
        // =================================================

        address = 32'h00000008;

        #1;

        $display("");
        $display("Address      = %h", address);
        $display("Instruction  = %h", instruction);

        if (instruction !== 32'hDEADBEEF)
            $display("FAIL: address 8");
        else
            $display("PASS: address 8");

        // =================================================
        // Default NOP
        // =================================================

        address = 32'h0000000C;

        #1;

        $display("");
        $display("Address      = %h", address);
        $display("Instruction  = %h", instruction);

        if (instruction !== 32'h00000013)
            $display("FAIL: default NOP");
        else
            $display("PASS: default NOP");

        // =================================================
        // COMPLETE
        // =================================================

        $display("");
        $display("====================================");
        $display(" INSTRUCTION MEMORY TEST COMPLETE   ");
        $display("====================================");

        $finish;

    end

endmodule
