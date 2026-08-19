;*******************************************************************************
; La musique YM2413 du stage 5 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($2C09). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; Le boss, le jingle de fin, le continue et le game over ne sont PLUS ici :
; ils vivent dans `common.music.ymm`, chargé une fois au boot en $20BC et
; jamais échangé. Ce bloc-ci ne porte que la piste du stage — d'où l'adresse
; $2C09, qui commence après le bloc commun.
;*******************************************************************************

sounds.level5.ymm     EXPORT

 SECTION code

sounds.level5.ymm
        INCLUDEBIN "src/stages/05/music/adnz/ymm/music.ymm"

 ENDSECTION
