;*******************************************************************************
; LE BANC DES ECRANS DE CLASSEMENT
;
; Un game mode reduit a l'os, dans la region `stage` a la place du title : il
; ouvre la machine comme le title (mode video, palette, verrou, IRQ), pose un
; credit fictif — 100 000 points au stage 1, le semis du cheat — et enchaine
; la sequence STAGE SCORE / saisie / RANKING en boucle, une seconde de noir
; entre deux tours. Rien d'autre n'est charge : le resident et la musique de
; saisie, ce que scenes.boot apporte. Voir le config a cote et
; doc/plan-ecrans-classement-boucle.md.
;*******************************************************************************
STAGE_ID equ 0

Obj_Index_Page    EXPORT
Obj_Index_Address EXPORT
Ani_Page_Index    EXPORT
Ani_Asd_Index     EXPORT
Img_Page_Index    EXPORT
mainloop.state    EXPORT
; Ce que le resident demande a un stage et que le banc n'exerce pas : des
; bouchons, pour que chaque symbole ait son emetteur (controle du builder).
stage.checkpointReset EXPORT
stage.paletteFadeIn   EXPORT
checkpoint.positions  EXPORT
main.endstage.counter EXPORT
main.endstage.phase   EXPORT
main.endstage.rallyX  EXPORT
main.endstage.rallyY  EXPORT
main.endstage.scoreArmed EXPORT
main.endstage.scoreDone  EXPORT

 SECTION code

        INCLUDE "src/common/engine/api.asm"
soundfx.frame      EXTERNAL
ymm.frame.play     EXTERNAL
; ce que l'index d'objets du banc designe (voir les tables en fin de fichier)
Ani_Asd_common        EXTERNAL
explosion.Object      EXTERNAL
loadFirePreset.Object EXTERNAL
patapata.Object       EXTERNAL
ranking.reset      EXTERNAL
ranking.stageAdd   EXTERNAL
ranking.em.on      EXTERNAL
playfield.clearBlast EXTERNAL

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/to8/controller/joypad.const.asm"
        INCLUDE "engine/object-management/Obj_Run.macro.asm"
        INCLUDE "gen/layout.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/bench.const.asm"
        INCLUDE "src/stages/01/objid.const.asm"   ; la numerotation du stage 1

stage.main EXPORT
stage.main
        jsr   IrqOff
        jsr   InitGlobals
        jsr   joypad.init              ; amorce le front de tir (engine, 05/09)
        jsr   Collision_ClearLists     ; les tetes de listes AABB : un Pata-Pata
                                       ;   s'y inscrit a sa naissance
        ldb   #objid.animation         ; la page et la table des scripts, pour
        jsr   moveByScript.register    ;   moveByScript (comme le stage)
        jsr   InitRNG
        lda   #1
        sta   ranking.em.on            ; les Pata-Pata de l'ecran de saisie
        _gfxmode.setBM16
        jsr   ymm.stop
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        jsr   InitStack
        jsr   ManagedObjects_ClearAll
        jsr   DisplaySprite_ClearAll
        jsr   EraseSprites_ClearAll
        jsr   InitDrawSprites
        jsr   bench.clearBuffers
        lda   #bench.MAGIC
        sta   bench.magic
        lda   #STAGE_ID
        sta   bench.stage
        jsr   gfxlock.bufferSwap.do
        jsr   RunObjects
        ldd   #bench.userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        lda   #8                       ; le plafond du stage, pas celui du title
        sta   gfxlock.frameDrop.max
        jsr   IrqOn
        ldd   #Pal_stage
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

bench.round
        ; LE CREDIT FICTIF : le semis de premiere entree du stage, avec le
        ; cheat de score — 100 000 points, tous au stage 1.
        clr   game.stage
        clrb
        jsr   ranking.reset
        ldd   #0
        std   globals.score
        sta   globals.score+2
        ldd   #1000
        std   globals.score+1
        jsr   ranking.stageAdd
        inc   bench.frames             ; un tour de plus, visible de la lane

        jsr   game.ranking.run         ; STAGE SCORE, la saisie, RANKING

        ; ENTRE DEUX TOURS : silence, noir, une seconde de boucle de jeu a
        ; vide — la transition que le continue fera plus tard.
        jsr   game.music.stop
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        lda   #50
        sta   bench.wait
!       jsr   bench.frame
        dec   bench.wait
        bne   <
        ldd   #Pal_stage
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow
        bra   bench.round

