// Generic SIMT IPDOM/JOIN metadata lookup.
// Metadata is loaded from two independent $readmemh files.
// Branch record: {branch_pc[31:0], reconvergence_pc[31:0]}.
// JOIN record:   {join_pc[31:0], owner_branch_pc[31:0], reconvergence_pc[31:0]}.
module simt_ipdom_lookup #(
    parameter BRANCH_METADATA_FILE = "build/metadata/simt_branch_metadata.mem",
    parameter JOIN_METADATA_FILE   = "build/metadata/simt_join_metadata.mem",
    parameter integer MAX_BRANCH_ENTRIES = 256,
    parameter integer MAX_JOIN_ENTRIES   = 256
) (
    input  wire [31:0] branch_pc,
    output reg  [31:0] reconvergence_pc,
    output reg         metadata_found,

    input  wire [31:0] join_pc,
    output reg  [31:0] join_owner_branch_pc,
    output reg  [31:0] join_reconvergence_pc,
    output reg         join_metadata_found
);

    reg [63:0] branch_metadata [0:MAX_BRANCH_ENTRIES-1];
    reg [95:0] join_metadata [0:MAX_JOIN_ENTRIES-1];

    integer i;

    initial begin
        for (i = 0; i < MAX_BRANCH_ENTRIES; i = i + 1)
            branch_metadata[i] = 64'hffffffffffffffff;

        for (i = 0; i < MAX_JOIN_ENTRIES; i = i + 1)
            join_metadata[i] = 96'hffffffffffffffffffffffff;

        if (BRANCH_METADATA_FILE != "")
            $readmemh(BRANCH_METADATA_FILE, branch_metadata);

        if (JOIN_METADATA_FILE != "")
            $readmemh(JOIN_METADATA_FILE, join_metadata);
    end

    always @(*) begin
        reconvergence_pc = 32'b0;
        metadata_found = 1'b0;

        for (integer branch_index = 0;
             branch_index < MAX_BRANCH_ENTRIES;
             branch_index = branch_index + 1) begin
            if (!metadata_found &&
                branch_metadata[branch_index][63:32] == branch_pc &&
                branch_metadata[branch_index] != 64'hffffffffffffffff) begin
                reconvergence_pc = branch_metadata[branch_index][31:0];
                metadata_found = 1'b1;
            end
        end
    end

    always @(*) begin
        join_owner_branch_pc = 32'b0;
        join_reconvergence_pc = 32'b0;
        join_metadata_found = 1'b0;

        for (integer join_index = 0;
             join_index < MAX_JOIN_ENTRIES;
             join_index = join_index + 1) begin
            if (!join_metadata_found &&
                join_metadata[join_index][95:64] == join_pc &&
                join_metadata[join_index] != 96'hffffffffffffffffffffffff) begin
                join_owner_branch_pc = join_metadata[join_index][63:32];
                join_reconvergence_pc = join_metadata[join_index][31:0];
                join_metadata_found = 1'b1;
            end
        end
    end

endmodule
