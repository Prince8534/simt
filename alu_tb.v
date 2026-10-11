`timescale 1ns/1ps

module simt_alu_tb;

    reg [31:0] A;
    reg [31:0] B;
    reg [3:0]  alu_control;

    wire [31:0] result;
    wire zero;
    wire negative;
    wire carry;

    simt_alu dut (
        .A(A),
        .B(B),
        .alu_control(alu_control),
        .result(result),
        .zero(zero),
        .negative(negative),
        .carry(carry)
    );

    integer errors;

    task check;
        input [31:0] expected;
        input [127:0] name;

        begin
            #1;

            if (result !== expected) begin
                $display(
                    "FAIL %-8s A=%h B=%h Result=%h Expected=%h",
                    name, A, B, result, expected
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS %-8s A=%h B=%h Result=%h",
                    name, A, B, result
                );
            end
        end
    endtask

    initial begin

        errors = 0;

        // -------------------------
        // ADD
        // -------------------------

        A = 32'd10;
        B = 32'd5;
        alu_control = 4'b0000;
        check(32'd15, "ADD");

        // -------------------------
        // SUB
        // -------------------------

        A = 32'd10;
        B = 32'd5;
        alu_control = 4'b0001;
        check(32'd5, "SUB");

        // -------------------------
        // SLL
        // -------------------------

        A = 32'd3;
        B = 32'd2;
        alu_control = 4'b0010;
        check(32'd12, "SLL");

        // -------------------------
        // SLT signed
        // -------------------------

        A = -32'sd5;
        B = 32'd3;
        alu_control = 4'b0011;
        check(32'd1, "SLT");

        A = 32'd5;
        B = 32'd3;
        alu_control = 4'b0011;
        check(32'd0, "SLT");

        // -------------------------
        // SLTU unsigned
        // -------------------------

        A = 32'hFFFFFFFF;
        B = 32'd1;
        alu_control = 4'b0100;
        check(32'd0, "SLTU");

        A = 32'd1;
        B = 32'hFFFFFFFF;
        alu_control = 4'b0100;
        check(32'd1, "SLTU");

        // -------------------------
        // XOR
        // -------------------------

        A = 32'hAAAA5555;
        B = 32'hFFFF0000;
        alu_control = 4'b0101;
        check(32'h55555555, "XOR");

        // -------------------------
        // SRL
        // -------------------------

        A = 32'h80000000;
        B = 32'd4;
        alu_control = 4'b0110;
        check(32'h08000000, "SRL");

        // -------------------------
        // SRA
        // -------------------------

        A = 32'h80000000;
        B = 32'd4;
        alu_control = 4'b0111;
        check(32'hF8000000, "SRA");

        // -------------------------
        // OR
        // -------------------------

        A = 32'hAAAA0000;
        B = 32'h00005555;
        alu_control = 4'b1000;
        check(32'hAAAA5555, "OR");

        // -------------------------
        // AND
        // -------------------------

        A = 32'hFFFF0000;
        B = 32'hFF00FF00;
        alu_control = 4'b1001;
        check(32'hFF000000, "AND");

        // -------------------------
        // ZERO FLAG
        // -------------------------

        A = 32'd5;
        B = 32'd5;
        alu_control = 4'b0001;

        #1;

        if (zero !== 1'b1) begin
            $display("FAIL ZERO FLAG");
            errors = errors + 1;
        end
        else begin
            $display("PASS ZERO FLAG");
        end

        // -------------------------
        // NEGATIVE FLAG
        // -------------------------

        A = 32'd0;
        B = 32'd1;
        alu_control = 4'b0001;

        #1;

        if (negative !== 1'b1) begin
            $display("FAIL NEGATIVE FLAG");
            errors = errors + 1;
        end
        else begin
            $display("PASS NEGATIVE FLAG");
        end

        // -------------------------
        // FINAL RESULT
        // -------------------------

        $display("");
        $display("========================================");
        $display("             SIMT ALU TEST");
        $display("========================================");

        if (errors == 0)
            $display("RESULT: ALU TEST PASSED");
        else begin
            $display("RESULT: ALU TEST FAILED");
            $display("ERRORS = %0d", errors);
        end

        $display("========================================");

        $finish;

    end

endmodule
