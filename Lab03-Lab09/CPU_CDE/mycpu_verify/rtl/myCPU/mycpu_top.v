`include "mycpu.h"

module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_en,
    output [ 3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_en,
    output [ 3:0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn; 

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;

wire [`ES_FWD_BLK_BUS_WD - 1:0] es_fwd_blk_bus;
wire [`MS_FWD_BLK_BUS_WD - 1:0] ms_fwd_blk_bus;

wire [64:0] mul_res_bus;

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

wire        wb_ertn;
wire        csr_has_int;
wire [31:0] exc_entry;
wire [31:0] exc_retaddr;

wire [`ES_CSR_BLK_BUS_WD-1:0] es_csr_blk_bus;
wire [`MS_CSR_BLK_BUS_WD-1:0] ms_csr_blk_bus;
wire [`WS_CSR_BLK_BUS_WD-1:0] ws_csr_blk_bus;

wire ms_to_es_st_cancel;


// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_wen  (inst_sram_wen  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),

    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        ),
    .exc_entry      (exc_entry      ),
    .exc_retaddr    (exc_retaddr    )
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
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
    //to fs
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
    .clk            (clk            ),
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
    .data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),

    .es_fwd_blk_bus (es_fwd_blk_bus),
    .es_mul_res_bus (mul_res_bus   ),

    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        ),
    .ms_to_es_st_cancel(ms_to_es_st_cancel),

    .es_csr_blk_bus (es_csr_blk_bus )
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
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
    .data_sram_rdata(data_sram_rdata),

    .ms_fwd_blk_bus (ms_fwd_blk_bus),
    .ms_mul_res_bus (mul_res_bus   ),
    
    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        ),
    .ms_to_es_st_cancel(ms_to_es_st_cancel),
    .ms_csr_blk_bus (ms_csr_blk_bus )
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
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

    .ertn_flush     (wb_ertn        ),

    .ws_csr_blk_bus (ws_csr_blk_bus )
);

csr u_csr(
    .clk        (clk        ),
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

    .ertn_flush (wb_ertn    ),
    
    .has_int    (csr_has_int),
    .exc_entry  (exc_entry  ),
    .exc_retaddr(exc_retaddr)
);

endmodule
