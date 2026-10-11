`timescale 1ns/1ps

module simt_join_control_tb;

    reg clk;
    reg reset;
    reg join_instr;

    reg [7:0]  thread_mask;
    reg [31:0] current_pc;

    reg [7:0]  top_deferred_mask;
    reg [31:0] top_deferred_pc;
    reg [31:0] top_reconvergence_pc;
    reg [7:0]  top_reconvergence_mask;
    reg        top_path_state;

    reg        stack_empty;

    wire [7:0]  next_thread_mask;
    wire [31:0] next_pc;

    wire stack_pop;
    wire path_state_update;

    simt_join_control dut (
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

        .next_thread_mask(next_thread_mask),
        .next_pc(next_pc),

        .stack_pop(stack_pop),
        .path_state_update(path_state_update)
    );

    always #5 clk = ~clk;

    integer errors;

    initial begin

        clk = 0;
        reset = 0;
        join_instr = 0;

        thread_mask = 8'b11001100;
        current_pc = 32'd30;

        top_deferred_mask = 8'b00110011;
        top_deferred_pc = 32'd20;

        top_reconvergence_pc = 32'd40;
        top_reconvergence_mask = 8'b11111111;

        top_path_state = 1'b0;

        stack_empty = 1'b0;

        errors = 0;

        // -----------------------------------------
        // FIRST JOIN
        // -----------------------------------------

        join_instr = 1;

        #1;

        if (next_thread_mask !== 8'b00110011) begin
            $display(
                "FAIL: First JOIN mask = %b",
                next_thread_mask
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "PASS: First JOIN switched to deferred mask"
            );
        end

        if (next_pc !== 32'd20) begin
            $display(
                "FAIL: First JOIN PC = %0d",
                next_pc
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "PASS: First JOIN switched to deferred PC"
            );
        end

        if (stack_pop !== 1'b0) begin
            $display("FAIL: First JOIN popped stack");
            errors = errors + 1;
        end
        else begin
            $display("PASS: First JOIN did not pop");
        end

        if (path_state_update !== 1'b1) begin
            $display("FAIL: First JOIN path state");
            errors = errors + 1;
        end
        else begin
            $display("PASS: First JOIN changed path state");
        end

        // -----------------------------------------
        // SECOND JOIN
        // -----------------------------------------

        top_path_state = 1'b1;

        thread_mask = 8'b00110011;
        current_pc = 32'd35;

        #1;

        if (next_thread_mask !== 8'b11111111) begin
            $display(
                "FAIL: Second JOIN mask = %b",
                next_thread_mask
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "PASS: Second JOIN restored original mask"
            );
        end

        if (next_pc !== 32'd40) begin
            $display(
                "FAIL: Second JOIN PC = %0d",
                next_pc
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "PASS: Second JOIN switched to reconvergence PC"
            );
        end

        if (stack_pop !== 1'b1) begin
            $display("FAIL: Second JOIN did not pop stack");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Second JOIN popped stack");
        end

        // -----------------------------------------
        // EMPTY STACK
        // JOIN should do nothing
        // -----------------------------------------

        stack_empty = 1'b1;

        #1;

        if (stack_pop !== 1'b0) begin
            $display("FAIL: JOIN popped empty stack");
            errors = errors + 1;
        end
        else begin
            $display("PASS: JOIN ignored empty stack");
        end

        // -----------------------------------------
        // RESULT
        // -----------------------------------------

        $display("");
        $display("========================================");
        $display("        SIMT JOIN CONTROL TEST");
        $display("========================================");

        if (errors == 0)
            $display("RESULT: JOIN CONTROL TEST PASSED");
        else begin
            $display("RESULT: JOIN CONTROL TEST FAILED");
            $display("ERRORS = %0d", errors);
        end

        $display("========================================");

        $finish;

    end

endmodule
