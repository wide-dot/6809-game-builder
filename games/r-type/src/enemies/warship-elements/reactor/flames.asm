; Les gerbes des reacteurs de ventre — GENERE par
; tools/gen_warship_flames.py depuis le dump arcade.
;
; Une chaine = les dix pas de l'animation, chacun donnant le rang de la
; POSE UNIQUE a jouer (l'arcade cycle quatre recettes sur dix pas). Le
; manager des gerbes (flamemgr.asm) y lit le rang, puis INSCRIT chez
; wsmgr la liste des tranches 16x12 de cette pose (fcb n puis la boite
; de pose, six octets, tools/wsmgr_box.py / fdb sets),
; que wsmgr dessine tranche par tranche, chacune testee contre la bande.
;
; Les images sont rangees pose par pose, fenetre par fenetre (rangees
; du haut vers le bas, colonnes de gauche a droite) : set_fl_<n>, n
; courant sur tout le dossier. Toutes les tranches d'une pose gardent
; le canevas de la gerbe, donc partagent son ancre.

; bottom-reactor-flame-straight-down : 4 poses uniques sur 10 pas (chaine 7EF2)
flame.chain.fl_d
        fcb   0,1,2,1,2,3,2,3,2,3
flame.sl.fl_d.0
        fcb   4,-5,11,1,-23,12,36
        fdb   set_fl_d_0,set_fl_d_1,set_fl_d_2,set_fl_d_3
flame.sl.fl_d.1
        fcb   4,-4,11,1,-23,12,36
        fdb   set_fl_d_4,set_fl_d_5,set_fl_d_6,set_fl_d_7
flame.sl.fl_d.2
        fcb   4,-4,10,1,-23,12,36
        fdb   set_fl_d_8,set_fl_d_9,set_fl_d_10,set_fl_d_11
flame.sl.fl_d.3
        fcb   4,-5,11,1,-23,12,36
        fdb   set_fl_d_12,set_fl_d_13,set_fl_d_14,set_fl_d_15
flame.sets.fl_d
        fdb   flame.sl.fl_d.0,flame.sl.fl_d.1,flame.sl.fl_d.2,flame.sl.fl_d.3

; bottom-reactor-flame-right : 4 poses uniques sur 10 pas (chaine 7F38)
flame.chain.fl_r
        fcb   0,1,2,3,2,3,2,3,2,3
flame.sl.fl_r.0
        fcb   8,-11,16,16,-23,11,36
        fdb   set_fl_r_0,set_fl_r_1,set_fl_r_2,set_fl_r_3,set_fl_r_4,set_fl_r_5,set_fl_r_6,set_fl_r_7
flame.sl.fl_r.1
        fcb   8,-11,16,16,-23,12,39
        fdb   set_fl_r_8,set_fl_r_9,set_fl_r_10,set_fl_r_11,set_fl_r_12,set_fl_r_13,set_fl_r_14,set_fl_r_15
flame.sl.fl_r.2
        fcb   8,-11,16,16,-23,11,36
        fdb   set_fl_r_16,set_fl_r_17,set_fl_r_18,set_fl_r_19,set_fl_r_20,set_fl_r_21,set_fl_r_22,set_fl_r_23
flame.sl.fl_r.3
        fcb   7,-10,11,15,-22,11,35
        fdb   set_fl_r_24,set_fl_r_25,set_fl_r_26,set_fl_r_27,set_fl_r_28,set_fl_r_29,set_fl_r_30
flame.sets.fl_r
        fdb   flame.sl.fl_r.0,flame.sl.fl_r.1,flame.sl.fl_r.2,flame.sl.fl_r.3

; bottom-reactor-flame-left : 4 poses uniques sur 10 pas (chaine 7F7E)
flame.chain.fl_l
        fcb   0,1,2,3,2,3,2,3,2,3
flame.sl.fl_l.0
        fcb   8,-9,14,14,-23,12,36
        fdb   set_fl_l_0,set_fl_l_1,set_fl_l_2,set_fl_l_3,set_fl_l_4,set_fl_l_5,set_fl_l_6,set_fl_l_7
flame.sl.fl_l.1
        fcb   7,-11,15,16,-23,12,37
        fdb   set_fl_l_8,set_fl_l_9,set_fl_l_10,set_fl_l_11,set_fl_l_12,set_fl_l_13,set_fl_l_14
flame.sl.fl_l.2
        fcb   7,-11,14,16,-23,12,36
        fdb   set_fl_l_15,set_fl_l_16,set_fl_l_17,set_fl_l_18,set_fl_l_19,set_fl_l_20,set_fl_l_21
flame.sl.fl_l.3
        fcb   7,-11,10,16,-21,10,34
        fdb   set_fl_l_22,set_fl_l_23,set_fl_l_24,set_fl_l_25,set_fl_l_26,set_fl_l_27,set_fl_l_28
flame.sets.fl_l
        fdb   flame.sl.fl_l.0,flame.sl.fl_l.1,flame.sl.fl_l.2,flame.sl.fl_l.3

; small-puffs : 4 poses uniques sur 4 pas (chaine 7FC4), calee en queue des dix
flame.chain.fl_p
        fcb   0,0,0,0,0,0,0,1,2,3
flame.sl.fl_p.0
        fcb   2,-5,12,1,-11,12,12
        fdb   set_fl_p_0,set_fl_p_1
flame.sl.fl_p.1
        fcb   2,-3,7,1,-11,12,12
        fdb   set_fl_p_2,set_fl_p_3
flame.sl.fl_p.2
        fcb   2,-3,8,0,-10,11,11
        fdb   set_fl_p_4,set_fl_p_5
flame.sl.fl_p.3
        fcb   2,-4,8,3,-7,8,8
        fdb   set_fl_p_6,set_fl_p_7
flame.sets.fl_p
        fdb   flame.sl.fl_p.0,flame.sl.fl_p.1,flame.sl.fl_p.2,flame.sl.fl_p.3

flame.Chains
        fdb   flame.chain.fl_d,flame.chain.fl_r,flame.chain.fl_l,flame.chain.fl_p
flame.Sets
        fdb   flame.sets.fl_d,flame.sets.fl_r,flame.sets.fl_l,flame.sets.fl_p
; la page des tranches de chaque gerbe : Img_Page_Index de cet identifiant
flame.PageIds
        fcb   ObjID_warship_flamemgr,ObjID_warship_flamemgr,ObjID_warship_turret,ObjID_warship_flamemgr
