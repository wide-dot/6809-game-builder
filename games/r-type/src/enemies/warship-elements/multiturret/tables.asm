; Tourelles MULTIPLES — GENERE par tools/gen_warship_frontmulti.py
; Quatre montages : 4 poses d'anim chacun (cycle temporel), un patron
; de tir de 5 vecteurs + le point de ponte, une boite partagee.

; multi-turret-top-left : anim 8006, tir 8066
multi.anim.multi_tl
        fdb   set_multi_tl_0,set_multi_tl_1,set_multi_tl_2,set_multi_tl_3
multi.fire.multi_tl
        fdb   0,-384 ; vecteur 0
        fdb   192,-384 ; vecteur 1
        fdb   -192,0 ; vecteur 2
        fdb   -192,-384 ; vecteur 3
        fdb   -192,384 ; vecteur 4
        fcb   0,2 ; le point de ponte, ecart signe

; multi-turret-bottom-left : anim 801E, tir 807E
multi.anim.multi_bl
        fdb   set_multi_bl_0,set_multi_bl_1,set_multi_bl_2,set_multi_bl_3
multi.fire.multi_bl
        fdb   0,384 ; vecteur 0
        fdb   192,384 ; vecteur 1
        fdb   -192,0 ; vecteur 2
        fdb   -192,384 ; vecteur 3
        fdb   -192,-384 ; vecteur 4
        fcb   0,254 ; le point de ponte, ecart signe

; multi-turret-top-right : anim 8036, tir 8096
multi.anim.multi_tr
        fdb   set_multi_tr_0,set_multi_tr_1,set_multi_tr_2,set_multi_tr_3
multi.fire.multi_tr
        fdb   0,-384 ; vecteur 0
        fdb   -192,-384 ; vecteur 1
        fdb   192,0 ; vecteur 2
        fdb   192,-384 ; vecteur 3
        fdb   192,384 ; vecteur 4
        fcb   0,2 ; le point de ponte, ecart signe

; multi-turret-bottom-right : anim 804E, tir 80AE
multi.anim.multi_br
        fdb   set_multi_br_0,set_multi_br_1,set_multi_br_2,set_multi_br_3
multi.fire.multi_br
        fdb   0,384 ; vecteur 0
        fdb   -192,384 ; vecteur 1
        fdb   192,0 ; vecteur 2
        fdb   192,384 ; vecteur 3
        fdb   192,-384 ; vecteur 4
        fcb   0,254 ; le point de ponte, ecart signe

multi.Anims
        fdb   multi.anim.multi_tl
        fdb   multi.anim.multi_bl
        fdb   multi.anim.multi_tr
        fdb   multi.anim.multi_br
multi.Fires
        fdb   multi.fire.multi_tl
        fdb   multi.fire.multi_bl
        fdb   multi.fire.multi_tr
        fdb   multi.fire.multi_br

; la boite (1000:80C6), partagee par les quatre montages
multi.BOX equ $0306
multi.CTR equ $0000
