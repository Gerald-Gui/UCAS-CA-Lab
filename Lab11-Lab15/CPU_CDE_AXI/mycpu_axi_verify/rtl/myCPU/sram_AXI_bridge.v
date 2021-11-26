`include "mycpu.h"

module sram_AXI_bridge (
    input           aclk,
    input           aresetn,
    // read requeset
    // master->slave
    output [ 3:0]   arid,
    output [31:0]   araddr,
    output [ 7:0]   arlen,
    output [ 2:0]   arsize,
    output [ 1:0]   arburst,
    output [ 1:0]   arlock,
    output [ 3:0]   arcache,
    output [ 2:0]   arprot,
    output          arvalid,
    // slave->master
    input           arready,
    // read response
    // slave->master
    input  [ 3:0]   rid,
    input  [31:0]   rdata,
    input  [ 1:0]   rresp,
    input           rlast,
    input           rvalid,
    // master->slave
    output          rready,
    // write request
    // master->slave
    output [ 3:0]   awid,
    output [31:0]   awaddr,
    output [ 7:0]   awlen,
    output [ 2:0]   awsize,
    output [ 1:0]   awburst,
    output [ 1:0]   awlock,
    output [ 3:0]   awcache,
    output [ 2:0]   awprot,
    output          awvalid,
    // slave->master
    input           awready,
    // write data
    // master->slave
    output  [ 3:0]  wid,
    output  [31:0]  wdata,
    output  [ 3:0]  wstrb,
    output          wlast,
    output          wvalid,
    // slave->master
    input           wready,
    // write response
    // slave->master
    input  [ 3:0]   bid,
    input  [ 1:0]   bresp,
    input           bvalid,
    // master->slave
    output          bready,
    
    // inst sram interface
    input           inst_sram_req,
    input           inst_sram_wr,
    input  [ 1:0]   inst_sram_size,
    input  [31:0]   inst_sram_addr,
    input  [ 3:0]   inst_sram_wstrb,
    input  [31:0]   inst_sram_wdata,
    output          inst_sram_addr_ok,
    output          inst_sram_data_ok,
    output [31:0]   inst_sram_rdata,
    // data sram interface
    input           data_sram_req,
    input           data_sram_wr,
    input  [ 1:0]   data_sram_size,
    input  [31:0]   data_sram_addr,
    input  [ 3:0]   data_sram_wstrb,
    input  [31:0]   data_sram_wdata,
    output          data_sram_addr_ok,
    output          data_sram_data_ok,
    output [31:0]   data_sram_rdata
);

// axi buffer
reg  [ 3:0] arid_r   ;
reg  [31:0] araddr_r ;
reg  [ 2:0] arsize_r ;
reg         arvalid_r;
// reg         rready_r ;
reg  [31:0] awaddr_r ;
reg  [ 2:0] awsize_r ;
reg         awvalid_r;
reg         awready_valid;
reg  [31:0] wdata_r  ;
reg  [ 3:0] wstrb_r  ;
reg         wvalid_r ;
reg         bready_r ;

reg  [ 3:0] rid_r;

// sram data buffer
reg  [31:0] inst_sram_data_buffer;
reg  [31:0] data_sram_data_buffer;

wire write_read_block;

// state machine
// parameter for state machine
parameter READ_REQ_RST          = 5'b00001;
parameter READ_DATA_REQ_START   = 5'b00010;
parameter READ_INST_REQ_START   = 5'b00100;
parameter READ_DATA_REQ_CHECK   = 5'b01000;
parameter READ_REQ_END          = 5'b10000;

parameter READ_DATA_RST         = 3'b001;
parameter READ_DATA_START       = 3'b010;
parameter READ_DATA_END         = 3'b100;

parameter WRITE_RST             = 4'b0001;
parameter WRITE_CHECK           = 4'b0010;
parameter WRITE_START           = 4'b0100;
parameter WRITE_RD_END          = 4'b1000;

parameter WRITE_RESPONSE_RST    = 3'b001;
parameter WRITE_RESPONSE_START  = 3'b010;
parameter WRITE_RESPONSE_END    = 3'b100;

// 4 state machine
reg  [ 4:0] rreq_cur_state;
reg  [ 4:0] rreq_nxt_state;
reg  [ 2:0] rdata_cur_state;
reg  [ 2:0] rdata_nxt_state;
reg  [ 3:0] wrd_cur_state;
reg  [ 3:0] wrd_nxt_state;
reg  [ 2:0] wresp_cur_state;
reg  [ 2:0] wresp_nxt_state;

reg  [ 1:0] read_business_counter [1:0];
reg  [ 1:0] write_business_counter;

// fixed assignment
// ar
assign arid    = arid_r;
assign araddr  = araddr_r;
assign arlen   = 8'b0;
assign arsize  = arsize_r;
assign arburst = 2'b1;
assign arlock  = 2'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;
assign arvalid = arvalid_r;
// r
assign rready  = |read_business_counter[0] || |read_business_counter[1];
// aw
assign awid    = 4'b1;
assign awaddr  = awaddr_r;
assign awlen   = 8'b0;
assign awsize  = awsize_r;
assign awburst = 2'b01;
assign awlock  = 2'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
assign awvalid = awvalid_r;
// w
assign wid     = 4'b1;
assign wdata   = wdata_r;
assign wstrb   = wstrb_r;
assign wlast   = 1'b1;
assign wvalid  = wvalid_r;
// b
assign bready  = bready_r;

// current state
always @(posedge aclk) begin
    if(~aresetn) begin
        rreq_cur_state <= READ_REQ_RST;
        rdata_cur_state <= READ_DATA_RST;
        wrd_cur_state <= WRITE_RST;
        wresp_cur_state <= WRITE_RESPONSE_RST;
    end else begin
        rreq_cur_state <= rreq_nxt_state;
        rdata_cur_state <= rdata_nxt_state;
        wrd_cur_state <= wrd_nxt_state;
        wresp_cur_state <= wresp_nxt_state;
    end
end

// next state, not clk!
always @(*) begin
    case(rreq_cur_state)
        READ_REQ_RST: begin
            if(data_sram_req && ~data_sram_wr) begin
                rreq_nxt_state = READ_DATA_REQ_CHECK;
            end else if(inst_sram_req) begin
                rreq_nxt_state = READ_INST_REQ_START;
            end else begin
                rreq_nxt_state = READ_REQ_RST;
            end
        end
        READ_DATA_REQ_START,READ_INST_REQ_START: begin
            if(arready && arvalid) begin
                rreq_nxt_state = READ_REQ_END;
            end else begin
                rreq_nxt_state = rreq_cur_state;
            end
        end
        READ_DATA_REQ_CHECK: begin
            if(bready && write_read_block) begin
                rreq_nxt_state = READ_DATA_REQ_CHECK;
            end else begin
                rreq_nxt_state = READ_DATA_REQ_START;
            end
        end
        READ_REQ_END: begin
            rreq_nxt_state = READ_REQ_RST;
        end
        default:
            rreq_nxt_state = READ_REQ_RST;
    endcase
end

always @(*) begin
    case(rdata_cur_state)
        READ_DATA_RST: begin
            if((arready && arvalid) || |read_business_counter[0] || |read_business_counter[1]) begin
                rdata_nxt_state = READ_DATA_START;
            end else begin
                rdata_nxt_state = READ_DATA_RST;
            end
        end
        READ_DATA_START: begin
            if(rvalid && rready) begin
                rdata_nxt_state = READ_DATA_END;
            end else begin
                rdata_nxt_state = rdata_cur_state;
            end
        end
        READ_DATA_END: begin
            if (rvalid && rready) begin
                rdata_nxt_state = READ_DATA_END;
            end else if(|read_business_counter[0] || |read_business_counter[1]) begin
                rdata_nxt_state = READ_DATA_START;
            end else begin
                rdata_nxt_state = READ_DATA_RST;
            end
        end
        default:
            rdata_nxt_state = READ_DATA_RST;
    endcase
end

always @(*) begin
    case(wrd_cur_state)
        WRITE_RST: begin
            if(data_sram_req && data_sram_wr) begin
                wrd_nxt_state = WRITE_CHECK;
            end else begin
                wrd_nxt_state = WRITE_RST;
            end
        end
        WRITE_CHECK: begin
            if(rready && write_read_block) begin
                wrd_nxt_state = WRITE_CHECK;
            end else begin
                wrd_nxt_state = WRITE_START;
            end
        end
        WRITE_START: begin
            if(wvalid && wready) begin
                wrd_nxt_state = WRITE_RD_END;
            end else begin
                wrd_nxt_state = wrd_cur_state;
            end
        end
        WRITE_RD_END: begin
            wrd_nxt_state = WRITE_RST;
        end
        default:
            wrd_nxt_state = WRITE_RST;
    endcase
end

always @(*) begin
    case(wresp_cur_state)
        WRITE_RESPONSE_RST: begin
            if(wvalid && wready) begin
                wresp_nxt_state = WRITE_RESPONSE_START;
            end else begin
                wresp_nxt_state = WRITE_RESPONSE_RST;
            end
        end
        WRITE_RESPONSE_START: begin
            if(bvalid && bready) begin
                wresp_nxt_state = WRITE_RESPONSE_END;
            end else begin
                wresp_nxt_state = wresp_cur_state;
            end
        end
        WRITE_RESPONSE_END: begin
            if(bvalid && bready) begin
                wresp_nxt_state = WRITE_RESPONSE_END;
            end if((wvalid && wready) || (write_business_counter != 2'b0)) begin
                wresp_nxt_state = WRITE_RESPONSE_START;
            end else begin
                wresp_nxt_state = WRITE_RESPONSE_RST;
            end
        end
        default:
            wresp_nxt_state = WRITE_RESPONSE_RST;
    endcase
end

// use counter to deal with multi-business
always @(posedge aclk) begin
    if(~aresetn) begin
        read_business_counter[0] <= 2'b0;
        read_business_counter[1] <= 2'b0;
    end else if(arready && arvalid && rvalid && rready) begin
        if(arid == 4'b0 && rid == 4'b0) begin
            read_business_counter[0] <= read_business_counter[0];
        end else if(arid == 4'b1 && rid == 4'b1) begin
            read_business_counter[1] <= read_business_counter[1];
        end else if(arid == 4'b0 && rid == 4'b1) begin
            read_business_counter[0] <= read_business_counter[0] + 2'b1;
            read_business_counter[1] <= read_business_counter[1] - 2'b1;
        end else if(arid == 4'b1 && rid == 4'b0) begin
            read_business_counter[0] <= read_business_counter[0] - 2'b1;
            read_business_counter[1] <= read_business_counter[1] + 2'b1;
        end
    end else if(arready && arvalid) begin
        if(arid == 4'b0) begin
            read_business_counter[0] <= read_business_counter[0] + 2'b1;
        end else if(arid == 4'b1) begin
            read_business_counter[1] <= read_business_counter[1] + 2'b1;
        end
    end else if(rvalid && rready) begin
        if(rid == 4'b0) begin
            read_business_counter[0] <= read_business_counter[0] - 2'b1;
        end else if(rid == 4'b1) begin
            read_business_counter[1] <= read_business_counter[1] - 2'b1;
        end
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        write_business_counter <= 2'b0;
    end else if(bvalid && bready && wvalid && wready) begin
        write_business_counter <= write_business_counter;
    end else if(wvalid && wready) begin
        write_business_counter <= write_business_counter + 2'b1;
    end else if(bvalid && bready) begin
        write_business_counter <= write_business_counter - 2'b1;
    end
end

// AXI
// reg signal
// READ
// ar
always @(posedge aclk) begin
    if(~aresetn) begin
        arid_r <= 4'b0;
        araddr_r <= 32'b0;
        arsize_r <= 3'b0;
    end else if((rreq_nxt_state == READ_DATA_REQ_START) || (rreq_cur_state == READ_DATA_REQ_START)) begin
        arid_r <= 4'b1;
        araddr_r <= data_sram_addr;
        arsize_r <= {1'b0,data_sram_size};
    end else if((rreq_nxt_state == READ_INST_REQ_START) || (rreq_cur_state == READ_INST_REQ_START)) begin
        arid_r <= 4'b0;
        araddr_r <= inst_sram_addr;
        arsize_r <= {1'b0,inst_sram_size};
    end else begin
        arid_r <= 4'b0;
        araddr_r <= 32'b0;
        arsize_r <= 3'b0;
    end
end

always @(posedge aclk) begin
    if(~aresetn || arready) begin
        arvalid_r <= 1'b0;
    end else if(rreq_cur_state == READ_DATA_REQ_START || rreq_cur_state == READ_INST_REQ_START) begin
        arvalid_r <= 1'b1;
    end else begin
        arvalid_r <= arvalid_r;
    end
end


always @(posedge aclk) begin
    if(~aresetn || rdata_nxt_state == READ_DATA_RST) begin
        rid_r <= 4'b0;
    end else if(rvalid) begin
        rid_r <= rid;
    end else begin
        rid_r <= rid_r;
    end
end

// WRITE
// aw
always @(posedge aclk) begin
    if(~aresetn) begin
        awaddr_r <= 32'b0;
        awsize_r <= 3'b0;
    end else if(wrd_cur_state == WRITE_START) begin
        awaddr_r <= data_sram_addr;
        awsize_r <= {1'b0,data_sram_size};
    end else begin
        awaddr_r <= 32'b0;
        awsize_r <= 3'b0;
    end
end

always @(posedge aclk) begin
    if(~aresetn || awready || awready_valid) begin
        awvalid_r <= 1'b0;
    end else if(wrd_cur_state == WRITE_START) begin
        awvalid_r <= 1'b1;
    end else begin
        awvalid_r <= awvalid_r;
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        awready_valid <= 1'b0;
    end else if(awvalid && awready) begin
        awready_valid <= 1'b1;
    end else if(wrd_nxt_state == WRITE_RD_END) begin
        awready_valid <= 1'b0;
    end
end

// w
always @(posedge aclk) begin
    if(~aresetn) begin
        wdata_r <= 32'b0;
        wstrb_r <= 4'b0;
    end else if(wrd_cur_state == WRITE_START) begin
        wdata_r <= data_sram_wdata;
        wstrb_r <= data_sram_wstrb;
    end else begin
        wdata_r <= wdata_r;
        wstrb_r <= wstrb_r;
    end
end

always @(posedge aclk) begin
    if(~aresetn || wready) begin
        wvalid_r <= 1'b0;
    end else if(wrd_cur_state == WRITE_START) begin
        wvalid_r <= 1'b1;
    end else begin
        wvalid_r <= 1'b0;
    end
end

// b
always @(posedge aclk) begin
    if(~aresetn || bvalid) begin
        bready_r <= 1'b0;
    end else if(wresp_nxt_state == WRITE_RESPONSE_START) begin
        bready_r <= 1'b1;
    end else begin
        bready_r <= 1'b0;
    end
end

// SRAM
assign inst_sram_addr_ok = (rreq_cur_state == READ_REQ_END && ~arid[0]);
assign inst_sram_data_ok = (rdata_cur_state == READ_DATA_END && ~rid_r[0]);
assign data_sram_addr_ok = ((rreq_cur_state == READ_REQ_END && arid[0]) || (wrd_cur_state == WRITE_RD_END));
assign data_sram_data_ok = (rdata_cur_state == READ_DATA_END && rid_r[0]) || (wresp_cur_state == WRITE_RESPONSE_END);

always @(posedge aclk) begin
    if(~aresetn) begin
        inst_sram_data_buffer <= 32'b0;
    end else if(rvalid && rready && ~rid[0]) begin
        inst_sram_data_buffer <= rdata;
    end

    if(~aresetn) begin
        data_sram_data_buffer <= 32'b0;
    end else if(rvalid && rready && rid[0]) begin
        data_sram_data_buffer <= rdata;
    end
end

assign inst_sram_rdata = inst_sram_data_buffer;
assign data_sram_rdata = data_sram_data_buffer;

assign write_read_block = (awaddr_r == araddr_r) && (arvalid_r && awvalid_r);

endmodule