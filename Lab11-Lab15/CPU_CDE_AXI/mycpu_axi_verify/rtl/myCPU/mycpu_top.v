`include "mycpu.h"

module mycpu_top(
    input           aclk,
    input           aresetn,
    // read requeset
    // master->slave
    output [ 3:0]   arid,
    output [31:0]   araddr,
    output [ 7:0]   arlen,
    output [ 2:0]   arsize,
    output [ 1:0]   arburst,
    output [ 1:0]   arlock,
    output [ 3:0]   arcache,
    output [ 2:0]   arprot,
    output          arvalid,
    // slave->master
    input           arready,
    // read response
    // slave->master
    input  [ 3:0]   rid,
    input  [31:0]   rdata,
    input  [ 1:0]   rresp,
    input           rlast,
    input           rvalid,
    // master->slave
    output          rready,
    // write request
    // master->slave
    output [ 3:0]   awid,
    output [31:0]   awaddr,
    output [ 7:0]   awlen,
    output [ 2:0]   awsize,
    output [ 1:0]   awburst,
    output [ 1:0]   awlock,
    output [ 3:0]   awcache,
    output [ 2:0]   awprot,
    output          awvalid,
    // slave->master
    input           awready,
    // write data
    // master->slave
    output  [ 3:0]  wid,
    output  [31:0]  wdata,
    output  [ 3:0]  wstrb,
    output          wlast,
    output          wvalid,
    // slave->master
    input           wready,
    // write response
    // slave->master
    input  [ 3:0]   bid,
    input  [ 1:0]   bresp,
    input           bvalid,
    // master->slave
    output          bready,

    // debug
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge aclk) reset <= ~aresetn; 

wire         fs_allowin;
wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         pfs_to_fs_valid;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;


wire [`ES_FWD_BLK_BUS_WD - 1:0] es_fwd_blk_bus;
wire [`MS_FWD_BLK_BUS_WD - 1:0] ms_fwd_blk_bus;

wire [64:0] mul_res_bus;
wire [63:0] div_res_bus;
wire        div_finish;

// CSR ports
wire [13:0] csr_wnum;
wire        csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wval;
wire [13:0] csr_rnum;
wire [31:0] csr_rval;

wire        wb_exc;
wire [ 5:0] wb_ecode;
wire [ 8:0] wb_esubcode;
wire [31:0] wb_pc;
wire [31:0] wb_badvaddr;
wire        badv_is_pc;
wire        badv_is_mem;

wire        wb_ertn;
wire        csr_has_int;
wire [31:0] exc_entry;
wire [31:0] exc_retaddr;

wire        wb_refetch;

wire        wb_flush;
wire [31:0] wb_flush_target;

wire [ 1:0] csr_crmd_plv;
wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [ 1:0] csr_crmd_datf;
wire [ 1:0] csr_crmd_datm;

wire [ 9:0] csr_asid_asid;
wire [18:0] csr_tlbehi_vppn;
wire [ 3:0] csr_tlbidx_index;

wire        csr_dmw0_plv0;
wire        csr_dmw0_plv3;
wire [ 1:0] csr_dmw0_mat;
wire [ 2:0] csr_dmw0_pseg;
wire [ 2:0] csr_dmw0_vseg;

wire        csr_dmw1_plv0;
wire        csr_dmw1_plv3;
wire [ 1:0] csr_dmw1_mat;
wire [ 2:0] csr_dmw1_pseg;
wire [ 2:0] csr_dmw1_vseg;

wire tlbrd_we;
wire tlbsrch_we;
wire tlbwr_we;
wire tlbfill_we;
wire tlbsrch_hit;
wire [ 3:0] tlbsrch_hit_index;

wire [`ES_CSR_BLK_BUS_WD-1:0] es_csr_blk_bus;
wire [`MS_CSR_BLK_BUS_WD-1:0] ms_csr_blk_bus;
wire [`WS_CSR_BLK_BUS_WD-1:0] ws_csr_blk_bus;

wire ms_to_es_ls_cancel;

