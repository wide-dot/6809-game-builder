; Les boites des 27 sous-parties de coque — GENERE par
; tools/gen_warship_parts.py depuis le dump arcade (deux indirections :
; vignette 40:c656+12i -> recette 1000:73xx -> boite 1000:77b8+8k).
;
; Une entree : fcb rx, ry, cx, cy — rayons et EXCENTRAGE du centre, en
; pixels v2. Les boites arcade sont asymetriques (le corps deborde vers
; le haut de l'ancre), d'ou l'excentrage ; l'axe y arcade monte, donc le
; signe s'inverse a la conversion.

part.Boxes
        fcb   11,10,0,8 ; #0 recette 7302 boite 77B8 face 0 — arcade x[-28..30] y[-24..4]
        fcb   14,16,3,14 ; #1 recette 7322 boite 77C0 face 1 — arcade x[-28..46] y[-40..4]
        fcb   11,7,0,4 ; #2 recette 7366 boite 77C8 face 0 — arcade x[-28..30] y[-15..4]
        fcb   9,10,-1,8 ; #3 recette 737E boite 77D0 face 1 — arcade x[-28..22] y[-24..4]
        fcb   9,7,-1,4 ; #4 recette 7398 boite 77D8 face 0 — arcade x[-28..22] y[-15..4]
        fcb   9,10,-1,8 ; #5 recette 73AC boite 77E0 face 1 — arcade x[-28..22] y[-24..4]
        fcb   12,13,2,10 ; #6 recette 73C6 boite 77E8 face 0 — arcade x[-28..38] y[-31..4]
        fcb   12,13,2,10 ; #7 recette 73F6 boite 77F0 face 1 — arcade x[-28..38] y[-31..4]
        fcb   9,13,-1,10 ; #8 recette 7426 boite 77F8 face 0 — arcade x[-28..22] y[-31..4]
        fcb   8,13,0,10 ; #9 recette 7446 boite 7800 face 1 — arcade x[-22..22] y[-31..4]
        fcb   9,13,-1,10 ; #10 recette 7466 boite 7808 face 0 — arcade x[-28..22] y[-31..4]
        fcb   9,13,-1,10 ; #11 recette 7486 boite 7810 face 1 — arcade x[-28..22] y[-31..4]
        fcb   14,19,3,16 ; #12 recette 74A6 boite 7818 face 0 — arcade x[-28..46] y[-47..4]
        fcb   14,16,3,14 ; #13 recette 74F6 boite 7820 face 1 — arcade x[-28..46] y[-40..4]
        fcb   9,22,-1,20 ; #14 recette 753A boite 7828 face 0 — arcade x[-28..22] y[-56..4]
        fcb   12,19,2,16 ; #15 recette 756C boite 7830 face 1 — arcade x[-28..38] y[-46..4]
        fcb   15,13,5,10 ; #16 recette 75B0 boite 7838 face 0 — arcade x[-28..54] y[-31..4]
        fcb   9,19,-1,16 ; #17 recette 75F0 boite 7840 face 1 — arcade x[-28..22] y[-47..4]
        fcb   11,13,0,10 ; #18 recette 761C boite 7848 face 0 — arcade x[-28..30] y[-31..4]
        fcb   12,10,2,8 ; #19 recette 7644 boite 7850 face 1 — arcade x[-28..38] y[-24..4]
        fcb   12,13,2,10 ; #20 recette 766A boite 7858 face 0 — arcade x[-28..38] y[-31..4]
        fcb   14,13,3,10 ; #21 recette 769A boite 7860 face 1 — arcade x[-28..46] y[-31..4]
        fcb   9,13,-1,10 ; #22 recette 76D2 boite 7868 face 0 — arcade x[-28..22] y[-31..4]
        fcb   9,13,-1,10 ; #23 recette 76F2 boite 7870 face 1 — arcade x[-28..22] y[-31..4]
        fcb   12,10,2,8 ; #24 recette 7712 boite 7878 face 0 — arcade x[-28..38] y[-24..4]
        fcb   15,10,5,8 ; #25 recette 7738 boite 7880 face 1 — arcade x[-28..54] y[-24..4]
        fcb   15,19,5,16 ; #26 recette 776A boite 7888 face 0 — arcade x[-28..54] y[-47..4]
