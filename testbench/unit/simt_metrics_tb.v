`timescale 1ns/1ps

module simt_metrics_tb;

    localparam LANES = 8;

    reg clk;
    reg reset;
    reg sample_enable;
    reg [LANES-1:0] thread_mask;

    wire [63:0] total_cycles;
    wire [63:0] useful_lane_cycles;
    wire [63:0] masked_lane_cycles;
    wire [31:0] efficiency_percent;

    integer failures;

    simt_metrics #(
        .LANES(LANES),
        .COUNTER_WIDTH(64)
    ) dut (
        .clk(clk),
        .reset(reset),
        .sample_enable(sample_enable),
        .thread_mask(thread_mask),
        .total_cycles(total_cycles),
        .useful_lane_cycles(useful_lane_cycles),
        .masked_lane_cycles(masked_lane_cycles),
        .efficiency_percent(efficiency_percent)
    );

    always #5 clk = ~clk;

    task sample_cycle;
        input [LANES-1:0] mask_value;
        begin
            @(negedge clk);
            thread_mask = mask_value;
            sample_enable = 1'b1;

            @(posedge clk);
            #1;
        end
    endtask

    task check_value;
        input [255:0] label;
        input [63:0] actual;
        input [63:0] expected;
        begin
            if (actual !== expected) begin
                $display(
                    "FAIL: %0s actual=%0d expected=%0d",
                    label, actual, expected
                );
                failures = failures + 1;
            end
            else begin
                $display("PASS: %0s = %0d", label, actual);
            end
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        sample_enable = 0;
        thread_mask = 0;
        failures = 0;

        $display("========================================");
        $display(" SIMT METRICS TEST");
        $display("========================================");

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // 8 active lanes: 8 useful, 0 masked.
        sample_cycle(8'b11111111);

        // 4 active lanes: 4 useful, 4 masked.
        sample_cycle(8'b00001111);

        // 2 active lanes: 2 useful, 6 masked.
        sample_cycle(8'b00000011);

        check_value("Total cycles", total_cycles, 3);
        check_value("Useful lane-cycles", useful_lane_cycles, 14);
        check_value("Masked lane-cycles", masked_lane_cycles, 10);
        check_value("Efficiency percent", efficiency_percent, 58);

        // A zero thread mask still counts as a sampled cycle.
        sample_cycle(8'b00000000);

        check_value("Total cycles after zero mask", total_cycles, 4);
        check_value("Useful cycles after zero mask",
                    useful_lane_cycles, 14);
        check_value("Masked cycles after zero mask",
                    masked_lane_cycles, 18);
        check_value("Efficiency after zero mask",
                    efficiency_percent, 43);

        // A cycle with sampling disabled must not change counters.
        @(negedge clk);
        sample_enable = 0;
        thread_mask = 8'b11111111;

        @(posedge clk);
        #1;

        check_value("Disabled sample leaves cycles unchanged",
                    total_cycles, 4);
        check_value("Disabled sample leaves useful count unchanged",
                    useful_lane_cycles, 14);
        check_value("Disabled sample leaves masked count unchanged",
                    masked_lane_cycles, 18);

        $display("----------------------------------------");

        if (failures == 0)
            $display("ALL SIMT METRICS CHECKS PASSED");
        else
            $display("SIMT METRICS FAILED: %0d checks", failures);

        $display("========================================");

        $finish;
    end

endmodule
