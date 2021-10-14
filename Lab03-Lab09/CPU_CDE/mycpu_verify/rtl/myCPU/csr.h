`ifndef CSR_H
    // CSR nums: 9 bits -> max 0x181
    // lab8 csrs
    `define CSR_CRMD    9'h000
    `define CSR_PRMD    9'h001
    `define CSR_ESTAT   9'h005
    `define CSR_ERA     9'h006
    `define CSR_EENTRY  9'h00c
    `define CSR_SAVE0   9'h030
    `define CSR_SAVE1   9'h031
    `define CSR_SAVE2   9'h032
    `define CSR_SAVE3   9'h033
    // lab9 csrs
    `define CSR_ECFG    9'h004
    `define CSR_BADV    9'h007
    `define CSR_TID     9'h040
    `define CSR_TCFG    9'h041
    `define CSR_TVAL    9'h042
    `define CSR_TICLR   9'h044

    // CSR fields
    // use as index
    // lab8 csrs
    // CRMD
    `define CSR_CRMD_PLV    1:0
    `define CSR_CRMD_IE     2
    /* DA PG DATF DATM -> addr translation: not implement yet */
    // `define CSR_CRMD_DA     3
    // `define CSR_CRMD_PG     4
    // `define CSR_CRMD_DATF   6:5
    // `define CSR_CRMD_DATM   8:7
    // PRMD
    `define CSR_PRMD_PPLV   1:0
    `define CSR_PRMD_PIE    2
    // ESTAT
    `define CSR_ESTAT_IS10  1:0
    /* other ESTAT fields not require wmask/wvalue */
    

    // exception codes
    // ECODE: 6 bits -> 21:16 in ESTAT
    // ESUBCODE: 9 bits -> 30:22 in ESTAT
    // lab8
    `define ECODE_SYS   6'h0B
    // lab9
    `define ECODE_INT   6'h00
    `define ECODE_ADE   6'h08   // ADEF && ADEM
        `define ESUBCODE_ADEF   9'h000
        `define ESUBCODE_ADEM   9'h000
    `define ECODE_ALE   6'h09
    `define ECODE_BRK   6'h0C
    `define ECODE_INE   6'h0D
`endif
