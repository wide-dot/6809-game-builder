;*******************************************************************************
; Le cast du stage 2 en UN direntry (group multi-membres)
;
; Le repertoire du disque est la denree rare : il reside dans le pool du
; loader (4060 octets), et son passage de 10 a 11 secteurs a creve le pool
; au premier echange de scene — cinq entrees de repertoire pour cinq
; squelettes etaient un luxe. Un group = un direntry multi-asm (exports
; fusionnes, un seul id de fichier) ; chaque ennemi garde SON fichier
; source dans src/enemies/, pret a grandir.
;
; L'entree de chaque objet est son export ; le bouchon commun compte le
; spawn dans les temoins du banc puis rend le slot — une implementation
; vide ne bloque jamais le pool d'objets.
;*******************************************************************************

gouger.Object   EXPORT
wick.Object     EXPORT
brood.Object    EXPORT
outslay.Object  EXPORT
gomander.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "src/common/bench.const.asm"

stage2.cast.stub
        ldd   bench.spawns              ; temoin du banc : ce spawn a eu lieu,
        addd  #1                        ; atteint par l'index du stage charge
        std   bench.spawns
        lda   bench.stage
        sta   bench.spawnStage
        jsr   UnloadObject_u            ; implementation vide : rendre le slot
        rts

        INCLUDE "src/enemies/gouger/obj.asm"
        INCLUDE "src/enemies/wick/obj.asm"
        INCLUDE "src/enemies/brood/obj.asm"
        INCLUDE "src/enemies/outslay/obj.asm"
        INCLUDE "src/enemies/gomander/obj.asm"

 ENDSECTION
