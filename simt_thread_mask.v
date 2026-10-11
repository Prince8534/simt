module simt_thread_mask (
    input  wire       clk,
    input  wire       reset,

    // TMC control
    input  wire       tmc,
    input  wire [7:0] tmc_mask,

    // Current SIMT thread mask
    output reg  [7:0] thread_mask
);

    always @(posedge clk) begin

        if (reset) begin
            thread_mask <= 8'b11111111;
        end
        else if (tmc) begin
            thread_mask <= tmc_mask;
        end

    end

endmodule
