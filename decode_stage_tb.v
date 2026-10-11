`timescale 1ns/1ps

module simt_decode_stage_tb;

    reg [31:0] instruction;

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

    simt_decode_stage dut (
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

    initial begin

        // =================================================
        // ADD x3, x1, x2
        // =================================================

        instruction = 32'h002081B3;

        #1;

        $display("");
        $display("ADD TEST");
        $display("--------");

        $display("rs1        = %d", rs1);
        $display("rs2        = %d", rs2);
        $display("rd         = %d", rd);
        $display("alu_control= %d", alu_control);
        $display("reg_write  = %b", reg_write);
        $display("illegal    = %b", illegal);

        if (rs1 !== 5'd1)
            $display("FAIL: ADD rs1");
        else
            $display("PASS: ADD rs1");

        if (rs2 !== 5'd2)
            $display("FAIL: ADD rs2");
        else
            $display("PASS: ADD rs2");

        if (rd !== 5'd3)
            $display("FAIL: ADD rd");
        else
            $display("PASS: ADD rd");

        if (!reg_write)
            $display("FAIL: ADD reg_write");
        else
            $display("PASS: ADD reg_write");

        if (illegal)
            $display("FAIL: ADD illegal");
        else
            $display("PASS: ADD legal");

        // =================================================
        // ADDI x5, x2, 10
        // =================================================

        instruction = 32'h00A10293;

        #1;

        $display("");
        $display("ADDI TEST");
        $display("---------");

        $display("rs1        = %d", rs1);
        $display("rd         = %d", rd);
        $display("immediate  = %h", immediate);
        $display("reg_write  = %b", reg_write);
        $display("illegal    = %b", illegal);

        if (rs1 !== 5'd2)
            $display("FAIL: ADDI rs1");
        else
            $display("PASS: ADDI rs1");

        if (rd !== 5'd5)
            $display("FAIL: ADDI rd");
        else
            $display("PASS: ADDI rd");

        if (immediate !== 32'd10)
            $display("FAIL: ADDI immediate");
        else
            $display("PASS: ADDI immediate");

        // =================================================
        // JOIN
        // Custom-0 opcode = 0001011
        // funct3 = 010
        // =================================================

        instruction = 32'b0;
        instruction[6:0] = 7'b0001011;
        instruction[14:12] = 3'b010;

        #1;

        $display("");
        $display("JOIN TEST");
        $display("---------");

        $display("join_instr = %b", join_instr);
        $display("split      = %b", split);
        $display("tmc        = %b", tmc);
        $display("illegal    = %b", illegal);

        if (!join_instr)
            $display("FAIL: JOIN not detected");
        else
            $display("PASS: JOIN detected");

        if (split)
            $display("FAIL: JOIN incorrectly detected as SPLIT");
        else
            $display("PASS: JOIN/SPLIT distinction");

        if (illegal)
            $display("FAIL: JOIN marked illegal");
        else
            $display("PASS: JOIN legal");

        // =================================================
        // SPLIT
        // Custom-0 opcode = 0001011
        // funct3 = 001
        // =================================================

        instruction = 32'b0;
        instruction[6:0] = 7'b0001011;
        instruction[14:12] = 3'b001;

        #1;

        $display("");
        $display("SPLIT TEST");
        $display("----------");

        $display("join_instr = %b", join_instr);
        $display("split      = %b", split);
        $display("tmc        = %b", tmc);
        $display("illegal    = %b", illegal);

        if (!split)
            $display("FAIL: SPLIT not detected");
        else
            $display("PASS: SPLIT detected");

        if (join_instr)
            $display("FAIL: SPLIT incorrectly detected as JOIN");
        else
            $display("PASS: SPLIT/JOIN distinction");

        if (illegal)
            $display("FAIL: SPLIT marked illegal");
        else
            $display("PASS: SPLIT legal");

        // =================================================
        // TMC
        // Custom-0 opcode = 0001011
        // funct3 = 000
        // =================================================

        instruction = 32'b0;
        instruction[6:0] = 7'b0001011;
        instruction[14:12] = 3'b000;

        #1;

        $display("");
        $display("TMC TEST");
        $display("--------");

        $display("tmc        = %b", tmc);
        $display("split      = %b", split);
        $display("join_instr = %b", join_instr);
        $display("illegal    = %b", illegal);

        if (!tmc)
            $display("FAIL: TMC not detected");
        else
            $display("PASS: TMC detected");

        if (illegal)
            $display("FAIL: TMC marked illegal");
        else
            $display("PASS: TMC legal");

        // =================================================
        // COMPLETE
        // =================================================

        $display("");
        $display("====================================");
        $display("       DECODE STAGE TEST COMPLETE   ");
        $display("====================================");

        $finish;

    end

endmodule
