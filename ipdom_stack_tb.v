`timescale 1ns/1ps

module ipdom_stack_tb;

    reg clk;
    reg reset;

    reg push;
    reg pop;

    reg [7:0]  push_deferred_mask;
    reg [31:0] push_deferred_pc;
    reg [31:0] push_reconvergence_pc;
    reg [7:0]  push_reconvergence_mask;
    reg        push_path_state;

    wire [7:0]  top_deferred_mask;
    wire [31:0] top_deferred_pc;
    wire [31:0] top_reconvergence_pc;
    wire [7:0]  top_reconvergence_mask;
    wire        top_path_state;

    wire empty;
    wire full;

    ipdom_stack dut (
        .clk(clk),
        .reset(reset),

        .push(push),
        .pop(pop),

        .push_deferred_mask(push_deferred_mask),
        .push_deferred_pc(push_deferred_pc),
        .push_reconvergence_pc(push_reconvergence_pc),
        .push_reconvergence_mask(push_reconvergence_mask),
        .push_path_state(push_path_state),

        .top_deferred_mask(top_deferred_mask),
        .top_deferred_pc(top_deferred_pc),
        .top_reconvergence_pc(top_reconvergence_pc),
        .top_reconvergence_mask(top_reconvergence_mask),
        .top_path_state(top_path_state),

        .empty(empty),
        .full(full)
    );

    always #5 clk = ~clk;

    integer errors;

    initial begin

        clk = 0;
        reset = 1;

        push = 0;
        pop = 0;

        push_deferred_mask = 0;
        push_deferred_pc = 0;
        push_reconvergence_pc = 0;
        push_reconvergence_mask = 0;
        push_path_state = 0;

        errors = 0;

        // -------------------------
        // RESET
        // -------------------------

        #12;
        reset = 0;

        #1;

        if (!empty) begin
            $display("FAIL: stack not empty after reset");
            errors = errors + 1;
        end
        else begin
            $display("PASS: stack empty after reset");
        end

        // -------------------------
        // PUSH ENTRY 1
        // -------------------------

        @(negedge clk);

        push = 1;

        push_deferred_mask = 8'b00110011;
        push_deferred_pc = 32'd20;
        push_reconvergence_pc = 32'd30;
        push_reconvergence_mask = 8'b11111111;
        push_path_state = 1'b0;

        @(posedge clk);
        #1;

        push = 0;

        if (top_deferred_mask !== 8'b00110011 ||
            top_deferred_pc !== 32'd20 ||
            top_reconvergence_pc !== 32'd30 ||
            top_reconvergence_mask !== 8'b11111111 ||
            top_path_state !== 1'b0) begin

            $display("FAIL: first stack entry incorrect");
            errors = errors + 1;

        end
        else begin
            $display("PASS: first stack entry");
        end

        // -------------------------
        // PUSH ENTRY 2
        // -------------------------

        @(negedge clk);

        push = 1;

        push_deferred_mask = 8'b00001111;
        push_deferred_pc = 32'd100;
        push_reconvergence_pc = 32'd120;
        push_reconvergence_mask = 8'b00111111;
        push_path_state = 1'b1;

        @(posedge clk);
        #1;

        push = 0;

        if (top_deferred_mask !== 8'b00001111 ||
            top_deferred_pc !== 32'd100 ||
            top_reconvergence_pc !== 32'd120 ||
            top_reconvergence_mask !== 8'b00111111 ||
            top_path_state !== 1'b1) begin

            $display("FAIL: nested stack entry incorrect");
            errors = errors + 1;

        end
        else begin
            $display("PASS: nested stack entry");
        end

        // -------------------------
        // POP
        // Should expose entry 1
        // -------------------------

        @(negedge clk);

        pop = 1;

        @(posedge clk);
        #1;

        pop = 0;

        if (top_deferred_mask !== 8'b00110011 ||
            top_deferred_pc !== 32'd20 ||
            top_reconvergence_pc !== 32'd30) begin

            $display("FAIL: POP did not expose previous entry");
            errors = errors + 1;

        end
        else begin
            $display("PASS: POP restored previous entry");
        end

        // -------------------------
        // POP AGAIN
        // -------------------------

        @(negedge clk);

        pop = 1;

        @(posedge clk);
        #1;

        pop = 0;

        if (!empty) begin
            $display("FAIL: stack not empty after second POP");
            errors = errors + 1;
        end
        else begin
            $display("PASS: stack empty after second POP");
        end

        // -------------------------
        // RESULT
        // -------------------------

        $display("");
        $display("========================================");
        $display("          IPDOM STACK TEST");
        $display("========================================");

        if (errors == 0)
            $display("RESULT: IPDOM STACK TEST PASSED");
        else begin
            $display("RESULT: IPDOM STACK TEST FAILED");
            $display("ERRORS = %0d", errors);
        end

        $display("========================================");

        $finish;

    end

endmodule
