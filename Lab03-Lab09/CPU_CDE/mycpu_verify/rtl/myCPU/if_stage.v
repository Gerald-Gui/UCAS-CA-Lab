`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,

    // exc && int
    input         wb_exc,
    input         wb_ertn,
    input  [31:0] exc_entry,
    input  [31:0] exc_retaddr
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
assign {br_taken,br_target} = br_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {
                       fs_exc_flgs,
                       fs_inst ,
                       fs_pc   
                      };

// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 32'h4;
// assign nextpc       = br_taken ? br_target   : seq_pc; 
assign nextpc       = wb_exc   ? exc_entry   :
                      wb_ertn  ? exc_retaddr :
                      br_taken ? br_target   :
                                 seq_pc;

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
// assign fs_to_ds_valid =  fs_valid && fs_ready_go;
assign fs_to_ds_valid = fs_valid & fs_ready_go & ~(wb_exc | wb_ertn);
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    // end else if (wb_exc | wb_ertn) begin
    //     fs_valid <= 1'b0;
    end else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    // end else if (wb_exc | wb_ertn) begin
    //     fs_pc <= (wb_exc ? exc_entry : exc_retaddr) - 32'h4;
    end else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

wire [`EXC_NUM - 1:0] fs_exc_flgs;
assign fs_exc_flgs[`EXC_FLG_ADEF] = |nextpc[1:0];
// init other exc to 0 by default
assign fs_exc_flgs[`EXC_FLG_SYS]  = 1'b0;
assign fs_exc_flgs[`EXC_FLG_ALE]  = 1'b0;
assign fs_exc_flgs[`EXC_FLG_BRK]  = 1'b0;
assign fs_exc_flgs[`EXC_FLG_INE]  = 1'b0;
assign fs_exc_flgs[`EXC_FLG_INT]  = 1'b0;

endmodule
