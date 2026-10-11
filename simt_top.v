
module simt_top (
    input wire clk,
    input wire reset,

    output wire [31:0] current_pc,
    output wire [31:0] instruction,
    output wire [7:0] thread_mask,

    output wire [7:0] predicate_mask,
    output wire branch_instr,
    output wire divergence,
    output wire split,
    output wire stack_push,
    output wire stack_pop,

    output wire [63:0] total_cycles,
    output wire [63:0] useful_lane_cycles,
    output wire [63:0] masked_lane_cycles,
    output wire [31:0] efficiency_percent
);

    reg [7:0] thread_mask_reg;

    wire [31:0] control_next_pc;
    wire [31:0] next_pc;
    wire [7:0] control_next_mask;

    assign next_pc = control_next_pc;

    // --------------------------------------------------------
    // SHARED FRONTEND
    // --------------------------------------------------------

    simt_frontend frontend (
        .clk(clk),
        .reset(reset),
        .next_pc(control_next_pc),
        .current_pc(current_pc),
        .instruction(instruction)
    );

    // --------------------------------------------------------
    // DECODER
    // --------------------------------------------------------

    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;

    wire [31:0] immediate;
    wire [3:0] instr_type;
    wire [4:0] alu_control;

    wire reg_write;
    wire mem_read;
    wire mem_write;

    wire branch;
    wire jump;
    wire jalr;

    wire [2:0] mem_type;

    wire tmc;
    wire split_instr;
    wire join_instr;

    wire fence;
    wire ecall;
    wire ebreak;
    wire illegal;

    simt_decoder decoder (
        .instruction(instruction),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .immediate(immediate),
        .instr_type(instr_type),
        .alu_control(alu_control),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .mem_type(mem_type),
        .tmc(tmc),
        .split(split_instr),
        .join_instr(join_instr),
        .fence(fence),
        .ecall(ecall),
        .ebreak(ebreak),
        .illegal(illegal)
    );

    assign branch_instr = branch;

    wire [2:0] branch_type;
    assign branch_type = instruction[14:12];

    // --------------------------------------------------------
    // SHARED EIGHT-LANE DATAPATH
    // --------------------------------------------------------

    wire [31:0] lane_result [0:7];
    wire [31:0] lane_rs1_data [0:7];
    wire [31:0] lane_rs2_data [0:7];

    wire lane_alu_src_imm;
    assign lane_alu_src_imm = (instr_type == 4'd1);

    simt_core core (
        .clk(clk),
        .reset(reset),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .alu_control(alu_control[3:0]),
        .alu_src_imm(lane_alu_src_imm),
        .immediate(immediate),
        .reg_write(
            reg_write &&
            !branch &&
            !join_instr &&
            !split_instr &&
            !tmc
        ),
        .thread_mask(thread_mask_reg),
        .lane_result(lane_result),
        .lane_rs1_data(lane_rs1_data),
        .lane_rs2_data(lane_rs2_data)
    );

    // --------------------------------------------------------
    // PER-LANE BRANCH COMPARISON
    // --------------------------------------------------------

    simt_branch_compare branch_compare (
        .rs1_data(lane_rs1_data),
        .rs2_data(lane_rs2_data),
        .branch_type(branch_type),
        .predicate_mask(predicate_mask)
    );

    // --------------------------------------------------------
    // COMPILER-GENERATED IPDOM LOOKUP
    // --------------------------------------------------------

    wire [31:0] reconvergence_pc;
    wire metadata_found;

    simt_ipdom_lookup ipdom_lookup (
        .branch_pc(current_pc),
        .reconvergence_pc(reconvergence_pc),
        .metadata_found(metadata_found)
    );

    // --------------------------------------------------------
    // CFG / BRANCH CONTROL
    // --------------------------------------------------------

    wire [31:0] taken_pc;
    wire [31:0] deferred_pc;

    wire branch_taken;
    wire branch_fallthrough;

    wire cfg_divergence;
    wire cfg_split;

    simt_cfg_controller cfg_controller (
        .current_pc(current_pc),
        .branch_immediate(immediate),
        .thread_mask(thread_mask_reg),
        .predicate_mask(predicate_mask),
        .branch_instr(branch),
        .reconvergence_pc(reconvergence_pc),
        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),
        .divergence(cfg_divergence),
        .branch_taken(branch_taken),
        .branch_fallthrough(branch_fallthrough),
        .split(cfg_split)
    );

    // --------------------------------------------------------
    // DIVERGENCE CONTROLLER + IPDOM STACK
    // --------------------------------------------------------

    wire [7:0] divergence_next_mask;
    wire [31:0] divergence_next_pc;

    simt_divergence_controller divergence_controller (
        .clk(clk),
        .reset(reset),
        .split(cfg_split),
        .join_instr(join_instr),
        .thread_mask(thread_mask_reg),
        .predicate_mask(predicate_mask),
        .current_pc(current_pc),
        .taken_pc(taken_pc),
        .deferred_pc(deferred_pc),
        .reconvergence_pc(reconvergence_pc),
        .next_thread_mask(divergence_next_mask),
        .next_pc(divergence_next_pc),
        .stack_push(stack_push),
        .stack_pop(stack_pop)
    );

    // --------------------------------------------------------
    // NEXT PC SELECTION
    // --------------------------------------------------------

    assign control_next_pc =
        cfg_split
            ? divergence_next_pc
        : join_instr
            ? divergence_next_pc
        : branch_taken
            ? taken_pc
        : branch_fallthrough
            ? deferred_pc
        : current_pc + 32'd4;

    // --------------------------------------------------------
    // NEXT THREAD MASK
    // --------------------------------------------------------

    assign control_next_mask =
        (cfg_split || join_instr)
            ? divergence_next_mask
            : thread_mask_reg;

    assign thread_mask = thread_mask_reg;

    always @(posedge clk) begin
        if (reset)
            thread_mask_reg <= 8'b11111111;
        else
            thread_mask_reg <= control_next_mask;
    end

    assign divergence = cfg_divergence;
    assign split = cfg_split;

    // --------------------------------------------------------
    // SIMULATION-TIME IPDOM SAFETY CHECK
    // --------------------------------------------------------
    // A divergent split must have compiler-generated metadata.
    // This check is excluded from synthesis.

`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (!reset && cfg_split && !metadata_found) begin
            $display("");
            $display("========================================");
            $display("FATAL: MISSING IPDOM METADATA");
            $display("Branch PC:        0x%08h", current_pc);
            $display("Instruction:      0x%08h", instruction);
            $display("Thread mask:      %08b", thread_mask_reg);
            $display("Predicate mask:   %08b", predicate_mask);
            $display("Lookup PC:        0x%08h", current_pc);
            $display("========================================");
            $fatal(1, "Cannot execute divergent split without IPDOM metadata");
        end
    end
`endif

    // --------------------------------------------------------
    // PERFORMANCE METRICS
    // --------------------------------------------------------

    wire metrics_sample_enable;
    assign metrics_sample_enable = !reset;

    simt_metrics #(
        .LANES(8),
        .COUNTER_WIDTH(64)
    ) metrics (
        .clk(clk),
        .reset(reset),
        .sample_enable(metrics_sample_enable),
        .thread_mask(thread_mask_reg),
        .total_cycles(total_cycles),
        .useful_lane_cycles(useful_lane_cycles),
        .masked_lane_cycles(masked_lane_cycles),
        .efficiency_percent(efficiency_percent)
    );

endmodule
