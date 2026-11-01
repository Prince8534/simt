module simt_frontend (
    input wire        clk,
    input wire        reset,

    // PC control
    input wire [31:0] next_pc,

    // Shared instruction
    output wire [31:0] current_pc,
    output wire [31:0] instruction
);

    // =====================================================
    // SHARED PC
    // =====================================================

    simt_pc pc_unit (
        .clk(clk),
        .reset(reset),

        .next_pc(next_pc),

        .current_pc(current_pc)
    );

    // =====================================================
    // SHARED INSTRUCTION MEMORY
    // =====================================================

    simt_instruction_memory instruction_memory (
        .address(current_pc),

        .instruction(instruction)
    );

endmodule
