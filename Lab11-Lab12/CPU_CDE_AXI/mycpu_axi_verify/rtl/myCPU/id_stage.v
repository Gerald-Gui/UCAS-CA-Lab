`include "mycpu.h"
`include "csr.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,

    // blk signals from es, ms, ws
    input  [`ES_FWD_BLK_BUS_WD-1:0] es_fwd_blk_bus,
    input  [`MS_FWD_BLK_BUS_WD-1:0] ms_fwd_blk_bus,

    // exc && int
    input csr_has_int,
    input wb_exc,
    input wb_ertn,
    output [13:0] csr_rnum,
    input  [31:0] csr_rval,

    input [`ES_CSR_BLK_BUS_WD-1:0] es_csr_blk_bus,
    input [`MS_CSR_BLK_BUS_WD-1:0] ms_csr_blk_bus,
    input [`WS_CSR_BLK_BUS_WD-1:0] ws_csr_blk_bus
);


reg        wb_exc_r;
reg        wb_ertn_r;

wire            ds_ready_go;
reg             ds_valid;

reg  [`FS_TO_DS_BUS_WD -1:0]     fs_to_ds_bus_r;

wire [31:0]     ds_inst;
wire [31:0]     ds_pc  ;
wire [`EXC_NUM - 1:0]     fs_to_ds_exc_flgs;
assign {fs_to_ds_exc_flgs,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire            rf_we   ;
wire [ 4:0]     rf_waddr;
wire [31:0]     rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire            br_taken;
wire            br_taken_cancel;
wire            br_stall;
wire [31:0]     br_target;

// sigs for exc || int
wire [`EXC_NUM - 1:0] ds_exc_flgs;

wire [18:0]     alu_op;
wire [ 4:0]     load_op;
wire [ 2:0]     store_op;
wire            src1_is_pc;
wire            src2_is_imm;
wire            res_from_mul;
wire            dst_is_r1;
wire            gr_we;
wire            mem_we;
wire            src_reg_is_rd;
wire [4: 0]     dest;
wire [31:0]     rj_value;
wire [31:0]     rkd_value;
wire [31:0]     ds_imm;
wire [31:0]     br_offs;
wire [31:0]     jirl_offs;

wire [ 5:0]     op_31_26;
wire [ 3:0]     op_25_22;
wire [ 1:0]     op_21_20;
wire [ 4:0]     op_19_15;
wire [ 4:0]     rd;
wire [ 4:0]     rj;
wire [ 4:0]     rk;
wire [11:0]     i12;
wire [19:0]     i20;
wire [15:0]     i16;
wire [25:0]     i26;

wire [63:0]     op_31_26_d;
wire [15:0]     op_25_22_d;
wire [ 3:0]     op_21_20_d;
wire [31:0]     op_19_15_d;
  
wire            inst_add_w; 
wire            inst_sub_w;  
wire            inst_slt;    
wire            inst_sltu;   
wire            inst_nor;    
wire            inst_and;    
wire            inst_or;     
wire            inst_xor;    
wire            inst_slli_w;  
wire            inst_srli_w;  
wire            inst_srai_w;  
wire            inst_addi_w; 
wire            inst_ld_w;  
wire            inst_st_w;   
wire            inst_jirl;   
wire            inst_b;      
wire            inst_bl;     
wire            inst_beq;    
wire            inst_bne;    
wire            inst_lu12i_w;
// inst for lab6 and lab7
// basic calculation
wire            inst_slti;
wire            inst_sltui;
wire            inst_andi;
wire            inst_ori;
wire            inst_xori;
wire            inst_sll_w;
wire            inst_srl_w;
wire            inst_sra_w;
wire            inst_pcaddu12i;
// mul and div
wire            inst_mul_w;
wire            inst_mulh_w;
wire            inst_mulh_wu;
wire            inst_div_w;
wire            inst_div_wu;
wire            inst_mod_w;
wire            inst_mod_wu;
// other b type
wire            inst_blt;
wire            inst_bge;
wire            inst_bltu;
wire            inst_bgeu;
// other ls type
wire            inst_ld_b;
wire            inst_ld_h;
wire            inst_st_b;
wire            inst_st_h;
wire            inst_ld_bu;
wire            inst_ld_hu;
// csr r/w inst
wire            inst_csrrd;
wire            inst_csrwr;
wire            inst_csrxchg;
// int inst
wire            inst_syscall;
wire            inst_ertn;
wire            inst_break;
// timer inst
wire            inst_rdcntid_w;
wire            inst_rdcntvl_w;
wire            inst_rdcntvh_w;

