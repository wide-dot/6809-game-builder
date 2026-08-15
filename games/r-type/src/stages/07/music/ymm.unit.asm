;*******************************************************************************
; La musique YM2413 du stage 7 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($20BC). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; Le morceau est `rtype-stage4.ymm` : c'est celui que le ymm.asm v1 du
; niveau 7 joue. Le dossier contient aussi `theme.ymm` (le thème partagé du
; niveau 4) et `music.ymm` (copie de celui du niveau 2), non retenus.
;
; Le boss et le jingle de fin voyagent avec le morceau, comme au stage 1 :
; rien ne les rechargera au moment où ils serviront. Leurs noms sont
; multi-fournisseurs (chaque bloc les porte), donc ce fichier reste indexé
; le temps du stage — ~40 octets de pool, sans danger depuis que le tampon
; de répertoire est statique hors pool (15/08).
;*******************************************************************************

sounds.level7.ymm     EXPORT
sounds.boss.ymm       EXPORT
sounds.clearstage.ymm EXPORT

 SECTION code

sounds.level7.ymm
        INCLUDEBIN "src/stages/07/music/adnz/ymm/rtype-stage4.ymm"
sounds.boss.ymm
        INCLUDEBIN "src/common/flow/bossmusic/music/ymm/music.ymm"
sounds.clearstage.ymm
        INCLUDEBIN "src/common/flow/clearstage/music/ymm/music.ymm"

 ENDSECTION
