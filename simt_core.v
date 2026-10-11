module simt_core (
    input wire clk,
    input wire reset,

    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,

    input wire [3:0] alu_control,
    input wire alu_src_imm,
    input wire [31:0] immediate,

    input wire reg_write,
    input wire [7:0] thread_mask,

    output wire [31:0] lane_result [0:7],

    // Register operands from each lane
    output wire [31:0] lane_rs1_data [0:7],
    output wire [31:0] lane_rs2_data [0:7]
);

    genvar lane;

    generate

        for (lane = 0; lane < 8; lane = lane + 1) begin : LANES

            simt_lane lane_unit (

                .clk(clk),
                .reset(reset),

                .thread_enable(thread_mask[lane]),

                .rs1(rs1),
                .rs2(rs2),
                .rd(rd),

                .alu_control(alu_control),
                .alu_src_imm(alu_src_imm),
                .immediate(immediate),

                .reg_write(reg_write),

                .result(lane_result[lane]),

                .rs1_data_out(lane_rs1_data[lane]),
                .rs2_data_out(lane_rs2_data[lane])
            );

        end

    endgenerate

endmodule
