`timescale 1ns / 1ps

module mylog2 #(
        parameter WIDTH = 32
    )(
        input  [        WIDTH - 1:0] src,
        output [$clog2(WIDTH) - 1:0] res
    );

    localparam IDX_WIDTH = $clog2(WIDTH);

    wire [IDX_WIDTH-1:0] base [IDX_WIDTH-1:0];

    assign base[IDX_WIDTH-1] = {1'b1, {IDX_WIDTH-1{1'b0}}};

    genvar i, j;
    generate 
        for (i = IDX_WIDTH-1; i > 0; i = i - 1) begin
            assign res[i] = src[base[i]+:({{IDX_WIDTH-1{1'b0}}, 1'b1} << i)] != 0;
            for (j = 0; j < IDX_WIDTH; j = j + 1) begin
                if (i == j) begin
                    assign base[i - 1][j] = res[i];
                end else if (i - 1 == j) begin
                    assign base[i - 1][j] = 1'b1;
                end else begin
                    assign base[i - 1][j] = base[i][j]; 
                end                
            end
        end
    endgenerate

    assign res[0] = src[base[0]];
endmodule