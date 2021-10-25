`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,

    // blk bus to id
    output [`MS_FWD_BLK_BUS_WD-1:0] ms_fwd_blk_bus,
    // mul final res
    input  [64:0] ms_mul_res_bus,

    input  wb_exc,
    input  wb_ertn,
    output ms_to_es_st_cancel,
    output [`MS_CSR_BLK_BUS_WD-1:0] ms_csr_blk_bus
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mul;
wire [ 4:0] ms_load_op;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire [`EXC_NUM-1:0] es_to_ms_exc_flgs;
wire [`EXC_NUM-1:0] ms_exc_flgs;
wire        ms_csr_we;
wire [13:0] ms_csr_wnum;
wire [31:0] ms_csr_wmask;
wire [31:0] ms_csr_wdata;
wire        ms_inst_ertn;

wire        ms_rdcn_en;
wire        ms_rdcn_sel;

assign {ms_rdcn_en     ,
        ms_rdcn_sel    ,
        ms_csr_we      ,
        ms_csr_wnum    ,
        ms_csr_wmask   ,
        ms_csr_wdata   ,
        ms_inst_ertn   ,
        es_to_ms_exc_flgs,
        ms_res_from_mul,  //75:75
        ms_load_op     ,  //74:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire        mul_res_sel;
wire [31:0] mul_result;
wire [31:0] mem_result;
wire        load_byte;
wire        load_half;
wire        load_word;
wire        load_signed;
wire [ 7:0] load_b_data;
wire [15:0] load_h_data;
wire [31:0] load_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {ms_csr_we      ,
                       ms_csr_wnum    ,
                       ms_csr_wmask   ,
                       ms_csr_wdata   ,
                       ms_inst_ertn   ,
                       ms_exc_flgs    ,
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

reg [63:0] stable_cnter;

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid & ms_ready_go & ~(wb_exc | wb_ertn);
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

assign mul_res_sel = ms_mul_res_bus[64];
assign mul_result  = mul_res_sel ? ms_mul_res_bus[63:32] :
                                   ms_mul_res_bus[31: 0];

assign load_byte = ms_load_op[4] | ms_load_op[1];
assign load_half = ms_load_op[3] | ms_load_op[0];
assign load_word = ms_load_op[2];
assign load_signed = ms_load_op[4] | ms_load_op[3];

assign mem_result = data_sram_rdata;
assign load_b_data = mem_result[{ms_alu_result[1:0], 3'b0}+:8];
assign load_h_data = mem_result[{ms_alu_result[1],   4'b0}+:16];
assign load_result = {32{load_byte}} & {{24{load_b_data[ 7] & load_signed}}, load_b_data} |
                     {32{load_half}} & {{16{load_h_data[15] & load_signed}}, load_h_data} |
                     {32{load_word}} & mem_result;

assign ms_final_result = ms_rdcn_en ? stable_cnter[{ms_rdcn_sel, 5'b0}+:32] :
                         ms_exc_flgs[`EXC_FLG_ALE] ? ms_alu_result :
                         ms_res_from_mul           ? mul_result    :
                         (|ms_load_op)             ? load_result   :
                                                     ms_alu_result;

assign ms_fwd_blk_bus = {ms_gr_we & ms_valid, ms_dest, ms_final_result};

assign ms_to_es_st_cancel = ((|ms_exc_flgs) | ms_inst_ertn) & ms_valid;
assign ms_csr_blk_bus     = {ms_csr_we & ms_valid, ms_inst_ertn & ms_valid, ms_csr_wnum};

assign ms_exc_flgs = es_to_ms_exc_flgs;

always @ (posedge clk) begin
    if (reset) begin
        stable_cnter <= 64'b0;
    end else begin
        stable_cnter <= stable_cnter + 64'b1;
    end
end

endmodule
