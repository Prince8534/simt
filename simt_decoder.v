module simt_decoder (

    input  wire [31:0] instruction,

    // Register fields
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,

    // Immediate
    output reg  [31:0] immediate,

    // Instruction classification
    output reg  [3:0]  instr_type,

    // ALU control
    output reg  [4:0]  alu_control,

    // Main control signals
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         branch,
    output reg         jump,
    output reg         jalr,

    // Memory operation
    output reg  [2:0]  mem_type,

    // SIMT control
    output reg         tmc,
    output reg         split,
    output reg         join_instr,

    // Special instructions
    output reg         fence,
    output reg         ecall,
    output reg         ebreak,

    // Invalid instruction
    output reg         illegal
);

    // ------------------------------------------------------------
    // RV32I major opcodes
    // ------------------------------------------------------------

    localparam [6:0] OPCODE_LOAD    = 7'b0000011;
    localparam [6:0] OPCODE_MISC_MEM= 7'b0001111;
    localparam [6:0] OPCODE_OP_IMM  = 7'b0010011;
    localparam [6:0] OPCODE_AUIPC   = 7'b0010111;
    localparam [6:0] OPCODE_STORE   = 7'b0100011;
    localparam [6:0] OPCODE_OP      = 7'b0110011;
    localparam [6:0] OPCODE_LUI     = 7'b0110111;
    localparam [6:0] OPCODE_BRANCH  = 7'b1100011;
    localparam [6:0] OPCODE_JALR    = 7'b1100111;
    localparam [6:0] OPCODE_JAL     = 7'b1101111;
    localparam [6:0] OPCODE_SYSTEM  = 7'b1110011;

    // ------------------------------------------------------------
    // Our SIMT custom-0 opcode
    // ------------------------------------------------------------

    localparam [6:0] OPCODE_CUSTOM0 = 7'b0001011;

    // ------------------------------------------------------------
    // Instruction types
    // ------------------------------------------------------------

    localparam [3:0] TYPE_R     = 4'd0;
    localparam [3:0] TYPE_I     = 4'd1;
    localparam [3:0] TYPE_S     = 4'd2;
    localparam [3:0] TYPE_B     = 4'd3;
    localparam [3:0] TYPE_U     = 4'd4;
    localparam [3:0] TYPE_J     = 4'd5;
    localparam [3:0] TYPE_SIMT  = 4'd6;
    localparam [3:0] TYPE_NONE  = 4'd15;

    // ------------------------------------------------------------
    // ALU operations
    // ------------------------------------------------------------

    localparam [4:0] ALU_ADD  = 5'd0;
    localparam [4:0] ALU_SUB  = 5'd1;
    localparam [4:0] ALU_SLL  = 5'd2;
    localparam [4:0] ALU_SLT  = 5'd3;
    localparam [4:0] ALU_SLTU = 5'd4;
    localparam [4:0] ALU_XOR  = 5'd5;
    localparam [4:0] ALU_SRL  = 5'd6;
    localparam [4:0] ALU_SRA  = 5'd7;
    localparam [4:0] ALU_OR   = 5'd8;
    localparam [4:0] ALU_AND  = 5'd9;

    // ------------------------------------------------------------
    // Memory types
    // ------------------------------------------------------------

    localparam [2:0] MEM_BYTE  = 3'd0;
    localparam [2:0] MEM_HALF  = 3'd1;
    localparam [2:0] MEM_WORD  = 3'd2;
    localparam [2:0] MEM_UBYTE = 3'd3;
    localparam [2:0] MEM_UHALF = 3'd4;

    // ------------------------------------------------------------
    // Register fields
    // ------------------------------------------------------------

    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd  = instruction[11:7];

    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];

    // ------------------------------------------------------------
    // Decoder
    // ------------------------------------------------------------

    always @(*) begin

        // Defaults
        immediate   = 32'b0;

        instr_type  = TYPE_NONE;
        alu_control = ALU_ADD;

        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        branch      = 1'b0;
        jump        = 1'b0;
        jalr        = 1'b0;

        mem_type    = MEM_WORD;

        tmc         = 1'b0;
        split       = 1'b0;
        join_instr        = 1'b0;

        fence       = 1'b0;
        ecall       = 1'b0;
        ebreak      = 1'b0;

        illegal     = 1'b0;

        case (opcode)

            // ====================================================
            // R-TYPE
            // ====================================================

            OPCODE_OP: begin

                instr_type = TYPE_R;
                reg_write  = 1'b1;

                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_ADD;
                        else if (funct7 == 7'b0100000)
                            alu_control = ALU_SUB;
                        else
                            illegal = 1'b1;
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SLL;
                        else
                            illegal = 1'b1;
                    end

                    3'b010: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SLT;
                        else
                            illegal = 1'b1;
                    end

                    3'b011: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SLTU;
                        else
                            illegal = 1'b1;
                    end

                    3'b100: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_XOR;
                        else
                            illegal = 1'b1;
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_control = ALU_SRA;
                        else
                            illegal = 1'b1;
                    end

                    3'b110: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_OR;
                        else
                            illegal = 1'b1;
                    end

                    3'b111: begin
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_AND;
                        else
                            illegal = 1'b1;
                    end

                    default:
                        illegal = 1'b1;

                endcase
            end


            // ====================================================
            // I-TYPE ALU
            // ====================================================

            OPCODE_OP_IMM: begin

                instr_type = TYPE_I;
                reg_write  = 1'b1;

                immediate = {{20{instruction[31]}},
                             instruction[31:20]};

                case (funct3)

                    3'b000:
                        alu_control = ALU_ADD;       // ADDI

                    3'b010:
                        alu_control = ALU_SLT;       // SLTI

                    3'b011:
                        alu_control = ALU_SLTU;      // SLTIU

                    3'b100:
                        alu_control = ALU_XOR;       // XORI

                    3'b110:
                        alu_control = ALU_OR;        // ORI

                    3'b111:
                        alu_control = ALU_AND;       // ANDI

                    3'b001: begin                    // SLLI
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SLL;
                        else
                            illegal = 1'b1;
                    end

                    3'b101: begin                    // SRLI/SRAI
                        if (funct7 == 7'b0000000)
                            alu_control = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_control = ALU_SRA;
                        else
                            illegal = 1'b1;
                    end

                    default:
                        illegal = 1'b1;

                endcase
            end


            // ====================================================
            // LOAD
            // ====================================================

            OPCODE_LOAD: begin

                instr_type = TYPE_I;
                reg_write  = 1'b1;
                mem_read   = 1'b1;

                immediate = {{20{instruction[31]}},
                             instruction[31:20]};

                case (funct3)

                    3'b000:
                        mem_type = MEM_BYTE;       // LB

                    3'b001:
                        mem_type = MEM_HALF;       // LH

                    3'b010:
                        mem_type = MEM_WORD;       // LW

                    3'b100:
                        mem_type = MEM_UBYTE;      // LBU

                    3'b101:
                        mem_type = MEM_UHALF;      // LHU

                    default:
                        illegal = 1'b1;

                endcase
            end


            // ====================================================
            // STORE
            // ====================================================

            OPCODE_STORE: begin

                instr_type = TYPE_S;
                mem_write  = 1'b1;

                immediate = {{20{instruction[31]}},
                             instruction[31:25],
                             instruction[11:7]};

                case (funct3)

                    3'b000:
                        mem_type = MEM_BYTE;       // SB

                    3'b001:
                        mem_type = MEM_HALF;       // SH

                    3'b010:
                        mem_type = MEM_WORD;       // SW

                    default:
                        illegal = 1'b1;

                endcase
            end


            // ====================================================
            // BRANCH
            // ====================================================

            OPCODE_BRANCH: begin

                instr_type = TYPE_B;
                branch     = 1'b1;

                immediate = {{19{instruction[31]}},
                             instruction[31],
                             instruction[7],
                             instruction[30:25],
                             instruction[11:8],
                             1'b0};

                case (funct3)

                    3'b000: ; // BEQ
                    3'b001: ; // BNE
                    3'b100: ; // BLT
                    3'b101: ; // BGE
                    3'b110: ; // BLTU
                    3'b111: ; // BGEU

                    default:
                        illegal = 1'b1;

                endcase
            end


            // ====================================================
            // JAL
            // ====================================================

            OPCODE_JAL: begin

                instr_type = TYPE_J;
                jump       = 1'b1;
                reg_write  = 1'b1;

                immediate = {{11{instruction[31]}},
                             instruction[31],
                             instruction[19:12],
                             instruction[20],
                             instruction[30:21],
                             1'b0};
            end


            // ====================================================
            // JALR
            // ====================================================

            OPCODE_JALR: begin

                instr_type = TYPE_I;
                jump       = 1'b1;
                jalr       = 1'b1;
                reg_write  = 1'b1;

                immediate = {{20{instruction[31]}},
                             instruction[31:20]};

                if (funct3 != 3'b000)
                    illegal = 1'b1;
            end


            // ====================================================
            // LUI
            // ====================================================

            OPCODE_LUI: begin

                instr_type = TYPE_U;
                reg_write  = 1'b1;

                immediate = {instruction[31:12], 12'b0};

            end


            // ====================================================
            // AUIPC
            // ====================================================

            OPCODE_AUIPC: begin

                instr_type = TYPE_U;
                reg_write  = 1'b1;

                immediate = {instruction[31:12], 12'b0};

            end


            // ====================================================
            // MISC-MEM
            // ====================================================

            OPCODE_MISC_MEM: begin

                // FENCE
                if (funct3 == 3'b000) begin
                    fence = 1'b1;
                end
                else begin
                    illegal = 1'b1;
                end

            end


            // ====================================================
            // SYSTEM
            // ====================================================

            OPCODE_SYSTEM: begin

                if (funct3 == 3'b000) begin

                    if (instruction[31:20] == 12'b0)
                        ecall = 1'b1;

                    else if (instruction[31:20] == 12'b1)
                        ebreak = 1'b1;

                    else
                        illegal = 1'b1;

                end
                else begin
                    illegal = 1'b1;
                end

            end


            // ====================================================
            // CUSTOM-0 : OUR SIMT EXTENSIONS
            // ====================================================

            OPCODE_CUSTOM0: begin

                instr_type = TYPE_SIMT;

                case (funct3)

                    3'b000: begin
                        // TMC
                        tmc = 1'b1;
                    end

                    3'b001: begin
                        // SPLIT
                        split = 1'b1;
                    end

                    3'b010: begin
                        // JOIN
                        join_instr = 1'b1;
                    end

                    default:
                        illegal = 1'b1;

                endcase
            end


            // ====================================================
            // UNKNOWN OPCODE
            // ====================================================

            default: begin
                illegal = 1'b1;
            end

        endcase

    end

endmodule
