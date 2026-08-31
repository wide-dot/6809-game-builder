; genere par tools/gen_overlay_nerves.py — NE PAS EDITER
; sequences d'effacement : un octet par tick = nb de morceaux
; retires ce tick (0-2), $FF = fin de sequence
ES_sys0
        fcb   1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1
        fcb   1,1,1
        fcb   $FF
ES_sys1
        fcb   1,1,0,0,0,1,1,1,1,1,1,1,1,1,0,0
        fcb   1,1
        fcb   $FF
ES_sys2
        fcb   1,1,1,0,0,0,0,1,1,1,1,1,1,1,0,0
        fcb   0,1,1
        fcb   $FF
ES_sys3
        fcb   1,1,1,1,1,1,2,2,1,1,1,1,1,2,1,1
        fcb   $FF
ES_index
        fdb   ES_sys0,ES_sys1,ES_sys2,ES_sys3
