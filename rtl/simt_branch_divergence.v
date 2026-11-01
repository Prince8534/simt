module simt_branch_divergence (
    input wire clk,
    input wire reset,

    input wire [31:0] instruction,

    input wire [31:0] reconvergence_pc,

    input wire join_instr,
    input wire [31:0] current_pc,


    output wire [31:0] next_pc,
    output wire [7:0] thread_mask,
    output wire [7:0] predicate_mask,

    output wire branch_instr,
    output wire divergence,
    output wire split,

    output wire stack_push,
    output wire stack_pop
);

    // ==================================================
    // DECODER
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
    wire decoded_join;

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
        .join_instr(decoded_join),

        .fence(fence),
        .ecall(ecall),
        .ebreak(ebreak),

        .illegal(illegal)
    );

    assign branch_instr = branch;


    // ==================================================
    // LANE REGISTER FILE READS
    // ==================================================

    wire [31:0] unused_lane_result [0:7];

    wire [31:0] lane_rs1_data [0:7];
    wire [31:0] lane_rs2_data [0:7];
    reg [7:0] thread_mask_reg;

    assign thread_mask = thread_mask_reg;


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

        // Reads are available for all lanes.
        // thread_mask controls writes in simt_lane.
        .thread_mask(thread_mask_reg),

        .lane_result(unused_lane_result),

        .lane_rs1_data(lane_rs1_data),
        .lane_rs2_data(lane_rs2_data)
    );


    // ==================================================
    // BRANCH COMPARATOR
    // ==================================================

    simt_branch_compare comparator (
        .rs1_data(lane_rs1_data),
        .rs2_data(lane_rs2_data),
        .branch_type(alu_control[2:0]),
        .predicate_mask(predicate_mask)
    );


    // ==================================================
    // THREAD MASK STATE
    // ==================================================



    // ==================================================
    // CFG CONTROLLER
    // ==================================================

    wire [31:0] taken_pc;
    wire [31:0] deferred_pc;

    wire branch_taken;
    wire branch_fallthrough;

    wire cfg_divergence;
    wire cfg_split;


    simt_cfg_controller cfg_controller (
        .current_pc(current_pc),
        .branch_immediate(immediate),

        .thread_mask(thread_mask_reg),
        .predicate_mask(predicate_mask),

        .branch_instr(branch),

        .reconvergence_pc(reconvergence_pc),

        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),

        .divergence(cfg_divergence),
        .branch_taken(branch_taken),
        .branch_fallthrough(branch_fallthrough),

        .split(cfg_split)
    );

    assign divergence = cfg_divergence;
    assign split = cfg_split;


    // ==================================================
    // STATEFUL DIVERGENCE / IPDOM CONTROL
    // ==================================================

    wire [7:0] controller_next_mask;
    wire [31:0] controller_next_pc;


    simt_divergence_controller divergence_controller (
        .clk(clk),
        .reset(reset),

        .split(cfg_split),
        .join_instr(join_instr),

        .thread_mask(thread_mask_reg),
        .predicate_mask(predicate_mask),

        .current_pc(current_pc),

        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),
        .reconvergence_pc(reconvergence_pc),

        .next_thread_mask(controller_next_mask),
        .next_pc(controller_next_pc),

        .stack_push(stack_push),
        .stack_pop(stack_pop)
    );


    // ==================================================
    // NEXT PC
    // ==================================================

    /*
        Divergent branch:
            taken path first

        Uniform taken:
            taken path

        Uniform not taken:
            fall-through

        JOIN:
            controller supplies deferred/reconvergence PC

        Normal:
            PC + 4
    */

    assign next_pc =
        join_instr ? controller_next_pc :
        cfg_split  ? controller_next_pc :
        branch_taken ? taken_pc :
        branch_fallthrough ? deferred_pc :
        current_pc + 32'd4;


    // ==================================================
    // THREAD MASK UPDATE
    // ==================================================

    always @(posedge clk) begin
        if (reset)
            thread_mask_reg <= 8'b11111111;
        else
            thread_mask_reg <= controller_next_mask;
    end

endmodule
