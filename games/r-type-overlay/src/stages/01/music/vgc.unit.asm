;*******************************************************************************
; La musique SN76489 — MIGRÉE MAIS DÉBRANCHÉE
;
; Elle est volontairement coupée pour rendre du temps CPU : la v1 la débranche
; déjà, et au même endroit — ses lignes sont commentées dans `main.d7.properties`
; (`#object.vgc01=…`), à l'init du niveau et dans son IRQ utilisateur.
;
; Cette unité et sa déclaration de configuration existent pour que la
; configuration ne se perde pas. La rallumer demandera de lui trouver une page
; et de reprendre le budget : le lecteur VGC et ses tampons sont plus gros que
; le YMM, et rien ne dit que la place soit encore là.
;*******************************************************************************

sounds.level1.vgc EXPORT
sounds.boss.vgc   EXPORT

 SECTION code

sounds.level1.vgc
        INCLUDEBIN "src/stages/01/music/adnz/vgc/music.vgc"
sounds.boss.vgc
        INCLUDEBIN "src/common/flow/bossmusic/music/vgc/music.vgc"

 ENDSECTION
