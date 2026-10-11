module simt_branch_execute (

    input wire clk,
    input wire reset,

    input wire [4:0] rs1,
    input wire [4:0] rs2,

    input wire [2:0] branch_type,

    output wire [7:0] predicate_mask
);

    // ------------------------------------------------
    // We instantiate the same 8-lane execution core.
    //
    // For this block we only care about register reads.
    // No ALU writeback is performed.
    // ------------------------------------------------

    wire [31:0] unused_lane_result [0:7];

    wire [31:0] lane_rs1_data [0:7];
    wire [31:0] lane_rs2_data [0:7];

    simt_core core (

        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),

        .rd(5'd0),

        .alu_control(4'b0000),
        .alu_src_imm(1'b0),
        .immediate(32'b0),

        .reg_write(1'b0),

        // All lanes may read their registers.
        .thread_mask(8'b11111111),

        .lane_result(unused_lane_result),

        .lane_rs1_data(lane_rs1_data),
        .lane_rs2_data(lane_rs2_data)
    );


    // ------------------------------------------------
    // Per-lane branch comparison
    // ------------------------------------------------

    simt_branch_compare comparator (

        .rs1_data(lane_rs1_data),
        .rs2_data(lane_rs2_data),

        .branch_type(branch_type),

        .predicate_mask(predicate_mask)
    );

endmodule
