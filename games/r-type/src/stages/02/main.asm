;*******************************************************************************
; Stage 2 — l'autre unité de la région interface
;
; Même structure que le stage 1, mêmes exports, contenu entièrement différent :
; sa carte est celle du niveau 2 (une caverne, bien plus dense en tuiles), sa
; wave n'a que les entrées dont les ennemis existent encore, et son index
; d'objets ne compte que deux identifiants contre seize.
;
; C'est cette différence de contenu sous une interface identique qui donne sa
; valeur au banc : si le moteur n'était pas repointé sur les tables de CE
; stage, il lirait un index de seize entrées là où il n'y en a que deux.
;*******************************************************************************

STAGE_ID equ 2

Obj_Index_Page    EXPORT
Obj_Index_Address EXPORT

; Les tables de carte vivent dans une page a elles : trop grosses pour la RAM
; residente des que le niveau est entier. Le scroll porte deja une page par
; plan de carte, donc il suffit de les lui designer.
map.even          EXTERNAL
map.odd           EXTERNAL

 SECTION code

        INCLUDE "src/common/engine/api.asm"

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"

        INCLUDE "gen/layout.asm"
        INCLUDE "src/common/bench.const.asm"
        INCLUDE "src/stages/02/map/intro/map.const.asm"

 opt c,ct

        INCLUDE "src/stages/stage-main.asm"

;*******************************************************************************
; Ce qui distingue ce stage
;*******************************************************************************
stage.setup
        ldd   #map.even
        std   scroll_map_even
        ldd   #map.odd
        std   scroll_map_odd
        lda   #map.RAM_OVER_CART+maps.page
        sta   scroll_map_page_even
        sta   scroll_map_page_odd

        ldd   #stage.wave
        std   object_wave_data
        std   object_wave_data_start
        lda   #map.RAM_OVER_CART+stage.page
        sta   object_wave_data_page
        rts

; Un seul passage : on vérifie que l'état persistant a traversé l'échange, on
; laisse la trace du passage, et on rend la main au stage 1.
stage.handOver
        jsr   IrqOff

        ldd   game.score
        cmpd  #bench.SCORE
        bne   stage2.stateLost
        lda   game.lives
        cmpa  #3
        bne   stage2.stateLost
        lda   #$01
        sta   bench.t3
stage2.stateLost

        ; le bouchon qui a tourné doit être CELUI de ce stage : le moteur ne
        ; peut l'atteindre qu'en lisant l'index que ce stage vient d'exporter
        lda   bench.spawnStage
        cmpa  #2
        bne   stage2.notRelinked
        lda   #$01
        sta   bench.t2
stage2.notRelinked

        lda   #2
        sta   game.stage
        ldx   #scenes.stage1
        jmp   game.stage.switch

;*******************************************************************************
; L'index d'objets et la wave — les données réelles du niveau 2
;*******************************************************************************
        INCLUDE "src/stages/02/objid.const.asm"

stage.wave
        INCLUDE "src/stages/02/wave.asm"

 ENDSECTION
