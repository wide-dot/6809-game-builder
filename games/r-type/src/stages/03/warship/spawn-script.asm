; Le script de spawn du vaisseau — GENERE par tools/gen_warship_spawn.py
; depuis re.arcade.r-type/out/warship/warship-spawn-script.asm.
;
; Une entree : fdb seuil (px de course de la couche), fdb x ecran,
;              fdb dy (relatif a l'ancre du maitre), fcb objid, fcb sous-type
; Fin : seuil = -1.
;
; L'abscisse est corrigee du decalage d'origine que l'export oublie
; (il traite une POSITION comme une DISTANCE) : voir le generateur.
; Le seuil se compare a mscroll.camera.x, la course de la couche (0..285).
; L'ordonnee vaut warship.BASEY + dy : l'arcade fait naitre chaque piece a
; `parent.Y + dy` et son maitre est pose a Y=0xF0 (create_warship 40:c46e),
; soit 117 chez nous.
;
; UN IDENTIFIANT NUL veut dire « pas encore porte » : le parcours saute
; l'entree. Les 68 places sont posees une fois pour toutes, chaque tranche
; de la campagne en allume une famille (doc/warship-parts-plan.md).
; L'etiquette warship.spawn.script est posee par le wrapper <unit> du
; config, comme pour le script de camera — ne pas la redefinir ici.

        INCLUDE "src/stages/03/objid.const.asm"
        INCLUDE "src/enemies/warship-elements/turret/turret.equ"

        fdb   6,162,0
        fcb   0,0 ; #0 arcade CBEF, pas encore porte
        fdb   24,149,0
        fcb   ObjID_warship_turret,turret.TOP ; #1 petite tourelle HAUT
        fdb   24,149,0
        fcb   ObjID_warship_turret,turret.BOTTOM ; #2 petite tourelle BAS
        fdb   24,150,-42
        fcb   ObjID_warship_turret,turret.TOP ; #3 petite tourelle HAUT
        fdb   24,147,31
        fcb   0,0 ; #4 arcade DB70, pas encore porte
        fdb   24,146,-27
        fcb   ObjID_warship_part,5 ; #5 sous-partie de coque #5
        fdb   24,146,15
        fcb   ObjID_warship_part,7 ; #6 sous-partie de coque #7
        fdb   30,152,0
        fcb   ObjID_warship_turret,turret.TOP ; #7 petite tourelle HAUT
        fdb   30,152,0
        fcb   ObjID_warship_turret,turret.BOTTOM ; #8 petite tourelle BAS
        fdb   33,150,-48
        fcb   ObjID_warship_turret,turret.TOP ; #9 petite tourelle HAUT
        fdb   33,146,-33
        fcb   ObjID_warship_part,4 ; #10 sous-partie de coque #4
        fdb   36,150,48
        fcb   ObjID_warship_turret,turret.BOTTOM ; #11 petite tourelle BAS
        fdb   39,146,-9
        fcb   ObjID_warship_part,6 ; #12 sous-partie de coque #6
        fdb   39,146,15
        fcb   ObjID_warship_part,8 ; #13 sous-partie de coque #8
        fdb   42,150,-54
        fcb   ObjID_warship_turret,turret.TOP ; #14 petite tourelle HAUT
        fdb   42,146,-39
        fcb   ObjID_warship_part,3 ; #15 sous-partie de coque #3
        fdb   45,150,48
        fcb   ObjID_warship_turret,turret.BOTTOM ; #16 petite tourelle BAS
        fdb   48,146,15
        fcb   ObjID_warship_part,9 ; #17 sous-partie de coque #9
        fdb   51,150,-60
        fcb   ObjID_warship_turret,turret.TOP ; #18 petite tourelle HAUT
        fdb   51,146,-45
        fcb   ObjID_warship_part,2 ; #19 sous-partie de coque #2
        fdb   54,150,36
        fcb   ObjID_warship_turret,turret.BOTTOM ; #20 petite tourelle BAS
        fdb   54,156,36
        fcb   0,0 ; #21 arcade CFE9, pas encore porte
        fdb   57,146,3
        fcb   ObjID_warship_part,10 ; #22 sous-partie de coque #10
        fdb   60,151,-68
        fcb   0,0 ; #23 arcade DB63, pas encore porte
        fdb   60,146,-75
        fcb   ObjID_warship_part,1 ; #24 sous-partie de coque #1
        fdb   63,150,36
        fcb   ObjID_warship_turret,turret.BOTTOM ; #25 petite tourelle BAS
        fdb   66,146,3
        fcb   ObjID_warship_part,11 ; #26 sous-partie de coque #11
        fdb   72,146,-93
        fcb   ObjID_warship_part,0 ; #27 sous-partie de coque #0
        fdb   75,150,19
        fcb   0,0 ; #28 arcade DB8A, pas encore porte
        fdb   75,156,18
        fcb   0,0 ; #29 arcade D095, pas encore porte
        fdb   75,146,-9
        fcb   ObjID_warship_part,12 ; #30 sous-partie de coque #12
        fdb   93,150,-63
        fcb   ObjID_warship_turret,turret.BIG ; #31 grosse tourelle
        fdb   93,146,-21
        fcb   ObjID_warship_part,13 ; #32 sous-partie de coque #13
        fdb   108,150,-57
        fcb   ObjID_warship_turret,turret.BIG ; #33 grosse tourelle
        fdb   111,146,-3
        fcb   ObjID_warship_part,14 ; #34 sous-partie de coque #14
        fdb   114,174,48
        fcb   0,0 ; #35 arcade D39E, pas encore porte
        fdb   120,150,42
        fcb   0,0 ; #36 arcade D8B7, pas encore porte
        fdb   123,150,-51
        fcb   ObjID_warship_turret,turret.BIG ; #37 grosse tourelle
        fdb   132,150,42
        fcb   0,0 ; #38 arcade D8C4, pas encore porte
        fdb   135,150,-37
        fcb   0,0 ; #39 arcade DB7D, pas encore porte
        fdb   144,150,42
        fcb   0,0 ; #40 arcade D8D1, pas encore porte
        fdb   155,150,-18
        fcb   0,0 ; #41 arcade DCC0, pas encore porte
        fdb   156,150,42
        fcb   0,0 ; #42 arcade D8DE, pas encore porte
        fdb   165,150,-60
        fcb   ObjID_warship_turret,turret.TOP ; #43 petite tourelle HAUT
        fdb   168,146,3
        fcb   ObjID_warship_part,15 ; #44 sous-partie de coque #15
        fdb   174,150,-66
        fcb   ObjID_warship_turret,turret.TOP ; #45 petite tourelle HAUT
        fdb   183,150,-72
        fcb   ObjID_warship_turret,turret.TOP ; #46 petite tourelle HAUT
        fdb   183,146,-9
        fcb   ObjID_warship_part,16 ; #47 sous-partie de coque #16
        fdb   195,150,-81
        fcb   ObjID_warship_turret,turret.BIG ; #48 grosse tourelle
        fdb   201,151,48
        fcb   ObjID_warship_turret,turret.BOTTOM ; #49 petite tourelle BAS
        fdb   204,146,3
        fcb   ObjID_warship_part,17 ; #50 sous-partie de coque #17
        fdb   210,152,35
        fcb   0,0 ; #51 arcade D5D7, pas encore porte
        fdb   212,150,-75
        fcb   ObjID_warship_turret,turret.BIG ; #52 grosse tourelle
        fdb   219,150,28
        fcb   0,0 ; #53 arcade D5CA, pas encore porte
        fdb   222,152,-72
        fcb   ObjID_warship_turret,turret.TOP ; #54 petite tourelle HAUT
        fdb   222,152,14
        fcb   0,0 ; #55 arcade D5BD, pas encore porte
        fdb   228,146,-15
        fcb   ObjID_warship_part,18 ; #56 sous-partie de coque #18
        fdb   240,131,-57
        fcb   ObjID_warship_part,19 ; #57 sous-partie de coque #19
        fdb   240,116,-63
        fcb   ObjID_warship_part,20 ; #58 sous-partie de coque #20
        fdb   240,98,-69
        fcb   ObjID_warship_part,21 ; #59 sous-partie de coque #21
        fdb   240,89,-57
        fcb   ObjID_warship_part,22 ; #60 sous-partie de coque #22
        fdb   240,80,-51
        fcb   ObjID_warship_part,23 ; #61 sous-partie de coque #23
        fdb   240,65,-45
        fcb   ObjID_warship_part,24 ; #62 sous-partie de coque #24
        fdb   240,50,-9
        fcb   ObjID_warship_part,25 ; #63 sous-partie de coque #25
        fdb   240,29,-39
        fcb   ObjID_warship_part,26 ; #64 sous-partie de coque #26
        fdb   240,149,-18
        fcb   0,0 ; #65 arcade D5B0, pas encore porte
        fdb   240,149,-45
        fcb   0,0 ; #66 arcade D596, pas encore porte
        fdb   240,152,-31
        fcb   0,0 ; #67 arcade D5A3, pas encore porte
        fdb   -1
