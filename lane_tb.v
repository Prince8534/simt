`timescale 1ns/1ps

module simt_lane_tb;

    reg clk;
    reg reset;
    reg thread_enable;

    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;

    reg [3:0] alu_control;
    reg        alu_src_imm;
    reg [31:0] immediate;
    reg        reg_write;

    wire [31:0] result;

    simt_lane dut (
        .clk(clk),
        .reset(reset),
        .thread_enable(thread_enable),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .alu_control(alu_control),
        .alu_src_imm(alu_src_imm),
        .immediate(immediate),
        .reg_write(reg_write),
        .result(result)
    );

    always #5 clk = ~clk;

    integer errors;

    initial begin

        clk = 0;
        reset = 1;
        thread_enable = 0;

        rs1 = 0;
        rs2 = 0;
        rd = 0;

        alu_control = 0;
        alu_src_imm = 0;
        immediate = 0;
        reg_write = 0;

        errors = 0;

        // -------------------------
        // RESET
        // -------------------------

        #12;
        reset = 0;

        // -------------------------
        // TEST 1
        // x1 = 10
        // -------------------------

        @(negedge clk);

        rd = 5'd1;
        immediate = 32'd10;
        alu_src_imm = 1'b1;
        alu_control = 4'b0000;
        reg_write = 1'b1;
        thread_enable = 1'b1;

        @(posedge clk);
        #1;

        // -------------------------
        // TEST 2
        // x2 = x1 + 5
        // -------------------------

        @(negedge clk);

        rs1 = 5'd1;
        rd = 5'd2;
        immediate = 32'd5;
        alu_src_imm = 1'b1;
        alu_control = 4'b0000;

        #1;

        if (result !== 32'd15) begin
            $display("FAIL: x1 + 5 = %0d", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: x1 + 5 = 15");
        end

        @(posedge clk);
        #1;

        // -------------------------
        // TEST 3
        // x3 = x1 + x2
        // -------------------------

        @(negedge clk);

        rs1 = 5'd1;
        rs2 = 5'd2;
        rd = 5'd3;

        alu_src_imm = 1'b0;
        alu_control = 4'b0000;

        #1;

        if (result !== 32'd25) begin
            $display("FAIL: x1 + x2 = %0d", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: x1 + x2 = 25");
        end

        @(posedge clk);
        #1;

        // -------------------------
        // TEST 4
        // Attempt to write x4 while
        // lane is masked
        // -------------------------

        @(negedge clk);

        rd = 5'd4;
        immediate = 32'd100;
        alu_src_imm = 1'b1;
        alu_control = 4'b0000;
        thread_enable = 1'b0;
        reg_write = 1'b1;

        @(posedge clk);
        #1;

        // Read x4
        @(negedge clk);

        rs1 = 5'd4;
        rs2 = 5'd0;
        alu_src_imm = 1'b0;
        alu_control = 4'b0000;
        reg_write = 1'b0;

        #1;

        if (result !== 32'd0) begin
            $display("FAIL: masked lane modified x4");
            errors = errors + 1;
        end
        else begin
            $display("PASS: masked lane prevented x4 write");
        end

        // -------------------------
        // TEST 5
        // x0 must remain zero
        // -------------------------

        @(negedge clk);

        thread_enable = 1'b1;
        rd = 5'd0;
        immediate = 32'hDEADBEEF;
        alu_src_imm = 1'b1;
        alu_control = 4'b0000;
        reg_write = 1'b1;

        @(posedge clk);
        #1;

        @(negedge clk);

        rs1 = 5'd0;
        rs2 = 5'd0;
        alu_src_imm = 1'b0;
        alu_control = 4'b0000;
        reg_write = 1'b0;

        #1;

        if (result !== 32'd0) begin
            $display("FAIL: x0 modified");
            errors = errors + 1;
        end
        else begin
            $display("PASS: x0 remains zero");
        end

        // -------------------------
        // RESULT
        // -------------------------

        $display("");
        $display("========================================");
        $display("          SIMT LANE TEST");
        $display("========================================");

        if (errors == 0)
            $display("RESULT: SIMT LANE TEST PASSED");
        else begin
            $display("RESULT: SIMT LANE TEST FAILED");
            $display("ERRORS = %0d", errors);
        end

        $display("========================================");

        $finish;

    end

endmodule