wire            ds_rdcn_en;
wire            ds_rdcn_sel;

wire            need_ui5;
wire            need_ui12;
wire            need_si12;
wire            need_si16;
wire            need_si20;
wire            need_si26;
wire            src2_is_4;

wire [ 4:0]     rf_raddr1;
wire [31:0]     rf_rdata1;
wire [ 4:0]     rf_raddr2;
wire [31:0]     rf_rdata2;

// sigs for branch judgement
wire            rj_eq_rd;
wire            rj_lt_rd;
wire            rju_lt_rdu;

wire regs_minus_carry;
wire regs_minus_low;
wire [31:0] regs_minus_res;

// csr insts
wire        ds_csr_we;
wire        ds_csr_re;  // read enable
wire [13:0] ds_csr_wnum;
wire [31:0] ds_csr_wdata;
wire [31:0] ds_csr_rdata;
wire [31:0] ds_csr_wmask;
wire [31:0] csr_num_mask;

// block && forward strategy
wire            es_fwd_we;
wire            es_blk_we;
wire [ 4:0]     es_waddr;
wire [31:0]     es_wdata;
wire            ms_fwd_we;
wire            ms_blk_we;
wire [ 4:0]     ms_waddr;
wire [31:0]     ms_wdata;

wire            es_blk;
wire            es_reg1_hazard;
wire            es_reg2_hazard;
wire            ms_blk;
wire            ms_reg1_hazard;
wire            ms_reg2_hazard;
wire            ws_reg1_hazard;
wire            ws_reg2_hazard;

wire            src_reg1;
wire            src_reg2;

// RAW for csrs
wire        es_csr_we;
wire        es_eret;
wire [13:0] es_csr_wnum;
wire        ms_csr_we;
wire        ms_eret;
wire [13:0] ms_csr_wnum;
wire        ws_csr_we;
wire        ws_eret;
wire [13:0] ws_csr_wnum;

wire csr_blk;
wire es_csr_blk;
wire ms_csr_blk;
wire ws_csr_blk;

// RAW for common usr insts
assign {es_fwd_we, es_blk_we, es_waddr, es_wdata} = es_fwd_blk_bus;
assign {ms_fwd_we, ms_blk_we, ms_waddr, ms_wdata} = ms_fwd_blk_bus;

