`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       35
    `define PFS_TO_FS_BUS_WD 47
    `define FS_TO_DS_BUS_WD 79
    `define DS_TO_ES_BUS_WD 306
    `define ES_TO_MS_BUS_WD 187
    `define MS_TO_WS_BUS_WD 175
    `define WS_TO_RF_BUS_WD 38

    `define ES_FWD_BLK_BUS_WD 39
    `define MS_FWD_BLK_BUS_WD 39

    `define EXC_NUM         15
    `define EXC_FLG_SYS     0
    `define EXC_FLG_ADEF    1
    `define EXC_FLG_ALE     2
    `define EXC_FLG_BRK     3
    `define EXC_FLG_INE     4
    `define EXC_FLG_INT     5
    `define EXC_FLG_ADEM    6
    `define EXC_FLG_TLBR_F  7
    `define EXC_FLG_PIL     8
    `define EXC_FLG_PIS     9
    `define EXC_FLG_PIF     10
    `define EXC_FLG_PME     11
    `define EXC_FLG_PPE_F   12
    `define EXC_FLG_TLBR_M  13
    `define EXC_FLG_PPE_M   14

    `define ES_CSR_BLK_BUS_WD 17
    `define MS_CSR_BLK_BUS_WD 17
    `define WS_CSR_BLK_BUS_WD 17
`endif
