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
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,

    output        csr_we,
    output [13:0] csr_wnum,
    output [31:0] csr_wmask,
    output [31:0] csr_wval,

    output        wb_exc,
    output [ 5:0] wb_ecode,
    output [ 8:0] wb_esubcode,
    output [31:0] wb_pc,
    output [31:0] wb_badvaddr,

    output ertn_flush,

    output [`WS_CSR_BLK_BUS_WD-1:0] ws_csr_blk_bus
);

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
wire [31:0] ws_pc;
assign {ws_csr_we      ,
        ws_csr_wnum    ,
        ws_csr_wmask   ,
        ws_csr_wdata   ,
        ws_inst_ertn   ,
        ws_exc_flgs    ,
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
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
    end else if (wb_exc | ertn_flush) begin
        ws_valid <= 1'b0;
    end else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we & ws_valid & ~wb_exc;
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
assign wb_ecode    = {6{ws_exc_flgs[`EXC_FLG_ADEF]}} & `ECODE_ADE |
                     {6{ws_exc_flgs[`EXC_FLG_ALE ]}} & `ECODE_ALE |
                     {6{ws_exc_flgs[`EXC_FLG_BRK ]}} & `ECODE_BRK |
                     {6{ws_exc_flgs[`EXC_FLG_INE ]}} & `ECODE_INE |
                     {6{ws_exc_flgs[`EXC_FLG_INT ]}} & `ECODE_INT |
                     {6{ws_exc_flgs[`EXC_FLG_SYS ]}} & `ECODE_SYS;
assign wb_esubcode = {9{ws_exc_flgs[`EXC_FLG_ADEF]}} & `ESUBCODE_ADEF;
assign wb_pc = ws_pc;
assign wb_badvaddr = ws_final_result;

assign ertn_flush = ws_inst_ertn & ws_valid;

assign ws_csr_blk_bus = {ws_csr_we & ws_valid, ws_inst_ertn & ws_valid, ws_csr_wnum};

endmodule
