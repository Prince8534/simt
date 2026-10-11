module simt_execution_top (
    input wire clk,
    input wire reset,

    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,

    input wire [4:0] alu_control,
    input wire alu_src_imm,
    input wire [31:0] immediate,

    input wire reg_write,
    input wire [7:0] thread_mask,

    input wire [2:0] branch_type,
    input wire branch_instr,

    output wire [31:0] lane_result [0:7],

    output wire [31:0] lane_rs1_data [0:7],
    output wire [31:0] lane_rs2_data [0:7],

    output wire [7:0] predicate_mask
);

    // ============================================================
    // SHARED 8-LANE DATAPATH
    //
    // This is the ONLY register-file instance.
    //
    // Arithmetic execution and branch comparison both use these
    // same lane-local registers.
    // ============================================================

    wire [31:0] unused_lane_result [0:7];

    simt_core core (
        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_control(alu_control[3:0]),
        .alu_src_imm(alu_src_imm),
        .immediate(immediate),

        .reg_write(reg_write),
        .thread_mask(thread_mask),

        .lane_result(lane_result),

        .lane_rs1_data(lane_rs1_data),
        .lane_rs2_data(lane_rs2_data)
    );


    // ============================================================
    // BRANCH COMPARATOR
    //
    // Reads the SAME register files used by the ALUs.
    // ============================================================

    simt_branch_compare comparator (
        .rs1_data(lane_rs1_data),
        .rs2_data(lane_rs2_data),
        .branch_type(branch_type),
        .predicate_mask(predicate_mask)
    );

endmodule
