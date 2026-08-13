;*******************************************************************************
; Title — la troisième unité du créneau d'échange (squelette T1b)
;
; Le title est « un stage sans scroll » : une unité alternative à la même
; place que stage1 et stage2 ($01/$8000), qui exporte les mêmes tables que le
; moteur résident relit, et qui s'échange par la même mécanique de scènes.
; Ses graphismes vivent dans l'arène `title` (pages des tuiles — un title ne
; coexiste jamais avec un stage).
;
; SQUELETTE : l'unité assemble, exporte l'interface et se gare. La boucle v1
; (v1-main.asm, 849 l. — phases du logo, musique ymm00+vgc00, press start)
; arrive en T1c ; la bascule vers le stage 1 en T3.
;*******************************************************************************

STAGE_ID equ 0
; La scène de CE mode : ce qu'il rend en partant vers le stage 1.
STAGE_SCENE equ scenes.title

Obj_Index_Page    EXPORT
Obj_Index_Address EXPORT
Ani_Page_Index    EXPORT
Ani_Asd_Index     EXPORT
Img_Page_Index    EXPORT
; L'etat de la boucle : le joueur resident l'ecrit a travers le lien, quel
; que soit le mode charge dans le creneau.
mainloop.state    EXPORT

 SECTION code

        INCLUDE "engine/system/to8/map.const.asm"

; l'entree est le premier octet de l'unite (cf. unit-entry-point.md)
title.init
        bra   *                        ; squelette : la boucle v1 arrive en T1c

; Les tables du squelette pointent toutes ici : un objet invoque sans etre
; porte ne fait rien — le geste du bouchon des stages.
title.placeholder
        rts

mainloop.state fcb 0

;*******************************************************************************
; L'index d'objets du title
;*******************************************************************************
        INCLUDE "src/title/objid.const.asm"
        INCLUDE "src/title/objid.index.asm"

 ENDSECTION
