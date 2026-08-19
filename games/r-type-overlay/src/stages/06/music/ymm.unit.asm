;*******************************************************************************
; La musique YM2413 du stage 6 — les données seules
;
; Le niveau 6 n'avait de musique ni en v1 ni en v2 (aucun dossier music dans
; son niveau v1) : ce bloc rejouait les OCTETS du niveau 1 en attendant un
; choix de l'auteur. Le choix est fait (18/08) — le stage a désormais SON
; VGM, et `music.xml` en tire son `music.ymm` comme pour les autres.
;
; Le nom suit la convention uniforme : chaque stage nomme sa musique
; `music.ymm`.
;
; Le boss, le jingle de fin, le continue et le game over ne sont PLUS ici :
; ils vivent dans `common.music.ymm`, chargé une fois au boot en $20BC et
; jamais échangé. Ce bloc-ci ne porte que la piste du stage — d'où l'adresse
; $2C09, qui commence après le bloc commun.
;*******************************************************************************

sounds.level6.ymm     EXPORT

 SECTION code

sounds.level6.ymm
        INCLUDEBIN "src/stages/06/music/adnz/ymm/music.ymm"

 ENDSECTION
