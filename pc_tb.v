`timescale 1ns/1ps

module simt_pc_tb;

    reg        clk;
    reg        reset;

    reg [31:0] next_pc;

    wire [31:0] current_pc;

    simt_pc dut (
        .clk(clk),
        .reset(reset),

        .next_pc(next_pc),

        .current_pc(current_pc)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 0;
        reset = 1;
        next_pc = 32'h00000000;

        // =================================================
        // RESET
        // =================================================

        @(posedge clk);
        #1;

        if (current_pc !== 32'h00000000)
            $display("FAIL: PC reset");
        else
            $display("PASS: PC reset");

        reset = 0;

        // =================================================
        // LOAD PC = 0x100
        // =================================================

        next_pc = 32'h00000100;

        @(posedge clk);
        #1;

        if (current_pc !== 32'h00000100)
            $display("FAIL: PC load");
        else
            $display("PASS: PC load");

        // =================================================
        // LOAD PC = 0x200
        // =================================================

        next_pc = 32'h00000200;

        @(posedge clk);
        #1;

        if (current_pc !== 32'h00000200)
            $display("FAIL: PC update");
        else
            $display("PASS: PC update");

        // =================================================
        // LOAD RECONVERGENCE PC
        // =================================================

        next_pc = 32'h00000400;

        @(posedge clk);
        #1;

        if (current_pc !== 32'h00000400)
            $display("FAIL: reconvergence PC");
        else
            $display("PASS: reconvergence PC");

        // =================================================
        // COMPLETE
        // =================================================

        $display("");
        $display("====================================");
        $display("        SIMT PC TEST COMPLETE       ");
        $display("====================================");

        $finish;

    end

endmodule
