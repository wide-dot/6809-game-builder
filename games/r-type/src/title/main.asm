;*******************************************************************************
; Title — la troisième unité du créneau d'échange
;
; Le title est « un stage sans scroll » : une unité alternative à la même
; place que stage1 et stage2 ($01/$8000), qui exporte les mêmes tables que le
; moteur résident relit, et qui s'échange par la même mécanique de scènes.
; Ses graphismes vivent dans l'arène `title` (pages des tuiles — un title ne
; coexiste jamais avec un stage).
;
; T1c : les phases 0-4 de l'attract v1 (v1-main.asm) — l'animation du logo —
; adaptées sur le moteur résident : la boucle v1 (WaitVBL, page de dessin
; fixe) devient la boucle v2 (verrou gfxlock, double tampon), les appels
; moteur passent par api.asm, l'objet logo est intégré à l'unité (ses images
; par l'index d'imageset, une page par image — le set est coupé en deux
; morceaux d'arène). Restent : text/scores/push_button et la musique (T2),
; press start → stage 1 (T3).
;*******************************************************************************

STAGE_ID equ 0
; La scène de CE mode : ce qu'il rend en partant vers le stage 1.
STAGE_SCENE equ scenes.title

Obj_Index_Page    EXPORT
Obj_Index_Address EXPORT
Ani_Page_Index    EXPORT
Ani_Asd_Index     EXPORT
Img_Page_Index    EXPORT
; L'etat de la boucle : le joueur resident l'ecrit a travers le lien, quel
; que soit le mode charge dans le creneau.
mainloop.state    EXPORT

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
        INCLUDE "engine/pack/ymm.asm"
        INCLUDE "engine/pack/vgc.asm"

        INCLUDE "gen/layout.asm"

; le son : lecteurs et donnees, resolus par le lien (dialecte v2 des lecteurs
; conserves — kept-v2-api.md). Le YMM est resident, le VGC est charge par la
; scene du title dans son arene, donnees colocalisees dans le meme direntry.
ymm.obj.play     EXTERNAL
ymm.frame.play   EXTERNAL
ym2413.init      EXTERNAL
vgc.obj.play     EXTERNAL
vgc.frame.play   EXTERNAL
sn76489.init     EXTERNAL
sounds.title.ymm EXTERNAL
sounds.title.vgc EXTERNAL

page.ymm equ map.RAM_OVER_CART+engine.sound.ymm.page
page.vgc equ map.RAM_OVER_CART+title.sound.vgc.page

; l'entree est le premier octet de l'unite (cf. unit-entry-point.md) ; le
; moteur resident y saute par le LIEN (`jmp stage.main` dans
; game.stage.switch) : le nom est commun aux trois unites du creneau
stage.main EXPORT
stage.main
        ; un echange peut arriver avec l'IRQ du mode precedent encore active
        jsr   IrqOff

        jsr   InitGlobals
        jsr   joypad.init

        ; 160x200 en 16 couleurs : sans ca la machine reste dans son mode de
        ; demarrage et lit les sprites comme du 320x200 deux couleurs
        _gfxmode.setBM16

        ; les deux puces au silence — l'etat connu du demarrage (v1 :
        ; resetsn/resetym ; v2 : les routines init des lecteurs, montees
        ; chacune avec sa page)
        _ram.cart.set #page.vgc
        _sn76489.init
        _ram.cart.set #page.ymm
        _ym2413.init

        ; palette au noir le temps de composer la premiere trame
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        jsr   InitStack
        jsr   ManagedObjects_ClearAll
        jsr   InitDrawSprites

; ---------------------------------------------------------------------------
; PHASE 0 : les six lettres du logo, montees avec leur sous-type (v1 phase 0)
; ---------------------------------------------------------------------------
        ldu   #addr_logo
        lda   #1                       ; sous-types 1..6 = R . T Y P E
title.mountLetter
        pshs  a,u
        jsr   LoadObject_x
        puls  a,u
        stx   ,u++
        sta   subtype,x
        pshs  a
        lda   #ObjID_logo
        sta   id,x
        puls  a
        inca
        cmpa  #7
        bne   title.mountLetter

