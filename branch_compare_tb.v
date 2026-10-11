`timescale 1ns/1ps

module simt_branch_compare_tb;

    reg [31:0] rs1_data [0:7];
    reg [31:0] rs2_data [0:7];

    reg [2:0] branch_type;

    wire [7:0] predicate_mask;

    simt_branch_compare dut (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .branch_type(branch_type),
        .predicate_mask(predicate_mask)
    );

    integer i;

    task check_mask;
        input [7:0] expected;
        input [127:0] test_name;

        begin
            #1;

            if (predicate_mask == expected)
                $display("PASS: %s -> %b",
                         test_name, predicate_mask);
            else
                $display("FAIL: %s -> got %b expected %b",
                         test_name, predicate_mask, expected);
        end
    endtask


    initial begin

        // =================================================
        // Set lane data
        // =================================================
        //
        // Lane 0: 10, 10
        // Lane 1: 10, 20
        // Lane 2: 20, 10
        // Lane 3: 20, 20
        // Lane 4: 5,  10
        // Lane 5: 10, 5
        // Lane 6: 0,  0
        // Lane 7: 30, 20
        // =================================================

        rs1_data[0] = 32'd10;
        rs2_data[0] = 32'd10;

        rs1_data[1] = 32'd10;
        rs2_data[1] = 32'd20;

        rs1_data[2] = 32'd20;
        rs2_data[2] = 32'd10;

        rs1_data[3] = 32'd20;
        rs2_data[3] = 32'd20;

        rs1_data[4] = 32'd5;
        rs2_data[4] = 32'd10;

        rs1_data[5] = 32'd10;
        rs2_data[5] = 32'd5;

        rs1_data[6] = 32'd0;
        rs2_data[6] = 32'd0;

        rs1_data[7] = 32'd30;
        rs2_data[7] = 32'd20;


        $display("");
        $display("====================================");
        $display(" SIMT BRANCH COMPARATOR TEST");
        $display("====================================");


        // =================================================
        // BEQ
        // =================================================

        branch_type = 3'b000;

        // Equal: lanes 0,3,6
        check_mask(
            8'b01001001,
            "BEQ"
        );


        // =================================================
        // BNE
        // =================================================

        branch_type = 3'b001;

        // Not equal: lanes 1,2,4,5,7
        check_mask(
            8'b10110110,
            "BNE"
        );


        // =================================================
        // BLT
        // =================================================

        branch_type = 3'b100;

        // Less-than: lanes 1,4
        check_mask(
            8'b00010010,
            "BLT"
        );


        // =================================================
        // BGE
        // =================================================

        branch_type = 3'b101;

        // Greater/equal: lanes 0,2,3,5,6,7
        check_mask(
            8'b11101101,
            "BGE"
        );


        // =================================================
        // BLTU
        // =================================================

        branch_type = 3'b110;

        check_mask(
            8'b00010010,
            "BLTU"
        );


        // =================================================
        // BGEU
        // =================================================

        branch_type = 3'b111;

        check_mask(
            8'b11101101,
            "BGEU"
        );


        $display("");
        $display("====================================");
        $display(" BRANCH COMPARATOR TEST COMPLETE");
        $display("====================================");

        $finish;

    end

endmodule
