`include "csr.h"

module csr(
    input clk,
    input rst,

    input [8:0] csr_num,

    input        csr_we,
    input [31:0] csr_wmask,
    input [31:0] csr_wval,

    output [31:0] csr_rval,

    input       wb_exc,
    input [5:0] wb_ecode,
    input [8:0] wb_esubcode,

    input ertn_flush,

    output exc_entry,
    output has_int
);

endmodule
