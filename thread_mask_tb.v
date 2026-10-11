`timescale 1ns/1ps

module simt_thread_mask_tb;

    reg clk;
    reg reset;

    reg tmc;
    reg [7:0] tmc_mask;

    wire [7:0] thread_mask;

    simt_thread_mask dut (
        .clk(clk),
        .reset(reset),
        .tmc(tmc),
        .tmc_mask(tmc_mask),
        .thread_mask(thread_mask)
    );

    always #5 clk = ~clk;

    integer errors;

    initial begin

        clk = 0;
        reset = 1;

        tmc = 0;
        tmc_mask = 8'b0;

        errors = 0;

        // -------------------------
        // TEST 1: RESET
        // -------------------------

        #12;

        if (thread_mask !== 8'b11111111) begin
            $display(
                "FAIL: Reset mask = %b, expected 11111111",
                thread_mask
            );
            errors = errors + 1;
        end
        else begin
            $display("PASS: Reset mask = 11111111");
        end

        reset = 0;

        // -------------------------
        // TEST 2: TMC
        // Set mask = 10101010
        // -------------------------

        @(negedge clk);

        tmc = 1;
        tmc_mask = 8'b10101010;

        @(posedge clk);
        #1;

        if (thread_mask !== 8'b10101010) begin
            $display(
                "FAIL: TMC mask = %b, expected 10101010",
                thread_mask
            );
            errors = errors + 1;
        end
        else begin
            $display("PASS: TMC changed mask to 10101010");
        end

        // -------------------------
        // TEST 3: TMC disabled
        // Mask should remain unchanged
        // -------------------------

        @(negedge clk);

        tmc = 0;
        tmc_mask = 8'b01010101;

        @(posedge clk);
        #1;

        if (thread_mask !== 8'b10101010) begin
            $display(
                "FAIL: Mask changed without TMC: %b",
                thread_mask
            );
            errors = errors + 1;
        end
        else begin
            $display("PASS: Mask preserved without TMC");
        end

        // -------------------------
        // TEST 4: Second TMC
        // -------------------------

        @(negedge clk);

        tmc = 1;
        tmc_mask = 8'b00001111;

        @(posedge clk);
        #1;

        if (thread_mask !== 8'b00001111) begin
            $display(
                "FAIL: Second TMC mask = %b",
                thread_mask
            );
            errors = errors + 1;
        end
        else begin
            $display("PASS: Second TMC changed mask to 00001111");
        end

        // -------------------------
        // RESULT
        // -------------------------

        $display("");
        $display("========================================");
        $display("       SIMT THREAD MASK TEST");
        $display("========================================");

        if (errors == 0)
            $display("RESULT: THREAD MASK TEST PASSED");
        else begin
            $display("RESULT: THREAD MASK TEST FAILED");
            $display("ERRORS = %0d", errors);
        end

        $display("========================================");

        $finish;

    end

endmodule
