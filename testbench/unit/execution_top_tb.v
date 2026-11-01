`timescale 1ns/1ps

module simt_execution_top_tb;

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

    reg [2:0] branch_type;
    reg branch_instr;

    wire [31:0] lane_result [0:7];

    wire [31:0] lane_rs1_data [0:7];
    wire [31:0] lane_rs2_data [0:7];

    wire [7:0] predicate_mask;


    // ============================================================
    // DUT
    // ============================================================

    simt_execution_top dut (
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

        .branch_type(branch_type),
        .branch_instr(branch_instr),

        .lane_result(lane_result),

        .lane_rs1_data(lane_rs1_data),
        .lane_rs2_data(lane_rs2_data),

        .predicate_mask(predicate_mask)
    );


    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;


    // ============================================================
    // TEST
    // ============================================================

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

        branch_type = 3'b000;
        branch_instr = 0;


        // ========================================================
        // RESET
        // ========================================================

        #12;
        reset = 0;

        #1;


        // ========================================================
        // INITIALIZE LANE REGISTERS
        // ========================================================

        dut.core.LANES[0].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[0].lane_unit.registers[2] = 32'd1;

        dut.core.LANES[1].lane_unit.registers[1] = 32'd20;
        dut.core.LANES[1].lane_unit.registers[2] = 32'd2;

        dut.core.LANES[2].lane_unit.registers[1] = 32'd30;
        dut.core.LANES[2].lane_unit.registers[2] = 32'd3;

        dut.core.LANES[3].lane_unit.registers[1] = 32'd40;
        dut.core.LANES[3].lane_unit.registers[2] = 32'd4;

        dut.core.LANES[4].lane_unit.registers[1] = 32'd50;
        dut.core.LANES[4].lane_unit.registers[2] = 32'd5;

        dut.core.LANES[5].lane_unit.registers[1] = 32'd60;
        dut.core.LANES[5].lane_unit.registers[2] = 32'd6;

        dut.core.LANES[6].lane_unit.registers[1] = 32'd70;
        dut.core.LANES[6].lane_unit.registers[2] = 32'd7;

        dut.core.LANES[7].lane_unit.registers[1] = 32'd80;
        dut.core.LANES[7].lane_unit.registers[2] = 32'd8;


        // ========================================================
        // ADD x3, x1, x2
        //
        // Expected:
        //
        // L0 = 11
        // L1 = 22
        // L2 = 33
        // L3 = 44
        // L4 = 55
        // L5 = 66
        // L6 = 77
        // L7 = 88
        // ========================================================

        rs1 = 5'd1;
        rs2 = 5'd2;
        rd = 5'd3;

        alu_control = 5'b00000;
        alu_src_imm = 1'b0;
        immediate = 32'b0;

        reg_write = 1'b1;
        thread_mask = 8'b11111111;

        #2;

        $display("");
        $display("========================================");
        $display(" SIMT EXECUTION DATAPATH TEST");
        $display("========================================");

        $display("");
        $display("ADD x3, x1, x2");
        $display("----------------");

        $display("L0 result = %0d", lane_result[0]);
        $display("L1 result = %0d", lane_result[1]);
        $display("L2 result = %0d", lane_result[2]);
        $display("L3 result = %0d", lane_result[3]);
        $display("L4 result = %0d", lane_result[4]);
        $display("L5 result = %0d", lane_result[5]);
        $display("L6 result = %0d", lane_result[6]);
        $display("L7 result = %0d", lane_result[7]);

        if (lane_result[0] == 32'd11)
            $display("PASS: L0 ADD");
        else
            $display("FAIL: L0 ADD");

        if (lane_result[7] == 32'd88)
            $display("PASS: L7 ADD");
        else
            $display("FAIL: L7 ADD");


        // ========================================================
        // COMMIT ADD
        // ========================================================

        #8;


        // ========================================================
        // VERIFY REGISTER WRITEBACK
        // ========================================================

        $display("");
        $display("REGISTER WRITEBACK");
        $display("------------------");

        if (dut.core.LANES[0].lane_unit.registers[3] == 32'd11)
            $display("PASS: L0 x3 = 11");
        else
            $display("FAIL: L0 x3");

        if (dut.core.LANES[3].lane_unit.registers[3] == 32'd44)
            $display("PASS: L3 x3 = 44");
        else
            $display("FAIL: L3 x3");

        if (dut.core.LANES[7].lane_unit.registers[3] == 32'd88)
            $display("PASS: L7 x3 = 88");
        else
            $display("FAIL: L7 x3");


// ----------------------------------------
// MASKED ADD
// ----------------------------------------

thread_mask = 8'b11001100;
rd = 5'd4;
reg_write = 1'b1;

#1;

$display("thread_mask = %b", thread_mask);

if (lane_result[2] == 32'd33)
    $display("PASS: L2 active");
else
    $display("FAIL: L2 active");

if (lane_result[3] == 32'd44)
    $display("PASS: L3 active");
else
    $display("FAIL: L3 active");

if (lane_result[6] == 32'd77)
    $display("PASS: L6 active");
else
    $display("FAIL: L6 active");

if (lane_result[7] == 32'd88)
    $display("PASS: L7 active");
else
    $display("FAIL: L7 active");

// IMPORTANT: give the register files a rising edge
#5;
clk = 1'b1;
#1;
clk = 1'b0;
#1;

// Now check architectural register state
if (dut.core.LANES[2].lane_unit.registers[4] == 32'd33)
    $display("PASS: L2 writeback");
else
    $display("FAIL: L2 writeback");

if (dut.core.LANES[7].lane_unit.registers[4] == 32'd88)
    $display("PASS: L7 writeback");
else
    $display("FAIL: L7 writeback");

if (dut.core.LANES[0].lane_unit.registers[4] == 32'd0)
    $display("PASS: L0 masked");
else
    $display("FAIL: L0 masked");

if (dut.core.LANES[5].lane_unit.registers[4] == 32'd0)
    $display("PASS: L5 masked");
else
    $display("FAIL: L5 masked");

        // ========================================================
        // BRANCH COMPARISON
        //
        // Reconfigure:
        //
        // L0: 10 == 10 -> true
        // L1: 20 == 20 -> true
        // L2: 30 != 99 -> false
        // L3: 40 != 99 -> false
        // L4: 50 == 50 -> true
        // L5: 60 == 60 -> true
        // L6: 70 != 99 -> false
        // L7: 80 != 99 -> false
        //
        // Expected:
        // 00110011
        // ========================================================

        thread_mask = 8'b11111111;

        dut.core.LANES[0].lane_unit.registers[2] = 32'd10;
        dut.core.LANES[1].lane_unit.registers[2] = 32'd20;
        dut.core.LANES[2].lane_unit.registers[2] = 32'd99;
        dut.core.LANES[3].lane_unit.registers[2] = 32'd99;
        dut.core.LANES[4].lane_unit.registers[2] = 32'd50;
        dut.core.LANES[5].lane_unit.registers[2] = 32'd60;
        dut.core.LANES[6].lane_unit.registers[2] = 32'd99;
        dut.core.LANES[7].lane_unit.registers[2] = 32'd99;

        rs1 = 5'd1;
        rs2 = 5'd2;

        branch_type = 3'b000;
        branch_instr = 1'b1;

        #2;

        $display("");
        $display("BEQ PREDICATE");
        $display("-------------");
        $display("predicate_mask = %08b", predicate_mask);

        if (predicate_mask == 8'b00110011)
            $display("PASS: branch predicate");
        else
            $display("FAIL: branch predicate");


        // ========================================================
        // COMPLETE
        // ========================================================

        $display("");
        $display("========================================");
        $display(" EXECUTION DATAPATH TEST COMPLETE");
        $display("========================================");

        $finish;

    end

endmodule
