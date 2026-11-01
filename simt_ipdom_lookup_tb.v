`timescale 1ns/1ps

module simt_ipdom_lookup_tb;
    reg [31:0] branch_pc;
    reg [31:0] join_pc;
    wire [31:0] reconvergence_pc;
    wire metadata_found;
    wire [31:0] join_owner_branch_pc;
    wire [31:0] join_reconvergence_pc;
    wire join_metadata_found;
    integer errors;

    simt_ipdom_lookup #(
        .BRANCH_METADATA_FILE("simt_ipdom_lookup_test_branch.mem"),
        .JOIN_METADATA_FILE("simt_ipdom_lookup_test_join.mem")
    ) dut (
        .branch_pc(branch_pc),
        .reconvergence_pc(reconvergence_pc),
        .metadata_found(metadata_found),
        .join_pc(join_pc),
        .join_owner_branch_pc(join_owner_branch_pc),
        .join_reconvergence_pc(join_reconvergence_pc),
        .join_metadata_found(join_metadata_found)
    );

    initial begin
        errors = 0;
        branch_pc = 32'h00000004;
        join_pc = 32'h0000000c;
        #2;

        if (metadata_found && reconvergence_pc == 32'h00000018)
            $display("[PASS] Branch metadata loaded and found");
        else begin
            $display("[FAIL] Branch metadata lookup");
            errors = errors + 1;
        end

        if (join_metadata_found &&
            join_owner_branch_pc == 32'h00000004 &&
            join_reconvergence_pc == 32'h00000018)
            $display("[PASS] JOIN owner and reconvergence metadata loaded");
        else begin
            $display("[FAIL] JOIN metadata lookup");
            errors = errors + 1;
        end

        branch_pc = 32'h00000044;
        join_pc = 32'h0000004c;
        #1;

        if (!metadata_found && !join_metadata_found)
            $display("[PASS] Missing entries are reported");
        else begin
            $display("[FAIL] Missing entry detection");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("ALL LOADABLE IPDOM LOOKUP TESTS PASSED");
        else
            $fatal(1, "Loadable IPDOM lookup test failed: %0d errors", errors);
        $finish;
    end
endmodule
