`timescale 1ns/1ps

module simt_metrics #(
    parameter LANES = 8,
    parameter COUNTER_WIDTH = 64
)(
    input wire clk,
    input wire reset,

    // Assert for each valid execution cycle to be measured.
    input wire sample_enable,

    // Canonical SIMT thread mask.
    input wire [LANES-1:0] thread_mask,

    output reg [COUNTER_WIDTH-1:0] total_cycles,
    output reg [COUNTER_WIDTH-1:0] useful_lane_cycles,
    output reg [COUNTER_WIDTH-1:0] masked_lane_cycles,

    // Integer percentage: 0 to 100.
    output wire [31:0] efficiency_percent
);

    integer i;
    reg [31:0] active_count;

    always @(*) begin
        active_count = 0;

        for (i = 0; i < LANES; i = i + 1) begin
            if (thread_mask[i])
                active_count = active_count + 1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            total_cycles        <= 0;
            useful_lane_cycles  <= 0;
            masked_lane_cycles  <= 0;
        end
        else if (sample_enable) begin
            total_cycles <= total_cycles + 1'b1;

            useful_lane_cycles <=
                useful_lane_cycles + active_count;

            masked_lane_cycles <=
                masked_lane_cycles + (LANES - active_count);
        end
    end

    assign efficiency_percent =
        (total_cycles == 0)
            ? 0
            : (useful_lane_cycles * 100) /
              (total_cycles * LANES);

endmodule