; les deux tampons video effaces au noir — l'idiome du checkpoint (on POSE la
; fenetre donnees sur un tampon, on ne bascule pas un registre qu'on ne
; possede pas). Au lancement du mode la fenetre porte encore la page DATA du
; loader : un effacement sans cette pose detruit cette page et laisse les
; tampons sales (vecu ici : un octet de residu de boot en pixel fantome) —
; bufferSwap.do ne monte rien, seul _gfxlock.on pose la fenetre en boucle de
; jeu. Cas : docs/lang/en/migration/relative-toggles-on-shared-registers.md
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

; une trame d'amorce, comme le stage : le double tampon bascule une fois et
; les objets deja montes tournent, avant que l'IRQ ne prenne la main
        jsr   gfxlock.bufferSwap.do
        jsr   RunObjects

; ---------------------------------------------------------------------------
; l'IRQ et le verrou de trame, puis la palette du title
; ---------------------------------------------------------------------------
        ldd   #title.userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        lda   #3
        sta   gfxlock.frameDrop.max
        jsr   IrqOn

        ldd   #Pal_title
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

; ---------------------------------------------------------------------------
; PHASE 1 : les lettres entrent par la droite (v1 phase 1)
; ---------------------------------------------------------------------------
        ldu   #addr_logo
        ldy   #logo_startx
        lda   #6
        sta   @n
title.p1.set
        ldx   ,u++
        ldd   ,y++
        std   x_pos,x
        ldd   #100
        std   y_pos,x
        ldd   #-$200
        std   x_vel,x
        lda   #0
@n      equ   *-1
        deca
        sta   @n
        bne   title.p1.set
title.p1.live
        ldu   #addr_logo
        ldx   ,u
        ldd   x_pos,x
        cmpd  #35
        ble   title.p2.init
        jsr   title.frame
        bra   title.p1.live

; ---------------------------------------------------------------------------
; PHASE 2 : les lettres s'ecartent vers la droite (v1 phase 2)
; ---------------------------------------------------------------------------
title.p2.init
        ldx   ,u
        ldy   #logo_finalpos
        ldd   ,y
        std   x_pos,x
        ldy   #logo_xvel
        lda   #6
        sta   @n
title.p2.set
        ldx   ,u++
        ldd   ,y++
        std   x_vel,x
        lda   #0
@n      equ   *-1
        deca
        sta   @n
        bne   title.p2.set
title.p2.live
        ldu   #addr_logo
        ldx   2,u
        ldd   x_pos,x
        cmpd  #50
        bge   title.p3.init
        jsr   title.frame
        bra   title.p2.live

; ---------------------------------------------------------------------------
; PHASE 3 : realignement, entree du TM en diagonale (v1 phase 3)
; ---------------------------------------------------------------------------
title.p3.init
        ldu   #addr_logo
        ldy   #logo_finalpos
        lda   #6
        sta   @n
title.p3.set
        ldx   ,u++
        ldd   #0
        std   x_vel,x
        ldd   ,y++
        std   x_pos,x
        lda   #0
@n      equ   *-1
        deca
        sta   @n
        bne   title.p3.set

        jsr   LoadObject_x             ; le TM (sous-type 0)
        stx   addr_tm
        lda   #ObjID_logo
        sta   id,x
        clr   subtype,x
        ldd   #0
        std   x_pos,x
        std   y_pos,x
        ldd   #690
        std   x_vel,x
        ldd   #650
        std   y_vel,x
title.p3.live
        ldx   addr_tm
        ldd   y_pos,x
        cmpd  #125
        bge   title.p4.init
        ldd   x_pos,x
        cmpd  #133
        bge   title.p4.init
        jsr   title.frame
        bra   title.p3.live

; ---------------------------------------------------------------------------
; PHASE 4 : le logo et le TM descendent (v1 phase 4)
; ---------------------------------------------------------------------------
title.p4.init
        ldu   #addr_logo
        lda   #6
        sta   @n
title.p4.set
        ldx   ,u++
        ldd   #200
        std   y_vel,x
        lda   #0
@n      equ   *-1
        deca
        sta   @n
        bne   title.p4.set

        ldx   addr_tm
        ldd   #0
        std   x_vel,x
        ldd   #200
        std   y_vel,x
        ldd   #138
        std   x_pos,x
        ldd   #130
        std   y_pos,x
