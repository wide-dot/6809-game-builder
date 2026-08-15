;*******************************************************************************
; La musique YM2413 du stage 6 — les données seules
;
; Le niveau 6 n'a de musique ni en v1 ni en v2 (aucun dossier music dans son
; niveau v1) : ce bloc rejoue les OCTETS du niveau 1 en attendant un choix
; de l'auteur (candidats au TODO : le theme.ymm partagé des dossiers 04/07,
; ou une conversion vgm2ymm dédiée).
;
; Le nom est celui de CE stage : les octets sont ceux du niveau 1, mais le
; morceau du stage 6 reste désigné par son propre symbole. Le boss et le
; jingle voyagent avec, comme partout — sa wave sème le marqueur de musique
; de boss.
;*******************************************************************************

sounds.level6.ymm     EXPORT
sounds.boss.ymm       EXPORT
sounds.clearstage.ymm EXPORT

 SECTION code

sounds.level6.ymm
        INCLUDEBIN "src/stages/01/music/adnz/ymm/music.ymm"
sounds.boss.ymm
        INCLUDEBIN "src/common/flow/bossmusic/music/ymm/music.ymm"
sounds.clearstage.ymm
        INCLUDEBIN "src/common/flow/clearstage/music/ymm/music.ymm"

 ENDSECTION
