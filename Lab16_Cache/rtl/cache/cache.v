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

    wire rst = ~resetn;

    localparam  IDLE    = 5'b00001,
                LOOKUP  = 5'b00010,
                MISS    = 5'b00100,
                REPLACE = 5'b01000,
                REFILL  = 5'b10000;
    localparam  WRBUF_IDLE  = 2'b01,
                WRBUF_WRITE = 2'b10;

    reg [4:0] cur_state;
    reg [4:0] nxt_state;

    reg [1:0] wrbuf_cur_state;
    reg [1:0] wrbuf_nxt_state;

    wire        vtag_we    [1:0];
    wire [ 7:0] vtag_addr  [1:0];
    wire [20:0] vtag_wdata [1:0];   // 20:20 v; 19:0 tag
    wire [20:0] vtag_rdata [1:0];

    wire        data_bank_we    [1:0][3:0];
    wire [ 7:0] data_bank_addr  [1:0][3:0];
    wire [31:0] data_bank_wdata [1:0][3:0];
    wire [31:0] data_bank_rdata [1:0][3:0];

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

    genvar i;

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
