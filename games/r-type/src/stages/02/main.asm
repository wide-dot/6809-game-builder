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
Ani_Page_Index    EXPORT
Ani_Asd_Index     EXPORT
Img_Page_Index    EXPORT

; Les tables de carte vivent dans une page a elles : trop grosses pour la RAM
; residente des que le niveau est entier. Le scroll porte deja une page par
; plan de carte, donc il suffit de les lui designer.
map.even          EXTERNAL
map.odd           EXTERNAL

; La wave vit dans le comblement du pageset des tuiles impaires : sa page est
; celle que le rangement lui a donnee, et le builder l'ecrit en equate.
stage.wave        EXTERNAL
patapata.Object   EXTERNAL

; La table des scripts d'animation, commune a tous les stages et dans sa
; propre page : moveByScript la lit par page montee.
Ani_Asd_common    EXTERNAL

; Le masque du champ de jeu, dans la page des overlays. Ce n'est pas un objet :
; il n'a ni etat ni OST, sa page est une equate (overlay.page) et son adresse
; ce symbole — paged.call suffit a l'atteindre. Les deux stages partagent
; stage-main.asm, donc les deux le declarent.
adr_playfield_mask_ND0 EXTERNAL

; Le champ d'etoiles, meme page que le masque. Trois routines sans etat, visees
; directement : pas d'ObjID, pas de commande en registre.
starfield.init    EXTERNAL
starfield.erase   EXTERNAL
starfield.draw    EXTERNAL

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
        INCLUDE "engine/object-management/Obj_Run.macro.asm"
        ; Les offsets d'OST du fondu : le stage arme l'objet, le moteur le fait
        ; tourner. Le fichier est garde par IFNDEF, donc inclus des deux cotes.
        INCLUDE "engine/objects/palette/fade/fade.equ"

        INCLUDE "gen/layout.asm"
        INCLUDE "src/common/bench.const.asm"
        INCLUDE "gen/stages/02/pages.asm"
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
        lda   #map.RAM_OVER_CART+stage.wave.page
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
        INCLUDE "src/stages/02/objid.index.asm"


 ENDSECTION
