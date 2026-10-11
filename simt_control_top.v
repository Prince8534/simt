module simt_control_top (
    input wire clk,
    input wire reset,

    output wire [31:0] current_pc,
    output wire [31:0] instruction,

    output wire [7:0] thread_mask,
    output wire [7:0] predicate_mask,

    output wire branch_instr,
    output wire divergence,
    output wire split,

    output wire stack_push,
    output wire stack_pop
);

    // ============================================================
    // NEXT PC
    // ============================================================

    wire [31:0] next_pc;


    // ============================================================
    // FRONTEND
    //
    // This is now the sole owner of the architectural PC.
    // ============================================================

    simt_frontend frontend (
        .clk(clk),
        .reset(reset),

        .next_pc(next_pc),

        .current_pc(current_pc),
        .instruction(instruction)
    );


    // ============================================================
    // DECODER
    //
    // We use the existing decoder to identify JOIN.
    // ============================================================

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
    wire split_instr;
    wire join_instr;

    wire fence;
    wire ecall;
    wire ebreak;
    wire illegal;


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
        .split(split_instr),
        .join_instr(join_instr),

        .fence(fence),
        .ecall(ecall),
        .ebreak(ebreak),

        .illegal(illegal)
    );


    // ============================================================
    // DIVERGENCE / CONTROL FLOW
    // ============================================================

    simt_branch_divergence divergence_unit (
        .clk(clk),
        .reset(reset),

        .current_pc(current_pc),
        .instruction(instruction),

        .reconvergence_pc(32'h00000040),

        .join_instr(join_instr),

        .next_pc(next_pc),

        .thread_mask(thread_mask),
        .predicate_mask(predicate_mask),

        .branch_instr(branch_instr),
        .divergence(divergence),
        .split(split),

        .stack_push(stack_push),
        .stack_pop(stack_pop)
    );

endmodule
