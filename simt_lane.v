module simt_lane (
    input wire clk,
    input wire reset,
    input wire thread_enable,

    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,

    input wire [3:0] alu_control,
    input wire alu_src_imm,
    input wire [31:0] immediate,

    input wire reg_write,

    output wire [31:0] result,

    // Expose lane-local register read data
    output wire [31:0] rs1_data_out,
    output wire [31:0] rs2_data_out
);

    reg [31:0] registers [0:31];

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    assign rs1_data =
        (rs1 == 5'd0) ? 32'b0 : registers[rs1];

    assign rs2_data =
        (rs2 == 5'd0) ? 32'b0 : registers[rs2];

    assign rs1_data_out = rs1_data;
    assign rs2_data_out = rs2_data;


    wire [31:0] alu_B;

    assign alu_B =
        alu_src_imm ? immediate : rs2_data;


    reg [31:0] alu_result;

    always @(*) begin

        case (alu_control)

            4'b0000:
                alu_result = rs1_data + alu_B;

            4'b0001:
                alu_result = rs1_data - alu_B;

            4'b0010:
                alu_result = rs1_data << alu_B[4:0];

            4'b0011:
                alu_result =
                    ($signed(rs1_data) < $signed(alu_B))
                    ? 32'd1 : 32'd0;

            4'b0100:
                alu_result =
                    (rs1_data < alu_B)
                    ? 32'd1 : 32'd0;

            4'b0101:
                alu_result = rs1_data ^ alu_B;

            4'b0110:
                alu_result = rs1_data >> alu_B[4:0];

            4'b0111:
                alu_result =
                    $signed(rs1_data) >>> alu_B[4:0];

            4'b1000:
                alu_result = rs1_data | alu_B;

            4'b1001:
                alu_result = rs1_data & alu_B;

            default:
                alu_result = 32'b0;

        endcase

    end

    assign result = alu_result;


    integer i;

    always @(posedge clk) begin

        if (reset) begin

            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;

        end

        else if (thread_enable &&
                 reg_write &&
                 (rd != 5'd0)) begin

            registers[rd] <= alu_result;

        end

    end

endmodule
