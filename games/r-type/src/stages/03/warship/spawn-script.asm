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

        fdb   6,170,0
        fcb   0,0 ; #0 arcade CBEF, pas encore porte
        fdb   24,157,0
        fcb   ObjID_warship_turret,turret.TOP ; #1 petite tourelle HAUT
        fdb   24,157,0
        fcb   ObjID_warship_turret,turret.BOTTOM ; #2 petite tourelle BAS
        fdb   24,158,-42
        fcb   ObjID_warship_turret,turret.TOP ; #3 petite tourelle HAUT
        fdb   24,155,31
        fcb   0,0 ; #4 arcade DB70, pas encore porte
        fdb   24,154,-27
        fcb   0,0 ; #5 arcade C692, pas encore porte
        fdb   24,154,15
        fcb   0,0 ; #6 arcade C6AA, pas encore porte
        fdb   30,160,0
        fcb   ObjID_warship_turret,turret.TOP ; #7 petite tourelle HAUT
        fdb   30,160,0
        fcb   ObjID_warship_turret,turret.BOTTOM ; #8 petite tourelle BAS
        fdb   33,158,-48
        fcb   ObjID_warship_turret,turret.TOP ; #9 petite tourelle HAUT
        fdb   33,154,-33
        fcb   0,0 ; #10 arcade C686, pas encore porte
        fdb   36,158,48
        fcb   ObjID_warship_turret,turret.BOTTOM ; #11 petite tourelle BAS
        fdb   39,154,-9
        fcb   0,0 ; #12 arcade C69E, pas encore porte
        fdb   39,154,15
        fcb   0,0 ; #13 arcade C6B6, pas encore porte
        fdb   42,158,-54
        fcb   ObjID_warship_turret,turret.TOP ; #14 petite tourelle HAUT
        fdb   42,154,-39
        fcb   0,0 ; #15 arcade C67A, pas encore porte
        fdb   45,158,48
        fcb   ObjID_warship_turret,turret.BOTTOM ; #16 petite tourelle BAS
        fdb   48,154,15
        fcb   0,0 ; #17 arcade C6C2, pas encore porte
        fdb   51,158,-60
        fcb   ObjID_warship_turret,turret.TOP ; #18 petite tourelle HAUT
        fdb   51,154,-45
        fcb   0,0 ; #19 arcade C66E, pas encore porte
        fdb   54,158,36
        fcb   ObjID_warship_turret,turret.BOTTOM ; #20 petite tourelle BAS
        fdb   54,164,36
        fcb   0,0 ; #21 arcade CFE9, pas encore porte
        fdb   57,154,3
        fcb   0,0 ; #22 arcade C6CE, pas encore porte
        fdb   60,159,-68
        fcb   0,0 ; #23 arcade DB63, pas encore porte
        fdb   60,154,-75
        fcb   0,0 ; #24 arcade C662, pas encore porte
        fdb   63,158,36
        fcb   ObjID_warship_turret,turret.BOTTOM ; #25 petite tourelle BAS
        fdb   66,154,3
        fcb   0,0 ; #26 arcade C6DA, pas encore porte
        fdb   72,154,-93
        fcb   0,0 ; #27 arcade C656, pas encore porte
        fdb   75,158,19
        fcb   0,0 ; #28 arcade DB8A, pas encore porte
        fdb   75,164,18
        fcb   0,0 ; #29 arcade D095, pas encore porte
        fdb   75,154,-9
        fcb   0,0 ; #30 arcade C6E6, pas encore porte
        fdb   93,158,-63
        fcb   ObjID_warship_turret,turret.BIG ; #31 grosse tourelle
        fdb   93,154,-21
        fcb   0,0 ; #32 arcade C6F2, pas encore porte
        fdb   108,158,-57
        fcb   ObjID_warship_turret,turret.BIG ; #33 grosse tourelle
        fdb   111,154,-3
        fcb   0,0 ; #34 arcade C6FE, pas encore porte
        fdb   114,182,48
        fcb   0,0 ; #35 arcade D39E, pas encore porte
        fdb   120,158,42
        fcb   0,0 ; #36 arcade D8B7, pas encore porte
        fdb   123,158,-51
        fcb   ObjID_warship_turret,turret.BIG ; #37 grosse tourelle
        fdb   132,158,42
        fcb   0,0 ; #38 arcade D8C4, pas encore porte
        fdb   135,158,-37
        fcb   0,0 ; #39 arcade DB7D, pas encore porte
        fdb   144,158,42
        fcb   0,0 ; #40 arcade D8D1, pas encore porte
        fdb   155,158,-18
        fcb   0,0 ; #41 arcade DCC0, pas encore porte
        fdb   156,158,42
        fcb   0,0 ; #42 arcade D8DE, pas encore porte
        fdb   165,158,-60
        fcb   ObjID_warship_turret,turret.TOP ; #43 petite tourelle HAUT
        fdb   168,154,3
        fcb   0,0 ; #44 arcade C70A, pas encore porte
        fdb   174,158,-66
        fcb   ObjID_warship_turret,turret.TOP ; #45 petite tourelle HAUT
        fdb   183,158,-72
        fcb   ObjID_warship_turret,turret.TOP ; #46 petite tourelle HAUT
        fdb   183,154,-9
        fcb   0,0 ; #47 arcade C716, pas encore porte
        fdb   195,158,-81
        fcb   ObjID_warship_turret,turret.BIG ; #48 grosse tourelle
        fdb   201,159,48
        fcb   ObjID_warship_turret,turret.BOTTOM ; #49 petite tourelle BAS
        fdb   204,154,3
        fcb   0,0 ; #50 arcade C722, pas encore porte
        fdb   210,160,35
        fcb   0,0 ; #51 arcade D5D7, pas encore porte
        fdb   212,158,-75
        fcb   ObjID_warship_turret,turret.BIG ; #52 grosse tourelle
        fdb   219,158,28
        fcb   0,0 ; #53 arcade D5CA, pas encore porte
        fdb   222,160,-72
        fcb   ObjID_warship_turret,turret.TOP ; #54 petite tourelle HAUT
        fdb   222,160,14
        fcb   0,0 ; #55 arcade D5BD, pas encore porte
        fdb   228,154,-15
        fcb   0,0 ; #56 arcade C72E, pas encore porte
        fdb   240,139,-57
        fcb   0,0 ; #57 arcade C73A, pas encore porte
        fdb   240,124,-63
        fcb   0,0 ; #58 arcade C746, pas encore porte
        fdb   240,106,-69
        fcb   0,0 ; #59 arcade C752, pas encore porte
        fdb   240,97,-57
        fcb   0,0 ; #60 arcade C75E, pas encore porte
        fdb   240,88,-51
        fcb   0,0 ; #61 arcade C76A, pas encore porte
        fdb   240,73,-45
        fcb   0,0 ; #62 arcade C776, pas encore porte
        fdb   240,58,-9
        fcb   0,0 ; #63 arcade C782, pas encore porte
        fdb   240,37,-39
        fcb   0,0 ; #64 arcade C78E, pas encore porte
        fdb   240,157,-18
        fcb   0,0 ; #65 arcade D5B0, pas encore porte
        fdb   240,157,-45
        fcb   0,0 ; #66 arcade D596, pas encore porte
        fdb   240,160,-31
        fcb   0,0 ; #67 arcade D5A3, pas encore porte
        fdb   -1
