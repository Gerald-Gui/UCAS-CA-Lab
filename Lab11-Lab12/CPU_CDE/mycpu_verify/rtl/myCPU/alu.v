module alu(
    input           clk,
    input           rst,
    input  [18:0]   alu_op,
    input  [31:0]   alu_src1,
    input  [31:0]   alu_src2,
    output [31:0]   alu_result,
  
    // lab6 added, for mul and div
    input           es_valid,
    output          is_div,
    output          div_res_sel,
    output          div_es_go,
    output          div_finish,
    output [64:0]   mul_res_bus,   // to MEM stage
    output [63:0]   div_res_bus   // to WB stage
);

wire op_add;    //add operation
wire op_sub;    //sub operation
wire op_slt;    //signed compared and set less than
wire op_sltu;   //unsigned compared and set less than
wire op_and;    //bitwise and
wire op_nor;    //bitwise nor
wire op_or;     //bitwise or
wire op_xor;    //bitwise xor
wire op_sll;    //logic left shift
wire op_srl;    //logic right shift
wire op_sra;    //arithmetic right shift
wire op_lui;    //Load Upper Immediate
wire op_mul;    //multiple
wire op_mulh;   //multiple
wire op_mulhu;  //multiple
wire op_div;    //divide
wire op_divu;   //fetch mod
wire op_mod;    //fetch mod
wire op_modu;   //fetch mod

reg  mul_res_sel; // 1 -> high; 0 -> low

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [63:0] mul_result;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mul  = alu_op[12];
assign op_mulh = alu_op[13];
assign op_mulhu= alu_op[14];
assign op_div  = alu_op[15];
assign op_divu = alu_op[16];
assign op_mod  = alu_op[17];
assign op_modu = alu_op[18];

assign is_div   = op_div | op_divu | op_mod | op_modu;
wire   use_div  = op_div | op_mod;
wire   use_divu = op_divu| op_modu;
assign div_res_sel = op_div | op_divu;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + {32'b0, adder_cin};

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
// assign lui_result = {alu_src2[14:0], alu_src2[19:15], 12'b0};
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

// MUL result
mul_top umul(
    .clk(clk),
    .rst(rst),
    .mul_signed(op_mulh),
    .src1(alu_src1),
    .src2(alu_src2),
    .res(mul_result)
);

assign mul_res_bus = {mul_res_sel, mul_result};

always @ (posedge clk) begin
    if (rst) begin
        mul_res_sel <= 1'b0;
    end else begin
        mul_res_sel <= op_mulh | op_mulhu;
    end
end

divider alu_div(
    .clk(clk),
    .rst(rst),
    .div(is_div),
    .div_signed(use_div),
    .x(alu_src1),
    .y(alu_src2),
    .div_total_result(div_res_bus),
    .es_go(div_es_go),
    .complete(div_finish)
);

// final result mux
assign alu_result = ({32{op_add | op_sub }} & add_sub_result)
                  | ({32{op_slt          }} & slt_result)
                  | ({32{op_sltu         }} & sltu_result)
                  | ({32{op_and          }} & and_result)
                  | ({32{op_nor          }} & nor_result)
                  | ({32{op_or           }} & or_result)
                  | ({32{op_xor          }} & xor_result)
                  | ({32{op_lui          }} & lui_result)
                  | ({32{op_sll          }} & sll_result)
                  | ({32{op_srl | op_sra }} & sr_result);

endmodule
