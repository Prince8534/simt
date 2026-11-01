`timescale 1ns/1ps

module simt_frontend_decode_tb;

    reg clk;
    reg reset;
    reg [31:0] next_pc;

    wire [31:0] current_pc;
    wire [31:0] instruction;

    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;

    wire [31:0] immediate;
    wire [3:0] instr_type;
    wire [4:0] alu_control;

    wire reg_write;
    wire mem_read;
    wire mem_write;
    wire branch;
    wire jump;
    wire jalr;

    wire [2:0] mem_type;

    wire tmc;
    wire split;
    wire join_instr;

    wire fence;
    wire ecall;
    wire ebreak;

    wire illegal;

    simt_frontend_decode dut (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),

        .current_pc(current_pc),
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

    // Clock
    always #5 clk = ~clk;

    initial begin

        clk = 0;
        reset = 1;
        next_pc = 32'h00000000;

        // Reset
        #10;
        reset = 0;

        // ------------------------------------------------
        // Put ADD x3,x1,x2 into instruction memory
        // ------------------------------------------------
        // Encoding = 32'h002081B3
        dut.frontend.instruction_memory.memory[0] = 32'h002081B3;

        #2;

        $display("");
        $display("====================================");
        $display(" FRONTEND + DECODE TEST");
        $display("====================================");

        $display("PC          = %h", current_pc);
        $display("Instruction = %h", instruction);

        $display("");
        $display("Decoded ADD");
        $display("------------");
        $display("rs1         = %d", rs1);
        $display("rs2         = %d", rs2);
        $display("rd          = %d", rd);
        $display("reg_write   = %b", reg_write);
        $display("illegal     = %b", illegal);

        if (rs1 == 5'd1)
            $display("PASS: rs1");
        else
            $display("FAIL: rs1");

        if (rs2 == 5'd2)
            $display("PASS: rs2");
        else
            $display("FAIL: rs2");

        if (rd == 5'd3)
            $display("PASS: rd");
        else
            $display("FAIL: rd");

        if (reg_write == 1'b1)
            $display("PASS: reg_write");
        else
            $display("FAIL: reg_write");

        if (illegal == 1'b0)
            $display("PASS: legal");
        else
            $display("FAIL: illegal");

        // ------------------------------------------------
        // Move PC to next instruction
        // ------------------------------------------------
        dut.frontend.instruction_memory.memory[1] = 32'h00A10293;
        next_pc = 32'h00000004;

        #10;

        $display("");
        $display("Decoded ADDI");
        $display("------------");
        $display("PC          = %h", current_pc);
        $display("Instruction = %h", instruction);
        $display("rs1         = %d", rs1);
        $display("rd          = %d", rd);
        $display("immediate   = %h", immediate);
        $display("reg_write   = %b", reg_write);
        $display("illegal     = %b", illegal);

        if (rs1 == 5'd2)
            $display("PASS: ADDI rs1");
        else
            $display("FAIL: ADDI rs1");

        if (rd == 5'd5)
            $display("PASS: ADDI rd");
        else
            $display("FAIL: ADDI rd");

        if (immediate == 32'd10)
            $display("PASS: ADDI immediate");
        else
            $display("FAIL: ADDI immediate");

        if (reg_write == 1'b1)
            $display("PASS: ADDI reg_write");
        else
            $display("FAIL: ADDI reg_write");

        // ------------------------------------------------
        // JOIN
        // ------------------------------------------------
        dut.frontend.instruction_memory.memory[2] = 32'h0000200B;
        next_pc = 32'h00000008;

        #10;

        $display("");
        $display("Decoded JOIN");
        $display("------------");
        $display("PC          = %h", current_pc);
        $display("Instruction = %h", instruction);
        $display("join_instr  = %b", join_instr);
        $display("split       = %b", split);
        $display("tmc         = %b", tmc);
        $display("illegal     = %b", illegal);

        if (join_instr == 1'b1)
            $display("PASS: JOIN");
        else
            $display("FAIL: JOIN");

        if (split == 1'b0 && tmc == 1'b0)
            $display("PASS: JOIN distinction");
        else
            $display("FAIL: JOIN distinction");

        if (illegal == 1'b0)
            $display("PASS: JOIN legal");
        else
            $display("FAIL: JOIN illegal");

        $display("");
        $display("====================================");
        $display(" FRONTEND + DECODE TEST COMPLETE");
        $display("====================================");

        $finish;
    end

endmodule
