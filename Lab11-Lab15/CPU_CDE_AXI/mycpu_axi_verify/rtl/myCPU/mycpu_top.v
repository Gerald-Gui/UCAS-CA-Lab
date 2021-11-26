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

wire        wb_ertn;
wire        csr_has_int;
wire [31:0] exc_entry;
wire [31:0] exc_retaddr;

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

    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        ),
    .exc_entry      (exc_entry      ),
    .exc_retaddr    (exc_retaddr    )
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

    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        )
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
    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        ),
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

    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        ),
    .ms_to_es_ls_cancel(ms_to_es_ls_cancel),

    .es_csr_blk_bus (es_csr_blk_bus )
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
    
    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        ),
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

    .ertn_flush     (wb_ertn        ),

    .ws_csr_blk_bus (ws_csr_blk_bus )
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

    .ertn_flush (wb_ertn    ),
    
    .has_int    (csr_has_int),
    .exc_entry  (exc_entry  ),
    .exc_retaddr(exc_retaddr)
);

endmodule
