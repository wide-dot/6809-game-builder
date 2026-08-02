;*******************************************************************************
; Stage 1 — l'unité échangeable
;
; Elle porte tout ce qui est propre au niveau 1 : la boucle, les deux cartes,
; la wave réelle de l'arcade, l'index d'objets. Le moteur, lui, est résident et
; n'est jamais rechargé — le stage l'atteint par les EXTERNAL d'api.asm.
;
; Ce que le stage EXPORTe, c'est son interface : les deux tables que le moteur
; relit. La région du layout est déclarée interface="true", donc le builder
; exige des deux stages la même liste d'exports.
;*******************************************************************************

STAGE_ID equ 1

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
; ce symbole — paged.call suffit a l'atteindre.
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
        INCLUDE "gen/stages/01/pages.asm"
        INCLUDE "src/stages/01/map/intro/map.const.asm"

 opt c,ct

        ; le loader saute sur le premier octet de la région : la boucle d'abord
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

; Deux passages : à l'aller on sème l'état et on part sur le stage 2 ; au
; retour on constate que l'échange est réversible et on exerce le checkpoint.
stage.handOver
        jsr   IrqOff

        lda   game.stage
        cmpa  #2
        beq   stage1.secondVisit

        ; --- premier passage ---
        ldd   bench.spawns
        beq   stage1.noSpawn                     ; la wave n'a rien peuplé : témoin muet
        std   bench.stage1Spawns
        lda   #$01
        sta   bench.t1
stage1.noSpawn
        lda   #1
        sta   game.stage
        ldx   #scenes.stage2
        jmp   game.stage.switch

        ; --- retour, après le stage 2 ---
stage1.secondVisit
        lda   #$01
        sta   bench.t4

        ; Checkpoint sans disque : on rembobine la wave et on demande à
        ; ObjectWave_Init de la recaler sur l'horloge de jeu. Elle doit
        ; retrouver exactement la position que la lecture normale avait
        ; atteinte — c'est le mécanisme de reprise en cours de niveau.
        ldd   object_wave_data
        pshs  d
        ldd   object_wave_data_start
        std   object_wave_data
        jsr   ObjectWave_Init
        ldd   object_wave_data
        cmpd  ,s++
        bne   stage1.noCheckpoint
        lda   #$01
        sta   bench.t5
stage1.noCheckpoint

stage1.idle   bra   stage1.idle

;*******************************************************************************
; L'index d'objets et la wave — les données réelles du niveau 1
;*******************************************************************************
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/stages/01/objid.index.asm"


 ENDSECTION

; Les deux cartes sont générées par les éléments <tilemap> de la config, dans
; leur propre section map.static : leurs références de tuiles sont cuites au
; build contre la région déclarée du tileset, donc elles ne coûtent aucune
; donnée de lien au chargement.
