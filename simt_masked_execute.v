module simt_masked_execute (
    input wire clk,
    input wire reset,
    input wire [31:0] current_pc,

    // Execution instruction/control
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [4:0] alu_control,
    input wire alu_src_imm,
    input wire [31:0] immediate,
    input wire reg_write,

    // SIMT control
    input wire split,
    input wire join_instr,
    input wire [7:0] predicate_mask,

    input wire [31:0] taken_pc,
    input wire [31:0] deferred_pc,
    input wire [31:0] reconvergence_pc,

    output wire [7:0] thread_mask,
    output wire [31:0] next_pc,

    output wire [31:0] lane_result [0:7],

    output wire stack_push,
    output wire stack_pop
);

    // ------------------------------------------------
    // Current thread mask
    // ------------------------------------------------
    reg [7:0] thread_mask_reg;

    assign thread_mask = thread_mask_reg;

    // ------------------------------------------------
    // Divergence controller
    // ------------------------------------------------
    wire [7:0] controller_next_mask;
    wire [31:0] controller_next_pc;

    simt_divergence_controller divergence_controller (
        .clk(clk),
        .reset(reset),

        .split(split),
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

    assign next_pc = controller_next_pc;

    // ------------------------------------------------
    // Register the new thread mask
    // ------------------------------------------------
    always @(posedge clk) begin
        if (reset)
            thread_mask_reg <= 8'b11111111;
        else
            thread_mask_reg <= controller_next_mask;
    end

    // ------------------------------------------------
    // 8-lane execution
    // ------------------------------------------------
    simt_execute_stage execute_stage (
        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_control(alu_control),
        .alu_src_imm(alu_src_imm),
        .immediate(immediate),

        .reg_write(reg_write),
        .thread_mask(thread_mask_reg),

        .lane_result(lane_result)
    );

endmodule
