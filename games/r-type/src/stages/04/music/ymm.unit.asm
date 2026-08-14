;*******************************************************************************
; La musique YM2413 du stage 4 — les données seules
;
; Le lecteur est résident depuis le boot (engine.sound.ymm) et ne monte
; qu'une page sous IRQ : les données d'un morceau vivent avec lui, au créneau
; musical de la page $1A ($20BC). Chaque stage y charge SON bloc — les
; fichiers stageN.music.ymm sont des alternatives à la même destination,
; comme le title.
;
; Le morceau est `theme.ymm`, décompressé du `theme.ymm.zx0` que le ymm.asm
; v1 du niveau 4 désigne (zx0 « classic » ; le lecteur lit du YMM nu, la
; compression du direntry appartient au codec du builder). C'est le même
; thème, octet pour octet, que celui du dossier du niveau 7.
;
; Le boss et le jingle de fin ne sont PAS embarqués : seul le main du
; stage 1 les joue aujourd'hui, et les exporter d'ici rendrait leurs noms
; multi-fournisseurs — chaque bloc musical redeviendrait un fichier indexé
; du pool, la fragilité exacte du game over (leçon du chantier collision).
;
; Le thème seul fait 5816 octets : il déborde le créneau de 5754 et mord
; sur $3736-$4000 — zone rendue par l'arène stage4.gfx, qui ne posait rien
; en page $1A au-delà de sa wave (voir to8.config.xml).
;*******************************************************************************

sounds.level4.ymm     EXPORT

 SECTION code

sounds.level4.ymm
        INCLUDEBIN "src/stages/04/music/adnz/ymm/theme.ymm"

 ENDSECTION