// inst sram interface
wire            inst_sram_req;
wire            inst_sram_wr;
wire  [ 1:0]    inst_sram_size;
wire  [31:0]    inst_sram_addr;
wire  [ 3:0]    inst_sram_wstrb;
wire  [31:0]    inst_sram_wdata;
wire            inst_sram_addr_ok;
wire            inst_sram_data_ok;
wire [31:0]     inst_sram_rdata;
// data sram interface
wire            data_sram_req;
wire            data_sram_wr;
wire  [ 1:0]    data_sram_size;
wire  [31:0]    data_sram_addr;
wire  [ 3:0]    data_sram_wstrb;
wire  [31:0]    data_sram_wdata;
wire            data_sram_addr_ok;
wire            data_sram_data_ok;
wire [31:0]     data_sram_rdata;

// TLB ports
wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [ 9:0] s0_asid = csr_asid_asid;
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_ppn;
wire [ 5:0] s0_ps;
wire [ 1:0] s0_plv;
wire [ 1:0] s0_mat;
wire        s0_d;
wire        s0_v;
wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [ 9:0] s1_asid;
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_ppn;
wire [ 5:0] s1_ps;
wire [ 1:0] s1_plv;
wire [ 1:0] s1_mat;
wire        s1_d;
wire        s1_v;
wire [ 4:0] invtlb_op;
wire        invtlb_valid;
wire        we;
wire [ 3:0] w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [ 5:0] w_ps;
wire [ 9:0] w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [ 1:0] w_plv0;
wire [ 1:0] w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [ 1:0] w_plv1;
wire [ 1:0] w_mat1;
wire        w_d1;
wire        w_v1;
wire [ 3:0] r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [ 5:0] r_ps;
wire [ 9:0] r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [ 1:0] r_plv0;
wire [ 1:0] r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [ 1:0] r_plv1;
wire [ 1:0] r_mat1;
wire        r_d1;
wire        r_v1;


assign wb_flush = wb_exc | wb_ertn | wb_refetch;
assign wb_flush_target = wb_exc     ? exc_entry     :
                         wb_refetch ? wb_pc + 32'd4 :
                                      exc_retaddr;

sram_AXI_bridge cpu_sram_AXI_bridge(
    .aclk      (aclk       ),
    .aresetn   (aresetn    ),   //low active

    .arid      (arid      ),
    .araddr    (araddr    ),
    .arlen     (arlen     ),
    .arsize    (arsize    ),
    .arburst   (arburst   ),
    .arlock    (arlock    ),
    .arcache   (arcache   ),
    .arprot    (arprot    ),
    .arvalid   (arvalid   ),
    .arready   (arready   ),
                
    .rid       (rid       ),
    .rdata     (rdata     ),
    .rresp     (rresp     ),
    .rlast     (rlast     ),
    .rvalid    (rvalid    ),
    .rready    (rready    ),
               
    .awid      (awid      ),
    .awaddr    (awaddr    ),
    .awlen     (awlen     ),
    .awsize    (awsize    ),
    .awburst   (awburst   ),
    .awlock    (awlock    ),
    .awcache   (awcache   ),
    .awprot    (awprot    ),
    .awvalid   (awvalid   ),
    .awready   (awready   ),
    
    .wid       (wid       ),
    .wdata     (wdata     ),
    .wstrb     (wstrb     ),
    .wlast     (wlast     ),
    .wvalid    (wvalid    ),
    .wready    (wready    ),
    
    .bid       (bid       ),
    .bresp     (bresp     ),
    .bvalid    (bvalid    ),
    .bready    (bready    ),
    .inst_sram_req      (inst_sram_req  ),
    .inst_sram_wr       (inst_sram_wr   ),
    .inst_sram_size     (inst_sram_size ),
    .inst_sram_wstrb    (inst_sram_wstrb),
    .inst_sram_addr     (inst_sram_addr ),
    .inst_sram_wdata    (inst_sram_wdata),
    .inst_sram_addr_ok  (inst_sram_addr_ok),
    .inst_sram_data_ok  (inst_sram_data_ok),
    .inst_sram_rdata    (inst_sram_rdata),
    .data_sram_req      (data_sram_req    ),
    .data_sram_wr       (data_sram_wr     ),
    .data_sram_size     (data_sram_size   ),
    .data_sram_addr     (data_sram_addr   ),
    .data_sram_wstrb    (data_sram_wstrb  ),
    .data_sram_wdata    (data_sram_wdata  ),
    .data_sram_addr_ok  (data_sram_addr_ok),
    .data_sram_data_ok  (data_sram_data_ok),
    .data_sram_rdata    (data_sram_rdata  )
);

