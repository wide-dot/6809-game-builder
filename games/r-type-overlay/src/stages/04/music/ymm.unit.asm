;*******************************************************************************
; La musique YM2413 du stage 4 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($2C09). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; Le morceau est `music.ymm`, produit par `music.xml` depuis le VGM du stage
; (le lecteur lit du YMM nu ; la compression du direntry appartient au codec
; du builder). Convention uniforme depuis le 18/08 : chaque stage nomme sa
; musique `music.ymm`, quel que soit le nom que le dossier v1 lui donnait.
;
; Ce que la régénération prouve : `music.ymm` sort du VGM **byte-identique**
; au `rtype-stage4.ymm` que la v1 rangeait dans le dossier du niveau 7. Le
; nom v1 disait donc vrai sur le morceau (le thème arcade du stage 4) et faux
; sur son dossier. Le `theme.ymm` v1 du niveau 4 (5816 o) est un autre
; morceau, non retenu.
;
; Le boss, le jingle de fin, le continue et le game over ne sont PLUS ici :
; ils vivent dans `common.music.ymm`, chargé une fois au boot en $20BC et
; jamais échangé. Ce bloc-ci ne porte que la piste du stage — d'où l'adresse
; $2C09, qui commence après le bloc commun.
;*******************************************************************************

sounds.level4.ymm     EXPORT

 SECTION code

sounds.level4.ymm
        INCLUDEBIN "src/stages/04/music/adnz/ymm/music.ymm"

 ENDSECTION
