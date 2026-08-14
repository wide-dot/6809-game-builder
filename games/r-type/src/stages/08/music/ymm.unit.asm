;*******************************************************************************
; La musique YM2413 du stage 8 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($20BC). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; Le morceau est `theme.ymm`, décompressé du `theme.ymm.zx0` que le ymm.asm
; v1 du niveau 8 désigne (zx0 « classic »). Le thème seul fait 7762 octets :
; il déborde le créneau de 5754 et continue sur $3736-$4000 — zone rendue par
; l'arène stage8.gfx (voir to8.config.xml). Pas de place pour le boss ni le
; jingle, et l'index v1 du niveau 8 ne les avait pas non plus (intro + thème,
; rien d'autre) ; l'intro (`intro.ymm.zx0`), sans accroche dans le flow v2,
; n'est pas câblée.
;*******************************************************************************

sounds.level8.ymm     EXPORT

 SECTION code

sounds.level8.ymm
        INCLUDEBIN "src/stages/08/music/adnz/ymm/theme.ymm"

 ENDSECTION
