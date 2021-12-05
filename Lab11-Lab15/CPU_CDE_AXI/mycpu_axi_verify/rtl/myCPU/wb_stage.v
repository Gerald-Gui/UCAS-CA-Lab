`include "mycpu.h"
`include "csr.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0]                   debug_wb_pc     ,
    output [ 3:0]                   debug_wb_rf_wen ,
    output [ 4:0]                   debug_wb_rf_wnum,
    output [31:0]                   debug_wb_rf_wdata,

    output                          csr_we,
    output [13:0]                   csr_wnum,
    output [31:0]                   csr_wmask,
    output [31:0]                   csr_wval,

    output                          wb_exc,
    output [ 5:0]                   wb_ecode,
    output [ 8:0]                   wb_esubcode,
    output [31:0]                   wb_pc,
    output [31:0]                   wb_badvaddr,
    output                          badv_is_pc,
    output                          badv_is_mem,

    output                          ertn_flush,

    output                          refetch_flush,

    output [`WS_CSR_BLK_BUS_WD-1:0] ws_csr_blk_bus,

    // for tlbrd
    output [ 3:0] r_index,
    output        tlbrd_we,
    input  [ 3:0] csr_tlbidx_index,

    // for tlbwr && tlbfill
    output        tlbwr_we,
    output        tlbfill_we,
    output [ 3:0] w_index,
    output        we,

    // for tlbsrch
    output        tlbsrch_we,
    output        tlbsrch_hit,
    output [ 3:0] tlbsrch_hit_index
);

reg         wb_flush_r;

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire [`EXC_NUM-1:0] ws_exc_flgs;
wire        ws_csr_we;
wire [13:0] ws_csr_wnum;
wire [31:0] ws_csr_wdata;
wire [31:0] ws_csr_wmask;
wire        ws_inst_ertn;

wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_res_from_ms;
wire [31:0] ws_pc;

wire        ws_refetch_flg;
wire        ws_inst_tlbsrch;
wire        ws_inst_tlbrd;
wire        ws_inst_tlbwr;
wire        ws_inst_tlbfill;
wire        ws_tlbsrch_hit;
wire [ 3:0] ws_tlbsrch_hit_index;

reg  [ 3:0] random;

assign {ws_refetch_flg ,
        ws_inst_tlbsrch,
        ws_inst_tlbrd  ,
        ws_inst_tlbwr  ,
        ws_inst_tlbfill,
        ws_tlbsrch_hit ,
        ws_tlbsrch_hit_index,
        ws_csr_we      ,
        ws_csr_wnum    ,
        ws_csr_wmask   ,
        ws_csr_wdata   ,
        ws_inst_ertn   ,
        ws_exc_flgs    ,
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_res_from_ms,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if(reset) begin
        ms_to_ws_bus_r <= `MS_TO_WS_BUS_WD'b0;
    end else if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

always @(posedge clk) begin
    if (reset) begin
        wb_flush_r <= 1'b0;
    end else if (wb_exc | ertn_flush) begin
        wb_flush_r <= 1'b1;
    end else if (ms_to_ws_valid & ws_allowin) begin
        wb_flush_r <= 1'b0;
    end
end

assign ws_final_result = ws_res_from_ms;

assign rf_we    = ws_gr_we & ws_valid & ~(wb_exc | ertn_flush | wb_flush_r);
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

assign csr_we    = ws_csr_we & ws_valid & ~wb_exc;
assign csr_wnum  = ws_csr_wnum;
assign csr_wmask = ws_csr_wmask;
assign csr_wval  = ws_csr_wdata;

assign wb_exc      = (|ws_exc_flgs) & ws_valid;
assign wb_ecode    = ws_exc_flgs[`EXC_FLG_INT ] ? `ECODE_INT :
                     ws_exc_flgs[`EXC_FLG_ADEF] ? `ECODE_ADE :
                     ws_exc_flgs[`EXC_FLG_TLBR_F] ? `ECODE_TLBR :
                     ws_exc_flgs[`EXC_FLG_PIF ] ? `ECODE_PIF :
                     ws_exc_flgs[`EXC_FLG_PPE_F] ? `ECODE_PPE :
                     ws_exc_flgs[`EXC_FLG_INE ] ? `ECODE_INE :
                     ws_exc_flgs[`EXC_FLG_SYS ] ? `ECODE_SYS :
                     ws_exc_flgs[`EXC_FLG_BRK ] ? `ECODE_BRK :
                     ws_exc_flgs[`EXC_FLG_ALE ] ? `ECODE_ALE :
                     ws_exc_flgs[`EXC_FLG_ADEM] ? `ECODE_ADE :
                     ws_exc_flgs[`EXC_FLG_TLBR_M] ? `ECODE_TLBR :
                     ws_exc_flgs[`EXC_FLG_PIL ] ? `ECODE_PIL :
                     ws_exc_flgs[`EXC_FLG_PIS ] ? `ECODE_PIS :
                     ws_exc_flgs[`EXC_FLG_PPE_M] ? `ECODE_PPE :
                     ws_exc_flgs[`EXC_FLG_PME ] ? `ECODE_PME : 6'h00;
assign wb_esubcode = {9{ws_exc_flgs[`EXC_FLG_ADEF]}} & `ESUBCODE_ADEF |
                     {9{ws_exc_flgs[`EXC_FLG_ADEM]}} & `ESUBCODE_ADEM;
assign wb_pc = ws_pc;
assign badv_is_pc = ws_exc_flgs[`EXC_FLG_ADEF]  | ws_exc_flgs[`EXC_FLG_TLBR_F] |
                    ws_exc_flgs[`EXC_FLG_PPE_F] | ws_exc_flgs[`EXC_FLG_PIF];
assign wb_badvaddr = ws_final_result;
assign badv_is_mem = ws_exc_flgs[`EXC_FLG_ALE]    | ws_exc_flgs[`EXC_FLG_ADEM]  |
                     ws_exc_flgs[`EXC_FLG_TLBR_M] | ws_exc_flgs[`EXC_FLG_PPE_M] |
                     ws_exc_flgs[`EXC_FLG_PIL]    | ws_exc_flgs[`EXC_FLG_PIS]   |
                     ws_exc_flgs[`EXC_FLG_PME];

assign ertn_flush = ws_inst_ertn & ws_valid;

assign refetch_flush = ws_refetch_flg & ws_valid;

assign ws_csr_blk_bus = {ws_csr_we & ws_valid, ws_inst_ertn & ws_valid, ws_inst_tlbsrch & ws_valid, ws_csr_wnum};

// X_{n+1} = (5 * X_n + 13) mod 16
always @ (posedge clk) begin
    if (reset) begin
        random <= 4'd1;
    end else begin
        random <= {random[1:0], 2'b0} + random + 4'd13;
    end
end

assign r_index = csr_tlbidx_index;
assign tlbrd_we = ws_inst_tlbrd;

assign tlbwr_we   = ws_inst_tlbwr;
assign tlbfill_we = ws_inst_tlbfill;
assign w_index = tlbwr_we ? csr_tlbidx_index : random;
assign we = tlbwr_we | tlbfill_we;

assign tlbsrch_we = ws_inst_tlbsrch;
assign tlbsrch_hit = ws_tlbsrch_hit;
assign tlbsrch_hit_index = ws_tlbsrch_hit_index;

endmodule