; Une trame de la boucle de jeu, sans objet ni logique : le modele du stage —
; verrou ouvert, fond efface par clearBlast, passe de sprites, verrou ferme.
bench.frame
        jsr   joypad.readKbd
        _gfxlock.on
        jsr   RunObjects
        lda   #map.RAM_OVER_CART+common.overlay.page
        ldx   #playfield.clearBlast
        jsr   paged.call
        jsr   BuildSprites
        _gfxlock.off
        _gfxlock.loop
        rts

; Les deux tampons a zero, comme le title a son entree.
bench.clearBuffers
        _ram.data.set #2
        ldu   #$0000
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.clearData
        jsr   paged.call
        _SwitchScreenBuffer
        ldu   #$0000
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.clearData
        jsr   paged.call
        _SwitchScreenBuffer
        rts

bench.userIRQ
        jsr   gfxlock.bufferSwap.check
        jsr   PalUpdateNow
        jsr   joypad.buffer.addDirection
        jsr   ymm.frame.play
        lda   #map.RAM_OVER_CART+common.soundfx.page
        ldx   #soundfx.frame
        jmp   paged.call

mainloop.state fcb 0
stage.checkpointReset
stage.paletteFadeIn   rts
checkpoint.positions  fdb 0,0,0,0
main.endstage.counter fcb 0
main.endstage.phase   fcb 0
main.endstage.rallyX  fdb 0
main.endstage.rallyY  fdb 0
main.endstage.scoreArmed fcb 0
main.endstage.scoreDone  fcb 0
bench.wait     fcb 0

; L'INDEX D'OBJETS DU BANC — la numerotation du stage 1 (objid.const.asm), les
; 33 premieres lignes, dont quatre seulement sont servies : l'animation (les
; scripts, pour moveByScript), l'explosion, le prereglage de tir et le
; Pata-Pata. Tout le reste est a zero : rien ne le lance ici.
Obj_Index_Page
        fcb   0                                          ; 0
        fcb   map.RAM_OVER_CART+common.anim.page         ; 1 ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page    ; 2 ObjID_explosion
        fill  0,9                                        ; 3..11
        fcb   map.RAM_OVER_CART+common.firechain.page    ; 12 ObjID_loadFirePreset
        fill  0,19                                       ; 13..31
        fcb   map.RAM_OVER_CART+lib.patapata.page        ; 32 ObjID_patapata
Obj_Index_Address
        fdb   0
        fdb   Ani_Asd_common                             ; 1
        fdb   explosion.Object                           ; 2
        fill  0,18                                       ; 3..11
        fdb   loadFirePreset.Object                      ; 12
        fill  0,38                                       ; 13..31
        fdb   patapata.Object                            ; 32
Img_Page_Index
        fcb   0
        fcb   map.RAM_OVER_CART+common.anim.page
        fcb   map.RAM_OVER_CART+common.explosion.page
        fill  0,9
        fcb   map.RAM_OVER_CART+common.firechain.page
        fill  0,19
        fcb   map.RAM_OVER_CART+lib.patapata.page
Ani_Page_Index
        fcb   0
        fcb   map.RAM_OVER_CART+common.anim.page
        fcb   map.RAM_OVER_CART+common.explosion.page
        fill  0,9
        fcb   map.RAM_OVER_CART+common.firechain.page
        fill  0,19
        fcb   map.RAM_OVER_CART+lib.patapata.page
Ani_Asd_Index
        fdb   Ani_Asd_none,Ani_Asd_none,Ani_Asd_none,Ani_Asd_none
        fdb   Ani_Asd_none,Ani_Asd_none,Ani_Asd_none,Ani_Asd_none
        fdb   Ani_Asd_none,Ani_Asd_none,Ani_Asd_none,Ani_Asd_none
        fdb   Ani_Asd_none,Ani_Asd_none,Ani_Asd_none,Ani_Asd_none
        fdb   Ani_Asd_none,Ani_Asd_none,Ani_Asd_none,Ani_Asd_none
        fdb   Ani_Asd_none,Ani_Asd_none,Ani_Asd_none,Ani_Asd_none
        fdb   Ani_Asd_none,Ani_Asd_none,Ani_Asd_none,Ani_Asd_none
        fdb   Ani_Asd_none,Ani_Asd_none,Ani_Asd_none,Ani_Asd_none
        fdb   Ani_Asd_none
Ani_Asd_none
        fdb   0
