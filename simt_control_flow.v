module simt_control_flow (
    input wire clk,
    input wire reset,

    // Current instruction information
    input wire branch_instr,
    input wire join_instr,

    input wire [31:0] branch_immediate,
    input wire [7:0] predicate_mask,

    // IPDOM information supplied by the known CFG
    input wire [31:0] reconvergence_pc,

    output wire [31:0] current_pc,
    output wire [31:0] next_pc,

    output wire [7:0] thread_mask,

    output wire divergence,
    output wire split,

    output wire stack_push,
    output wire stack_pop
);

    // --------------------------------------------------
    // Thread mask state
    // --------------------------------------------------

    reg [7:0] thread_mask_reg;

    assign thread_mask = thread_mask_reg;


    // --------------------------------------------------
    // PC
    // --------------------------------------------------

    simt_pc pc_unit (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .current_pc(current_pc)
    );


    // --------------------------------------------------
    // CFG / branch controller
    // --------------------------------------------------

    wire [31:0] taken_pc;
    wire [31:0] deferred_pc;

    wire branch_taken;
    wire branch_fallthrough;

    wire cfg_split;

    simt_cfg_controller cfg_controller (
        .current_pc(current_pc),
        .branch_immediate(branch_immediate),

        .thread_mask(thread_mask_reg),
        .predicate_mask(predicate_mask),

        .branch_instr(branch_instr),

        .reconvergence_pc(reconvergence_pc),

        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),

        .divergence(divergence),
        .branch_taken(branch_taken),
        .branch_fallthrough(branch_fallthrough),

        .split(cfg_split)
    );

    assign split = cfg_split;


    // --------------------------------------------------
    // Divergence / IPDOM controller
    // --------------------------------------------------

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


    // --------------------------------------------------
    // Select next PC
    // --------------------------------------------------

    /*
       Priority:

       1. JOIN
       2. Divergent SPLIT
       3. Uniform branch taken
       4. Uniform branch fall-through
       5. Normal sequential execution
    */

    assign next_pc =
        join_instr     ? controller_next_pc :
        cfg_split      ? controller_next_pc :
        branch_taken   ? taken_pc :
        branch_fallthrough ? deferred_pc :
        current_pc + 32'd4;


    // --------------------------------------------------
    // Update thread mask
    // --------------------------------------------------

    always @(posedge clk) begin
        if (reset)
            thread_mask_reg <= 8'b11111111;
        else
            thread_mask_reg <= controller_next_mask;
    end

endmodule
