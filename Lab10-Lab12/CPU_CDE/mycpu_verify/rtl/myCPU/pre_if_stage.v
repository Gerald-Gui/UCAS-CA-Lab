`include "mycpu.h"

module pre_if_stage (
    input                            clk              ,
    input                            reset            ,
    //from fs
    input                            fs_allowin       ,
    input                            fs_block   ,
    //to fs
    output [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus    ,
    output                           pfs_to_fs_valid  ,
    //br
    input [`BR_BUS_WD - 1        :0] br_bus           ,
    //inst_sram
    output                           inst_sram_req,
    output                           inst_sram_wr,
    output [ 1:0]                    inst_sram_size,
    output [ 3:0]                    inst_sram_wstrb,
    output [31:0]                    inst_sram_addr,
    output [31:0]                    inst_sram_wdata,
    input                            inst_sram_addr_ok,
    input                            inst_sram_data_ok,
    input  [31:0]                    inst_sram_rdata,
    // exc && int
    input                            wb_exc,
    input                            wb_ertn,
    input  [31:0]                    exc_entry,
    input  [31:0]                    exc_retaddr
);

    //control signals
    reg  pfs_valid;
    wire pfs_ready_go;
    
    //inst_sram
    reg        inst_sram_addr_ok_r;
    reg        inst_sram_data_ok_r;
    reg [31:0] inst_buff;

    //br
    wire br_stall;
    wire br_taken;
    wire br_taken_cancel;
    wire [31:0] br_target;
    assign {br_taken, br_taken_cancel, br_stall, br_target} = br_bus;
    reg        br_taken_r;
    reg [31:0] br_target_r;
    
    //pc
    reg  [31:0] pfs_pc;
    wire [31:0] nextpc;
    wire [31:0] seq_pc;

    //reflush
    reg        wb_exc_r;
    reg        wb_ertn_r;
    reg [31:0] exc_entry_r;
    reg [31:0] exc_retaddr_r;

    reg inst_cancel;

    //control signals
    assign pfs_ready_go = (inst_sram_addr_ok && inst_sram_req) || inst_sram_addr_ok_r && ~(wb_ertn | wb_exc);
    assign pfs_to_fs_valid = pfs_valid && pfs_ready_go;
    always @(posedge clk) begin
        if (reset  ) begin
            pfs_valid <= 1'b0;
        end
        else begin
            pfs_valid <= 1'b1;
        end
    end

    //to fs
    assign pfs_to_fs_bus = {inst_sram_data_ok && fs_block ? 1'b1 : inst_sram_data_ok_r,//64:64
                            inst_sram_data_ok && fs_block? inst_sram_rdata : inst_buff,          //63:32
                            nextpc              //31:0
                           };

    //inst_sram
    always @(posedge clk) begin
        if (reset) begin
            inst_sram_addr_ok_r <= 1'b0;
        end else if (inst_sram_addr_ok && inst_sram_req && !fs_allowin) begin
            inst_sram_addr_ok_r <= 1'b1;
        end else if (fs_allowin || (wb_ertn | wb_exc)) begin
            inst_sram_addr_ok_r <= 1'b0;
        end
    end

    always @(posedge clk ) begin
        if (reset || fs_allowin || (wb_ertn | wb_exc)) begin
            inst_sram_data_ok_r <= 1'b0;
        end else if (inst_sram_data_ok && fs_block && !inst_cancel) begin
            inst_sram_data_ok_r <= 1'b1;
        end

        if (reset || fs_allowin || (wb_ertn | wb_exc)) begin
            inst_buff <= 32'b0;
        end else if (inst_sram_data_ok && fs_block && !inst_cancel) begin
            inst_buff <= inst_sram_rdata;
        end
    end

    assign inst_sram_req = pfs_valid && !inst_sram_addr_ok_r && !br_stall && fs_allowin;
    assign inst_sram_wr = 1'b0;
    assign inst_sram_size = 2'b10;
    assign inst_sram_wstrb = 4'b0;
    assign inst_sram_wdata = 32'b0;
    assign inst_sram_addr = nextpc;

    //inst_cancel
    always @(posedge clk ) begin
        if (reset) begin
            inst_cancel <= 1'b0;
        end else if (pfs_ready_go && ((wb_ertn | wb_exc) || (wb_ertn_r | wb_exc_r) || br_taken || br_taken_r)) begin
            inst_cancel <= 1'b1;
        end else if (inst_sram_data_ok) begin
            inst_cancel <= 1'b0;
        end
    end
    
    //br
    always @(posedge clk) begin
        if (reset) begin
            br_taken_r <= 1'b0;
            br_target_r <= 32'b0;
        end else if (pfs_ready_go && fs_allowin)begin
            br_taken_r <= 1'b0;
            br_target_r <= 32'b0;
        end else if (br_taken && !br_stall) begin
            br_taken_r <= 1'b1;
            br_target_r <= br_target;
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            wb_exc_r <= 1'b0;
            wb_ertn_r <= 1'b0;
            exc_entry_r <= 32'b0;
            exc_retaddr_r <= 32'b0;
        end else if (pfs_ready_go && fs_allowin)begin
            wb_exc_r <= 1'b0;
            wb_ertn_r <= 1'b0;
            exc_entry_r <= 32'b0;
            exc_retaddr_r <= 32'b0;
        end else if (wb_exc) begin
            wb_exc_r <= 1'b1;
            exc_entry_r <= exc_entry;
        end else if (wb_ertn) begin
            wb_ertn_r <= 1'b1;
            exc_retaddr_r <= exc_retaddr;
        end
    end
    
    //pc
    assign seq_pc = pfs_pc + 32'h4;
    assign nextpc   = wb_exc   ? exc_entry   :
                      wb_exc_r   ? exc_entry_r   :
                      wb_ertn  ? exc_retaddr :
                      wb_ertn_r  ? exc_retaddr_r :
                      br_taken_r ? br_target_r   :
                      (br_taken && !br_stall) ? br_target   :
                                 seq_pc;
    always @(posedge clk ) begin
        if (reset) begin
            pfs_pc <= 32'h1bfffffc;
        end else if (pfs_ready_go && fs_allowin) begin
            pfs_pc <= nextpc;
        end
    end

endmodule