assign src_reg1 = ~ds_exc_flgs[`EXC_FLG_INE] & ~(inst_b | inst_bl | inst_csrrd | inst_csrwr | inst_syscall | inst_ertn | inst_break |
                                                 inst_rdcntid_w | inst_rdcntvh_w | inst_rdcntvl_w);
assign src_reg2 = inst_add_w  | inst_sub_w  | inst_slt    | inst_sltu   |
                  inst_nor    | inst_and    | inst_or     | inst_xor    |
                  inst_st_w   | inst_beq    | inst_bne    | inst_blt    |
                  inst_bge    | inst_bltu   | inst_bgeu   | inst_sll_w  |
                  inst_srl_w  | inst_sra_w  | inst_mul_w  | inst_mulh_w |
                  inst_mulh_wu| inst_div_w  | inst_div_wu | inst_mod_w  |
                  inst_mod_wu | inst_csrwr  | inst_csrxchg;

assign es_blk = es_blk_we && es_waddr != 0 && (
                src_reg1 && es_waddr == rf_raddr1 ||
                src_reg2 && es_waddr == rf_raddr2
                );

assign ms_blk = ms_blk_we && ms_waddr != 0 && (
                src_reg1 && ms_waddr == rf_raddr1 ||
                src_reg2 && ms_waddr == rf_raddr2
                );

assign es_reg1_hazard = es_fwd_we && es_waddr != 0 && src_reg1 && es_waddr == rf_raddr1;
assign es_reg2_hazard = es_fwd_we && es_waddr != 0 && src_reg2 && es_waddr == rf_raddr2;
assign ms_reg1_hazard = ms_fwd_we && ms_waddr != 0 && src_reg1 && ms_waddr == rf_raddr1;
assign ms_reg2_hazard = ms_fwd_we && ms_waddr != 0 && src_reg2 && ms_waddr == rf_raddr2;
assign ws_reg1_hazard = rf_we     && rf_waddr != 0 && src_reg1 && rf_waddr == rf_raddr1;
assign ws_reg2_hazard = rf_we     && rf_waddr != 0 && src_reg2 && rf_waddr == rf_raddr2;

assign ds_to_es_bus = {
                       ds_rdcn_en  ,  //285:285
                       ds_rdcn_sel ,  //284:284
                       ds_csr_we   ,  //283:283
                       ds_csr_re   ,  //282:282
                       ds_csr_wnum ,  //281:268
                       ds_csr_wmask,  //267:236
                       ds_csr_wdata,  //235:204
                       ds_csr_rdata,  //203:172
                       inst_ertn   ,  //171:171
                       ds_exc_flgs ,  //170:165
                       alu_op      ,  //164:146
                       res_from_mul,  //145:145
                       load_op     ,  //144:140
                       store_op    ,  //139:137
                       src1_is_pc  ,  //136:136
                       src2_is_imm ,  //135:135
                       gr_we       ,  //134:134
                       mem_we      ,  //133:133
                       dest        ,  //132:128
                       ds_imm      ,  //127:96
                       rj_value    ,  //95 :64
                       rkd_value   ,  //63 :32
                       ds_pc          //31 :0
                      };

// with blk
assign ds_ready_go    = ~(es_blk | ms_blk | csr_blk);
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid & ds_ready_go && ~(wb_ertn || wb_exc || wb_ertn_r || wb_exc_r);

always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
end

always @(posedge clk) begin 
    if(reset) begin
        fs_to_ds_bus_r <= `FS_TO_DS_BUS_WD'b0;
    end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

always @(posedge clk) begin
    if (reset) begin
        wb_exc_r <= 1'b0;
        wb_ertn_r <= 1'b0;
    end else if (wb_exc) begin
        wb_exc_r <= 1'b1;
    end else if (wb_ertn) begin
        wb_ertn_r <= 1'b1;
    end else if (fs_to_ds_valid & ds_allowin)begin
        wb_exc_r <= 1'b0;
        wb_ertn_r <= 1'b0;
    end
end

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

// add lab6 decode insts
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];


assign inst_slti  = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi  = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori   = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori  = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25];

assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];

assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];

assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];  
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];    
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];    
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];

assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];

