module tlb #(
        parameter TLBNUM = 16
    )(
        input   clk,

        // search port 0 (for fetch)
        input  [              18:0] s0_vppn,
        input                       s0_va_bit12,
        input  [               9:0] s0_asid,
        output                      s0_found,
        output [$clog2(TLBNUM)-1:0] s0_index,
        output [              19:0] s0_ppn,
        output [               5:0] s0_ps,
        output [               1:0] s0_plv,
        output [               1:0] s0_mat,
        output                      s0_d,
        output                      s0_v,

        // search port 1 (for load/store)
        input  [              18:0] s1_vppn,
        input                       s1_va_bit12,
        input  [               9:0] s1_asid,
        output                      s1_found,
        output [$clog2(TLBNUM)-1:0] s1_index,
        output [              19:0] s1_ppn,
        output [               5:0] s1_ps,
        output [               1:0] s1_plv,
        output [               1:0] s1_mat,
        output                      s1_d,
        output                      s1_v,

        // invtlb opcode
        input  [               4:0] invtlb_op,

        // write port
        input                       we,
        input  [$clog2(TLBNUM)-1:0] w_index,
        input                       w_e,
        input  [              18:0] w_vppn,
        input  [               5:0] w_ps,
        input  [               9:0] w_asid,
        input                       w_g,

        input  [              19:0] w_ppn0,
        input  [               1:0] w_plv0,
        input  [               1:0] w_mat0,
        input                       w_d0,
        input                       w_v0,

        input  [              19:0] w_ppn1,
        input  [               1:0] w_plv1,
        input  [               1:0] w_mat1,
        input                       w_d1,
        input                       w_v1,

        // read port
        input  [$clog2(TLBNUM)-1:0] r_index,
        output                      r_e,
        output [              18:0] r_vppn,
        output [               5:0] r_ps,
        output [               9:0] r_asid,
        output                      r_g,

        output [              19:0] r_ppn0,
        output [               1:0] r_plv0,
        output [               1:0] r_mat0,
        output                      r_d0,
        output                      r_v0,

        output [              19:0] r_ppn1,
        output [               1:0] r_plv1,
        output [               1:0] r_mat1,
        output                      r_d1,
        output                      r_v1
    );

    reg [TLBNUM-1:0] tlb_e;
    reg [TLBNUM-1:0] tlb_ps;    // 1 -> 4 MB
                                // 0 -> 4 KB
    
    reg [18:0] tlb_vppn [TLBNUM-1:0];
    reg [ 9:0] tlb_asid [TLBNUM-1:0];
    reg        tlb_g    [TLBNUM-1:0];
    
    reg [19:0] tlb_ppn0 [TLBNUM-1:0];
    reg [ 1:0] tlb_plv0 [TLBNUM-1:0];
    reg [ 1:0] tlb_mat0 [TLBNUM-1:0];
    reg        tlb_d0   [TLBNUM-1:0];
    reg        tlb_v0   [TLBNUM-1:0];
    
    reg [19:0] tlb_ppn1 [TLBNUM-1:0];
    reg [ 1:0] tlb_plv1 [TLBNUM-1:0];
    reg [ 1:0] tlb_mat1 [TLBNUM-1:0];
    reg        tlb_d1   [TLBNUM-1:0];
    reg        tlb_v1   [TLBNUM-1:0];

    wire [TLBNUM-1:0] match0;
    wire [TLBNUM-1:0] match1;

    wire s0_ppg_sel;
    wire s1_ppg_sel;

    // 0 -> G == 0
    // 1 -> G == 1
    // 2 -> s1_asid == ASID
    // 3 -> s1_vppn == VPPN (with PS)
    wire [TLBNUM-1:0] inv_match [3:0];
    wire [TLBNUM-1:0] inv_op_mask [31:0];

    always @ (posedge clk) begin
        if (we) begin
            tlb_e   [w_index] <= w_e;
            tlb_ps  [w_index] <= w_ps == 6'd22;
            tlb_vppn[w_index] <= w_vppn;
            tlb_asid[w_index] <= w_asid;
            tlb_g   [w_index] <= w_g;

            tlb_ppn0[w_index] <= w_ppn0;
            tlb_plv0[w_index] <= w_plv0;
            tlb_mat0[w_index] <= w_mat0;
            tlb_d0  [w_index] <= w_d0;
            tlb_v0  [w_index] <= w_v0;

            tlb_ppn1[w_index] <= w_ppn1;
            tlb_plv1[w_index] <= w_plv1;
            tlb_mat1[w_index] <= w_mat1;
            tlb_d1  [w_index] <= w_d1;
            tlb_v1  [w_index] <= w_v1;
        end else begin
            tlb_e <= ~inv_op_mask[invtlb_op] & tlb_e;
        end
    end

    // read port
    assign r_e    = tlb_e   [r_index];
    assign r_vppn = tlb_vppn[r_index];
    assign r_ps   = tlb_ps  [r_index] ? 6'd22 : 6'd12;
    assign r_asid = tlb_asid[r_index];
    assign r_g    = tlb_g   [r_index];
    
    assign r_ppn0 = tlb_ppn0[r_index];
    assign r_plv0 = tlb_plv0[r_index];
    assign r_mat0 = tlb_mat0[r_index];
    assign r_d0   = tlb_d0  [r_index];
    assign r_v0   = tlb_v0  [r_index];

    assign r_ppn1 = tlb_ppn1[r_index];
    assign r_plv1 = tlb_plv1[r_index];
    assign r_mat1 = tlb_mat1[r_index];
    assign r_d1   = tlb_d1  [r_index];
    assign r_v1   = tlb_v1  [r_index];

    // search match
    genvar i;
    generate for (i = 0; i < TLBNUM; i = i + 1) begin
        assign match0[i] = tlb_e[i] && (tlb_g[i] || tlb_asid[i] == s0_asid) &&
                            s0_vppn[18:10] == tlb_vppn[i][18:10]            &&  // cmp high bits whatever ps is
                           (s0_vppn[ 9: 0] == tlb_vppn[i][ 9: 0] || tlb_ps[i]); // if ps == 4 KB, cmp low bits
        assign match1[i] = tlb_e[i] && (tlb_g[i] || tlb_asid[i] == s1_asid) &&
                            s1_vppn[18:10] == tlb_vppn[i][18:10]            &&
                           (s1_vppn[ 9: 0] == tlb_vppn[i][ 9: 0] || tlb_ps[i]);
    end
    endgenerate

    // search port
    assign s0_found = |match0;
    mylog2 #(.WIDTH(TLBNUM)) s0_log2(.src(match0), .res(s0_index));
    assign s0_ppg_sel = tlb_ps[s0_index] ? s0_vppn[9] : s0_va_bit12;
    assign s0_ps      = tlb_ps[s0_index] ? 6'd22 : 6'd12;

    assign s0_ppn   = s0_ppg_sel ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
    assign s0_plv   = s0_ppg_sel ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
    assign s0_mat   = s0_ppg_sel ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
    assign s0_d     = s0_ppg_sel ? tlb_d1  [s0_index] : tlb_d0  [s0_index];
    assign s0_v     = s0_ppg_sel ? tlb_v1  [s0_index] : tlb_v0  [s0_index];

    assign s1_found = |match1;
    mylog2 #(.WIDTH(TLBNUM)) s1_log2(.src(match1), .res(s1_index));
    assign s1_ppg_sel = tlb_ps[s1_index] ? s1_vppn[9] : s1_va_bit12;
    assign s1_ps      = tlb_ps[s1_index] ? 6'd22 : 6'd12;

    assign s1_ppn   = s1_ppg_sel ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
    assign s1_plv   = s1_ppg_sel ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
    assign s1_mat   = s1_ppg_sel ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
    assign s1_d     = s1_ppg_sel ? tlb_d1  [s1_index] : tlb_d0  [s1_index];
    assign s1_v     = s1_ppg_sel ? tlb_v1  [s1_index] : tlb_v0  [s1_index];

    generate for (i = 0; i < TLBNUM; i = i + 1) begin
       assign inv_match[0][i] = ~tlb_g[i];
       assign inv_match[1][i] =  tlb_g[i];
       assign inv_match[2][i] = s1_asid == tlb_asid[i];
       assign inv_match[3][i] = s1_vppn[18:10] == tlb_vppn[i][18:10]            &&
                               (s1_vppn[ 9: 0] == tlb_vppn[i][ 9: 0] || tlb_ps[i]);
    end        
    endgenerate

    assign inv_op_mask[0] = 16'b0;  // TODO: update to 16'hffff if enable INVTLB
    assign inv_op_mask[1] = 16'hffff;
    assign inv_op_mask[2] = inv_match[1];
    assign inv_op_mask[3] = inv_match[0];
    assign inv_op_mask[4] = inv_match[0] & inv_match[2];
    assign inv_op_mask[5] = inv_match[0] & inv_match[2] & inv_match[3];
    assign inv_op_mask[6] = (inv_match[0] | inv_match[2]) & inv_match[3];
    generate for (i = 7; i < 32; i = i + 1) begin
        assign inv_op_mask[i] = 16'b0; 
    end
    endgenerate
endmodule
