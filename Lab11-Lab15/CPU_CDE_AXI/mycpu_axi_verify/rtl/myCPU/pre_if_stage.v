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
    input  [31:0]                    flush_target,
    // csr
    input         csr_crmd_da,
    input         csr_crmd_pg,
    input  [ 1:0] csr_crmd_plv,
    // tlb
    output [19:0] s0_va_highbits,
    // s0_asid == csr.asid.asid
    input         s0_found,
    input  [ 3:0] s0_index,
    input  [19:0] s0_ppn,
    input  [ 5:0] s0_ps,
    input  [ 1:0] s0_plv,
    input  [ 1:0] s0_mat,
    input         s0_d,
    input         s0_v,
    // DMW
    input        csr_dmw0_plv0,
    input        csr_dmw0_plv3,
    input [ 1:0] csr_dmw0_mat,
    input [ 2:0] csr_dmw0_pseg,
    input [ 2:0] csr_dmw0_vseg,

    input        csr_dmw1_plv0,
    input        csr_dmw1_plv3,
    input [ 1:0] csr_dmw1_mat,
    input [ 2:0] csr_dmw1_pseg,
    input [ 2:0] csr_dmw1_vseg
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

    // exc flgs
    wire [`EXC_NUM - 1:0] pfs_exc_flgs;
    
    // v-p addr
    wire pfs_da;
    wire pfs_dmw0_hit;
    wire pfs_dmw1_hit;
    wire pfs_tlb_trans;
    wire [31:0] pfs_dmw0_paddr;
    wire [31:0] pfs_dmw1_paddr;
    wire [31:0] pfs_tlb_paddr;

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
    assign pfs_to_fs_bus = {pfs_exc_flgs, nextpc};

    assign inst_sram_req = pfs_valid && fs_allowin & ~(pfs_reflush);
    assign inst_sram_wr = 1'b0;
    assign inst_sram_size = 2'b10;
    assign inst_sram_wstrb = 4'b0;
    assign inst_sram_wdata = 32'b0;
    assign inst_sram_addr = pfs_da       ? nextpc         :
                            pfs_dmw0_hit ? pfs_dmw0_paddr :
                            pfs_dmw1_hit ? pfs_dmw1_paddr :
                                           pfs_tlb_paddr;
                            
    
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

    // v-p addr
    assign s0_va_highbits = nextpc[31:12];
    
    assign pfs_da = csr_crmd_da & ~csr_crmd_pg;
    assign pfs_dmw0_hit = nextpc[31:29] == csr_dmw0_vseg &&
                          (csr_crmd_plv == 2'd0 && csr_dmw0_plv0 || csr_crmd_plv == 2'd3 && csr_dmw0_plv3);
    assign pfs_dmw1_hit = nextpc[31:29] == csr_dmw1_vseg &&
                          (csr_crmd_plv == 2'd0 && csr_dmw1_plv0 || csr_crmd_plv == 2'd3 && csr_dmw1_plv3);
    assign pfs_dmw0_paddr = {csr_dmw0_pseg, nextpc[28:0]};
    assign pfs_dmw1_paddr = {csr_dmw1_pseg, nextpc[28:0]};
    assign pfs_tlb_paddr = s0_ps == 6'd22 ? {s0_ppn[19:10], nextpc[21:0]} :
                                            {s0_ppn, nextpc[11:0]};

    assign pfs_tlb_trans = ~pfs_da & ~pfs_dmw0_hit & ~pfs_dmw1_hit;
    // exc flgs
    assign pfs_exc_flgs[`EXC_FLG_SYS]  = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_ADEF] = (|nextpc[1:0]) | (nextpc[31] & csr_crmd_plv == 2'd3);
    assign pfs_exc_flgs[`EXC_FLG_ALE]  = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_BRK]  = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_INE]  = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_INT]  = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_ADEM] = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_TLBR_F] = pfs_tlb_trans & ~s0_found;
    assign pfs_exc_flgs[`EXC_FLG_TLBR_M] = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_PIL]  = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_PIS]  = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_PIF]  = pfs_tlb_trans & ~s0_v;
    assign pfs_exc_flgs[`EXC_FLG_PME]  = 1'b0;
    assign pfs_exc_flgs[`EXC_FLG_PPE_F] = pfs_tlb_trans & (csr_crmd_plv > s0_plv);
    assign pfs_exc_flgs[`EXC_FLG_PPE_M] = 1'b0;
endmodule
