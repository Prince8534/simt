module simt_cfg_controller (
    input wire [31:0] current_pc,
    input wire [31:0] branch_immediate,

    input wire [7:0] thread_mask,
    input wire [7:0] predicate_mask,

    input wire branch_instr,

    // Supplied by the known CFG/IPDOM information.
    input wire [31:0] reconvergence_pc,

    output wire [31:0] taken_pc,
    output wire [31:0] deferred_pc,

    output wire divergence,
    output wire branch_taken,
    output wire branch_fallthrough,

    output wire split
);

    assign taken_pc = current_pc + branch_immediate;

    assign deferred_pc = current_pc + 32'd4;

    // Only threads currently active in the thread mask
    // participate in the branch decision.
    wire [7:0] taken_mask;
    wire [7:0] deferred_mask;

    assign taken_mask =
        thread_mask & predicate_mask;

    assign deferred_mask =
        thread_mask & ~predicate_mask;

    // Uniform branch cases.
    assign branch_taken =
        branch_instr &&
        (taken_mask == thread_mask) &&
        (thread_mask != 8'b0);

    assign branch_fallthrough =
        branch_instr &&
        (deferred_mask == thread_mask) &&
        (thread_mask != 8'b0);

    // Both sides contain active threads.
    // Therefore this is a divergent branch.
    assign divergence =
        branch_instr &&
        (taken_mask != 8'b0) &&
        (deferred_mask != 8'b0);

    assign split = divergence;

endmodule
