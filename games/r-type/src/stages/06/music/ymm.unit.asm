;*******************************************************************************
; La musique YM2413 du stage 6 — les données seules
;
; Le niveau 6 n'avait de musique ni en v1 ni en v2 (aucun dossier music dans
; son niveau v1) : ce bloc rejouait les OCTETS du niveau 1 en attendant un
; choix de l'auteur. Le choix est fait (18/08) — le stage a désormais SON
; VGM, et `music.xml` en tire son `music.ymm` comme pour les autres.
;
; Le nom suit la convention uniforme : chaque stage nomme sa musique
; `music.ymm`. Le boss et le
; jingle voyagent avec, comme partout — sa wave sème le marqueur de musique
; de boss.
;*******************************************************************************

sounds.level6.ymm     EXPORT
sounds.boss.ymm       EXPORT
sounds.clearstage.ymm EXPORT

 SECTION code

sounds.level6.ymm
        INCLUDEBIN "src/stages/06/music/adnz/ymm/music.ymm"
sounds.boss.ymm
        INCLUDEBIN "src/common/flow/bossmusic/music/ymm/music.ymm"
sounds.clearstage.ymm
        INCLUDEBIN "src/common/flow/clearstage/music/ymm/music.ymm"

 ENDSECTION
