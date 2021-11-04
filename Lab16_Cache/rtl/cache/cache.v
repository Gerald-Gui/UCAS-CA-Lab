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
        input  [ 2:0]   ret_last,
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
    genvar i;

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

    // RAM ports

    wire        vtag_we    [1:0];
    wire [ 7:0] vtag_addr  [1:0];
    wire [20:0] vtag_wdata [1:0];   // 20:20 v; 19:0 tag
    wire [20:0] vtag_rdata [1:0];

    wire        data_bank_we    [1:0][3:0];
    wire [ 7:0] data_bank_addr  [1:0][3:0];
    wire [31:0] data_bank_wdata [1:0][3:0];
    wire [31:0] data_bank_rdata [1:0][3:0];



    wire hit_write; 

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
                if (valid) begin
                    nxt_state = LOOKUP;
                end else begin
                    nxt_state = IDLE;
                end
            default:nxt_state = IDLE;
        endcase
    end

    // IDLE

    assign addr_ok = cur_state[`IDLE];
    
    always @ (posedge clk_g) begin
        if (rst) begin
            req_buf <= 69'b0;
        end else if (valid && addr_ok) begin
            req_buf <= {op, wstrb, wdata, index, tag, offset};
        end
    end
    assign {op_r, wstrb_r, wdata_r, index_r, tag_r, offset_r} = req_buf;

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


    // vtag ram: 20:20 v; 19:0 tag
    generate for (i = 0; i < 2; i = i + 1) begin
        v_tag_ram vtag_rami(
            .clka (clk_g),
            .wea  (vtag_we[i]),
            .addra(vtag_addr[i]),
            .dina (vtag_wdata[i]),
            .douta(vtag_rdata[i])
        );
    end
    endgenerate

    // data bank ram
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
