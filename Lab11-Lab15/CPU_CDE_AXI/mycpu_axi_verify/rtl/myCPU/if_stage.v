`include "mycpu.h"

module if_stage(
    input                           clk            ,
    input                           reset          ,
    //allwoin
    input                           ds_allowin     ,
    //from pfs
    input                            pfs_to_fs_valid,
    input  [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus  ,
    //to pfs
    output                           fs_allowin     ,
    //to ds
    output                          fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0]  fs_to_ds_bus   ,
    // inst sram interface
    input                           inst_sram_addr_ok,
    input                           inst_sram_data_ok,
    input  [31:0]                   inst_sram_rdata,

    // exc && int && refetch
    input                           wb_flush
);

    reg         wb_flush_r;

    reg         fs_valid;
    wire        fs_ready_go;

    wire [`EXC_NUM - 1:0] fs_exc_flgs;

    wire [31                   :0] pfs_pc;
    reg  [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus_r;
    assign {fs_exc_flgs, pfs_pc} = pfs_to_fs_bus_r;

    wire [31:0] fs_inst;
    wire [31:0] fs_pc;
    assign fs_to_ds_bus = {
                        fs_exc_flgs,
                        fs_inst ,
                        fs_pc   
                        };

    reg        fs_inst_valid;
    reg [31:0] fs_inst_buff;

    wire fs_inst_cancel;

    assign fs_inst_cancel = (wb_flush || wb_flush_r);

    // IF stage
    assign fs_ready_go    = fs_inst_valid || (fs_valid && inst_sram_data_ok);
    assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
    assign fs_to_ds_valid =  fs_valid && fs_ready_go && ~fs_inst_cancel;


    always @(posedge clk) begin
        if (reset) begin
            fs_valid <= 1'b0;
        end
        else if (fs_allowin) begin
            fs_valid <= pfs_to_fs_valid;
        end
    end

    always @(posedge clk ) begin
        if(reset) begin
            fs_inst_valid <= 1'b0;
        end
        else if(!fs_inst_valid && inst_sram_data_ok && !fs_inst_cancel && !ds_allowin) begin
            fs_inst_valid <= 1'b1;
        end
        else if (ds_allowin || fs_inst_cancel) begin
            fs_inst_valid <= 1'b0;
        end

        if(reset) begin
            fs_inst_buff <= 32'b0;
        end
        else if(!fs_inst_valid && inst_sram_data_ok && !fs_inst_cancel && !ds_allowin) begin
            fs_inst_buff <= inst_sram_rdata;
        end
        else if (ds_allowin || fs_inst_cancel) begin
            fs_inst_buff <= 32'b0;
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            pfs_to_fs_bus_r <= `PFS_TO_FS_BUS_WD'b0;
        end else if(pfs_to_fs_valid && fs_allowin) begin
            pfs_to_fs_bus_r <= pfs_to_fs_bus;
        end
    end


    always @(posedge clk) begin
        if (reset) begin
            wb_flush_r <= 1'b0;
        end else if (wb_flush) begin
            wb_flush_r <= 1'b1;
        end else if (pfs_to_fs_valid && fs_allowin) begin
            wb_flush_r <= 1'b0;
        end 
    end

    assign fs_pc = pfs_pc;
    assign fs_inst = fs_inst_valid ? fs_inst_buff : inst_sram_rdata;

endmodule
