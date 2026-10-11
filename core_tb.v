`timescale 1ns/1ps

module simt_core_tb;

    reg clk;
    reg reset;

    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;

    reg [3:0] alu_control;
    reg        alu_src_imm;
    reg [31:0] immediate;
    reg        reg_write;

    reg [7:0] thread_mask;

    wire [31:0] lane_result [0:7];

    simt_core dut (
        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_control(alu_control),
        .alu_src_imm(alu_src_imm),
        .immediate(immediate),
        .reg_write(reg_write),

        .thread_mask(thread_mask),

        .lane_result(lane_result)
    );

    always #5 clk = ~clk;

    integer i;
    integer errors;

    initial begin

        clk = 0;
        reset = 1;

        rs1 = 0;
        rs2 = 0;
        rd = 0;

        alu_control = 0;
        alu_src_imm = 0;
        immediate = 0;
        reg_write = 0;

        thread_mask = 8'b00000000;

        errors = 0;

        // -------------------------
        // RESET
        // -------------------------

        #12;
        reset = 0;

        // =====================================================
        // TEST 1
        // Every lane:
        //
        // x1 = lane_number + 1
        //
        // Since the instruction is shared, we cannot generate
        // different immediates per lane here.
        //
        // First initialize x1 in every lane with the same value.
        // =====================================================

        @(negedge clk);

        rd = 5'd1;
        immediate = 32'd10;

        alu_src_imm = 1'b1;
        alu_control = 4'b0000;
        reg_write = 1'b1;

        thread_mask = 8'b11111111;

        @(posedge clk);
        #1;

        // =====================================================
        // TEST 2
        //
        // All 8 lanes:
        //
        // x2 = x1 + 5
        //
        // Expected: every lane gets 15.
        // =====================================================

        @(negedge clk);

        rs1 = 5'd1;
        rd = 5'd2;

        immediate = 32'd5;
        alu_src_imm = 1'b1;
        alu_control = 4'b0000;
        reg_write = 1'b1;

        thread_mask = 8'b11111111;

        #1;

        for (i = 0; i < 8; i = i + 1) begin

            if (lane_result[i] !== 32'd15) begin
                $display(
                    "FAIL: Lane %0d result = %0d, expected 15",
                    i,
                    lane_result[i]
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: Lane %0d result = 15",
                    i
                );
            end

        end

        @(posedge clk);
        #1;

        // =====================================================
        // TEST 3
        //
        // Divergent-style mask:
        //
        // 10101010
        //
        // Lanes 1,3,5,7 active
        //
        // Attempt:
        // x3 = x1 + 100
        //
        // Only active lanes should commit.
        // =====================================================

        @(negedge clk);

        rs1 = 5'd1;
        rd = 5'd3;

        immediate = 32'd100;
        alu_src_imm = 1'b1;
        alu_control = 4'b0000;
        reg_write = 1'b1;

        thread_mask = 8'b10101010;

        #1;

        for (i = 0; i < 8; i = i + 1) begin

            if (lane_result[i] !== 32'd110) begin
                $display(
                    "FAIL: Lane %0d ALU result = %0d",
                    i,
                    lane_result[i]
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: Lane %0d ALU result = 110",
                    i
                );
            end

        end

        @(posedge clk);
        #1;

        // =====================================================
        // TEST 4
        //
        // Switch mask:
        //
        // 01010101
        //
        // Lanes 0,2,4,6 active
        //
        // x3 = x1 + 200
        // =====================================================

        @(negedge clk);

        immediate = 32'd200;

        thread_mask = 8'b01010101;

        #1;

        for (i = 0; i < 8; i = i + 1) begin

            if (lane_result[i] !== 32'd210) begin
                $display(
                    "FAIL: Lane %0d result = %0d",
                    i,
                    lane_result[i]
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: Lane %0d result = 210",
                    i
                );
            end

        end

        @(posedge clk);
        #1;

        // =====================================================
        // FINAL
        // =====================================================

        $display("");
        $display("========================================");
        $display("          SIMT CORE TEST");
        $display("========================================");

        if (errors == 0)
            $display("RESULT: SIMT CORE TEST PASSED");
        else begin
            $display("RESULT: SIMT CORE TEST FAILED");
            $display("ERRORS = %0d", errors);
        end

        $display("========================================");

        $finish;

    end

endmodule