title.p4.live
        ldu   #addr_logo
        ldx   ,u
        ldd   y_pos,x
        cmpd  #126
        bge   title.hold.init
        jsr   title.frame
        bra   title.p4.live

; ---------------------------------------------------------------------------
; TENUE : le logo s'arrete (v1 phase 5, sans la musique ni le texte — T2)
; ---------------------------------------------------------------------------
title.hold.init
        ldu   #addr_logo
        lda   #6
        sta   @n
title.hold.set
        ldx   ,u++
        ldd   #0
        std   y_vel,x
        lda   #0
@n      equ   *-1
        deca
        sta   @n
        bne   title.hold.set
        ldx   addr_tm
        ldd   #0
        std   y_vel,x

        ; la musique, au moment v1 (phase 5 : l'arret du logo) : les DEUX
        ; flux, armes sous masque IRQ comme la v1 (v1-main.asm:445-451) —
        ; frame.play tourne deja dans l'IRQ, obj.play remet le flux a zero
        jsr   IrqOff
        _ram.cart.set #page.ymm
        _ymm.obj.play #page.ymm,#sounds.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK
        _ram.cart.set #page.vgc
        _vgc.obj.play #page.vgc,#sounds.title.vgc,#vgc.LOOP,#vgc.NO_CALLBACK
        jsr   IrqOn
title.hold.live
        jsr   title.frame
        bra   title.hold.live

; ---------------------------------------------------------------------------
; La trame : la boucle v1 (WaitVBL + dessins) devient le tour de verrou v2 —
; c'est le segment de rendu du corps de stage, sans tuiles ni surimpressions.
; ---------------------------------------------------------------------------
title.frame
        jsr   joypad.readKbd
        jsr   RunObjects
        jsr   CheckSpritesRefresh
        _gfxlock.on
        jsr   EraseSprites
        jsr   UnsetDisplayPriority
        jsr   DrawSprites
        _gfxlock.off
        _gfxlock.loop
        rts

title.userIRQ
        jsr   gfxlock.bufferSwap.check
        jsr   PalUpdateNow
        ; le son dans l'IRQ, comme la v1 (UserIRQ : une trame de chaque flux) ;
        ; sans morceau arme les lecteurs ressortent d'eux-memes
        _ymm.frame.play #page.ymm
        _vgc.frame.play #page.vgc
        rts

; ---------------------------------------------------------------------------
; L'objet logo — logo.asm v1 repris tel quel, ses images par l'index
; d'imageset (set_logo_0 = TM, 1..6 = R . T Y P E, l'ordre de la serie)
; ---------------------------------------------------------------------------
logo.Object
        lda   routine,u
        asla
        ldx   #logo.routines
        jmp   [a,x]
logo.routines
        fdb   logo.init
        fdb   logo.live
logo.init
        lda   subtype,u
        inca
        sta   priority,u
        deca
        asla
        ldx   #logoimages
        ldx   a,x
        stx   image_set,u
        lda   render_flags,u
        ora   #render_playfieldcoord_mask
        sta   render_flags,u
        inc   routine,u
logo.live
        jsr   ObjectMoveSync
        jmp   DisplaySprite

logoimages
        fdb   set_logo_0               ; TM
        fdb   set_logo_1               ; R
        fdb   set_logo_2               ; .
        fdb   set_logo_3               ; T
        fdb   set_logo_4               ; Y
        fdb   set_logo_5               ; P
        fdb   set_logo_6               ; E

; Les tables du squelette pointent ici : un objet invoque sans etre porte ne
; fait rien — le geste du bouchon des stages.
title.placeholder
        rts

mainloop.state fcb 0

addr_logo
        fdb   0                        ; R
        fdb   0                        ; .
        fdb   0                        ; T
        fdb   0                        ; Y
        fdb   0                        ; P
        fdb   0                        ; E
addr_tm fdb   0

logo_startx
        fdb   150,146,150,150,150,149
logo_xvel
        fdb   0,84,132,216,300,384
logo_finalpos
        fdb   32,50,67,90,112,134

;*******************************************************************************
; L'index d'objets du title
;*******************************************************************************
        INCLUDE "src/title/objid.const.asm"
        INCLUDE "src/title/objid.index.asm"

 ENDSECTION
