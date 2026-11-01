module simt_frontend_decode (
    input wire clk,
    input wire reset,
    input wire [31:0] next_pc,

    output wire [31:0] current_pc,
    output wire [31:0] instruction,

    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,

    output wire [31:0] immediate,
    output wire [3:0] instr_type,
    output wire [4:0] alu_control,

    output wire reg_write,
    output wire mem_read,
    output wire mem_write,
    output wire branch,
    output wire jump,
    output wire jalr,

    output wire [2:0] mem_type,

    output wire tmc,
    output wire split,
    output wire join_instr,

    output wire fence,
    output wire ecall,
    output wire ebreak,

    output wire illegal
);

    // -------------------------
    // Frontend
    // -------------------------
    simt_frontend frontend (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .current_pc(current_pc),
        .instruction(instruction)
    );

    // -------------------------
    // Decode
    // -------------------------
    simt_decode_stage decode (
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

endmodule
