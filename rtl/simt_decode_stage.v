module simt_decode_stage (
    input wire [31:0] instruction,

    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,

    output wire [31:0] immediate,

    output wire [3:0]  instr_type,
    output wire [4:0]  alu_control,

    output wire        reg_write,
    output wire        mem_read,
    output wire        mem_write,
    output wire        branch,
    output wire        jump,
    output wire        jalr,

    output wire [2:0]  mem_type,

    output wire        tmc,
    output wire        split,
    output wire        join_instr,

    output wire        fence,
    output wire        ecall,
    output wire        ebreak,

    output wire        illegal
);

    simt_decoder decoder (
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
