;*******************************************************************************
; Title — la troisième unité du créneau d'échange
;
; Le title est « un stage sans scroll » : une unité alternative à la même
; place que stage1 et stage2 ($01/$8000), qui exporte les mêmes tables que le
; moteur résident relit, et qui s'échange par la même mécanique de scènes.
; Ses graphismes vivent dans l'arène `title` (pages des tuiles — un title ne
; coexiste jamais avec un stage).
;
; L'attract v1 COMPLET (v1-main.asm) adapté sur le moteur résident : la
; boucle v1 (WaitVBL, page de dessin fixe) devient la boucle v2 (verrou
; gfxlock, double tampon), les appels moteur passent par api.asm. Les phases :
; 0-4 l'animation du logo (objet logo dans l'unité), 5 la musique et la
; machine à écrire, 6 le PUSH FIRE BUTTON clignotant, puis la boucle
; d'attract 7 (extinction) → 8 (tableau des scores) → 9 (logo + texte
; rapide) → 7... Text, push_button et scores sont des unités paginées de
; l'arène title (le motif des ennemis), atteintes par l'index d'objets ;
; leurs entrées sont auto-modifiées par ce main ($12/$39/$A6 — l'idiome v1).
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

; l'unite paginee du cheat de selection de stage (title.cheat)
title.cheat.tick   EXTERNAL
title.cheat.launch EXTERNAL
soundfx.frame      EXTERNAL
        INCLUDE "src/common/cast.const.asm"

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
        ; DESARMER le morceau du mode precedent, PAS SEULEMENT faire taire la
        ; puce. `_ym2413.init` coupe le son a l'instant t ; il ne coupe pas la
        ; LECTURE, dont le statut est resident — des que l'IRQ du title tourne,
        ; `_ymm.frame.play` reprend le morceau ou il en etait. Vecu ici : la
        ; musique de game over debordait sur le title.
        ; `ymm.stop` fait les deux : `clr ymm.status` puis `jmp ym2413.init`,
        ; d'ou l'absence de `_ym2413.init` ici — ce serait le meme appel deux
        ; fois.
        jsr   ymm.stop

        ; palette au noir le temps de composer la premiere trame
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        jsr   InitStack
        jsr   ManagedObjects_ClearAll
        ; PURGER AUSSI LES STRUCTURES DE RENDU. Elles nomment des objets, et
        ; `ManagedObjects_ClearAll` vient de tous les effacer : sans ce geste
        ; la liste de priorite et la liste de cellules de fond survivent a
        ; l'echange en designant des morts.
        ; Voir docs/lang/en/migration/resident-render-structures.md
        jsr   DisplaySprite_ClearAll
        jsr   EraseSprites_ClearAll
        jsr   InitDrawSprites

        ; le title s'inscrit dans les temoins : « qui tourne » est observable
        ; de bout en bout par la lane (le title est l'unite 0 du creneau)
        lda   #bench.MAGIC
        sta   bench.magic
        lda   #STAGE_ID
        sta   bench.stage

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

; la machine a ecrire, montee ETEINTE (entree a rts jusqu'a la phase 5 —
; l'idiome v1) ; son OST detourne x_vel : l'adresse de la table des dix
; lignes de score, que sa routine de tableau parcourt
        _Obj_Mount ObjID_text
        lda   #$39
        sta   ,x
        jsr   LoadObject_x
        stx   addr_text
        lda   #ObjID_text
        sta   id,x
        ldd   #addr_scores
        std   x_vel,x
        clr   subtype,x

; les dix lignes du tableau des scores, cachees (bit 7 du sous-type),
; x=45, y de 35 en pas de 14 (les positions v1)
        ldu   #addr_scores
        lda   #$80
        ldb   #35
title.mountScore
        pshs  d,u
        jsr   LoadObject_x
        puls  d,u
        stx   ,u++
        sta   subtype,x
        pshs  d
        lda   #ObjID_scores
        sta   id,x
        ldd   #45
        std   x_pos,x
        puls  d
        clr   y_pos,x
        stb   y_pos+1,x
        adda  #1
        addb  #14
        cmpa  #$8A
        bne   title.mountScore

; les deux tampons video effaces au noir — l'idiome du checkpoint (on POSE la
; fenetre donnees sur un tampon, on ne bascule pas un registre qu'on ne
; possede pas). Au lancement du mode la fenetre porte encore la page DATA du
; loader : un effacement sans cette pose detruit cette page et laisse les
; tampons sales (vecu ici : un octet de residu de boot en pixel fantome) —
; bufferSwap.do ne monte rien, seul _gfxlock.on pose la fenetre en boucle de
; jeu. Cas : docs/lang/en/migration/relative-toggles-on-shared-registers.md
        jsr   title.clearBuffers

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
        bge   title.p5.init
        jsr   title.frame
        bra   title.p4.live

; ---------------------------------------------------------------------------
; PHASE 5 : le logo s'arrete, la musique demarre, le texte se tape (v1 ph. 5)
; ---------------------------------------------------------------------------
title.p5.init
        ldu   #addr_logo
        lda   #6
        sta   @n
title.p5.set
        ldx   ,u++
        ldd   #0
        std   y_vel,x
        lda   #0
@n      equ   *-1
        deca
        sta   @n
        bne   title.p5.set
        ldx   addr_tm
        ldd   #0
        std   y_vel,x

        ; la machine a ecrire demarre : entree remise a nop (l'idiome v1)
        _Obj_Mount ObjID_text
        lda   #$12
        sta   ,x

        ; la musique, au moment v1 (phase 5 : l'arret du logo) : les DEUX
        ; flux, armes sous masque IRQ comme la v1 (v1-main.asm:445-451) —
        ; frame.play tourne deja dans l'IRQ, obj.play remet le flux a zero
        jsr   IrqOff
        _ram.cart.set #page.ymm
        _ymm.obj.play #page.ymm,#sounds.title.ymm,#ymm.LOOP,#ymm.NO_CALLBACK
        _ram.cart.set #page.vgc
        _vgc.obj.play #page.vgc,#sounds.title.vgc,#vgc.LOOP,#vgc.NO_CALLBACK
        jsr   IrqOn
title.p5.live
        ; la machine a ecrire s'eteint elle-meme a la fin de sa frappe :
        ; son entree redevenue rts est le temoin de fin de phase (v1)
        _Obj_Mount ObjID_text
        lda   ,x
        cmpa  #$39
        beq   title.p6.init
        jsr   title.checkStart
        lbne  title.launchGame
        jsr   title.frame
        bra   title.p5.live

; ---------------------------------------------------------------------------
; PHASE 6 : le PUSH FIRE BUTTON clignotant, un temps d'attente (v1 phase 6)
; ---------------------------------------------------------------------------
title.p6.init
        jsr   LoadObject_x
        stx   addr_pushbutton
        lda   #ObjID_push_button
        sta   id,x
        ldd   #110
        std   x_pos,x
        ldd   #62
        std   y_pos,x
        ldx   #$100
        stx   title.p6.counter
title.p6.live
        ldx   title.p6.counter
        beq   title.p7.init
        leax  -1,x
        stx   title.p6.counter
        jsr   title.checkStart
        lbne  title.launchGame
        jsr   title.frame
        bra   title.p6.live

; ---------------------------------------------------------------------------
; PHASE 7 : extinction du logo et du bouton, deux trames — une par tampon,
; le temps que leurs sprites s'effacent (v1 phase 7). Tete de la boucle
; d'attract : 7 -> 8 (scores) -> 9 (logo + texte rapide) -> 7...
; ---------------------------------------------------------------------------
title.p7.init
        lda   #$39
        sta   logo.Object
        _Obj_Mount ObjID_push_button
        lda   #$39
        sta   ,x
        jsr   title.frame
        jsr   title.frame

; ---------------------------------------------------------------------------
; PHASE 8 : le tableau des scores (v1 phase 8) — tampons au noir, palette
; des chiffres, le texte en mode tableau (routine 0, sous-type 2)
; ---------------------------------------------------------------------------
title.p8.init
        jsr   title.clearBuffers

        ldd   #Pal_scores
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ldx   addr_text
        clr   routine,x
        lda   #2                       ; = tableau des scores
        sta   subtype,x
        _Obj_Mount ObjID_text
        lda   #$12
        sta   ,x

        ldx   #$50
        stx   title.p8.counter
title.p8.live
        ldx   title.p8.counter
        beq   title.p9.init
        leax  -1,x
        stx   title.p8.counter
        jsr   title.checkStart
        lbne  title.launchGame
        jsr   title.frame
        bra   title.p8.live

; ---------------------------------------------------------------------------
; PHASE 9 : logo et texte a grande vitesse (v1 phase 9) — tampons au noir,
; palette du title, les dix lignes recachees, le texte en mode rapide, le
; logo et le bouton rallumes ($A6 : leur premier octet, lda routine,u)
; ---------------------------------------------------------------------------
title.p9.init
        jsr   title.clearBuffers

        ldd   #Pal_title
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ldu   #addr_scores
        lda   #$80
title.p9.hide
        ldx   ,u++
        sta   subtype,x
        inca
        cmpa  #$8A
        bne   title.p9.hide

        ldx   addr_text
        clr   routine,x
        lda   #1                       ; = texte rapide
        sta   subtype,x

        lda   #$A6
        sta   logo.Object
        _Obj_Mount ObjID_push_button
        lda   #$A6
        sta   ,x

        ldx   #$100
        stx   title.p9.counter
title.p9.live
        ldx   title.p9.counter
        lbeq  title.p7.init
        leax  -1,x
        stx   title.p9.counter
        jsr   title.checkStart
        lbne  title.launchGame
        jsr   title.frame
        bra   title.p9.live

; ---------------------------------------------------------------------------
; Les deux tampons video au noir — l'idiome du checkpoint (on POSE la fenetre
; donnees, on ne bascule pas un registre qu'on ne possede pas ; cas :
; relative-toggles-on-shared-registers.md). Quatre appelants : l'ouverture,
; les phases 8 et 9, le depart.
; ---------------------------------------------------------------------------
title.clearBuffers
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

; ---------------------------------------------------------------------------
; Le declencheur de depart, partage par toutes les phases a musique : les
; manettes d'abord (v1 : Fire_Press), boutons A et B des DEUX ports, le
; clavier passant par le test integre de joypad.readKbd (bouton B du port
; 0) ; PLUS le bit KTEST du PIA avec son propre front — l'idiome du modele
; sound, style R-Type. L'injection clavier seule ne suffit pas : sans
; extension manette le port se lit tout « tenu » (vecu sous toje), le bit
; injecte tombe dans un bit deja a 1 et l'arete ne vient jamais.
; Sortie : Z=0 si le depart est demande.
; ---------------------------------------------------------------------------
title.checkStart
        lda   joypad.pressed.fire
        anda  #joypad.x.A+joypad.x.B
        bne   @go
        lda   map.MC6821.PRA
        lsra
        bcs   @keyDown
        clr   title.keydown            ; touche relachee : le front se rearme
        clra                           ; Z=1 : pas de depart
        rts
@keyDown
        tst   title.keydown
        bne   @held                    ; toujours tenue : un seul depart
        inc   title.keydown
        lda   #1                       ; Z=0 : depart
        rts
@held   clra
@go     rts

; ---------------------------------------------------------------------------
; DEPART : la sequence LaunchGame de la v1 (palette au noir, IRQ coupee,
; puces au silence), puis l'echange v2 — le title rend SA scene et charge
; celle du stage 1, exactement le geste de stage.gameOver. `game.stage` a
; zero fait de cette entree une premiere entree : le stage reseme les vies
; et le score.
; ---------------------------------------------------------------------------
title.launchGame
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; L'ECRAN DE CHARGEMENT (v1 : le game mode loading entier). Ecran
        ; nettoye, les objets de l'attract effaces, l'image LOADING dessinee
        ; dans les DEUX tampons (deux trames), palette rallumee : elle reste
        ; visible pendant tout le scene.load synchrone qui suit — le loader
        ; v2 n'ecrit pas dans les tampons video —, jusqu'a l'effacement
        ; d'ouverture du stage.
        jsr   title.clearBuffers

        jsr   ManagedObjects_ClearAll
        jsr   DisplaySprite_ClearAll   ; meme raison qu'a l'entree du mode
        jsr   EraseSprites_ClearAll
        jsr   InitDrawSprites

        jsr   LoadObject_x
        lda   #ObjID_loading
        sta   id,x
        ldd   #80
        std   x_pos,x
        ldd   #100
        std   y_pos,x
        jsr   title.frame
        jsr   title.frame

        ldd   #Pal_loading
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        jsr   IrqOff
        _ram.cart.set #page.vgc
        _sn76489.init
        _ram.cart.set #page.ymm
        _ym2413.init

        ; l'unite paginee rend la scene du title (game.stage.unload), choisit
        ; la cible du depart — stage 1, ou celle que le cheat a comptee —,
        ; pose game.stage et saute dans game.stage.switch : on ne revient pas
        lda   #map.RAM_OVER_CART+title.cheat.page
        ldx   #title.cheat.launch
        jsr   paged.call

; ---------------------------------------------------------------------------
; La trame : la boucle v1 (WaitVBL + dessins) devient le tour de verrou v2 —
; c'est le segment de rendu du corps de stage, sans tuiles ni surimpressions.
; ---------------------------------------------------------------------------
title.frame
        jsr   joypad.readKbd
        ; le cheat de selection de stage : etat, machine et table vivent dans
        ; leur page (la carte residente est pleine) — un paged.call par trame
        lda   #map.RAM_OVER_CART+title.cheat.page
        ldx   #title.cheat.tick
        jsr   paged.call
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
        ; le pilote de bruitages, comme stage.userIRQ : sans lui la boite aux
        ; lettres soundFX.newSound (le bip du cheat) reste muette au title —
        ; l'unite soundfx est en RAM depuis scenes.boot
        lda   #map.RAM_OVER_CART+common.soundfx.page
        ldx   #soundfx.frame
        jmp   paged.call

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
title.keydown  fcb 0                   ; front du declencheur clavier

addr_logo
        fdb   0                        ; R
        fdb   0                        ; .
        fdb   0                        ; T
        fdb   0                        ; Y
        fdb   0                        ; P
        fdb   0                        ; E
addr_tm fdb   0
addr_text       fdb   0
addr_pushbutton fdb   0
addr_scores     fdb   0,0,0,0,0,0,0,0,0,0

title.p6.counter fdb  0
title.p8.counter fdb  0
title.p9.counter fdb  0

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
        INCLUDE "src/common/bench.const.asm"

 ENDSECTION
