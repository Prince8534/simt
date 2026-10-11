module simt_divergence_controller (
    input  wire        clk,
    input  wire        reset,

    input  wire        split,
    input  wire        join_instr,

    input  wire [7:0]  thread_mask,
    input  wire [7:0]  predicate_mask,

    input  wire [31:0] current_pc,
    input  wire [31:0] taken_pc,
    input  wire [31:0] deferred_pc,
    input  wire [31:0] reconvergence_pc,

    output reg [7:0]  next_thread_mask,
    output reg [31:0] next_pc,

    output wire       stack_push,
    output wire       stack_pop
);

    // =====================================================
    // SPLIT
    // =====================================================

    wire [7:0] split_taken_mask;
    wire [7:0] split_deferred_mask;

    simt_split split_unit (
        .thread_mask(thread_mask),
        .predicate_mask(predicate_mask),

        .taken_mask(split_taken_mask),
        .deferred_mask(split_deferred_mask)
    );

    wire divergent;

    assign divergent =
        (split_taken_mask != 8'b0) &&
        (split_deferred_mask != 8'b0);

    // =====================================================
    // IPDOM STACK
    // =====================================================

    wire [7:0]  top_deferred_mask;
    wire [31:0] top_deferred_pc;
    wire [31:0] top_reconvergence_pc;
    wire [7:0]  top_reconvergence_mask;
    wire        top_path_state;

    wire stack_empty;
    wire stack_full;

    reg stack_push_int;
    reg stack_pop_int;

    reg update_top_path_state;
    reg new_path_state;

    ipdom_stack ipdom (
        .clk(clk),
        .reset(reset),

        .push(stack_push_int),
        .pop(stack_pop_int),

        .update_top_path_state(update_top_path_state),
        .new_path_state(new_path_state),

        .push_deferred_mask(split_deferred_mask),
        .push_deferred_pc(deferred_pc),
        .push_reconvergence_pc(reconvergence_pc),
        .push_reconvergence_mask(thread_mask),
        .push_path_state(1'b0),

        .top_deferred_mask(top_deferred_mask),
        .top_deferred_pc(top_deferred_pc),
        .top_reconvergence_pc(top_reconvergence_pc),
        .top_reconvergence_mask(top_reconvergence_mask),
        .top_path_state(top_path_state),

        .empty(stack_empty),
        .full(stack_full)
    );

    // =====================================================
    // JOIN
    // =====================================================

    wire [7:0]  join_thread_mask;
    wire [31:0] join_pc;
    wire        join_pop;
    wire        join_path_state;

    simt_join_control join_control (
        .clk(clk),
        .reset(reset),

        .join_instr(join_instr),

        .thread_mask(thread_mask),
        .current_pc(current_pc),

        .top_deferred_mask(top_deferred_mask),
        .top_deferred_pc(top_deferred_pc),
        .top_reconvergence_pc(top_reconvergence_pc),
        .top_reconvergence_mask(top_reconvergence_mask),
        .top_path_state(top_path_state),

        .stack_empty(stack_empty),

        .next_thread_mask(join_thread_mask),
        .next_pc(join_pc),

        .stack_pop(join_pop),
        .path_state_update(join_path_state)
    );

    // =====================================================
    // CONTROL DECISION
    // =====================================================

    always @(*) begin

        stack_push_int = 1'b0;
        stack_pop_int = 1'b0;

        update_top_path_state = 1'b0;
        new_path_state = 1'b0;

        next_thread_mask = thread_mask;
        next_pc = current_pc + 32'd4;

        // -------------------------------------------------
        // SPLIT
        // -------------------------------------------------

        if (split && divergent && !stack_full) begin

            stack_push_int = 1'b1;

            next_thread_mask = split_taken_mask;
            next_pc = taken_pc;

        end

        // -------------------------------------------------
        // JOIN
        // -------------------------------------------------

        else if (join_instr && !stack_empty) begin

            next_thread_mask = join_thread_mask;
            next_pc = join_pc;

            if (join_pop) begin

                stack_pop_int = 1'b1;

            end
            else begin

                update_top_path_state = 1'b1;
                new_path_state = join_path_state;

            end

        end

    end

    assign stack_push = stack_push_int;
    assign stack_pop  = stack_pop_int;

endmodule
