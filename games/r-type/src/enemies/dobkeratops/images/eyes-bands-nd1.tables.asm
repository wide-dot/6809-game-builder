; genere par tools/gen_overlay_nerves.py — NE PAS EDITER
; par systeme : fcb nb, puis par bande : fdb gauche, fdb
; droite+1 (bornes playfield, ancre = eyemgr.X), fdb ND1
EB_sys0
        fcb   5
        fdb   eyemgr.X-35,eyemgr.X-23
        fdb   adr_dkeyes_b00_ND1
        fdb   eyemgr.X-23,eyemgr.X-7
        fdb   adr_dkeyes_b01_ND1
        fdb   eyemgr.X-7,eyemgr.X+9
        fdb   adr_dkeyes_b02_ND1
        fdb   eyemgr.X+9,eyemgr.X+25
        fdb   adr_dkeyes_b03_ND1
        fdb   eyemgr.X+25,eyemgr.X+37
        fdb   adr_dkeyes_b04_ND1
EB_sys1
        fcb   3
        fdb   eyemgr.X-2,eyemgr.X+9
        fdb   adr_dkeyes_b10_ND1
        fdb   eyemgr.X+9,eyemgr.X+25
        fdb   adr_dkeyes_b11_ND1
        fdb   eyemgr.X+25,eyemgr.X+41
        fdb   adr_dkeyes_b12_ND1
EB_sys2
        fcb   3
        fdb   eyemgr.X-3,eyemgr.X+9
        fdb   adr_dkeyes_b20_ND1
        fdb   eyemgr.X+9,eyemgr.X+25
        fdb   adr_dkeyes_b21_ND1
        fdb   eyemgr.X+25,eyemgr.X+41
        fdb   adr_dkeyes_b22_ND1
EB_sys3
        fcb   5
        fdb   eyemgr.X-35,eyemgr.X-23
        fdb   adr_dkeyes_b30_ND1
        fdb   eyemgr.X-23,eyemgr.X-7
        fdb   adr_dkeyes_b31_ND1
        fdb   eyemgr.X-7,eyemgr.X+9
        fdb   adr_dkeyes_b32_ND1
        fdb   eyemgr.X+9,eyemgr.X+25
        fdb   adr_dkeyes_b33_ND1
        fdb   eyemgr.X+25,eyemgr.X+37
        fdb   adr_dkeyes_b34_ND1
EB_index
        fdb   EB_sys0,EB_sys1,EB_sys2,EB_sys3
