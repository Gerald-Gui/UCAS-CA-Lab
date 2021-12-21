module cache(
        input  clk_g,
        input  resetn,

        input           valid,
        input           op,
        input  [ 7:0]   index,
        input  [19:0]   tag,
        input  [ 3:0]   offset,
        input  [ 3:0]   wstrb,
        input  [31:0]   wdata,

        output          addr_ok,
        output          data_ok,
        output [31:0]   rdata,

        output          rd_req,
        output [ 2:0]   rd_type,
        output [31:0]   rd_addr,
        input           rd_rdy,
        input           ret_valid,
        input           ret_last,
        input  [31:0]   ret_data,

        output          wr_req,
        output [  2:0]  wr_type,
        output [ 31:0]  wr_addr,
        output [  3:0]  wr_wstrb,
        output [127:0]  wr_data,
        input           wr_rdy
    );

    `define IDLE    0
    `define LOOKUP  1
    `define MISS    2
    `define REPLACE 3
    `define REFILL  4
    localparam  IDLE    = 5'b00001,
                LOOKUP  = 5'b00010,
                MISS    = 5'b00100,
                REPLACE = 5'b01000,
                REFILL  = 5'b10000;
    `define WRBUF_IDLE  0
    `define WRBUF_WRITE 1
    localparam  WRBUF_IDLE  = 2'b01,
                WRBUF_WRITE = 2'b10;
    genvar i, j;

    wire rst = ~resetn;

    reg [4:0] cur_state;
    reg [4:0] nxt_state;

    reg [1:0] wrbuf_cur_state;
    reg [1:0] wrbuf_nxt_state;

    // main state machine logic

    reg  [68:0] req_buf;   // {op, wstrb, wdata, index, tag, offset}
    wire        op_r;
    wire [ 3:0] wstrb_r;
    wire [31:0] wdata_r;
    wire [ 7:0] index_r;
    wire [19:0] tag_r;
    wire [ 3:0] offset_r;

    // cache tables
    // RAM ports
    wire        tag_we    [1:0];
    wire [ 7:0] tag_addr  [1:0];
    wire [19:0] tag_wdata [1:0];   // 19:0 tag
    wire [19:0] tag_rdata [1:0];

    wire [ 3:0] data_bank_we    [1:0][3:0];
    wire [ 7:0] data_bank_addr  [1:0][3:0];
    wire [31:0] data_bank_wdata [1:0][3:0];
    wire [31:0] data_bank_rdata [1:0][3:0];

    // valid array
    reg  [255:0] valid_arr [1:0];

    // dirty array
    reg  [255:0] dirty_arr [1:0];

    // hits
    wire [1:0] way_hit;
    wire cache_hit;

    wire hit_write;
    wire hit_write_hazard;

    // data
    wire [31:0] load_res;

    // replace && refill
    reg  [15:0] lfsr;
    wire        replace_way;
    reg  [ 1:0] ret_cnt;

    // axi wr
    reg  wr_req_r;

    // write state machine
    reg  [48:0] write_buf;  // way, index, offset, wstrb, wdata
    wire        wrbuf_way;
    wire [ 7:0] wrbuf_index;
    wire [ 3:0] wrbuf_offset;
    wire [ 3:0] wrbuf_wstrb;
    wire [31:0] wrbuf_wdata;

    // cache main state machine

    always @ (posedge clk_g) begin
        if (rst) begin
            cur_state <= IDLE;
        end else begin
            cur_state <= nxt_state;
        end
    end

    always @ (*) begin
        case (cur_state)
            IDLE:
                if (valid & ~hit_write_hazard) begin
                    nxt_state = LOOKUP;
                end else begin
                    nxt_state = IDLE;
                end
            LOOKUP:
                if (cache_hit & (~valid | hit_write_hazard)) begin
                    nxt_state = IDLE;
                end else if (cache_hit & valid) begin
                    nxt_state = LOOKUP;
                end else if (~dirty_arr[replace_way][index_r] | ~valid_arr[replace_way][index_r]) begin
                    nxt_state = REPLACE;
                end else begin
                    nxt_state = MISS;
                end
            MISS:
                if (~wr_rdy) begin
                    nxt_state = MISS;
                end else begin
                    nxt_state = REPLACE;
                end
            REPLACE:
                if (~rd_rdy) begin
                    nxt_state = REPLACE;
                end else begin
                    nxt_state = REFILL;
                end
            REFILL:
                if (ret_valid & ret_last) begin
                    nxt_state = IDLE;
                end else begin
                    nxt_state = REFILL;
                end
            default:nxt_state = IDLE;
        endcase
    end

    // IDLE
    
    always @ (posedge clk_g) begin
        if (rst) begin
            req_buf <= 69'b0;
        end else if (valid && addr_ok) begin
            req_buf <= {op, wstrb, wdata, index, tag, offset};
        end
    end
    assign {op_r, wstrb_r, wdata_r, index_r, tag_r, offset_r} = req_buf;
    
    assign tag_addr[0] = cur_state[`IDLE] || cur_state[`LOOKUP] ? index : index_r;
    assign tag_addr[1] = cur_state[`IDLE] || cur_state[`LOOKUP] ? index : index_r;

    generate
        for (i = 0; i < 2; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                assign data_bank_addr[i][j] = cur_state[`IDLE] || cur_state[`LOOKUP] ? index : index_r;
            end
        end
    endgenerate

    
    // LOOKUP
    assign way_hit[0] = valid_arr[0][index_r] && (tag_rdata[0][19:0] == tag_r);
    assign way_hit[1] = valid_arr[1][index_r] && (tag_rdata[1][19:0] == tag_r);
    assign cache_hit = |way_hit;

    assign hit_write = cache_hit & op_r & cur_state[`LOOKUP];

    assign hit_write_hazard = cur_state[`LOOKUP] && hit_write && valid && ~op && {index, offset} == {index_r, offset_r} ||
                              wrbuf_cur_state[`WRBUF_WRITE] && valid && ~op && offset[3:2] == offset_r[3:2];

    assign load_res = data_bank_rdata[way_hit[1]][offset_r[3:2]];

    // replace
    always @ (posedge clk_g) begin
        if (rst) begin
            lfsr <= 16'b1001_1101_1101_1000;
        end else if (ret_valid & ret_last) begin
            lfsr <= {lfsr[0] ^ lfsr[4] ^ lfsr[8] ^ lfsr[12], lfsr[15:1]};
        end
    end
    assign replace_way = lfsr[0];

    // refill
    always @ (posedge clk_g) begin
        if (rst) begin
            ret_cnt <= 2'b0;
        end else if (ret_valid & ~ret_last) begin
            ret_cnt <= ret_cnt + 2'd1;
        end else if (ret_valid & ret_last) begin
            ret_cnt <= 2'b0;
        end
    end

    // write buffer state machine
    always @ (posedge clk_g) begin
        if (rst) begin
            wrbuf_cur_state <= WRBUF_IDLE;
        end else begin
            wrbuf_cur_state <= wrbuf_nxt_state;
        end
    end

    always @ (*) begin
        case (wrbuf_cur_state)
            WRBUF_IDLE:
                if (hit_write) begin
                    wrbuf_nxt_state = WRBUF_WRITE;
                end else begin
                    wrbuf_nxt_state = WRBUF_IDLE;
                end
            WRBUF_WRITE:
                if (hit_write) begin
                    wrbuf_nxt_state = WRBUF_WRITE;
                end else begin
                    wrbuf_nxt_state = WRBUF_IDLE;
                end
            default:wrbuf_nxt_state = WRBUF_IDLE;
        endcase
    end

    always @ (posedge clk_g) begin
        if (rst) begin
            write_buf <= 49'b0;
        end else if (hit_write) begin
            write_buf <= {way_hit[1], index_r, offset_r, wstrb_r, wdata_r};
        end
    end
    
    assign {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata} = write_buf;
    
    // dirty array
    always @ (posedge clk_g) begin
        if (rst) begin
            dirty_arr[0] <= 256'b0;
            dirty_arr[1] <= 256'b0;
        end else if (wrbuf_cur_state[`WRBUF_WRITE]) begin
            dirty_arr[wrbuf_way][wrbuf_index] <= 1'b1;
        end else if (ret_valid & ret_last) begin
            dirty_arr[replace_way][index_r] <= op_r;
        end
    end

    // to cpu
    assign addr_ok = cur_state[`IDLE]
                   | cur_state[`LOOKUP] & valid &  op & cache_hit
                   | cur_state[`LOOKUP] & valid & ~op & cache_hit & ~hit_write_hazard;
    assign data_ok = cur_state[`LOOKUP] & cache_hit
                   | cur_state[`LOOKUP] & op_r
                   | cur_state[`REFILL] & ret_valid & ret_cnt == offset_r[3:2] & ~op_r;
    assign rdata = ret_valid ? ret_data : load_res;

    // to axi
    assign rd_req  = cur_state[`REPLACE];
    assign rd_type = 3'b100;
    assign rd_addr = {tag_r, index_r, offset_r};

    assign wr_req = wr_req_r;
    always @ (posedge clk_g) begin
        if (rst) begin
            wr_req_r <= 1'b0;
        end else if (cur_state[`MISS] & wr_rdy) begin
            wr_req_r <= 1'b1;
        end else begin
            wr_req_r <= 1'b0;
        end
    end
    assign wr_type  = 3'b100;
    assign wr_addr  = {tag_rdata[replace_way][19:0], index_r, offset_r};
    assign wr_wstrb = 4'hf;
    assign wr_data  = {data_bank_rdata[replace_way][3],
                       data_bank_rdata[replace_way][2],
                       data_bank_rdata[replace_way][1],
                       data_bank_rdata[replace_way][0]};

    // valid array
    always @ (posedge clk_g) begin
        if (rst) begin
            valid_arr[0] <= 256'b0;
            valid_arr[1] <= 256'b0;
        end else if (ret_valid & ret_last) begin
            valid_arr[replace_way][index_r] <= 1'b1;
        end
    end

    assign tag_we[0] = ret_valid & ret_last & ~replace_way;
    assign tag_we[1] = ret_valid & ret_last &  replace_way;
    assign tag_wdata[0] = tag_r;
    assign tag_wdata[1] = tag_r;

    // tag ram
    generate for (i = 0; i < 2; i = i + 1) begin
        tag_ram tag_rami(
            .clka (clk_g),
            .wea  (tag_we[i]),
            .addra(tag_addr[i]),
            .dina (tag_wdata[i]),
            .douta(tag_rdata[i])
        );
    end
    endgenerate

    // data bank ram

    generate
        for (i = 0; i < 4; i = i + 1) begin
            assign data_bank_we[0][i] = {4{wrbuf_cur_state[`WRBUF_WRITE] & wrbuf_offset[3:2] == i & ~wrbuf_way}} & wrbuf_wstrb
                                      | {4{ret_valid & ret_cnt == i & ~replace_way}} & 4'hf;
            assign data_bank_we[1][i] = {4{wrbuf_cur_state[`WRBUF_WRITE] & wrbuf_offset[3:2] == i &  wrbuf_way}} & wrbuf_wstrb
                                      | {4{ret_valid & ret_cnt == i &  replace_way}} & 4'hf;
            assign data_bank_wdata[0][i] = wrbuf_cur_state[`WRBUF_WRITE] ? wrbuf_wdata :
                                           offset_r[3:2] != i || ~op_r   ? ret_data    :
                                           {wstrb_r[3] ? wdata_r[31:24] : ret_data[31:24],
                                            wstrb_r[2] ? wdata_r[23:16] : ret_data[23:16],
                                            wstrb_r[1] ? wdata_r[15: 8] : ret_data[15: 8],
                                            wstrb_r[0] ? wdata_r[ 7: 0] : ret_data[ 7: 0]};
            assign data_bank_wdata[1][i] = wrbuf_cur_state[`WRBUF_WRITE] ? wrbuf_wdata :
                                           offset_r[3:2] != i || ~op_r   ? ret_data    :
                                           {wstrb_r[3] ? wdata_r[31:24] : ret_data[31:24],
                                            wstrb_r[2] ? wdata_r[23:16] : ret_data[23:16],
                                            wstrb_r[1] ? wdata_r[15: 8] : ret_data[15: 8],
                                            wstrb_r[0] ? wdata_r[ 7: 0] : ret_data[ 7: 0]};
        end
    endgenerate

    // way 0
    generate for (i = 0; i < 4; i = i + 1) begin
        data_bank_ram db_rami(
            .clka (clk_g),
            .wea  (data_bank_we[0][i]),
            .addra(data_bank_addr[0][i]),
            .dina (data_bank_wdata[0][i]),
            .douta(data_bank_rdata[0][i])
        );
    end
    endgenerate

    // way 1
    generate for (i = 0; i < 4; i = i + 1) begin
        data_bank_ram db_rami(
            .clka (clk_g),
            .wea  (data_bank_we[1][i]),
            .addra(data_bank_addr[1][i]),
            .dina (data_bank_wdata[1][i]),
            .douta(data_bank_rdata[1][i])
        );
    end
    endgenerate

endmodule
