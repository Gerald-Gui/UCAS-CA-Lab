`ifndef CSR_H
    /*
     * CSR nums: 14 bits len of imm in inst
     */
    // lab8 csrs
    `define CSR_CRMD    14'h000
    `define CSR_PRMD    14'h001
    `define CSR_ESTAT   14'h005
    `define CSR_ERA     14'h006
    `define CSR_EENTRY  14'h00c
    `define CSR_SAVE0   14'h030
    `define CSR_SAVE1   14'h031
    `define CSR_SAVE2   14'h032
    `define CSR_SAVE3   14'h033
    // lab9 csrs
    `define CSR_ECFG    14'h004
    `define CSR_BADV    14'h007
    `define CSR_TID     14'h040
    `define CSR_TCFG    14'h041
    `define CSR_TVAL    14'h042
    `define CSR_TICLR   14'h044

    /*
     *  CSR fields
     */
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
    // ERA
    `define CSR_ERA_PC      31:0
    // EENTRY
    `define CSR_EENTRY_VA   31:6
    // SAVE0-3
    `define CSR_SAVE_DATA   31:0

    // lab9 csrs
    // ECFG
    `define CSR_ECFG_LIE    12:0
    // BADV
    `define CSR_BADV_VAddr  31:0
    // TID
    `define CSR_TID_TID     31:0
    // TCFG
    `define CSR_TCFG_EN      0
    `define CSR_TCFG_PERIOD  1
    `define CSR_TCFG_INITVAL 31:2
    // TVAL read-only
    // TICLR
    `define CSR_TICLR_CLR   0
    

    // exception codes
    // ECODE: 6 bits -> 21:16 in ESTAT
    // ESUBCODE: 9 bits -> 30:22 in ESTAT
    // lab8
    `define ECODE_SYS   6'h0B
    // lab9
    `define ECODE_INT   6'h00
    `define ECODE_ADE   6'h08   // ADEF && ADEM
        `define ESUBCODE_ADEF   9'h000
        `define ESUBCODE_ADEM   9'h001
    `define ECODE_ALE   6'h09
    `define ECODE_BRK   6'h0C
    `define ECODE_INE   6'h0D

    // CSR write masks
    `define CSR_MASK_CRMD   32'h0000_0007   // only plv, ie
    `define CSR_MASK_PRMD   32'h0000_0007
    `define CSR_MASK_ESTAT  32'h0000_0003   // only SIS RW
    `define CSR_MASK_ERA    32'hffff_ffff
    `define CSR_MASK_EENTRY 32'hffff_ffc0
    `define CSR_MASK_SAVE   32'hffff_ffff
    // lab9
    `define CSR_MASK_ECFG   32'h0000_1fff
    `define CSR_MASK_BADV   32'hffff_ffff
    `define CSR_MASK_TID    32'hffff_ffff
    `define CSR_MASK_TCFG   32'hffff_ffff
    `define CSR_MASK_TICLR  32'h0000_0001
`endif
