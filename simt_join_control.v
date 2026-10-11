module simt_join_control (
    input wire        clk,
    input wire        reset,

    input wire        join_instr,

    // Current execution state
    input wire [7:0]  thread_mask,
    input wire [31:0] current_pc,

    // Top IPDOM stack entry
    input wire [7:0]  top_deferred_mask,
    input wire [31:0] top_deferred_pc,
    input wire [31:0] top_reconvergence_pc,
    input wire [7:0]  top_reconvergence_mask,
    input wire        top_path_state,

    input wire        stack_empty,

    // Updated execution state
    output reg [7:0]  next_thread_mask,
    output reg [31:0] next_pc,

    // Stack control
    output reg        stack_pop,

    // Updated path state to be stored
    output reg        path_state_update
);

    always @(*) begin

        // Default: continue normally
        next_thread_mask = thread_mask;
        next_pc = current_pc + 32'd4;

        stack_pop = 1'b0;
        path_state_update = top_path_state;

        if (join_instr && !stack_empty) begin

            // -----------------------------------------
            // FIRST JOIN
            //
            // Taken path has completed.
            // Switch to deferred path.
            // -----------------------------------------

            if (top_path_state == 1'b0) begin

                next_thread_mask =
                    top_deferred_mask;

                next_pc =
                    top_deferred_pc;

                // Mark that deferred path is now active
                path_state_update = 1'b1;

            end

            // -----------------------------------------
            // SECOND JOIN
            //
            // Deferred path has completed.
            // Reconverge.
            // -----------------------------------------

            else begin

                next_thread_mask =
                    top_reconvergence_mask;

                next_pc =
                    top_reconvergence_pc;

                // Remove completed divergence entry
                stack_pop = 1'b1;

                path_state_update = 1'b0;

            end

        end

    end

endmodule
