; La roue de visee des tourelles — GENERE par tools/gen_turret_sets.py.
; Seize directions, neuf poses : la roue est palindromique et l'arcade
; fait exactement cela (table de 16 pointeurs vers 9 sprites, 1000:8258
; pour la petite HAUT, 8278 pour la BAS, 81fa pour la grosse).
; L'index vaut la direction de setDirectionTo divisee par quatre.

; small-turret-top : 9 poses pour 16 directions
turret.wheel.small_turret_top
        fdb   set_small_turret_top_0,set_small_turret_top_1,set_small_turret_top_2,set_small_turret_top_3
        fdb   set_small_turret_top_4,set_small_turret_top_3,set_small_turret_top_2,set_small_turret_top_1
        fdb   set_small_turret_top_0,set_small_turret_top_5,set_small_turret_top_6,set_small_turret_top_6
        fdb   set_small_turret_top_7,set_small_turret_top_6,set_small_turret_top_8,set_small_turret_top_5

; small-turret-bottom : 9 poses pour 16 directions
turret.wheel.small_turret_bottom
        fdb   set_small_turret_bottom_0,set_small_turret_bottom_1,set_small_turret_bottom_2,set_small_turret_bottom_3
        fdb   set_small_turret_bottom_4,set_small_turret_bottom_3,set_small_turret_bottom_2,set_small_turret_bottom_1
        fdb   set_small_turret_bottom_0,set_small_turret_bottom_5,set_small_turret_bottom_6,set_small_turret_bottom_7
        fdb   set_small_turret_bottom_8,set_small_turret_bottom_7,set_small_turret_bottom_6,set_small_turret_bottom_5

; big-turret : 9 poses pour 16 directions
turret.wheel.big_turret
        fdb   set_big_turret_0,set_big_turret_1,set_big_turret_2,set_big_turret_3
        fdb   set_big_turret_4,set_big_turret_3,set_big_turret_2,set_big_turret_1
        fdb   set_big_turret_0,set_big_turret_5,set_big_turret_6,set_big_turret_6
        fdb   set_big_turret_7,set_big_turret_6,set_big_turret_8,set_big_turret_5
