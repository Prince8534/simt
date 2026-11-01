`timescale 1ns/1ps

module simt_decoder_tb;

    reg  [31:0] instruction;

    wire [4:0]  rs1;
    wire [4:0]  rs2;
    wire [4:0]  rd;
    wire [31:0] immediate;

    wire [3:0]  instr_type;
    wire [4:0]  alu_control;

    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        branch;
    wire        jump;
    wire        jalr;

    wire [2:0]  mem_type;

    wire        tmc;
    wire        split;
    wire        join_instr;

    wire        fence;
    wire        ecall;
    wire        ebreak;

    wire        illegal;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    simt_decoder dut (
        .instruction(instruction),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .immediate(immediate),

        .instr_type(instr_type),
        .alu_control(alu_control),

        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),

        .mem_type(mem_type),

        .tmc(tmc),
        .split(split),
        .join_instr(join_instr),

        .fence(fence),
        .ecall(ecall),
        .ebreak(ebreak),

        .illegal(illegal)
    );

    integer pass_count;
    integer fail_count;

    // ------------------------------------------------------------
    // Test helper
    // ------------------------------------------------------------

    task check_valid;
        input [31:0] inst;
        input [255:0] name;

        begin
            instruction = inst;
            #1;

            if (illegal == 1'b0) begin
                pass_count = pass_count + 1;
                $display("PASS  %-10s instruction=%h",
                         name, instruction);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL  %-10s instruction=%h marked ILLEGAL",
                         name, instruction);
            end
        end
    endtask


    task check_illegal;
        input [31:0] inst;
        input [255:0] name;

        begin
            instruction = inst;
            #1;

            if (illegal == 1'b1) begin
                pass_count = pass_count + 1;
                $display("PASS  %-10s correctly illegal",
                         name);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL  %-10s accepted illegal instruction",
                         name);
            end
        end
    endtask


    // ------------------------------------------------------------
    // R-type constructor
    // ------------------------------------------------------------

    function [31:0] make_r;
        input [6:0] funct7;
        input [4:0] rs2_f;
        input [4:0] rs1_f;
        input [2:0] funct3_f;
        input [4:0] rd_f;

        begin
            make_r = {
                funct7,
                rs2_f,
                rs1_f,
                funct3_f,
                rd_f,
                7'b0110011
            };
        end
    endfunction


    // ------------------------------------------------------------
    // I-type constructor
    // ------------------------------------------------------------

    function [31:0] make_i;
        input [11:0] imm_f;
        input [4:0]  rs1_f;
        input [2:0]  funct3_f;
        input [4:0]  rd_f;
        input [6:0]  opcode_f;

        begin
            make_i = {
                imm_f,
                rs1_f,
                funct3_f,
                rd_f,
                opcode_f
            };
        end
    endfunction


    // ------------------------------------------------------------
    // S-type constructor
    // ------------------------------------------------------------

    function [31:0] make_s;
        input [11:0] imm_f;
        input [4:0]  rs2_f;
        input [4:0]  rs1_f;
        input [2:0]  funct3_f;

        begin
            make_s = {
                imm_f[11:5],
                rs2_f,
                rs1_f,
                funct3_f,
                imm_f[4:0],
                7'b0100011
            };
        end
    endfunction


    // ------------------------------------------------------------
    // B-type constructor
    // ------------------------------------------------------------

    function [31:0] make_b;
        input [12:0] imm_f;
        input [4:0]  rs2_f;
        input [4:0]  rs1_f;
        input [2:0]  funct3_f;

        begin
            make_b = {
                imm_f[12],
                imm_f[10:5],
                rs2_f,
                rs1_f,
                funct3_f,
                imm_f[4:1],
                imm_f[11],
                7'b1100011
            };
        end
    endfunction


    // ------------------------------------------------------------
    // J-type constructor
    // ------------------------------------------------------------

    function [31:0] make_j;
        input [20:0] imm_f;
        input [4:0]  rd_f;

        begin
            make_j = {
                imm_f[20],
                imm_f[10:1],
                imm_f[11],
                imm_f[19:12],
                rd_f,
                7'b1101111
            };
        end
    endfunction


    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------

    initial begin

        pass_count = 0;
        fail_count = 0;
        instruction = 32'b0;

        $display("");
        $display("========================================");
        $display("       SIMT DECODER TESTBENCH");
        $display("========================================");
        $display("");

        // ========================================================
        // R-TYPE
        // ========================================================

        check_valid(
            make_r(7'b0000000, 5'd7, 5'd6, 3'b000, 5'd5),
            "ADD"
        );

        check_valid(
            make_r(7'b0100000, 5'd7, 5'd6, 3'b000, 5'd5),
            "SUB"
        );

        check_valid(
            make_r(7'b0000000, 5'd7, 5'd6, 3'b001, 5'd5),
            "SLL"
        );

        check_valid(
            make_r(7'b0000000, 5'd7, 5'd6, 3'b010, 5'd5),
            "SLT"
        );

        check_valid(
            make_r(7'b0000000, 5'd7, 5'd6, 3'b011, 5'd5),
            "SLTU"
        );

        check_valid(
            make_r(7'b0000000, 5'd7, 5'd6, 3'b100, 5'd5),
            "XOR"
        );

        check_valid(
            make_r(7'b0000000, 5'd7, 5'd6, 3'b101, 5'd5),
            "SRL"
        );

        check_valid(
            make_r(7'b0100000, 5'd7, 5'd6, 3'b101, 5'd5),
            "SRA"
        );

        check_valid(
            make_r(7'b0000000, 5'd7, 5'd6, 3'b110, 5'd5),
            "OR"
        );

        check_valid(
            make_r(7'b0000000, 5'd7, 5'd6, 3'b111, 5'd5),
            "AND"
        );


        // ========================================================
        // I-TYPE ALU
        // ========================================================

        check_valid(
            make_i(12'h123, 5'd6, 3'b000, 5'd5, 7'b0010011),
            "ADDI"
        );

        check_valid(
            make_i(12'h123, 5'd6, 3'b010, 5'd5, 7'b0010011),
            "SLTI"
        );

        check_valid(
            make_i(12'h123, 5'd6, 3'b011, 5'd5, 7'b0010011),
            "SLTIU"
        );

        check_valid(
            make_i(12'h123, 5'd6, 3'b100, 5'd5, 7'b0010011),
            "XORI"
        );

        check_valid(
            make_i(12'h123, 5'd6, 3'b110, 5'd5, 7'b0010011),
            "ORI"
        );

        check_valid(
            make_i(12'h123, 5'd6, 3'b111, 5'd5, 7'b0010011),
            "ANDI"
        );

        check_valid(
            make_i(12'b00000000101, 5'd6, 3'b001, 5'd5, 7'b0010011),
            "SLLI"
        );

        check_valid(
            make_i(12'b00000000101, 5'd6, 3'b101, 5'd5, 7'b0010011),
            "SRLI"
        );

        check_valid(
            make_i(12'b010000000101, 5'd6, 3'b101, 5'd5, 7'b0010011),
            "SRAI"
        );


        // ========================================================
        // LOADS
        // ========================================================

        check_valid(
            make_i(12'h020, 5'd10, 3'b000, 5'd5, 7'b0000011),
            "LB"
        );

        check_valid(
            make_i(12'h020, 5'd10, 3'b001, 5'd5, 7'b0000011),
            "LH"
        );

        check_valid(
            make_i(12'h020, 5'd10, 3'b010, 5'd5, 7'b0000011),
            "LW"
        );

        check_valid(
            make_i(12'h020, 5'd10, 3'b100, 5'd5, 7'b0000011),
            "LBU"
        );

        check_valid(
            make_i(12'h020, 5'd10, 3'b101, 5'd5, 7'b0000011),
            "LHU"
        );


        // ========================================================
        // STORES
        // ========================================================

        check_valid(
            make_s(12'h020, 5'd5, 5'd10, 3'b000),
            "SB"
        );

        check_valid(
            make_s(12'h020, 5'd5, 5'd10, 3'b001),
            "SH"
        );

        check_valid(
            make_s(12'h020, 5'd5, 5'd10, 3'b010),
            "SW"
        );


        // ========================================================
        // BRANCHES
        // ========================================================

        check_valid(
            make_b(13'h004, 5'd7, 5'd6, 3'b000),
            "BEQ"
        );

        check_valid(
            make_b(13'h004, 5'd7, 5'd6, 3'b001),
            "BNE"
        );

        check_valid(
            make_b(13'h004, 5'd7, 5'd6, 3'b100),
            "BLT"
        );

        check_valid(
            make_b(13'h004, 5'd7, 5'd6, 3'b101),
            "BGE"
        );

        check_valid(
            make_b(13'h004, 5'd7, 5'd6, 3'b110),
            "BLTU"
        );

        check_valid(
            make_b(13'h004, 5'd7, 5'd6, 3'b111),
            "BGEU"
        );


        // ========================================================
        // JAL
        // ========================================================

        check_valid(
            make_j(21'h00100, 5'd1),
            "JAL"
        );


        // ========================================================
        // JALR
        // ========================================================

        check_valid(
            make_i(12'h040, 5'd10, 3'b000, 5'd1, 7'b1100111),
            "JALR"
        );


        // ========================================================
        // LUI
        // ========================================================

        check_valid(
            {20'hABCDE, 5'd5, 7'b0110111},
            "LUI"
        );


        // ========================================================
        // AUIPC
        // ========================================================

        check_valid(
            {20'hABCDE, 5'd5, 7'b0010111},
            "AUIPC"
        );


        // ========================================================
        // FENCE
        // ========================================================

        check_valid(
            32'h0000000F,
            "FENCE"
        );


        // ========================================================
        // ECALL
        // ========================================================

        check_valid(
            32'h00000073,
            "ECALL"
        );


        // ========================================================
        // EBREAK
        // ========================================================

        check_valid(
            32'h00100073,
            "EBREAK"
        );


        // ========================================================
        // SIMT EXTENSIONS
        // custom-0 = 0001011
        // ========================================================

        check_valid(
            32'b00000000000000000_000_00000_0001011,
            "TMC"
        );

        check_valid(
            32'b00000000000000000_001_00000_0001011,
            "SPLIT"
        );

        check_valid(
            32'b00000000000000000_010_00000_0001011,
            "JOIN"
        );


        // ========================================================
        // ILLEGAL INSTRUCTIONS
        // ========================================================

        check_illegal(
            make_r(7'b1111111, 5'd7, 5'd6, 3'b000, 5'd5),
            "BAD_R"
        );

        check_illegal(
            make_i(12'h123, 5'd6, 3'b011, 5'd5, 7'b1100111),
            "BAD_JALR"
        );

        check_illegal(
            32'hFFFFFFFF,
            "BAD_ALL"
        );


        // ========================================================
        // SUMMARY
        // ========================================================

        $display("");
        $display("========================================");
        $display("             TEST SUMMARY");
        $display("========================================");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT: ALL DECODER TESTS PASSED");
        else
            $display("RESULT: DECODER TEST FAILED");

        $display("========================================");
        $display("");

        $finish;

    end

endmodule
