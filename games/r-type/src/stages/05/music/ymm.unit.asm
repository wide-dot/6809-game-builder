;*******************************************************************************
; La musique YM2413 du stage 5 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($20BC). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; Le boss et le jingle de fin ne sont PAS embarqués : seul le main du
; stage 1 les joue aujourd'hui, et les exporter d'ici rendrait leurs noms
; multi-fournisseurs — chaque bloc musical redeviendrait un fichier indexé
; du pool, la fragilité exacte du game over (leçon du chantier collision).
;*******************************************************************************

sounds.level5.ymm     EXPORT

 SECTION code

sounds.level5.ymm
        INCLUDEBIN "src/stages/05/music/adnz/ymm/music.ymm"

 ENDSECTION
