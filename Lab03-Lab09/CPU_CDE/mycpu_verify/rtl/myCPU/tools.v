module decoder_2_4(
    input  [ 1:0] in,
    output [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_4_16(
    input  [ 3:0] in,
    output [15:0] out
);

genvar i;
generate for (i=0; i<16; i=i+1) begin : gen_for_dec_4_16
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_5_32(
    input  [ 4:0] in,
    output [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  [ 5:0] in,
    output [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule

module mul_top(
        input clk,
        input rst,

        input mul_signed,

        input [31:0] src1,
        input [31:0] src2,

        output [63:0] res
    );

    wire [65:0] p [16:0];
    wire [16:0] c;
    wire [16:0] trans_p [65:0];

    wire [65:0] add_src1;
    wire [65:0] add_src2;
    wire [13:0] wallace_c [65:0];
    wire [65:0] Carry;
    wire [65:0] Sum;

    wire [32:0] ext_src1;
    wire [32:0] ext_src2;

    // reg [132:0] bus;

    // always @ (posedge clk) begin
    //     if (rst) begin
    //         bus <= 133'b0;
    //     end else begin
    //         bus <= {add_src1, add_src2, c[15]};
    //     end
    // end

    // assign res = bus[132:67] + bus[66:1] + {65'b0, bus[0]};
    assign res = add_src1 + add_src2 + {65'b0, c[15]};

    assign add_src1 = Sum;
    assign add_src2 = {Carry[64:0], c[14]};

    assign ext_src1 = {mul_signed & src1[31], src1};
    assign ext_src2 = {mul_signed & src2[31], src2};

    boothgen booth00(.y({ext_src2[1:0], 1'b0}), .p(p[ 0]), .c(c[ 0]), .x({{33{ext_src1[32]}}, ext_src1}));
    boothgen booth01(.y(ext_src2[ 3: 1]), .p(p[ 1]), .c(c[ 1]), .x({{31{ext_src1[32]}}, ext_src1,  2'b0}));
    boothgen booth02(.y(ext_src2[ 5: 3]), .p(p[ 2]), .c(c[ 2]), .x({{29{ext_src1[32]}}, ext_src1,  4'b0}));
    boothgen booth03(.y(ext_src2[ 7: 5]), .p(p[ 3]), .c(c[ 3]), .x({{27{ext_src1[32]}}, ext_src1,  6'b0}));
    boothgen booth04(.y(ext_src2[ 9: 7]), .p(p[ 4]), .c(c[ 4]), .x({{25{ext_src1[32]}}, ext_src1,  8'b0}));
    boothgen booth05(.y(ext_src2[11: 9]), .p(p[ 5]), .c(c[ 5]), .x({{23{ext_src1[32]}}, ext_src1, 10'b0}));
    boothgen booth06(.y(ext_src2[13:11]), .p(p[ 6]), .c(c[ 6]), .x({{21{ext_src1[32]}}, ext_src1, 12'b0}));
    boothgen booth07(.y(ext_src2[15:13]), .p(p[ 7]), .c(c[ 7]), .x({{19{ext_src1[32]}}, ext_src1, 14'b0}));
    boothgen booth08(.y(ext_src2[17:15]), .p(p[ 8]), .c(c[ 8]), .x({{17{ext_src1[32]}}, ext_src1, 16'b0}));
    boothgen booth09(.y(ext_src2[19:17]), .p(p[ 9]), .c(c[ 9]), .x({{15{ext_src1[32]}}, ext_src1, 18'b0}));
    boothgen booth10(.y(ext_src2[21:19]), .p(p[10]), .c(c[10]), .x({{13{ext_src1[32]}}, ext_src1, 20'b0}));
    boothgen booth11(.y(ext_src2[23:21]), .p(p[11]), .c(c[11]), .x({{11{ext_src1[32]}}, ext_src1, 22'b0}));
    boothgen booth12(.y(ext_src2[25:23]), .p(p[12]), .c(c[12]), .x({{ 9{ext_src1[32]}}, ext_src1, 24'b0}));
    boothgen booth13(.y(ext_src2[27:25]), .p(p[13]), .c(c[13]), .x({{ 7{ext_src1[32]}}, ext_src1, 26'b0}));
    boothgen booth14(.y(ext_src2[29:27]), .p(p[14]), .c(c[14]), .x({{ 5{ext_src1[32]}}, ext_src1, 28'b0}));
    boothgen booth15(.y(ext_src2[31:29]), .p(p[15]), .c(c[15]), .x({{ 3{ext_src1[32]}}, ext_src1, 30'b0}));
    boothgen booth16(.y({ext_src2[32], ext_src2[32:31]}), .p(p[16]), .c(c[16]), .x({ext_src1[32], ext_src1, 32'b0}));

    genvar i;
    generate
        for (i = 0; i < 66; i = i + 1) begin
            assign trans_p[i] = {p[16][i], p[15][i], p[14][i], p[13][i], p[12][i],
                                 p[11][i], p[10][i], p[ 9][i], p[ 8][i],
                                 p[ 7][i], p[ 6][i], p[ 5][i], p[ 4][i],
                                 p[ 3][i], p[ 2][i], p[ 1][i], p[ 0][i]};
        end
    endgenerate

    wallace w00(.clk(clk), .rst(rst), .in(trans_p[ 0]), .cin(c[13:0]), .cout(wallace_c[0]), .carry(Carry[0]), .sum(Sum[0]));

    generate
        for (i = 1; i < 66; i = i + 1) begin
            wallace wi(.clk(clk), .rst(rst), .in(trans_p[i]), .cin(wallace_c[i-1]), .cout(wallace_c[i]), .carry(Carry[i]), .sum(Sum[i]));
        end
    endgenerate

endmodule

module boothgen(
        input [ 2:0] y,
        input [65:0] x,
        output       c,
        output[65:0] p
    );

    wire [3:0] sel; // 0 -> +X; 1 -> +2X; 2 -> -2X; 3 -> -X

    assign sel[0] = ~y[2] & (y[1] ^ y[0]);
    assign sel[1] = ~y[2] &  y[1] &  y[0];
    assign sel[2] =  y[2] & ~y[1] & ~y[0];
    assign sel[3] =  y[2] & (y[1] ^ y[0]);

    assign c = sel[2] | sel[3];

    assign p[0] = sel[0] & x[0] | sel[2] | sel[3] & ~x[0];

    genvar i;
    generate
        for (i = 1; i < 66; i = i + 1) begin
            assign p[i] = sel[0] &  x[i    ] |
                          sel[1] &  x[i - 1] |
                          sel[2] & ~x[i - 1] |
                          sel[3] & ~x[i    ];
        end
    endgenerate


endmodule

module wallace (
        input clk,
        input rst,
        input [16:0] in,
        input [13:0] cin,

        output [13:0] cout,
        output        carry,
        output        sum
    );

    // wire [13:0] C_out;
    wire [15:0] Sum;


    // level 1
    csa3to2 csa1_1(.a(in[ 4]), .b(in[ 3]), .cin(in[ 2]), .sum(Sum[0]), .cout(cout[4]));
    csa3to2 csa1_2(.a(in[ 7]), .b(in[ 6]), .cin(in[ 5]), .sum(Sum[1]), .cout(cout[3]));
    csa3to2 csa1_3(.a(in[10]), .b(in[ 9]), .cin(in[ 8]), .sum(Sum[2]), .cout(cout[2]));
    csa3to2 csa1_4(.a(in[13]), .b(in[12]), .cin(in[11]), .sum(Sum[3]), .cout(cout[1]));
    csa3to2 csa1_5(.a(in[16]), .b(in[15]), .cin(in[14]), .sum(Sum[4]), .cout(cout[0]));

    // level 2
    csa3to2 csa2_1(.a(cin[2]), .b(cin[3]), .cin(cin[4]), .sum(Sum[5]), .cout(cout[8]));
    csa3to2 csa2_2(.a( in[0]), .b(cin[0]), .cin(cin[1]), .sum(Sum[6]), .cout(cout[7]));
    csa3to2 csa2_3(.a(Sum[1]), .b(Sum[0]), .cin( in[1]), .sum(Sum[7]), .cout(cout[6]));
    csa3to2 csa2_4(.a(Sum[4]), .b(Sum[3]), .cin(Sum[2]), .sum(Sum[8]), .cout(cout[5]));

    // level 3
    csa3to2 csa3_1(.a(Sum[5]), .b(cin[5]), .cin(cin[6]), .sum(Sum[ 9]), .cout(cout[10]));
    csa3to2 csa3_2(.a(Sum[8]), .b(Sum[7]), .cin(Sum[6]), .sum(Sum[10]), .cout(cout[ 9]));

    // level 4
    csa3to2 csa4_1(.a(cin[ 8]), .b(cin[9]), .cin(cin[10]), .sum(Sum[11]), .cout(cout[12]));
    csa3to2 csa4_2(.a(Sum[10]), .b(Sum[9]), .cin(cin[ 7]), .sum(Sum[12]), .cout(cout[11]));

    // level 5
    csa3to2 csa5_1(.a(Sum[12]), .b(Sum[11]), .cin(cin[11]), .sum(Sum[13]), .cout(cout[13]));

    // level 6
    csa3to2 csa6_1(.a(Sum[13]), .b(cin[12]), .cin(cin[13]), .sum(sum), .cout(carry));

endmodule

module csa3to2 #(
        parameter DATA_WIDTH = 1
    )(
        input [DATA_WIDTH - 1:0] a,
        input [DATA_WIDTH - 1:0] b,
        input cin,

        output cout,
        output [DATA_WIDTH - 1:0] sum
    );

    assign {cout, sum} = a + b + cin;

endmodule
