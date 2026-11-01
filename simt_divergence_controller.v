
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

    // JOIN ownership metadata.
    // Legacy instances may leave these inputs unconnected.
    input  wire [31:0] join_owner_branch_pc,
    input  wire [31:0] join_reconvergence_pc,
    input  wire        join_metadata_found,

    output reg  [7:0]  next_thread_mask,
    output reg  [31:0] next_pc,

    output wire        stack_push,
    output wire        stack_pop
);

    // -----------------------------------------------------
    // SPLIT MASK GENERATION
    // -----------------------------------------------------

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

    // -----------------------------------------------------
    // IPDOM STACK
    // -----------------------------------------------------

    wire [31:0] top_branch_pc;
    wire [7:0]  top_deferred_mask;
    wire [31:0] top_deferred_pc;
    wire [31:0] top_reconvergence_pc;
    wire [7:0]  top_reconvergence_mask;
    wire        top_path_state;

    wire stack_empty;
    wire stack_full;

    reg stack_push_int;
    reg stack_pop_int;

    wire join_path_state;
    assign join_path_state = normal_join_path_state;
    reg update_top_path_state;
    reg new_path_state;

    ipdom_stack ipdom (
        .clk(clk),
        .reset(reset),

        .push(stack_push_int),
        .pop(stack_pop_int),

        .update_top_path_state(update_top_path_state),
        .new_path_state(new_path_state),

        .push_branch_pc(current_pc),
        .push_deferred_mask(split_deferred_mask),
        .push_deferred_pc(deferred_pc),
        .push_reconvergence_pc(reconvergence_pc),
        .push_reconvergence_mask(thread_mask),
        .push_path_state(1'b0),

        .top_branch_pc(top_branch_pc),
        .top_deferred_mask(top_deferred_mask),
        .top_deferred_pc(top_deferred_pc),
        .top_reconvergence_pc(top_reconvergence_pc),
        .top_reconvergence_mask(top_reconvergence_mask),
        .top_path_state(top_path_state),

        .empty(stack_empty),
        .full(stack_full)
    );

    // -----------------------------------------------------
    // NORMAL DIVERGENT JOIN CONTROL
    // -----------------------------------------------------

    wire [7:0]  normal_join_mask;
    wire [31:0] normal_join_pc;
    wire        normal_join_pop;
    wire        normal_join_path_state;

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

        .next_thread_mask(normal_join_mask),
        .next_pc(normal_join_pc),

        .stack_pop(normal_join_pop),
        .path_state_update(normal_join_path_state)
    );

    // -----------------------------------------------------
    // JOIN OWNERSHIP DECISION
    // -----------------------------------------------------

    wire join_metadata_valid;
    wire join_matches_top;

    // An unconnected legacy input does not activate
    // owner-aware handling.
    assign join_metadata_valid =
        (join_metadata_found === 1'b1);

    assign join_matches_top =
        join_metadata_valid &&
        !stack_empty &&
        (join_owner_branch_pc == top_branch_pc);

    // -----------------------------------------------------
    // CONTROL DECISION
    // -----------------------------------------------------

    always @(*) begin
        stack_push_int = 1'b0;
        stack_pop_int = 1'b0;

        update_top_path_state = 1'b0;
        new_path_state = 1'b0;

        next_thread_mask = thread_mask;
        next_pc = current_pc + 32'd4;

        // ---------------------------------------------
        // DIVERGENT SPLIT
        // ---------------------------------------------

        if (split && divergent && !stack_full) begin
            stack_push_int = 1'b1;

            next_thread_mask = split_taken_mask;
            next_pc = taken_pc;
        end

        // ---------------------------------------------
        // JOIN
        // ---------------------------------------------

        else if (join_instr) begin

            if (join_metadata_valid) begin

                // This JOIN belongs to the active
                // divergent branch at the top of stack.
                if (join_matches_top) begin
                    next_thread_mask = normal_join_mask;
                    next_pc = normal_join_pc;

                    if (normal_join_pop) begin
                        stack_pop_int = 1'b1;
                    end
                    else begin
                        update_top_path_state = 1'b1;
                        new_path_state = normal_join_path_state;
                    end
                end

                // This JOIN belongs to another region.
                // It must not consume the outer stack entry.
                else begin
                    next_thread_mask = thread_mask;
                    next_pc = join_reconvergence_pc;
                end
            end

            // Legacy behavior for controller instances
            // that do not supply JOIN metadata.
            else if (!stack_empty) begin
                next_thread_mask = normal_join_mask;
                next_pc = normal_join_pc;

                if (normal_join_pop) begin
                    stack_pop_int = 1'b1;
                end
                else begin
                    update_top_path_state = 1'b1;
                    new_path_state = normal_join_path_state;
                end
            end
        end
    end

    assign stack_push = stack_push_int;
    assign stack_pop  = stack_pop_int;

endmodule
