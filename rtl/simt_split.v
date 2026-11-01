module simt_split (
    input  wire [7:0] thread_mask,
    input  wire [7:0] predicate_mask,

    output wire [7:0] taken_mask,
    output wire [7:0] deferred_mask
);

    assign taken_mask =
        thread_mask & predicate_mask;

    assign deferred_mask =
        thread_mask & ~predicate_mask;

endmodule
