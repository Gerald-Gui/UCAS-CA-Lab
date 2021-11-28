`include "csr.h"

module csr(
    input clk,
    input rst,

    input         csr_we,
    input  [13:0] csr_wnum,
    input  [31:0] csr_wmask,
    input  [31:0] csr_wval,

    input  [13:0] csr_rnum,
    output [31:0] csr_rval,

    input         wb_exc,
    input  [ 5:0] wb_ecode,
    input  [ 8:0] wb_esubcode,
    input  [31:0] wb_pc,
    input  [31:0] wb_badvaddr,

    input ertn_flush,

    output has_int,
    output [31:0] exc_entry,
    output [31:0] exc_retaddr,

    input         tlbsrch_we,
    input         tlbsrch_hit,
    input         tlbrd_we,
    input         tlbwr_we,
    input         tlbfill_we,
    input  [ 3:0] tlb_hit_index,
    
    input         w_tlb_e,
    input  [ 5:0] w_tlb_ps,
    input  [18:0] w_tlb_vppn,
    input  [ 9:0] w_tlb_asid,
    input         w_tlb_g,

    input  [19:0] w_tlb_ppn0,
    input  [ 1:0] w_tlb_plv0,
    input  [ 1:0] w_tlb_mat0,
    input         w_tlb_d0,
    input         w_tlb_v0,

    input  [19:0] w_tlb_ppn1,
    input  [ 1:0] w_tlb_plv1,
    input  [ 1:0] w_tlb_mat1,
    input         w_tlb_d1,
    input         w_tlb_v1,

    output         r_tlb_e,
    output  [ 5:0] r_tlb_ps,
    output  [18:0] r_tlb_vppn,
    output  [ 9:0] r_tlb_asid,
    output         r_tlb_g,

    output  [19:0] r_tlb_ppn0,
    output  [ 1:0] r_tlb_plv0,
    output  [ 1:0] r_tlb_mat0,
    output         r_tlb_d0,
    output         r_tlb_v0,

    output  [19:0] r_tlb_ppn1,
    output  [ 1:0] r_tlb_plv1,
    output  [ 1:0] r_tlb_mat1,
    output         r_tlb_d1,
    output         r_tlb_v1
);

    // lab8 csrs
    reg  [ 1:0] csr_crmd_plv;
    reg         csr_crmd_ie;
    reg         csr_crmd_da;
    reg         csr_crmd_pg;
    reg  [ 1:0] csr_crmd_datf;
    reg  [ 1:0] csr_crmd_datm;
    wire [31:0] csr_crmd_rval;

    reg  [ 1:0] csr_prmd_pplv;
    reg         csr_prmd_pie;
    wire [31:0] csr_prmd_rval;

    reg  [12:0] csr_ecfg_lie;
    wire [31:0] csr_ecfg_rval;

    reg  [12:0] csr_estat_is;
    reg  [ 5:0] csr_estat_ecode;
    reg  [ 8:0] csr_estat_esubcode;
    wire [31:0] csr_estat_rval;

    reg  [31:0] csr_era_pc;
    wire [31:0] csr_era_rval;

    reg  [25:0] csr_eentry_va;
    wire [31:0] csr_eentry_rval;

    reg  [31:0] csr_save_data [3:0];
    wire [31:0] csr_save_rval [3:0];

    reg  [31:0] csr_badv_vaddr;
    wire [31:0] csr_badv_rval;

    reg  [31:0] csr_tid_tid;
    wire [31:0] csr_tid_rval;

    reg         csr_tcfg_en;
    reg         csr_tcfg_period;
    reg  [29:0] csr_tcfg_initval;
    wire [31:0] csr_tcfg_rval;

    wire [31:0] tcfg_nxt_val;
    wire [31:0] csr_tval_rval;
    reg  [31:0] timer_cnt;

    wire [31:0] csr_ticlr_rval;

    reg  [ 3:0] csr_tlbidx_index;
    reg  [ 5:0] csr_tlbidx_ps;
    reg         csr_tlbidx_ne;
    wire [31:0] csr_tlbidx_rval;

    reg  [18:0] csr_tlbehi_vppn;
    wire [31:0] csr_tlbehi_rval;

    reg         csr_tlbelo0_v;
    reg         csr_tlbelo0_d;
    reg  [ 1:0] csr_tlbelo0_plv;
    reg  [ 1:0] csr_tlbelo0_mat;
    reg         csr_tlbelo0_g;
    reg  [23:0] csr_tlbelo0_ppn;
    wire [31:0] csr_tlbelo0_rval;

    reg         csr_tlbelo1_v;
    reg         csr_tlbelo1_d;
    reg  [ 1:0] csr_tlbelo1_plv;
    reg  [ 1:0] csr_tlbelo1_mat;
    reg         csr_tlbelo1_g;
    reg  [23:0] csr_tlbelo1_ppn;
    wire [31:0] csr_tlbelo1_rval;

    reg  [ 9:0] csr_asid_asid;
    wire [31:0] csr_asid_rval;

    reg  [25:0] csr_tlbrentry_pa;
    wire [31:0] csr_tlbrentry_rval;

    /*
     *  CRMD
     */
    // plv ie
    always @ (posedge clk) begin
        if (rst) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end else if (wb_exc) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
        end else if (csr_we && csr_wnum == `CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wval[`CSR_CRMD_PLV] |
                           ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
            csr_crmd_ie  <= csr_wmask[`CSR_CRMD_IE]  & csr_wval[`CSR_CRMD_IE]  |
                           ~csr_wmask[`CSR_CRMD_IE]  & csr_crmd_ie;
        end
    end
    // da pg datf datm
    always @ (posedge clk) begin
        if (rst) begin
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end else if (wb_exc && wb_ecode == `ECODE_TLBR) begin
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end else if (ertn_flush && wb_ecode == `ECODE_TLBR) begin
            csr_crmd_da <= 1'b0;
            csr_crmd_pg <= 1'b1;
            csr_crmd_datf <= 2'b01;
            csr_crmd_datm <= 2'b01;
        end else if (csr_we && csr_wnum == `CSR_CRMD) begin
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wval[`CSR_CRMD_DA] |
                          ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wval[`CSR_CRMD_PG] |
                          ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
            csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wval[`CSR_CRMD_DATF] |
                            ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wval[`CSR_CRMD_DATM] |
                            ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
        end
    end
    assign csr_crmd_rval = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

    /*
     *  PRMD
     */
    always @ (posedge clk) begin
        if(rst) begin
            csr_prmd_pie <= 1'b0;
            csr_prmd_pplv <= 2'b0;
        end else if (wb_exc) begin
            csr_prmd_pie  <= csr_crmd_ie;
            csr_prmd_pplv <= csr_crmd_plv;
        end else if (csr_we && csr_wnum == `CSR_PRMD) begin
            csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE]  & csr_wval[`CSR_PRMD_PIE]  |
                            ~csr_wmask[`CSR_PRMD_PIE]  & csr_prmd_pie;
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wval[`CSR_PRMD_PPLV] |
                            ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        end
    end
    assign csr_prmd_rval = {29'b0, csr_prmd_pie, csr_prmd_pplv};

    /*
     *  ECFG
     */
    always @ (posedge clk) begin
        if (rst) begin
            csr_ecfg_lie <= 13'b0;
        end else if (csr_we && csr_wnum == `CSR_ECFG) begin
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wval[`CSR_ECFG_LIE] |
                           ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
        end
    end
    assign csr_ecfg_rval = {19'b0, csr_ecfg_lie};

    /*
     *  ESTAT
     */
    // field: IS 12:0
    always @ (posedge clk) begin
        // software int
        if (rst) begin
            csr_estat_is[1:0] <= 2'b0;
        end else if (csr_we && csr_wnum == `CSR_ESTAT) begin
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wval[`CSR_ESTAT_IS10] |
                                ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
        end

        // TODO(lab9): 
        // 9:2 hardware int
        csr_estat_is[9:2] <= 8'b0;
        // 10  undefined -> reserve to 0
        csr_estat_is[10]  <= 1'b0;
        // 11  timer int
        if(rst) begin
            csr_estat_is[11] <= 1'b0;
        end else if (timer_cnt == 32'b0) begin
            csr_estat_is[11] <= 1'b1;
        end else if (csr_we && csr_wnum == `CSR_TICLR    &&
                               csr_wmask[`CSR_TICLR_CLR] &&
                               csr_wval[`CSR_TICLR_CLR]) begin
            csr_estat_is[11] <= 1'b0;
        end
        // 12  ipi int (no need to imple -> set to 0)
        csr_estat_is[12]  <= 1'b0;
    end

    // field: ECODE     21:16
    //        ESUBCODE  30:22
    always @ (posedge clk) begin
        if (rst) begin
            csr_estat_ecode    <= 6'b0;
            csr_estat_esubcode <= 9'b0;
        end else if (wb_exc) begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end

    assign csr_estat_rval = {1'b0,
                             csr_estat_esubcode,
                             csr_estat_ecode,
                             3'b0,
                             csr_estat_is};

    /*
     *  ERA
     */
    always @ (posedge clk) begin
        if(rst) begin
            csr_era_pc <= 32'b0;
        end else if (wb_exc) begin
            csr_era_pc <= wb_pc;
        end else if (csr_we && csr_wnum == `CSR_ERA) begin
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wval[`CSR_ERA_PC] |
                         ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
        end
    end
    assign csr_era_rval = csr_era_pc;

    /*
     *  EENTRY
     */
    always @ (posedge clk) begin
        if (rst) begin
            csr_eentry_va <= 26'b0;
        end else if (csr_we && csr_wnum == `CSR_EENTRY) begin
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wval[`CSR_EENTRY_VA] |
                            ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
        end
    end
    assign csr_eentry_rval = {csr_eentry_va, 6'b0};

    /*
     *  SAVE 0~3
     */
    always @ (posedge clk) begin
        if(rst) begin
            csr_save_data[0] <= 32'b0;
            csr_save_data[1] <= 32'b0;
            csr_save_data[2] <= 32'b0;
            csr_save_data[3] <= 32'b0;
        end else if (csr_we) begin
            if (csr_wnum == `CSR_SAVE0) begin
                csr_save_data[0] <= csr_wmask[`CSR_SAVE_DATA] & csr_wval[`CSR_SAVE_DATA] |
                                   ~csr_wmask[`CSR_SAVE_DATA] & csr_save_data[0];
            end
            if (csr_wnum == `CSR_SAVE1) begin
                csr_save_data[1] <= csr_wmask[`CSR_SAVE_DATA] & csr_wval[`CSR_SAVE_DATA] |
                                   ~csr_wmask[`CSR_SAVE_DATA] & csr_save_data[1];
            end
            if (csr_wnum == `CSR_SAVE2) begin
                csr_save_data[2] <= csr_wmask[`CSR_SAVE_DATA] & csr_wval[`CSR_SAVE_DATA] |
                                   ~csr_wmask[`CSR_SAVE_DATA] & csr_save_data[2];
            end
            if (csr_wnum == `CSR_SAVE3) begin
                csr_save_data[3] <= csr_wmask[`CSR_SAVE_DATA] & csr_wval[`CSR_SAVE_DATA] |
                                   ~csr_wmask[`CSR_SAVE_DATA] & csr_save_data[3];
            end
        end
    end
    // assign csr_save_rval = csr_save_data;
    assign csr_save_rval[0] = csr_save_data[0];
    assign csr_save_rval[1] = csr_save_data[1];
    assign csr_save_rval[2] = csr_save_data[2];
    assign csr_save_rval[3] = csr_save_data[3];

    /*
     *  BADV
     */
    always @ (posedge clk) begin
        if(rst)begin
            csr_badv_vaddr <= 32'b0;
        end
        if (wb_exc) begin
            if (wb_ecode == `ECODE_ADE) begin
                if (wb_esubcode == `ESUBCODE_ADEF) begin
                    csr_badv_vaddr <= wb_pc;
                end
            end else if (wb_ecode == `ECODE_ALE) begin
                csr_badv_vaddr <= wb_badvaddr;
            end
        end
    end
    assign csr_badv_rval = csr_badv_vaddr;

    /*
     *  TID
     */
    always @ (posedge clk) begin
        if (rst) begin
            csr_tid_tid <= 32'd0;
        end else if (csr_we && csr_wnum == `CSR_TID) begin
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wval[`CSR_TID_TID] |
                          ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
        end
    end
    assign csr_tid_rval = csr_tid_tid;

    /*
     *  TCFG
     */
    always @ (posedge clk) begin
        if (rst) begin
            csr_tcfg_en <= 1'b0;
            csr_tcfg_period <= 1'b0;
            csr_tcfg_initval <= 30'b0;
        end else if (csr_we && csr_wnum == `CSR_TCFG) begin
            csr_tcfg_en      <= csr_wmask[`CSR_TCFG_EN] & csr_wval[`CSR_TCFG_EN] |
                               ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
            csr_tcfg_period  <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wval[`CSR_TCFG_PERIOD] |
                               ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_period;
            csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wval[`CSR_TCFG_INITVAL] |
                               ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
        end
    end
    assign csr_tcfg_rval = {csr_tcfg_initval, csr_tcfg_period, csr_tcfg_en};

    /*
     *  TVAL
     */
    assign tcfg_nxt_val = csr_wmask & csr_wval |
                         ~csr_wmask & csr_tcfg_rval;
    always @ (posedge clk) begin
        if (rst) begin
            timer_cnt <= 32'hffffffff;
        end else if (csr_we && csr_wnum == `CSR_TCFG && tcfg_nxt_val[`CSR_TCFG_EN]) begin
            timer_cnt <= {tcfg_nxt_val[`CSR_TCFG_INITVAL], 2'b0};
        end else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
            if (timer_cnt == 32'b0 && csr_tcfg_period) begin
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            end else begin
                timer_cnt <= timer_cnt - 32'd1;
            end
        end
    end
    assign csr_tval_rval = timer_cnt;

    /*
     *  TICLR
     */
    assign csr_ticlr_rval = 32'b0;

    /*
     *  TLBIDX
     */
    // reg  [ 3:0] csr_tlbidx_index;
    // reg  [ 5:0] csr_tlbidx_ps;
    // reg         csr_tlbidx_ne;
    // wire [31:0] csr_tlbidx_rval;
    always @ (posedge clk) begin
        if (rst) begin
            csr_tlbidx_index <= 4'b0;
            csr_tlbidx_ps    <= 6'b0;
            csr_tlbidx_ne    <= 1'b1;
        end else if (tlbrd_we) begin
            csr_tlbidx_index <= tlb_hit_index;
            csr_tlbidx_ps <= w_tlb_ps;
            csr_tlbidx_ne <= ~w_tlb_e;
        end else if (tlbsrch_we) begin
            csr_tlbidx_index <= tlbsrch_hit ? tlb_hit_index : csr_tlbidx_index;
            csr_tlbidx_ne <= ~tlbsrch_hit;
        end else if (csr_we && csr_wnum == `CSR_TLBIDX) begin
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wval[`CSR_TLBIDX_INDEX] |
                               ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wval[`CSR_TLBIDX_PS] |
                            ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wval[`CSR_TLBIDX_NE] |
                            ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
        end
    end
    assign csr_tlbidx_rval = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};

    /*
     *  TLBEHI
     */
    always @ (posedge clk) begin
        if (rst) begin
            csr_tlbehi_vppn <= 19'b0;
        end else if (tlbrd_we) begin
            csr_tlbehi_vppn <= w_tlb_vppn;
        end else if (csr_we && csr_wnum == `CSR_TLBEHI) begin
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wval[`CSR_TLBEHI_VPPN] |
                              ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
        end
        // TODO: TLB related exceptions
    end
    assign csr_tlbehi_rval = {csr_tlbehi_vppn, 13'b0};

    /*
     *  TLBELO
     */
    always @ (posedge clk) begin
        if (rst) begin
            csr_tlbelo0_v   <= 1'b0;
            csr_tlbelo0_d   <= 1'b0;
            csr_tlbelo0_plv <= 2'b0;
            csr_tlbelo0_mat <= 2'b0;
            csr_tlbelo0_g   <= 1'b0;
            csr_tlbelo0_ppn <= 24'b0;

            csr_tlbelo1_v   <= 1'b0;
            csr_tlbelo1_d   <= 1'b0;
            csr_tlbelo1_plv <= 2'b0;
            csr_tlbelo1_mat <= 2'b0;
            csr_tlbelo1_g   <= 1'b0;
            csr_tlbelo1_ppn <= 24'b0;
        end else if (tlbrd_we) begin
            csr_tlbelo0_v   <= w_tlb_v0;
            csr_tlbelo0_d   <= w_tlb_d0;
            csr_tlbelo0_plv <= w_tlb_plv0;
            csr_tlbelo0_mat <= w_tlb_mat0;
            csr_tlbelo0_g   <= w_tlb_g;
            csr_tlbelo0_ppn <= {4'b0, w_tlb_ppn0};

            csr_tlbelo1_v   <= w_tlb_v1;
            csr_tlbelo1_d   <= w_tlb_d1;
            csr_tlbelo1_plv <= w_tlb_plv1;
            csr_tlbelo1_mat <= w_tlb_mat1;
            csr_tlbelo1_g   <= w_tlb_g;
            csr_tlbelo1_ppn <= {4'b0, w_tlb_ppn1};
        end else if (csr_we) begin
            if (csr_wnum == `CSR_TLBELO0) begin
                csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wval[`CSR_TLBELO_V]   |
                                  ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo0_v;
                csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wval[`CSR_TLBELO_D]   |
                                  ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo0_d;
                csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wval[`CSR_TLBELO_PLV] |
                                  ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
                csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wval[`CSR_TLBELO_MAT] |
                                  ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
                csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wval[`CSR_TLBELO_G]   |
                                  ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo0_g;
                csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wval[`CSR_TLBELO_PPN] |
                                  ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
            end else if (csr_wnum == `CSR_TLBELO1) begin
                csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wval[`CSR_TLBELO_V]   |
                                  ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo1_v;
                csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wval[`CSR_TLBELO_D]   |
                                  ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo1_d;
                csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wval[`CSR_TLBELO_PLV] |
                                  ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
                csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wval[`CSR_TLBELO_MAT] |
                                  ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
                csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wval[`CSR_TLBELO_G]   |
                                  ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo1_g;
                csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wval[`CSR_TLBELO_PPN] |
                                  ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
            end
        end
    end
    assign csr_tlbelo0_rval = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
    assign csr_tlbelo1_rval = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};

    /*
     *  ASID
     */
    always @ (posedge clk) begin
        if (rst) begin
            csr_asid_asid <= 10'b0;
        end else if (tlbrd_we) begin
            csr_asid_asid <= w_tlb_asid;
        end else if (csr_we && csr_wnum == `CSR_ASID) begin
            csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wval[`CSR_ASID_ASID] |
                            ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
        end
    end
    // set ASIDBITS to 10
    assign csr_asid_rval = {8'b0, 8'd10, 6'b0, csr_asid_asid};

    /*
     *  TLBRENTRY
     */
    always @ (posedge clk) begin
        if (rst) begin
            csr_tlbrentry_pa <= 26'b0;
        end else if (csr_we && csr_wnum == `CSR_TLBRENTRY) begin
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wval[`CSR_TLBRENTRY_PA] |
                               ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
        end
    end
    assign csr_tlbrentry_rval = {csr_tlbrentry_pa, 6'b0};

    /*
     * CSR output logic
     */
    assign csr_rval = {32{csr_rnum == `CSR_CRMD  }}  & csr_crmd_rval    |
                      {32{csr_rnum == `CSR_PRMD  }}  & csr_prmd_rval    |
                      {32{csr_rnum == `CSR_ESTAT }}  & csr_estat_rval   |
                      {32{csr_rnum == `CSR_ERA   }}  & csr_era_rval     |
                      {32{csr_rnum == `CSR_EENTRY}}  & csr_eentry_rval  |
                      {32{csr_rnum == `CSR_SAVE0 }}  & csr_save_rval[0] |
                      {32{csr_rnum == `CSR_SAVE1 }}  & csr_save_rval[1] |
                      {32{csr_rnum == `CSR_SAVE2 }}  & csr_save_rval[2] |
                      {32{csr_rnum == `CSR_SAVE3 }}  & csr_save_rval[3] |
                      {32{csr_rnum == `CSR_ECFG  }}  & csr_ecfg_rval    |
                      {32{csr_rnum == `CSR_BADV  }}  & csr_badv_rval    |
                      {32{csr_rnum == `CSR_TID   }}  & csr_tid_rval     |
                      {32{csr_rnum == `CSR_TCFG  }}  & csr_tcfg_rval    |
                      {32{csr_rnum == `CSR_TVAL  }}  & csr_tval_rval    |
                      {32{csr_rnum == `CSR_TICLR }}  & csr_ticlr_rval   |
                      {32{csr_rnum == `CSR_TLBIDX}}  & csr_tlbidx_rval  |
                      {32{csr_rnum == `CSR_TLBEHI}}  & csr_tlbehi_rval  |
                      {32{csr_rnum == `CSR_TLBELO0}} & csr_tlbelo0_rval |
                      {32{csr_rnum == `CSR_TLBELO1}} & csr_tlbelo1_rval |
                      {32{csr_rnum == `CSR_TLBRENTRY}} & csr_tlbrentry_rval;
    assign exc_entry   = csr_eentry_rval;
    assign exc_retaddr = csr_era_rval;
    assign has_int     = (|(csr_estat_is & csr_ecfg_lie)) & csr_crmd_ie;

endmodule
