module simt_branch_compare (
    input wire [31:0] rs1_data [0:7],
    input wire [31:0] rs2_data [0:7],

    input wire [2:0] branch_type,

    output reg [7:0] predicate_mask
);

    integer i;

    // RV32I branch funct3 encoding
    localparam BR_BEQ  = 3'b000;
    localparam BR_BNE  = 3'b001;
    localparam BR_BLT  = 3'b100;
    localparam BR_BGE  = 3'b101;
    localparam BR_BLTU = 3'b110;
    localparam BR_BGEU = 3'b111;

    always @(*) begin

        predicate_mask = 8'b0;

        for (i = 0; i < 8; i = i + 1) begin

            case (branch_type)

                BR_BEQ:
                    predicate_mask[i] =
                        (rs1_data[i] == rs2_data[i]);

                BR_BNE:
                    predicate_mask[i] =
                        (rs1_data[i] != rs2_data[i]);

                BR_BLT:
                    predicate_mask[i] =
                        ($signed(rs1_data[i]) < $signed(rs2_data[i]));

                BR_BGE:
                    predicate_mask[i] =
                        ($signed(rs1_data[i]) >= $signed(rs2_data[i]));

                BR_BLTU:
                    predicate_mask[i] =
                        (rs1_data[i] < rs2_data[i]);

                BR_BGEU:
                    predicate_mask[i] =
                        (rs1_data[i] >= rs2_data[i]);

                default:
                    predicate_mask[i] = 1'b0;

            endcase

        end
    end

endmodule