//PRE_IF stage
pre_if_stage pre_if_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .fs_allowin     (fs_allowin     ),    
    //outputs
    .pfs_to_fs_bus  (pfs_to_fs_bus  ),
    .pfs_to_fs_valid(pfs_to_fs_valid),    
    //brbus
    .br_bus         (br_bus         ),
    // inst sram interface
    .inst_sram_req  (inst_sram_req  ),
    .inst_sram_wr   (inst_sram_wr   ),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),

    .flush       (wb_flush),
    .flush_target(wb_flush_target),

    .s0_va_highbits ({s0_vppn, s0_va_bit12}),
    .s0_found       (s0_found),
    .s0_index       (s0_index),
    .s0_ppn         (s0_ppn),
    .s0_ps          (s0_ps),
    .s0_plv         (s0_plv),
    .s0_mat         (s0_mat),
    .s0_d           (s0_d),
    .s0_v           (s0_v),

    .csr_crmd_da    (csr_crmd_da),
    .csr_crmd_pg    (csr_crmd_pg),
    .csr_crmd_plv   (csr_crmd_plv),

    .csr_dmw0_plv0  (csr_dmw0_plv0),
    .csr_dmw0_plv3  (csr_dmw0_plv3),
    .csr_dmw0_mat   (csr_dmw0_mat),
    .csr_dmw0_pseg  (csr_dmw0_pseg),
    .csr_dmw0_vseg  (csr_dmw0_vseg),

    .csr_dmw1_plv0  (csr_dmw1_plv0),
    .csr_dmw1_plv3  (csr_dmw1_plv3),
    .csr_dmw1_mat   (csr_dmw1_mat),
    .csr_dmw1_pseg  (csr_dmw1_pseg),
    .csr_dmw1_vseg  (csr_dmw1_vseg)
);

