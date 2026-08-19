;*******************************************************************************
; Le lot F de la bibliothèque : mid, en squelette (voir obj.asm).
; Même charpente que le cast du stage 2 : le bouchon compte le spawn dans
; les témoins du banc puis rend le slot.
;*******************************************************************************

mid.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "src/common/bench.const.asm"

lib.mid.stub
        ldd   bench.spawns              ; temoin du banc : ce spawn a eu lieu,
        addd  #1                        ; atteint par l'index du stage charge
        std   bench.spawns
        lda   bench.stage
        sta   bench.spawnStage
        jsr   UnloadObject_u            ; implementation vide : rendre le slot
        rts

        INCLUDE "src/enemies/mid/obj.asm"

 ENDSECTION
