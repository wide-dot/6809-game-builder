; GENERE par tools/gen_warship_slices.py — les tranches 16x12 de chaque
; pose : fcb n, la boite de pose (six octets, tools/wsmgr_box.py),
; puis n imagesets dans l'ordre de peinture (rangees du
; haut vers le bas). Voir wsmgr.asm.

core.sl.core_closed.0
        fcb   4,-11,16,16,-11,12,12
        fdb   set_core_closed_0,set_core_closed_1,set_core_closed_2,set_core_closed_3
core.sl.core_closed.1
        fcb   4,-11,16,16,-11,12,12
        fdb   set_core_closed_4,set_core_closed_5,set_core_closed_6,set_core_closed_7
core.sl.core_closed.2
        fcb   4,-11,16,16,-11,12,12
        fdb   set_core_closed_8,set_core_closed_9,set_core_closed_10,set_core_closed_11
core.sl.core_closed.3
        fcb   4,-11,16,16,-11,12,12
        fdb   set_core_closed_12,set_core_closed_13,set_core_closed_14,set_core_closed_15
core.sl.core_closed.4
        fcb   4,-11,16,16,-11,12,12
        fdb   set_core_closed_0,set_core_closed_16,set_core_closed_2,set_core_closed_17
core.sl.core_closed.5
        fcb   4,-11,16,16,-11,12,12
        fdb   set_core_closed_0,set_core_closed_18,set_core_closed_2,set_core_closed_19
core.sl.core_closed.6
        fcb   4,-11,16,16,-11,12,12
        fdb   set_core_closed_0,set_core_closed_20,set_core_closed_2,set_core_closed_21
core.sl.core_closed.7
        fcb   2,-11,16,0,-11,12,12
        fdb   set_core_closed_0,set_core_closed_2
core.sl.core_closed.8
        fcb   2,-11,14,0,-11,12,12
        fdb   set_core_closed_22,set_core_closed_23
core.sl.core_closed.9
        fcb   2,-11,12,0,-11,12,12
        fdb   set_core_closed_24,set_core_closed_25
core.sl.core_closed.10
        fcb   2,-11,10,0,-11,12,12
        fdb   set_core_closed_26,set_core_closed_27
core.sl.core_opening.0
        fcb   2,-10,9,0,-11,12,12
        fdb   set_core_opening_0,set_core_opening_1
core.sl.core_opening.1
        fcb   2,-10,9,0,-11,12,12
        fdb   set_core_opening_0,set_core_opening_1
core.sl.core_opening.2
        fcb   2,-10,9,0,-11,12,12
        fdb   set_core_opening_0,set_core_opening_1
core.sl.core_opening.3
        fcb   2,-10,9,0,-11,12,12
        fdb   set_core_opening_0,set_core_opening_1
core.sl.core_opening.4
        fcb   2,-10,9,0,-11,12,12
        fdb   set_core_opening_0,set_core_opening_1
core.sl.core_opening.5
        fcb   2,-10,9,0,-11,12,12
        fdb   set_core_opening_0,set_core_opening_1
core.sl.core_opening.6
        fcb   2,-9,8,0,-11,12,12
        fdb   set_core_opening_2,set_core_opening_3
core.sl.core_opening.7
        fcb   2,-9,8,0,-11,12,12
        fdb   set_core_opening_4,set_core_opening_5
core.sl.core_open.0
        fcb   2,-10,9,0,-11,12,12
        fdb   set_core_open_0,set_core_open_1
core.sl.core_open_flash.0
        fcb   2,-10,9,0,-11,12,12
        fdb   set_core_open_flash_0,set_core_open_flash_1
