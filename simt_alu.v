module simt_alu (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  alu_control,

    output reg  [31:0] result,
    output wire        zero,
    output wire        negative,
    output wire        carry
);

    reg carry_internal;

    always @(*) begin

        result = 32'b0;
        carry_internal = 1'b0;

        case (alu_control)

            // ADD
            4'b0000: begin
                {carry_internal, result} = {1'b0, A} + {1'b0, B};
            end

            // SUB
            4'b0001: begin
                {carry_internal, result} = {1'b0, A} - {1'b0, B};
            end

            // SLL
            4'b0010: begin
                result = A << B[4:0];
            end

            // SLT - signed
            4'b0011: begin
                result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
            end

            // SLTU - unsigned
            4'b0100: begin
                result = (A < B) ? 32'd1 : 32'd0;
            end

            // XOR
            4'b0101: begin
                result = A ^ B;
            end

            // SRL
            4'b0110: begin
                result = A >> B[4:0];
            end

            // SRA
            4'b0111: begin
                result = $signed(A) >>> B[4:0];
            end

            // OR
            4'b1000: begin
                result = A | B;
            end

            // AND
            4'b1001: begin
                result = A & B;
            end

            default: begin
                result = 32'b0;
                carry_internal = 1'b0;
            end

        endcase

    end

    assign zero     = (result == 32'b0);
    assign negative = result[31];
    assign carry    = carry_internal;

endmodule
