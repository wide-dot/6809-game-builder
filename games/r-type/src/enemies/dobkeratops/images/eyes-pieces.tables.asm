; genere par tools/gen_overlay_nerves.py — NE PAS EDITER
; par systeme : fcb nb, puis fdb routine par morceau, dans
; l'ordre de retrait (parite unique, cf. manifest)
EP_sys0
        fcb   16
        fdb   adr_dkeyes_p0_00_ND0
        fdb   adr_dkeyes_p0_01_ND0
        fdb   adr_dkeyes_p0_02_ND0
        fdb   adr_dkeyes_p0_03_ND0
        fdb   adr_dkeyes_p0_04_ND0
        fdb   adr_dkeyes_p0_05_ND0
        fdb   adr_dkeyes_p0_06_ND0
        fdb   adr_dkeyes_p0_07_ND0
        fdb   adr_dkeyes_p0_08_ND0
        fdb   adr_dkeyes_p0_09_ND0
        fdb   adr_dkeyes_p0_10_ND0
        fdb   adr_dkeyes_p0_11_ND0
        fdb   adr_dkeyes_p0_12_ND0
        fdb   adr_dkeyes_p0_13_ND0
        fdb   adr_dkeyes_p0_14_ND0
        fdb   adr_dkeyes_p0_15_ND0
EP_sys1
        fcb   13
        fdb   adr_dkeyes_p1_00_ND0
        fdb   adr_dkeyes_p1_01_ND0
        fdb   adr_dkeyes_p1_02_ND0
        fdb   adr_dkeyes_p1_03_ND0
        fdb   adr_dkeyes_p1_04_ND0
        fdb   adr_dkeyes_p1_05_ND0
        fdb   adr_dkeyes_p1_06_ND0
        fdb   adr_dkeyes_p1_07_ND0
        fdb   adr_dkeyes_p1_08_ND0
        fdb   adr_dkeyes_p1_09_ND0
        fdb   adr_dkeyes_p1_10_ND0
        fdb   adr_dkeyes_p1_11_ND0
        fdb   adr_dkeyes_p1_12_ND0
EP_sys2
        fcb   12
        fdb   adr_dkeyes_p2_00_ND0
        fdb   adr_dkeyes_p2_01_ND0
        fdb   adr_dkeyes_p2_02_ND0
        fdb   adr_dkeyes_p2_03_ND0
        fdb   adr_dkeyes_p2_04_ND0
        fdb   adr_dkeyes_p2_05_ND0
        fdb   adr_dkeyes_p2_06_ND0
        fdb   adr_dkeyes_p2_07_ND0
        fdb   adr_dkeyes_p2_08_ND0
        fdb   adr_dkeyes_p2_09_ND0
        fdb   adr_dkeyes_p2_10_ND0
        fdb   adr_dkeyes_p2_11_ND0
EP_sys3
        fcb   19
        fdb   adr_dkeyes_p3_00_ND0
        fdb   adr_dkeyes_p3_01_ND0
        fdb   adr_dkeyes_p3_02_ND0
        fdb   adr_dkeyes_p3_03_ND0
        fdb   adr_dkeyes_p3_04_ND0
        fdb   adr_dkeyes_p3_05_ND0
        fdb   adr_dkeyes_p3_06_ND0
        fdb   adr_dkeyes_p3_07_ND0
        fdb   adr_dkeyes_p3_08_ND0
        fdb   adr_dkeyes_p3_09_ND0
        fdb   adr_dkeyes_p3_10_ND0
        fdb   adr_dkeyes_p3_11_ND0
        fdb   adr_dkeyes_p3_12_ND0
        fdb   adr_dkeyes_p3_13_ND0
        fdb   adr_dkeyes_p3_14_ND0
        fdb   adr_dkeyes_p3_15_ND0
        fdb   adr_dkeyes_p3_16_ND0
        fdb   adr_dkeyes_p3_17_ND0
        fdb   adr_dkeyes_p3_18_ND0
EP_index
        fdb   EP_sys0,EP_sys1,EP_sys2,EP_sys3
