module simt_split_control (
    input wire        clk,
    input wire        reset,

    input wire        split,
    input wire        join,

    input wire [7:0]  thread_mask,
    input wire [7:0]  predicate_mask,

    input wire [31:0] current_pc,
    input wire [31:0] branch_target,
    input wire [31:0] reconvergence_pc,

    output reg  [7:0] next_thread_mask,
    output reg  [31:0] next_pc,

    // Stack interface
    output reg        stack_push,
    output reg        stack_pop,

    output reg [7:0]  push_deferred_mask,
    output reg [31:0] push_deferred_pc,
    output reg [31:0] push_reconvergence_pc,
    output reg [7:0]  push_reconvergence_mask
);

    wire [7:0] taken_mask;
    wire [7:0] deferred_mask;

    assign taken_mask =
        thread_mask & predicate_mask;

    assign deferred_mask =
        thread_mask & ~predicate_mask;

    wire divergent;

    assign divergent =
        (taken_mask != 8'b0) &&
        (deferred_mask != 8'b0);

    always @(*) begin

        // Defaults
        next_thread_mask = thread_mask;
        next_pc = current_pc + 32'd4;

        stack_push = 1'b0;
        stack_pop  = 1'b0;

        push_deferred_mask = 8'b0;
        push_deferred_pc = 32'b0;
        push_reconvergence_pc = 32'b0;
        push_reconvergence_mask = 8'b0;

        // ---------------------------------------------
        // SPLIT
        // ---------------------------------------------

        if (split) begin

            if (divergent) begin

                // Save deferred path
                stack_push = 1'b1;

                push_deferred_mask =
                    deferred_mask;

                push_deferred_pc =
                    current_pc + 32'd4;

                push_reconvergence_pc =
                    reconvergence_pc;

                push_reconvergence_mask =
                    thread_mask;

                // Taken path executes first
                next_thread_mask =
                    taken_mask;

                next_pc =
                    branch_target;

            end
            else begin

                // Uniform path:
                // no stack push
                if (taken_mask != 8'b0) begin
                    next_thread_mask = taken_mask;
                    next_pc = branch_target;
                end
                else begin
                    next_thread_mask = deferred_mask;
                    next_pc = current_pc + 32'd4;
                end

            end

        end

    end

endmodule
