`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,

    // blk bus to id
    output [`ES_FWD_BLK_BUS_WD-1:0] es_fwd_blk_bus,
    // mul pipe res for MEM
    output [64:0] es_mul_res_bus
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [18:0] es_alu_op     ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;

wire [31:0] store_data    ;

wire [ 4:0] es_load_op;
wire [ 2:0] es_store_op;
wire        es_res_from_mul;
wire        is_div;
wire        div_finish;
wire        waiting_ready;

assign {es_alu_op      ,  //164:146
        es_res_from_mul,  //145:145
        es_load_op     ,  //144:140
        es_store_op    ,  //139:137
        es_src1_is_pc  ,  //136:136
        es_src2_is_imm ,  //135:135
        es_gr_we       ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;

//assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mul,  //75:75
                       es_load_op     ,  //74:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };

assign es_ready_go    = ~(is_div & ~div_finish);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin     
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
                                      es_rj_value;
                                      
assign es_alu_src2 = es_src2_is_imm ? es_imm : 
                                      es_rkd_value;

alu u_alu(
    .clk        (clk          ),
    .rst        (reset        ),
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .es_valid   (es_valid     ),
    .is_div     (is_div       ),
    .div_finish (div_finish   ),
    .mul_res_bus(es_mul_res_bus)
    );

assign store_data = es_store_op[2] ? {4{es_rkd_value[ 7:0]}} :  // b
                    es_store_op[1] ? {2{es_rkd_value[15:0]}} :  // h
                                        es_rkd_value[31:0];     // w

assign data_sram_en    = ((|es_load_op) || es_mem_we) && es_valid;
assign data_sram_wen   = es_store_op[2] ? (4'h1 <<  es_alu_result[1:0])      : // b
                         es_store_op[1] ? (4'h3 << {es_alu_result[1], 1'b0}) : // h
                         es_store_op[0] ? 4'hf : 4'h0;                          // w

assign data_sram_addr  = {es_alu_result[31:2], 2'b0};
assign data_sram_wdata = store_data;

assign es_fwd_blk_bus = {
    es_gr_we & es_valid,
    ((|es_load_op) | es_res_from_mul) & es_valid,
    es_dest,
    es_alu_result};

endmodule
