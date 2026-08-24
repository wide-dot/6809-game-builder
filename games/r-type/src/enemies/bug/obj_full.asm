; ---------------------------------------------------------------------------
; Object
;
; input REG : [u] pointer to Object Status Table (OST)
; ---------
;
; ---------------------------------------------------------------------------

; V2-DEVIATION: obj_main.asm n'est PAS un en-tete : c'est le corps commun de
; l'objet (les deux versions level1/full s'y adossent). Seul le chemin change.
        INCLUDE "src/enemies/bug/obj_main.asm"
ImageIndex
        fdb   Img_bug_0
        fdb   Img_bug_1
        fdb   Img_bug_2
        fdb   Img_bug_3
        fdb   Img_bug_4
        fdb   Img_bug_5
        fdb   Img_bug_6
        fdb   Img_bug_7
        fdb   Img_bug_8
        fdb   Img_bug_9
        fdb   Img_bug_10
        fdb   Img_bug_11
        fdb   Img_bug_12
        fdb   Img_bug_13
        fdb   Img_bug_14
        fdb   Img_bug_15
 
