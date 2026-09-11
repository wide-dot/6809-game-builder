; GENERE par tools/gen_warship_slices.py — les tranches 16x12 de chaque
; pose : fcb n, la boite de pose (six octets, tools/wsmgr_box.py),
; puis n imagesets dans l'ordre de peinture (rangees du
; haut vers le bas). Voir wsmgr.asm.

react.sl.rear_reactor.0
        fcb   6,-17,16,32,-11,12,12
        fdb   set_rear_reactor_0,set_rear_reactor_1,set_rear_reactor_2,set_rear_reactor_3,set_rear_reactor_4,set_rear_reactor_5
react.sl.reactor_startup.0
        fcb   8,1,8,8,-21,10,34
        fdb   set_reactor_startup_0,set_reactor_startup_1,set_reactor_startup_2,set_reactor_startup_3,set_reactor_startup_4,set_reactor_startup_5,set_reactor_startup_6,set_reactor_startup_7
react.sl.reactor_startup.1
        fcb   2,14,11,0,-11,12,12
        fdb   set_reactor_startup_8,set_reactor_startup_9
react.sl.reactor_startup.2
        fcb   2,16,9,0,-9,10,10
        fdb   set_reactor_startup_10,set_reactor_startup_11
react.sl.reactor_startup.3
        fcb   2,18,7,0,-6,7,7
        fdb   set_reactor_startup_12,set_reactor_startup_13
react.sl.reactor_flame_0.0
        fcb   6,-23,16,32,-11,12,12
        fdb   set_reactor_flame_0_0,set_reactor_flame_0_1,set_reactor_flame_0_2,set_reactor_flame_0_3,set_reactor_flame_0_4,set_reactor_flame_0_5
react.sl.reactor_flame_1.0
        fcb   6,-23,16,32,-10,11,12
        fdb   set_reactor_flame_1_0,set_reactor_flame_1_1,set_reactor_flame_1_2,set_reactor_flame_1_3,set_reactor_flame_1_4,set_reactor_flame_1_5
react.sl.escape_capsule.0
        fcb   8,-29,16,48,-11,12,12
        fdb   set_escape_capsule_0,set_escape_capsule_1,set_escape_capsule_2,set_escape_capsule_3,set_escape_capsule_4,set_escape_capsule_5,set_escape_capsule_6,set_escape_capsule_7
react.sl.small_escape_capsule.0
        fcb   4,-11,16,16,-11,12,12
        fdb   set_small_escape_capsule_0,set_small_escape_capsule_1,set_small_escape_capsule_2,set_small_escape_capsule_3
react.sl.falling_triangle.0
        fcb   4,-10,15,15,-11,12,12
        fdb   set_falling_triangle_0,set_falling_triangle_1,set_falling_triangle_2,set_falling_triangle_3