// IF stage
if_stage if_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    
    .pfs_to_fs_valid(pfs_to_fs_valid),  
    .pfs_to_fs_bus  (pfs_to_fs_bus  ),
    //outputs
    .fs_allowin     (fs_allowin     ),

    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata  (inst_sram_rdata  ),

    .wb_flush(wb_flush)
);
// ID stage
id_stage id_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to pre-if
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),

    .es_fwd_blk_bus (es_fwd_blk_bus ),
    .ms_fwd_blk_bus (ms_fwd_blk_bus ),

    .csr_has_int    (csr_has_int    ),
    .wb_flush       (wb_flush       ),
    .csr_rnum       (csr_rnum       ),
    .csr_rval       (csr_rval       ),

    .es_csr_blk_bus (es_csr_blk_bus ),
    .ms_csr_blk_bus (ms_csr_blk_bus ),
    .ws_csr_blk_bus (ws_csr_blk_bus )
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_req    (data_sram_req    ),
    .data_sram_wr     (data_sram_wr     ),
    .data_sram_size   (data_sram_size   ),
    .data_sram_addr   (data_sram_addr   ),
    .data_sram_wstrb  (data_sram_wstrb  ),
    .data_sram_wdata  (data_sram_wdata  ),
    .data_sram_addr_ok(data_sram_addr_ok),

    .es_fwd_blk_bus (es_fwd_blk_bus ),
    .es_mul_res_bus (mul_res_bus    ),
    .es_div_res_bus (div_res_bus    ),
    .div_finish     (div_finish     ),

    .wb_flush       (wb_flush       ),
    .ms_to_es_ls_cancel(ms_to_es_ls_cancel),

    .es_csr_blk_bus (es_csr_blk_bus ),

    .s1_va_highbits ({s1_vppn, s1_va_bit12}),
    .s1_asid        (s1_asid),
    .s1_found       (s1_found),
    .s1_index       (s1_index),
    .s1_ppn         (s1_ppn),
    .s1_ps          (s1_ps),
    .s1_plv         (s1_plv),
    .s1_mat         (s1_mat),
    .s1_d           (s1_d),
    .s1_v           (s1_v),

    .invtlb_valid   (invtlb_valid),
    .invtlb_op      (invtlb_op),

    .csr_asid_asid  (csr_asid_asid),
    .csr_tlbehi_vppn(csr_tlbehi_vppn),

    .csr_crmd_da    (csr_crmd_da),
    .csr_crmd_pg    (csr_crmd_pg),
    .csr_crmd_plv   (csr_crmd_plv),

    .csr_dmw0_plv0  (csr_dmw0_plv0),
    .csr_dmw0_plv3  (csr_dmw0_plv3),
    .csr_dmw0_mat   (csr_dmw0_mat),
    .csr_dmw0_pseg  (csr_dmw0_pseg),
    .csr_dmw0_vseg  (csr_dmw0_vseg),

    .csr_dmw1_plv0  (csr_dmw1_plv0),
    .csr_dmw1_plv3  (csr_dmw1_plv3),
    .csr_dmw1_mat   (csr_dmw1_mat),
    .csr_dmw1_pseg  (csr_dmw1_pseg),
    .csr_dmw1_vseg  (csr_dmw1_vseg)
);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata  (data_sram_rdata  ),

    .ms_fwd_blk_bus (ms_fwd_blk_bus ),
    .ms_mul_res_bus (mul_res_bus    ),
    .ms_div_res_bus (div_res_bus    ),
    .ms_div_finish  (div_finish     ),
    
    .wb_flush       (wb_flush       ),
    .ms_to_es_ls_cancel(ms_to_es_ls_cancel),
    .ms_csr_blk_bus (ms_csr_blk_bus )
);
// WB stage
wb_stage wb_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

    .csr_we         (csr_we         ),
    .csr_wnum       (csr_wnum       ),
    .csr_wmask      (csr_wmask      ),
    .csr_wval       (csr_wval       ),

    .wb_exc         (wb_exc         ),
    .wb_ecode       (wb_ecode       ),
    .wb_esubcode    (wb_esubcode    ),
    .wb_pc          (wb_pc          ),
    .wb_badvaddr    (wb_badvaddr    ),
    .badv_is_pc     (badv_is_pc     ),
    .badv_is_mem    (badv_is_mem    ),

    .ertn_flush     (wb_ertn        ),

    .refetch_flush  (wb_refetch     ),

    .ws_csr_blk_bus (ws_csr_blk_bus ),

    .r_index         (r_index),
    .tlbrd_we        (tlbrd_we),
    .csr_tlbidx_index(csr_tlbidx_index),

    .tlbwr_we        (tlbwr_we),
    .tlbfill_we      (tlbfill_we),
    .w_index         (w_index),
    .we              (we),
    
    .tlbsrch_we      (tlbsrch_we),
    .tlbsrch_hit     (tlbsrch_hit),
    .tlbsrch_hit_index(tlbsrch_hit_index)
);

