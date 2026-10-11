module ipdom_stack (
    input  wire        clk,
    input  wire        reset,

    //by me
    input wire update_top_path_state,
    input wire new_path_state,

    input  wire        push,
    input  wire        pop,

    input  wire [7:0]  push_deferred_mask,
    input  wire [31:0] push_deferred_pc,
    input  wire [31:0] push_reconvergence_pc,
    input  wire [7:0] push_reconvergence_mask,
    input  wire        push_path_state,

    output reg  [7:0]  top_deferred_mask,
    output reg  [31:0] top_deferred_pc,
    output reg  [31:0] top_reconvergence_pc,
    output reg  [7:0]  top_reconvergence_mask,
    output reg         top_path_state,

    output wire        empty,
    output wire        full
);

    // 8-entry IPDOM stack
    reg [7:0]  deferred_mask_stack      [0:7];
    reg [31:0] deferred_pc_stack        [0:7];
    reg [31:0] reconvergence_pc_stack   [0:7];
    reg [7:0]  reconvergence_mask_stack [0:7];
    reg        path_state_stack         [0:7];

    reg [3:0] stack_pointer;

    assign empty = (stack_pointer == 4'd0);
    assign full  = (stack_pointer == 4'd8);

    // Top-of-stack is the entry immediately below stack_pointer.
    always @(*) begin

        if (stack_pointer != 0) begin

            top_deferred_mask =
                deferred_mask_stack[stack_pointer - 1];

            top_deferred_pc =
                deferred_pc_stack[stack_pointer - 1];

            top_reconvergence_pc =
                reconvergence_pc_stack[stack_pointer - 1];

            top_reconvergence_mask =
                reconvergence_mask_stack[stack_pointer - 1];

            top_path_state =
                path_state_stack[stack_pointer - 1];

        end
        else begin

            top_deferred_mask = 8'b0;
            top_deferred_pc = 32'b0;
            top_reconvergence_pc = 32'b0;
            top_reconvergence_mask = 8'b0;
            top_path_state = 1'b0;

        end

    end

    integer i;

    always @(posedge clk) begin

        if (reset) begin

            stack_pointer <= 4'd0;

            for (i = 0; i < 8; i = i + 1) begin
                deferred_mask_stack[i] <= 8'b0;
                deferred_pc_stack[i] <= 32'b0;
                reconvergence_pc_stack[i] <= 32'b0;
                reconvergence_mask_stack[i] <= 8'b0;
                path_state_stack[i] <= 1'b0;
            end

        end

        // -------------------------
        // PUSH
        // -------------------------

        else if (push && !full) begin

            deferred_mask_stack[stack_pointer] <=
                push_deferred_mask;

            deferred_pc_stack[stack_pointer] <=
                push_deferred_pc;

            reconvergence_pc_stack[stack_pointer] <=
                push_reconvergence_pc;

            reconvergence_mask_stack[stack_pointer] <=
                push_reconvergence_mask;

            path_state_stack[stack_pointer] <=
                push_path_state;

            stack_pointer <= stack_pointer + 4'd1;

        end

        // -------------------------
        // POP
        // -------------------------

        else if (pop && !empty) begin

            stack_pointer <= stack_pointer - 4'd1;

        end
        else if (update_top_path_state && !empty) begin
            path_state_stack[stack_pointer - 1] <= new_path_state;
        end

    end

endmodule
