;*******************************************************************************
; La musique YM2413 du stage 8 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($2C09). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; Le morceau est `music.ymm`, produit par `music.xml` depuis le VGM du stage :
; c'est la version définitive de la musique, et elle remplace le `theme.ymm`
; v1 (7762 o) que ce bloc jouait jusqu'au 18/08. Nom normalisé comme partout
; ailleurs.
;
; Le bloc ne fait plus que 289 octets : le débordement sur $3736-$4000 que le
; thème v1 imposait — zone rendue par l'arène stage8.gfx — n'a plus lieu
; d'être.
;
; Le boss, le jingle de fin, le continue et le game over vivent dans
; `common.music.ymm`, chargé une fois au boot en $20BC et jamais échangé. Ce
; bloc-ci ne porte que la piste du stage — d'où l'adresse $2C09, qui commence
; après le bloc commun. Le stage 8 les gagne au passage : l'index v1 du
; niveau 8 n'avait ni boss ni jingle.
;*******************************************************************************

sounds.level8.ymm     EXPORT

 SECTION code

sounds.level8.ymm
        INCLUDEBIN "src/stages/08/music/adnz/ymm/music.ymm"

 ENDSECTION
