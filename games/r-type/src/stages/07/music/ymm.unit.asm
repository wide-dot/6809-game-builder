;*******************************************************************************
; La musique YM2413 du stage 7 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($2C09). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; La musique du stage 7 n'est pas prête : `music.ymm` est un PLACEHOLDER en
; attendant. Le nom est celui de la convention — chaque stage nomme sa musique
; `music.ymm` — pour que le branchement du vrai morceau ne soit qu'un
; remplacement de fichier, sans toucher à cette unité.
;
; C'est le seul stage sans VGM source dans le dépôt, donc le seul absent de
; `music.xml` : il n'y a rien à régénérer tant que le morceau n'est pas fait.
;
; Le boss, le jingle de fin, le continue et le game over ne sont PLUS ici :
; ils vivent dans `common.music.ymm`, chargé une fois au boot en $20BC et
; jamais échangé. Ce bloc-ci ne porte que la piste du stage — d'où l'adresse
; $2C09, qui commence après le bloc commun.
;*******************************************************************************

sounds.level7.ymm     EXPORT

 SECTION code

sounds.level7.ymm
        INCLUDEBIN "src/stages/07/music/adnz/ymm/music.ymm"

 ENDSECTION
