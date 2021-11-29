`include "mycpu.h"

module pre_if_stage (
    input                            clk              ,
    input                            reset            ,
    //from fs
    input                            fs_allowin       ,
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
    // exc && int && refetch
    input                            flush,
    input  [31:0]                    flush_target
);

    //control signals
    reg  pfs_valid;
    wire pfs_ready_go;

    //br
    wire br_stall;
    wire br_taken;
    wire br_taken_cancel;
    wire [31:0] br_target;
    assign {br_taken, br_taken_cancel, br_stall, br_target} = br_bus;
    reg        br_taken_r;
    reg        br_stall_r;
    reg [31:0] br_target_r;
    
    //pc
    reg  [31:0] pfs_pc;
    wire [31:0] nextpc;
    wire [31:0] seq_pc;

    //reflush
    reg        pfs_reflush;

    reg        flush_r;
    reg [31:0] flush_target_r;

    //control signals
    assign pfs_ready_go = (inst_sram_addr_ok && inst_sram_req) && ~(((
        flush_r || br_stall_r) && pfs_reflush) || flush || br_stall);
    assign pfs_to_fs_valid = pfs_valid && pfs_ready_go;
    always @(posedge clk) begin
        if (reset  ) begin
            pfs_valid <= 1'b0;
        end else begin
            pfs_valid <= 1'b1;
        end
    end

    //to fs
    assign pfs_to_fs_bus = nextpc;

    assign inst_sram_req = pfs_valid && fs_allowin & ~(pfs_reflush);
    assign inst_sram_wr = 1'b0;
    assign inst_sram_size = 2'b10;
    assign inst_sram_wstrb = 4'b0;
    assign inst_sram_wdata = 32'b0;
    assign inst_sram_addr = nextpc;
    
    //br
    always @(posedge clk) begin
        if (reset) begin
            br_taken_r <= 1'b0;
            br_stall_r <= 1'b0;
            br_target_r <= 32'b0;
        end else if(br_stall) begin
            br_stall_r <= 1'b1;
        end else if (br_taken && !br_stall) begin
            br_taken_r <= 1'b1;
            br_target_r <= br_target;
        end else if (inst_sram_addr_ok && ~pfs_reflush && fs_allowin)begin
            br_taken_r <= 1'b0;
            br_stall_r <= 1'b0;
            br_target_r <= 32'b0;
        end 
    end
    
    always @(posedge clk) begin
        if (reset) begin
            flush_r <= 1'b0;
            flush_target_r <= 32'b0;
        end else if (flush) begin
            flush_r <= 1'b1;
            flush_target_r <= flush_target;
        end else if (inst_sram_addr_ok && ~pfs_reflush && fs_allowin) begin
            flush_r <= 1'b0;
            flush_target_r <= 32'b0;
        end

        if (reset) begin
            pfs_reflush <= 1'b0;
        end else if (inst_sram_req && (flush | (br_stall && inst_sram_addr_ok))) begin
            pfs_reflush <= 1'b1;
        end else if (inst_sram_data_ok) begin
            pfs_reflush <= 1'b0;
        end
    end
    
    //pc
    assign seq_pc = pfs_pc + 32'h4;
    assign nextpc   = flush      ? flush_target   :
                      flush_r    ? flush_target_r :
                      br_taken_r ? br_target_r    :
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