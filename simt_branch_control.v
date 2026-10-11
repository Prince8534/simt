module simt_branch_control (
    input wire clk,
    input wire reset,

    input wire [31:0] current_pc,
    input wire [31:0] instruction,

    input wire [31:0] reconvergence_pc,

    output wire [31:0] next_pc,
    output wire [7:0] predicate_mask,

    output wire branch_instr,
    output wire divergence,
    output wire split
);

    // ==================================================
    // DECODER OUTPUTS
    // ==================================================

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


    // ==================================================
    // INSTRUCTION DECODER
    // ==================================================

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


    // ==================================================
    // EXPORT DECODER BRANCH SIGNAL
    // ==================================================

    assign branch_instr = branch;


    // ==================================================
    // LANE REGISTER FILE READS
    // ==================================================

    wire [31:0] unused_lane_result [0:7];

    wire [31:0] lane_rs1_data [0:7];
    wire [31:0] lane_rs2_data [0:7];


    simt_core core (
        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_control(4'b0000),
        .alu_src_imm(1'b0),
        .immediate(32'b0),

        .reg_write(1'b0),

        .thread_mask(8'b11111111),

        .lane_result(unused_lane_result),

        .lane_rs1_data(lane_rs1_data),
        .lane_rs2_data(lane_rs2_data)
    );


    // ==================================================
    // BRANCH PREDICATE GENERATION
    //
    // Decoder's alu_control[2:0] contains funct3:
    //
    // 000 = BEQ
    // 001 = BNE
    // 100 = BLT
    // 101 = BGE
    // 110 = BLTU
    // 111 = BGEU
    // ==================================================

    simt_branch_compare comparator (
        .rs1_data(lane_rs1_data),
        .rs2_data(lane_rs2_data),
        .branch_type(alu_control[2:0]),
        .predicate_mask(predicate_mask)
    );


    // ==================================================
    // CFG CONTROLLER
    // ==================================================

    wire [31:0] taken_pc;
    wire [31:0] deferred_pc;

    wire branch_taken;
    wire branch_fallthrough;


    simt_cfg_controller cfg_controller (
        .current_pc(current_pc),
        .branch_immediate(immediate),

        .thread_mask(8'b11111111),
        .predicate_mask(predicate_mask),

        .branch_instr(branch),

        .reconvergence_pc(reconvergence_pc),

        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),

        .divergence(divergence),
        .branch_taken(branch_taken),
        .branch_fallthrough(branch_fallthrough),

        .split(split)
    );


    // ==================================================
    // NEXT PC
    // ==================================================
    //
    // Branch taken:
    //     current_pc + branch immediate
    //
    // Branch not taken:
    //     current_pc + 4
    //
    // Non-branch:
    //     current_pc + 4
    // ==================================================

    assign next_pc =
        split              ? taken_pc :
        branch_taken       ? taken_pc :
        branch_fallthrough ? deferred_pc :
        current_pc + 32'd4;

endmodule
