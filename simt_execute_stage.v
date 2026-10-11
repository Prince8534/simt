module simt_execute_stage (
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

    output wire [31:0] lane_result [0:7]
);

    // ------------------------------------------------
    // ALU control adapter
    //
    // Decoder: 5-bit ALU control
    // Lane:    4-bit ALU control
    //
    // Current supported ALU operations are 0-9,
    // so the lower four bits preserve the encoding.
    // ------------------------------------------------
    wire [3:0] lane_alu_control;

    assign lane_alu_control = alu_control[3:0];

    // ------------------------------------------------
    // 8-lane SIMT execution core
    // ------------------------------------------------
    simt_core core (
        .clk(clk),
        .reset(reset),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_control(lane_alu_control),
        .alu_src_imm(alu_src_imm),
        .immediate(immediate),

        .reg_write(reg_write),
        .thread_mask(thread_mask),

        .lane_result(lane_result)
    );

endmodule