assign inst_csrrd   = op_31_26_d[6'h01] & ds_inst[25:24] == 2'b0 & ds_inst[9:5] == 5'h00;
assign inst_csrwr   = op_31_26_d[6'h01] & ds_inst[25:24] == 2'b0 & ds_inst[9:5] == 5'h01;
assign inst_csrxchg = op_31_26_d[6'h01] & ds_inst[25:24] == 2'b0 & ds_inst[9:5] != 5'h00
                                                                 & ds_inst[9:5] != 5'h01;
assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b10] & op_19_15_d[5'h16];
assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0e;

assign inst_break   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b10] & op_19_15_d[5'h14];

assign inst_rdcntid_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h18 & rd == 5'h00;
assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h18 & rj == 5'h00;
assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h19 & rj == 5'h00;

assign ds_rdcn_en  = inst_rdcntvh_w | inst_rdcntvl_w;
assign ds_rdcn_sel = inst_rdcntvh_w;

assign alu_op[ 0] = inst_add_w  | inst_addi_w | (|load_op) | (|store_op) | inst_jirl | inst_bl |
                    inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt    | inst_slti;
assign alu_op[ 3] = inst_sltu   | inst_sltui;
assign alu_op[ 4] = inst_and    | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or     | inst_ori;
assign alu_op[ 7] = inst_xor    | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w ;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_div_wu;
assign alu_op[17] = inst_mod_w;
assign alu_op[18] = inst_mod_wu;

assign load_op  = {inst_ld_b, inst_ld_h, inst_ld_w, inst_ld_bu, inst_ld_hu};
assign store_op = {inst_st_b, inst_st_h, inst_st_w};

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si12  =  inst_addi_w |  (|load_op) | (|store_op) | inst_slti | inst_sltui;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bltu | inst_bge | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;


assign ds_imm = src2_is_4 ? 32'h4                      :
                need_si20 ? {i20[19:0], 12'b0}         :
		        // need_si20 ? {12'b0,i20[4:0],i20[19:5]} :  //i20[16:5]==i12[11:0]
                need_ui12 ? {20'b0,i12[11:0]}          :
  /*need_ui5 || need_si12*/ {{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} : 
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | (|store_op) | inst_csrwr | inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w | 
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       (|load_op)  |
                       (|store_op) |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i;

assign res_from_mul  = inst_mul_w | inst_mulh_w | inst_mulh_wu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~(|store_op)  & ~inst_beq  & ~inst_bne & ~inst_bge     & ~inst_bgeu    &
                       ~inst_blt     & ~inst_bltu & ~inst_b   & ~inst_syscall & ~inst_ertn    &
                       ~inst_break;
assign mem_we        = |store_op;
assign dest          = dst_is_r1      ? 5'd1 :
                       inst_rdcntid_w ? rj   : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = es_reg1_hazard ? es_wdata :
                   ms_reg1_hazard ? ms_wdata :
                   ws_reg1_hazard ? rf_wdata :
                                    rf_rdata1;
assign rkd_value = es_reg2_hazard ? es_wdata :
                   ms_reg2_hazard ? ms_wdata :
                   ws_reg2_hazard ? rf_wdata :
                                    rf_rdata2;

assign rj_eq_rd  = (rj_value == rkd_value);


assign {regs_minus_carry, regs_minus_res, regs_minus_low}
    = {1'b1, rj_value, 1'b1} + {1'b0, ~rkd_value, 1'b1};
assign rj_lt_rd = (rj_value[31] & ~rkd_value[31]) |
                 ((rj_value[31] ^~ rkd_value[31]) & regs_minus_res[31]);
assign rju_lt_rdu = regs_minus_carry;


assign br_taken = (   (inst_beq  &&  rj_eq_rd)
                   || (inst_bne  && !rj_eq_rd)
                   || (inst_blt  &&  rj_lt_rd)
                   || (inst_bge  && !rj_lt_rd)
                   || (inst_bltu &&  rju_lt_rdu)
                   || (inst_bgeu && !rju_lt_rdu)
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && ds_valid && ds_ready_go; 
assign br_target = (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_bl || inst_b) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);
// assign br_stall = es_blk | ms_blk | csr_blk;
assign br_taken_cancel = br_taken && ds_ready_go;
assign br_stall = (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_bl || inst_jirl || inst_b) & !ds_ready_go;
assign br_bus       = {br_taken,br_taken_cancel,br_stall,br_target};
/*
 *  exc && int
 */
assign ds_exc_flgs[`EXC_FLG_SYS]  = inst_syscall;
assign ds_exc_flgs[`EXC_FLG_INE]  = ~(inst_add_w  | inst_sub_w   | inst_slt   | inst_sltu      | inst_nor     |
                                      inst_and    | inst_or      | inst_xor   | inst_slli_w    | inst_srli_w  |
                                      inst_srai_w | inst_addi_w  | inst_ld_w  | inst_st_w      | inst_jirl    |
                                      inst_b      | inst_bl      | inst_beq   | inst_bne       | inst_lu12i_w |
                                      inst_slti   | inst_sltui   | inst_andi  | inst_ori       | inst_xori    |
                                      inst_sll_w  | inst_srl_w   | inst_sra_w | inst_pcaddu12i | inst_mul_w   |
                                      inst_mulh_w | inst_mulh_wu | inst_div_w | inst_div_wu    | inst_mod_w   |
                                      inst_mod_wu | inst_blt     | inst_bge   | inst_bltu      | inst_bgeu    |
                                      inst_ld_b   | inst_ld_h    | inst_st_b  | inst_st_h      | inst_ld_bu   |
                                      inst_ld_hu  | inst_csrrd   | inst_csrwr | inst_csrxchg   | inst_syscall |
                                      inst_ertn   | inst_break   | inst_rdcntid_w | inst_rdcntvh_w | inst_rdcntvl_w);
assign ds_exc_flgs[`EXC_FLG_INT]  = csr_has_int;
assign ds_exc_flgs[`EXC_FLG_BRK]  = inst_break;
// other exc flgs from fs
assign ds_exc_flgs[`EXC_FLG_ALE]  = fs_to_ds_exc_flgs[`EXC_FLG_ALE];
assign ds_exc_flgs[`EXC_FLG_ADEF] = fs_to_ds_exc_flgs[`EXC_FLG_ADEF];

// csr insts
assign ds_csr_we    = inst_csrwr | inst_csrxchg;
assign ds_csr_re    = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid_w;
assign ds_csr_wnum  = ds_inst[23:10];
assign ds_csr_wdata = rkd_value;
assign ds_csr_rdata = csr_rval;

assign csr_num_mask = {32{ds_csr_wnum == `CSR_CRMD  }} & `CSR_MASK_CRMD   |
                      {32{ds_csr_wnum == `CSR_PRMD  }} & `CSR_MASK_PRMD   |
                      {32{ds_csr_wnum == `CSR_ESTAT }} & `CSR_MASK_ESTAT  |
                      {32{ds_csr_wnum == `CSR_ERA   }} & `CSR_MASK_ERA    |
                      {32{ds_csr_wnum == `CSR_EENTRY}} & `CSR_MASK_EENTRY |
                      {32{ds_csr_wnum == `CSR_SAVE0 ||
                          ds_csr_wnum == `CSR_SAVE1 ||
                          ds_csr_wnum == `CSR_SAVE2 ||
                          ds_csr_wnum == `CSR_SAVE3 }} & `CSR_MASK_SAVE   |
                      {32{ds_csr_wnum == `CSR_ECFG  }} & `CSR_MASK_ECFG   |
                      {32{ds_csr_wnum == `CSR_BADV  }} & `CSR_MASK_BADV   |
                      {32{ds_csr_wnum == `CSR_TID   }} & `CSR_MASK_TID    |
                      {32{ds_csr_wnum == `CSR_TCFG  }} & `CSR_MASK_TCFG   |
                      {32{ds_csr_wnum == `CSR_TICLR }} & `CSR_MASK_TICLR;
assign ds_csr_wmask = inst_csrxchg ? rj_value : csr_num_mask;

assign csr_rnum = inst_rdcntid_w ? `CSR_TID : ds_inst[23:10];

// RAW for csrs
assign {es_csr_we, es_eret, es_csr_wnum} = es_csr_blk_bus;
assign {ms_csr_we, ms_eret, ms_csr_wnum} = ms_csr_blk_bus;
assign {ws_csr_we, ws_eret, ws_csr_wnum} = ws_csr_blk_bus;

assign csr_blk = ds_csr_re & (es_csr_blk | ms_csr_blk | ws_csr_blk);
assign es_csr_blk = es_csr_we &&  csr_rnum == es_csr_wnum && es_csr_wnum != 0 ||
                    es_eret   &&  csr_rnum == `CSR_CRMD                       ||
                    inst_ertn && (es_csr_wnum == `CSR_ERA || es_csr_wnum == `CSR_PRMD);
assign ms_csr_blk = ms_csr_we &&  csr_rnum == ms_csr_wnum && ms_csr_wnum != 0 ||
                    ms_eret   &&  csr_rnum == `CSR_CRMD                       ||
                    inst_ertn && (ms_csr_wnum == `CSR_ERA || ms_csr_wnum == `CSR_PRMD);
assign ws_csr_blk = ws_csr_we &&  csr_rnum == ws_csr_wnum && ws_csr_wnum != 0 ||
                    ws_eret   &&  csr_rnum == `CSR_CRMD                       ||
                    inst_ertn && (ws_csr_wnum == `CSR_ERA || ws_csr_wnum == `CSR_PRMD);

endmodule
