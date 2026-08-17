;*******************************************************************************
; La musique YM2413 du stage 8 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($20BC). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; Le morceau est `music.ymm`, produit par `music.xml` depuis le VGM du stage :
; c'est la version définitive de la musique, et elle remplace le `theme.ymm`
; v1 (7762 o) que ce bloc jouait jusqu'au 18/08. Nom normalisé comme partout
; ailleurs.
;
; Le bloc ne fait plus que 289 octets et tient donc largement dans le créneau
; de 5754 : le débordement sur $3736-$4000 que le thème v1 imposait — zone
; rendue par l'arène stage8.gfx — n'a plus lieu d'être. Pas de boss ni de
; jingle ici, comme l'index v1 du niveau 8 qui n'en avait pas non plus.
;*******************************************************************************

sounds.level8.ymm     EXPORT

 SECTION code

sounds.level8.ymm
        INCLUDEBIN "src/stages/08/music/adnz/ymm/music.ymm"

 ENDSECTION
