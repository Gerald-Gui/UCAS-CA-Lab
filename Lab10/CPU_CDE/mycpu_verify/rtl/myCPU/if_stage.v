`include "mycpu.h"

module if_stage(
    input                           clk            ,
    input                           reset          ,
    //allwoin
    input                           ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0]  br_bus         ,
    //from pfs
    input                            pfs_to_fs_valid,
    input  [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus  ,
    //to pfs
    output                           fs_allowin     ,
    output                           fs_block ,
    //to ds
    output                          fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0]  fs_to_ds_bus   ,
    // inst sram interface
    output                          inst_sram_req    ,
    output                          inst_sram_wr     ,
    output [ 1:0]                   inst_sram_size   ,
    output [31:0]                   inst_sram_addr   ,
    output [ 3:0]                   inst_sram_wstrb  ,
    output [31:0]                   inst_sram_wdata  ,
    input                           inst_sram_addr_ok,
    input                           inst_sram_data_ok,
    input  [31:0]                   inst_sram_rdata,

    // exc && int
    input                           wb_exc,
    input                           wb_ertn
);


    reg        wb_exc_r;
    reg        wb_ertn_r;

    reg         fs_valid;
    wire        fs_ready_go;

    wire         br_stall;
    wire         br_taken;
    wire         br_taken_cancel;
    wire [ 31:0] br_target;
    assign {br_taken, br_taken_cancel, br_stall, br_target} = br_bus;

    wire                           pfs_inst_valid;
    wire [31                   :0] pfs_inst;
    wire [31                   :0] pfs_pc;
    reg  [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus_r;
    assign {pfs_inst_valid, pfs_inst, pfs_pc} = pfs_to_fs_bus_r;

    wire [31:0] fs_inst;
    wire  [31:0] fs_pc;
    wire [`EXC_NUM - 1:0] fs_exc_flgs;
    assign fs_to_ds_bus = {
                        fs_exc_flgs,
                        fs_inst ,
                        fs_pc   
                        };

    reg        fs_inst_valid;
    reg [31:0] fs_inst_buff;

    reg fs_inst_cancel;

    // IF stage
    assign fs_ready_go    = pfs_inst_valid || fs_inst_valid || (fs_valid && inst_sram_data_ok);
    assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
    assign fs_to_ds_valid =  fs_valid && fs_ready_go && ~(br_taken && ~br_stall) && ~(wb_ertn | wb_exc) && ~fs_inst_cancel;

    always @(posedge clk) begin
        if (reset) begin
            fs_valid <= 1'b0;
        end
        else if (fs_allowin) begin
            fs_valid <= pfs_to_fs_valid;
        end
    end

    assign fs_block = !fs_valid || fs_inst_valid || pfs_inst_valid;

    always @(posedge clk ) begin
        if(reset) begin
            fs_inst_valid <= 1'b0;
        end
        else if(!fs_inst_valid && inst_sram_data_ok && !fs_inst_cancel && !ds_allowin) begin
            fs_inst_valid <= 1'b1;
        end
        else if (ds_allowin || (wb_ertn | wb_exc) ) begin
            fs_inst_valid <= 1'b0;
        end

        if(reset) begin
            fs_inst_buff <= 32'b0;
        end
        else if(!fs_inst_valid && inst_sram_data_ok && !fs_inst_cancel && !ds_allowin) begin
            fs_inst_buff <= inst_sram_rdata;
        end
        else if (ds_allowin || (wb_ertn | wb_exc) ) begin
            fs_inst_buff <= 32'b0;
        end
    end

    always @(posedge clk) begin
        if(pfs_to_fs_valid && fs_allowin) begin
            pfs_to_fs_bus_r <= pfs_to_fs_bus;
        end
    end

    //inst_cancel
    always @(posedge clk ) begin
        if(reset) begin
            fs_inst_cancel <= 1'b0;
        end
        else if(!fs_allowin && !fs_ready_go && ((wb_ertn | wb_exc) ||( br_taken && ~br_stall))) begin
            fs_inst_cancel <= 1'b1;
        end
        else if(inst_sram_data_ok) begin
            fs_inst_cancel <= 1'b0;
        end
    end


    always @(posedge clk) begin
        if (reset) begin
            wb_exc_r <= 1'b0;
            wb_ertn_r <= 1'b0;
        end else if (fs_ready_go && ds_allowin)begin
            wb_exc_r <= 1'b0;
            wb_ertn_r <= 1'b0;
        end else if (wb_exc) begin
            wb_exc_r <= 1'b1;
        end else if (wb_ertn) begin
            wb_ertn_r <= 1'b1;
        end
    end

    assign fs_pc = pfs_pc;
    assign fs_inst = pfs_inst_valid ? pfs_inst : fs_inst_valid ? fs_inst_buff : inst_sram_rdata;

    assign fs_exc_flgs[`EXC_FLG_ADEF] = |fs_pc[1:0];
    // init other exc to 0 by default
    assign fs_exc_flgs[`EXC_FLG_SYS]  = 1'b0;
    assign fs_exc_flgs[`EXC_FLG_ALE]  = 1'b0;
    assign fs_exc_flgs[`EXC_FLG_BRK]  = 1'b0;
    assign fs_exc_flgs[`EXC_FLG_INE]  = 1'b0;
    assign fs_exc_flgs[`EXC_FLG_INT]  = 1'b0;

endmodule
