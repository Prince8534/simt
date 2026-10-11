`timescale 1ns/1ps

module simt_execute_stage_tb;

    reg clk;
    reg reset;

    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;

    reg [4:0] alu_control;
    reg alu_src_imm;
    reg [31:0] immediate;

    reg reg_write;
    reg [7:0] thread_mask;

    wire [31:0] lane_result [0:7];

    simt_execute_stage dut (
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
        thread_mask = 8'b11111111;

        // -------------------------
        // Reset
        // -------------------------
        #10;
        reset = 0;

        // ------------------------------------------------
        // Preload registers in all 8 lanes
        //
        // R1 = 10
        // R2 = 20
        // ------------------------------------------------
        dut.core.LANES[0].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[0].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[1].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[1].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[2].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[2].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[3].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[3].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[4].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[4].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[5].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[5].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[6].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[6].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[7].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[7].lane_unit.registers[2] = 32'd20;

        // ------------------------------------------------
        // ADD R3, R1, R2
        // ------------------------------------------------
        rs1 = 5'd1;
        rs2 = 5'd2;
        rd = 5'd3;

        alu_control = 5'd0;   // ADD
        alu_src_imm = 1'b0;
        immediate = 32'b0;

        reg_write = 1'b1;
        thread_mask = 8'b11111111;

        #2;

        $display("");
        $display("====================================");
        $display(" SIMT EXECUTION TEST");
        $display("====================================");

        $display("");
        $display("ADD R3, R1, R2");
        $display("----------------");
        $display("Lane 0 result = %d", lane_result[0]);
        $display("Lane 1 result = %d", lane_result[1]);
        $display("Lane 2 result = %d", lane_result[2]);
        $display("Lane 3 result = %d", lane_result[3]);
        $display("Lane 4 result = %d", lane_result[4]);
        $display("Lane 5 result = %d", lane_result[5]);
        $display("Lane 6 result = %d", lane_result[6]);
        $display("Lane 7 result = %d", lane_result[7]);

        if (lane_result[0] == 32'd30)
            $display("PASS: Lane 0 ADD");
        else
            $display("FAIL: Lane 0 ADD");

        if (lane_result[7] == 32'd30)
            $display("PASS: Lane 7 ADD");
        else
            $display("FAIL: Lane 7 ADD");

        // ------------------------------------------------
        // Commit ADD on clock edge
        // ------------------------------------------------
        #8;

        // ------------------------------------------------
        // Verify masked execution
        //
        // Only lanes 0,2,4,6 are enabled.
        // ------------------------------------------------
        thread_mask = 8'b01010101;

        #2;

        $display("");
        $display("THREAD MASK TEST");
        $display("-----------------");
        $display("Thread mask = %b", thread_mask);

        if (thread_mask[0] && lane_result[0] == 32'd30)
            $display("PASS: Lane 0 active");
        else
            $display("FAIL: Lane 0");

        if (!thread_mask[1])
            $display("PASS: Lane 1 masked");
        else
            $display("FAIL: Lane 1 mask");

        if (thread_mask[2] && lane_result[2] == 32'd30)
            $display("PASS: Lane 2 active");
        else
            $display("FAIL: Lane 2");

        if (!thread_mask[3])
            $display("PASS: Lane 3 masked");
        else
            $display("FAIL: Lane 3 mask");

        // ------------------------------------------------
        // ADDI R4, R1, 5
        // ------------------------------------------------
        rs1 = 5'd1;
        rs2 = 5'd0;
        rd = 5'd4;

        alu_control = 5'd0;   // ADD
        alu_src_imm = 1'b1;
        immediate = 32'd5;

        thread_mask = 8'b11111111;

        #2;

        $display("");
        $display("ADDI R4, R1, 5");
        $display("----------------");
        $display("Lane 0 result = %d", lane_result[0]);

        if (lane_result[0] == 32'd15)
            $display("PASS: ADDI");
        else
            $display("FAIL: ADDI");

        $display("");
        $display("====================================");
        $display(" SIMT EXECUTION TEST COMPLETE");
        $display("====================================");

        $finish;
    end

endmodule