csr u_csr(
    .clk        (aclk        ),
    .rst        (reset      ),
    
    .csr_wnum   (csr_wnum   ),
    .csr_we     (csr_we     ),
    .csr_wmask  (csr_wmask  ),
    .csr_wval   (csr_wval   ),

    .csr_rnum   (csr_rnum   ),
    .csr_rval   (csr_rval   ),

    .wb_exc     (wb_exc     ),
    .wb_ecode   (wb_ecode   ),
    .wb_esubcode(wb_esubcode),
    .wb_pc      (wb_pc      ),
    .wb_badvaddr(wb_badvaddr),

    .badv_is_pc (badv_is_pc ),
    .badv_is_mem(badv_is_mem),

    .ertn_flush (wb_ertn    ),
    
    .has_int    (csr_has_int),
    .exc_entry  (exc_entry  ),
    .exc_retaddr(exc_retaddr),

    .csr_crmd_plv(csr_crmd_plv),
    .csr_crmd_da(csr_crmd_da),
    .csr_crmd_pg(csr_crmd_pg),
    .csr_crmd_datf(csr_crmd_datf),
    .csr_crmd_datm(csr_crmd_datm),

    .csr_asid_asid   (csr_asid_asid),
    .csr_tlbehi_vppn (csr_tlbehi_vppn),
    .csr_tlbidx_index(csr_tlbidx_index),

    .csr_dmw0_plv0   (csr_dmw0_plv0),
    .csr_dmw0_plv3   (csr_dmw0_plv3),
    .csr_dmw0_mat    (csr_dmw0_mat),
    .csr_dmw0_pseg   (csr_dmw0_pseg),
    .csr_dmw0_vseg   (csr_dmw0_vseg),

    .csr_dmw1_plv0   (csr_dmw1_plv0),
    .csr_dmw1_plv3   (csr_dmw1_plv3),
    .csr_dmw1_mat    (csr_dmw1_mat),
    .csr_dmw1_pseg   (csr_dmw1_pseg),
    .csr_dmw1_vseg   (csr_dmw1_vseg),

    .tlbsrch_we      (tlbsrch_we),
    .tlbsrch_hit     (tlbsrch_hit),
    .tlb_hit_index   (tlbsrch_hit_index),
    .tlbrd_we        (tlbrd_we),
    .tlbwr_we        (tlbwr_we),
    .tlbfill_we      (tlbfill_we),

    .r_tlb_e         (r_e),
    .r_tlb_ps        (r_ps),
    .r_tlb_vppn      (r_vppn),
    .r_tlb_asid      (r_asid),
    .r_tlb_g         (r_g),
    .r_tlb_ppn0      (r_ppn0),
    .r_tlb_plv0      (r_plv0),
    .r_tlb_mat0      (r_mat0),
    .r_tlb_d0        (r_d0),
    .r_tlb_v0        (r_v0),
    .r_tlb_ppn1      (r_ppn1),
    .r_tlb_plv1      (r_plv1),
    .r_tlb_mat1      (r_mat1),
    .r_tlb_d1        (r_d1),
    .r_tlb_v1        (r_v1),

    .w_tlb_e         (w_e),
    .w_tlb_ps        (w_ps),
    .w_tlb_vppn      (w_vppn),
    .w_tlb_asid      (w_asid),
    .w_tlb_g         (w_g),
    .w_tlb_ppn0      (w_ppn0),
    .w_tlb_plv0      (w_plv0),
    .w_tlb_mat0      (w_mat0),
    .w_tlb_d0        (w_d0),
    .w_tlb_v0        (w_v0),
    .w_tlb_ppn1      (w_ppn1),
    .w_tlb_plv1      (w_plv1),
    .w_tlb_mat1      (w_mat1),
    .w_tlb_d1        (w_d1),
    .w_tlb_v1        (w_v1)
);

tlb #(.TLBNUM(16)) u_tlb(
    .clk        (aclk),
    
    .s0_vppn    (s0_vppn),
    .s0_va_bit12(s0_va_bit12),
    .s0_asid    (s0_asid),
    .s0_found   (s0_found),
    .s0_index   (s0_index),
    .s0_ppn     (s0_ppn),
    .s0_ps      (s0_ps),
    .s0_plv     (s0_plv),
    .s0_mat     (s0_mat),
    .s0_d       (s0_d),
    .s0_v       (s0_v),

    .s1_vppn    (s1_vppn),
    .s1_va_bit12(s1_va_bit12),
    .s1_asid    (s1_asid),
    .s1_found   (s1_found),
    .s1_index   (s1_index),
    .s1_ppn     (s1_ppn),
    .s1_ps      (s1_ps),
    .s1_plv     (s1_plv),
    .s1_mat     (s1_mat),
    .s1_d       (s1_d),
    .s1_v       (s1_v),

    .invtlb_op  (invtlb_op),
    .invtlb_valid(invtlb_valid),
    
    .we         (we),
    .w_index    (w_index),
    .w_e        (w_e),
    .w_vppn     (w_vppn),
    .w_ps       (w_ps),
    .w_asid     (w_asid),
    .w_g        (w_g),

    .w_ppn0     (w_ppn0),
    .w_plv0     (w_plv0),
    .w_mat0     (w_mat0),
    .w_d0       (w_d0),
    .w_v0       (w_v0),

    .w_ppn1     (w_ppn1),
    .w_plv1     (w_plv1),
    .w_mat1     (w_mat1),
    .w_d1       (w_d1),
    .w_v1       (w_v1),

    .r_index    (r_index),
    .r_e        (r_e),
    .r_vppn     (r_vppn),
    .r_ps       (r_ps),
    .r_asid     (r_asid),
    .r_g        (r_g),

    .r_ppn0     (r_ppn0),
    .r_plv0     (r_plv0),
    .r_mat0     (r_mat0),
    .r_d0       (r_d0),
    .r_v0       (r_v0),

    .r_ppn1     (r_ppn1),
    .r_plv1     (r_plv1),
    .r_mat1     (r_mat1),
    .r_d1       (r_d1),
    .r_v1       (r_v1)
);

endmodule
