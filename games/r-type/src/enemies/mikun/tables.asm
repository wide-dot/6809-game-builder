; GENERE par tools/gen_mikun.py depuis la ROM arcade — ne pas editer.

; 1000:4284 -> 9010/9050/9090/90D0 : les seize directions de lancement,
; une table par difficulte. v2 : vx x 0,375, vy x -0,75 (Y vers le bas).
; Direction 0 = vers le haut, 16 = a droite, 32 = en bas, 48 = a gauche ;
; l'offset dans une table EST la direction (multiple de 4).
mikun.Vel
; --- difficulte 0 (1000:9010) ---
        fdb   0,-432        ; dir  0  arcade 0,576
        fdb   84,-408       ; dir  4  arcade 224,544
        fdb   168,-336      ; dir  8  arcade 448,448
        fdb   222,-192      ; dir 12  arcade 592,256
        fdb   252,0         ; dir 16  arcade 672,0
        fdb   222,192       ; dir 20  arcade 592,-256
        fdb   168,336       ; dir 24  arcade 448,-448
        fdb   84,408        ; dir 28  arcade 224,-544
        fdb   0,432         ; dir 32  arcade 0,-576
        fdb   -84,408       ; dir 36  arcade -224,-544
        fdb   -168,336      ; dir 40  arcade -448,-448
        fdb   -222,192      ; dir 44  arcade -592,-256
        fdb   -252,0        ; dir 48  arcade -672,0
        fdb   -222,-192     ; dir 52  arcade -592,256
        fdb   -168,-336     ; dir 56  arcade -448,448
        fdb   -84,-408      ; dir 60  arcade -224,544
; --- difficulte 1 (1000:9050) ---
        fdb   0,-492        ; dir  0  arcade 0,656
        fdb   96,-468       ; dir  4  arcade 256,624
        fdb   186,-372      ; dir  8  arcade 496,496
        fdb   252,-216      ; dir 12  arcade 672,288
        fdb   288,0         ; dir 16  arcade 768,0
        fdb   252,216       ; dir 20  arcade 672,-288
        fdb   186,372       ; dir 24  arcade 496,-496
        fdb   96,468        ; dir 28  arcade 256,-624
        fdb   0,492         ; dir 32  arcade 0,-656
        fdb   -96,468       ; dir 36  arcade -256,-624
        fdb   -186,372      ; dir 40  arcade -496,-496
        fdb   -252,216      ; dir 44  arcade -672,-288
        fdb   -288,0        ; dir 48  arcade -768,0
        fdb   -252,-216     ; dir 52  arcade -672,288
        fdb   -186,-372     ; dir 56  arcade -496,496
        fdb   -96,-468      ; dir 60  arcade -256,624
; --- difficulte 2 (1000:9090) ---
        fdb   0,-552        ; dir  0  arcade 0,736
        fdb   114,-528      ; dir  4  arcade 304,704
        fdb   210,-420      ; dir  8  arcade 560,560
        fdb   288,-240      ; dir 12  arcade 768,320
        fdb   318,0         ; dir 16  arcade 848,0
        fdb   288,240       ; dir 20  arcade 768,-320
        fdb   210,420       ; dir 24  arcade 560,-560
        fdb   114,528       ; dir 28  arcade 304,-704
        fdb   0,552         ; dir 32  arcade 0,-736
        fdb   -114,528      ; dir 36  arcade -304,-704
        fdb   -210,420      ; dir 40  arcade -560,-560
        fdb   -288,240      ; dir 44  arcade -768,-320
        fdb   -318,0        ; dir 48  arcade -848,0
        fdb   -288,-240     ; dir 52  arcade -768,320
        fdb   -210,-420     ; dir 56  arcade -560,560
        fdb   -114,-528     ; dir 60  arcade -304,704
; --- difficulte 3 (1000:90D0) ---
        fdb   0,-600        ; dir  0  arcade 0,800
        fdb   120,-564      ; dir  4  arcade 320,752
        fdb   222,-456      ; dir  8  arcade 592,608
        fdb   312,-264      ; dir 12  arcade 832,352
        fdb   342,0         ; dir 16  arcade 912,0
        fdb   312,264       ; dir 20  arcade 832,-352
        fdb   222,456       ; dir 24  arcade 592,-608
        fdb   120,564       ; dir 28  arcade 320,-752
        fdb   0,600         ; dir 32  arcade 0,-800
        fdb   -120,564      ; dir 36  arcade -320,-752
        fdb   -222,456      ; dir 40  arcade -592,-608
        fdb   -312,264      ; dir 44  arcade -832,-352
        fdb   -342,0        ; dir 48  arcade -912,0
        fdb   -312,-264     ; dir 52  arcade -832,352
        fdb   -222,-456     ; dir 56  arcade -592,608
        fdb   -120,-564     ; dir 60  arcade -320,752

; 1000:943C la periode d'emission, en trames de jeu, par jeton & 15
mikun.Periods
        fdb   320,304,272,240,224,144,96,64
        fdb   48,48,48,48,48,48,48,48

; les poses des directions 8 a 15, dans stage8.mikun.img
mikun.DIR_IMG2 equ 32                   ; premiere direction de cette page
set_mikunb_0 EXTERNAL
set_mikunb_1 EXTERNAL
set_mikunb_2 EXTERNAL
set_mikunb_3 EXTERNAL
set_mikunb_4 EXTERNAL
set_mikunb_5 EXTERNAL
set_mikunb_6 EXTERNAL
set_mikunb_7 EXTERNAL
set_mikunb_8 EXTERNAL
set_mikunb_9 EXTERNAL
set_mikunb_10 EXTERNAL
set_mikunb_11 EXTERNAL
set_mikunb_12 EXTERNAL
set_mikunb_13 EXTERNAL

; 1000:428C les deux poses de chaque direction (recette, recette+6) :
; l'offset dans la table EST la direction. Rang = pose importee
; (images/frames, cycle.txt).
mikun.Poses
        fdb   set_mikun_0,set_mikun_1  ; dir  0  1000:42AC
        fdb   set_mikun_2,set_mikun_3  ; dir  4  1000:42B8
        fdb   set_mikun_4,set_mikun_5  ; dir  8  1000:42C4
        fdb   set_mikun_6,set_mikun_7  ; dir 12  1000:42D0
        fdb   set_mikun_6,set_mikun_7  ; dir 16  1000:42DC
        fdb   set_mikun_8,set_mikun_9  ; dir 20  1000:42E8
        fdb   set_mikun_10,set_mikun_11  ; dir 24  1000:42F4
        fdb   set_mikun_12,set_mikun_13  ; dir 28  1000:4300
        fdb   set_mikunb_0,set_mikunb_1  ; dir 32  1000:430C
        fdb   set_mikunb_2,set_mikunb_3  ; dir 36  1000:4318
        fdb   set_mikunb_4,set_mikunb_5  ; dir 40  1000:4324
        fdb   set_mikunb_6,set_mikunb_7  ; dir 44  1000:4330
        fdb   set_mikunb_8,set_mikunb_9  ; dir 48  1000:433C
        fdb   set_mikunb_8,set_mikunb_9  ; dir 52  1000:4348
        fdb   set_mikunb_10,set_mikunb_11  ; dir 56  1000:4354
        fdb   set_mikunb_12,set_mikunb_13  ; dir 60  1000:4360
