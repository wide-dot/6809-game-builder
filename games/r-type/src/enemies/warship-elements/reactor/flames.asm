; Les gerbes des reacteurs de ventre — GENERE par
; tools/gen_warship_flames.py depuis le dump arcade.
;
; Une chaine = les dix pas de l'animation, chacun donnant le rang de la
; POSE UNIQUE a jouer (l'arcade cycle quatre recettes sur dix pas). Le
; manager y lit le rang, puis dessine les QUATRE TRANCHES de cette pose
; qui tiennent dans la bande.
;
; Les images sont rangees pose par pose, tranche par tranche :
;   set_fl_<n>, n courant sur tout le dossier, tranche 0 = la plus HAUTE.
; Ce sont les IMAGESETS : le manager y lit la geometrie (bornes, taille,
; centre) pour son test de bande, puis l'adresse de la routine compilee —
; le meme chemin que outslay.RecPublish. Les quatre tranches d'une pose
; se dessinent a la MEME ancre : elles gardent le canevas de la gerbe.

; bottom-reactor-flame-straight-down : 4 poses uniques sur dix pas (chaine 7EF2)
flame.chain.fl_d
        fcb   0,1,2,1,2,3,2,3,2,3
flame.sets.fl_d
        fdb   set_fl_0,set_fl_1,set_fl_2,set_fl_3
        fdb   set_fl_4,set_fl_5,set_fl_6,set_fl_7
        fdb   set_fl_8,set_fl_9,set_fl_10,set_fl_11
        fdb   set_fl_12,set_fl_13,set_fl_14,set_fl_15

; bottom-reactor-flame-right : 4 poses uniques sur dix pas (chaine 7F38)
flame.chain.fl_r
        fcb   0,1,2,3,2,3,2,3,2,3
flame.sets.fl_r
        fdb   set_fl_16,set_fl_17,set_fl_18,set_fl_19
        fdb   set_fl_20,set_fl_21,set_fl_22,set_fl_23
        fdb   set_fl_24,set_fl_25,set_fl_26,set_fl_27
        fdb   set_fl_28,set_fl_29,set_fl_30,set_fl_31

; bottom-reactor-flame-left : 4 poses uniques sur dix pas (chaine 7F7E)
flame.chain.fl_l
        fcb   0,1,2,3,2,3,2,3,2,3
flame.sets.fl_l
        fdb   set_fl_32,set_fl_33,set_fl_34,set_fl_35
        fdb   set_fl_36,set_fl_37,set_fl_38,set_fl_39
        fdb   set_fl_40,set_fl_41,set_fl_42,set_fl_43
        fdb   set_fl_44,set_fl_45,set_fl_46,set_fl_47

flame.Chains
        fdb   flame.chain.fl_d,flame.chain.fl_r,flame.chain.fl_l
flame.Sets
        fdb   flame.sets.fl_d,flame.sets.fl_r,flame.sets.fl_l
