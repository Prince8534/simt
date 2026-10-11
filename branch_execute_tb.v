`timescale 1ns/1ps

module simt_branch_execute_tb;

    reg clk;
    reg reset;

    reg [4:0] rs1;
    reg [4:0] rs2;

    reg [2:0] branch_type;

    wire [7:0] predicate_mask;


    simt_branch_execute dut (

        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),

        .branch_type(branch_type),

        .predicate_mask(predicate_mask)
    );


    always #5 clk = ~clk;


    initial begin

        clk = 0;
        reset = 1;

        rs1 = 0;
        rs2 = 0;

        branch_type = 3'b000;


        // ================================================
        // RESET
        // ================================================

        #10;
        reset = 0;


        // ================================================
        // Put actual values into lane-local registers
        // ================================================
        //
        // R1 / R2:
        //
        // Lane 0: 10 == 10
        // Lane 1: 10 != 20
        // Lane 2: 20 != 10
        // Lane 3: 20 == 20
        // Lane 4: 5  <  10
        // Lane 5: 10 >  5
        // Lane 6: 0  == 0
        // Lane 7: 30 >  20
        // ================================================

        dut.core.LANES[0].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[0].lane_unit.registers[2] = 32'd10;

        dut.core.LANES[1].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[1].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[2].lane_unit.registers[1] = 32'd20;
        dut.core.LANES[2].lane_unit.registers[2] = 32'd10;

        dut.core.LANES[3].lane_unit.registers[1] = 32'd20;
        dut.core.LANES[3].lane_unit.registers[2] = 32'd20;

        dut.core.LANES[4].lane_unit.registers[1] = 32'd5;
        dut.core.LANES[4].lane_unit.registers[2] = 32'd10;

        dut.core.LANES[5].lane_unit.registers[1] = 32'd10;
        dut.core.LANES[5].lane_unit.registers[2] = 32'd5;

        dut.core.LANES[6].lane_unit.registers[1] = 32'd0;
        dut.core.LANES[6].lane_unit.registers[2] = 32'd0;

        dut.core.LANES[7].lane_unit.registers[1] = 32'd30;
        dut.core.LANES[7].lane_unit.registers[2] = 32'd20;


        // ================================================
        // Select R1 and R2
        // ================================================

        rs1 = 5'd1;
        rs2 = 5'd2;


        $display("");
        $display("====================================");
        $display(" REAL-LANE BRANCH TEST");
        $display("====================================");


        // ================================================
        // BEQ
        // ================================================

        branch_type = 3'b000;

        #2;

        $display("");
        $display("BEQ");
        $display("---");

        $display("predicate_mask = %b", predicate_mask);

        if (predicate_mask == 8'b01001001)
            $display("PASS: BEQ");
        else
            $display("FAIL: BEQ");


        // ================================================
        // BNE
        // ================================================

        branch_type = 3'b001;

        #2;

        $display("");
        $display("BNE");
        $display("---");

        $display("predicate_mask = %b", predicate_mask);

        if (predicate_mask == 8'b10110110)
            $display("PASS: BNE");
        else
            $display("FAIL: BNE");


        // ================================================
        // BLT
        // ================================================

        branch_type = 3'b100;

        #2;

        $display("");
        $display("BLT");
        $display("---");

        $display("predicate_mask = %b", predicate_mask);

        if (predicate_mask == 8'b00010010)
            $display("PASS: BLT");
        else
            $display("FAIL: BLT");


        // ================================================
        // BGE
        // ================================================

        branch_type = 3'b101;

        #2;

        $display("");
        $display("BGE");
        $display("---");

        $display("predicate_mask = %b", predicate_mask);

        if (predicate_mask == 8'b11101101)
            $display("PASS: BGE");
        else
            $display("FAIL: BGE");


        // ================================================
        // BLTU
        // ================================================

        branch_type = 3'b110;

        #2;

        $display("");
        $display("BLTU");
        $display("----");

        $display("predicate_mask = %b", predicate_mask);

        if (predicate_mask == 8'b00010010)
            $display("PASS: BLTU");
        else
            $display("FAIL: BLTU");


        // ================================================
        // BGEU
        // ================================================

        branch_type = 3'b111;

        #2;

        $display("");
        $display("BGEU");
        $display("----");

        $display("predicate_mask = %b", predicate_mask);

        if (predicate_mask == 8'b11101101)
            $display("PASS: BGEU");
        else
            $display("FAIL: BGEU");


        // ================================================
        // FINAL
        // ================================================

        $display("");
        $display("====================================");
        $display(" REAL-LANE BRANCH TEST COMPLETE");
        $display("====================================");

        $finish;

    end

endmodule
