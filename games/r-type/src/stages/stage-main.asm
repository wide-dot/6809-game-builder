;*******************************************************************************
; Le corps de stage — partagé par les stages, la politique reste à chacun
;
; La boucle principale appartient au stage, pas au moteur : c'est ce qui rend
; la frontière traçable sans deviner de crochets. Les deux stages de ce banc
; ont la même boucle — comme en v1, où les mains 02..08 étaient des copies du
; 01 — donc elle est écrite une fois ici, et chaque stage fournit ce qui le
; distingue par deux routines :
;
;   stage.setup     ses cartes, sa largeur, sa wave
;   stage.handOver  ce qu'il fait quand son temps est écoulé
;
; Ce fichier doit être inclus EN PREMIER dans la section du stage : l'unité est
; chargée à l'adresse de la région et le loader saute sur son premier octet.
;*******************************************************************************

stage.main
        ; un échange arrive avec l'IRQ du stage précédent encore active
        jsr   IrqOff

        jsr   InitGlobals
        jsr   joypad.init

        ; 160x200 en 16 couleurs : sans ça la machine reste dans son mode de
        ; démarrage et lit les tuiles comme du 320x200 deux couleurs
        _gfxmode.setBM16

        lda   game.stage
        bne   stage.stateKept
        ; première entrée de la partie : on sème l'état qui doit survivre aux
        ; échanges. Il vit dans le moteur, donc plus personne n'y touche.
        ldd   #bench.SCORE
        std   game.score
        lda   #3
        sta   game.lives
        lda   #bench.MAGIC
        sta   bench.magic
stage.stateKept

        lda   #STAGE_ID
        sta   bench.stage

        ldd   #Pal_stage
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; les deux tampons : le scroll ne peint que son viewport
        _ram.data.set #2
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory
        _ram.data.set #3
        ldx   #$0000
        jsr   ClearInterlacedEvenDataMemory
        ldx   #$0000
        jsr   ClearInterlacedOddDataMemory

        ; le viewport, en tuiles et en pixels — commun aux deux niveaux
        lda   #12
        sta   scroll_vp_h_tiles
        lda   #map.ROWS
        sta   scroll_vp_v_tiles
        lda   #12
        sta   scroll_tile_width
        sta   scroll_tile_height
        lda   #8
        sta   scroll_vp_x_pos
        lda   #11
        sta   scroll_vp_y_pos
        ldd   #bench.SCROLL_VEL
        std   scroll_vel

        jsr   stage.setup                  ; cartes, largeur, wave : le stage
        jsr   InitScroll

        ; InitScroll cale le plafond caméra sur le map_width figé à l'assemblage
        ; du moteur ; chaque stage a le sien, et l'écrit par-dessus. C'est la
        ; porte que le boss de la v1 utilisait déjà pour figer la caméra.
        ldd   #map.COLS*12-144
        std   scroll_max

        ; L'horloge de niveau repart a zero. Les horodatages d'une wave sont
        ; ceux de l'arcade, comptes depuis le debut du stage — en v1 c'etait
        ; gratuit, un changement de game mode rechargeait le moteur avec ses
        ; variables. Ici le moteur est RESIDENT : son horloge traverse
        ; l'echange, et c'est au stage de la remettre a zero.
        ldd   #0
        std   gfxlock.frame.gameCount

        ; moveByScript garde la page et l'adresse de la table de scripts dans
        ; des operandes auto-modifiees — il y en a DEUX pour la page, une par
        ; routine qui monte. Le moteur a la routine qui les pose toutes : elle
        ; les lit dans l'index d'objets, a l'identifiant de l'objet animation.
        ldb   #objid.animation
        jsr   moveByScript.register

        jsr   ObjectWave_Init              ; cale le pointeur de wave sur l'horloge
        jsr   InitStack
        jsr   ManagedObjects_ClearAll
        jsr   InitRNG

        ; les structures de priorite du dessin de sprites, une par tampon
        jsr   InitDrawSprites

        ldd   #stage.userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        jsr   IrqOn

; L'ordre de la v1 : Scroll et ObjectWave hors du verrou, DrawTiles dedans.
; Seul le second touche l'écran.
; L'ordre est celui de la v1 : effacer avant de repeindre les tuiles, dessiner
; les sprites apres — sinon un sprite est recouvert par le decor de sa trame.
stage.loop
        jsr   Scroll
        jsr   ObjectWave
        jsr   RunObjects
        jsr   CheckSpritesRefresh
        _gfxlock.on
        jsr   EraseSprites
        jsr   UnsetDisplayPriority
        jsr   DrawTiles
        jsr   DrawSprites
        _gfxlock.off

        inc   bench.frames
        ldd   glb_camera_x_pos
        std   bench.camera

        ; La main se passe sur l'horloge de niveau, pas sur un compteur de
        ; tours : c'est la meme echelle que les horodatages de la wave.
        ldd   gfxlock.frame.gameCount
        cmpd  #bench.STAGE_FRAMES
        bhs   stage.handOver

        _gfxlock.loop
        lbra  stage.loop

stage.userIRQ
        jsr   gfxlock.bufferSwap.check
        jmp   PalUpdateNow

; L'objet bouchon : toutes les entrées de l'index du stage pointent ici tant
; que les ennemis ne sont pas portés. Il prouve le chemin complet — la wave a
; réservé un slot et posé l'identifiant, RunObjects a lu l'index du stage
; chargé, monté la page et sauté à l'adresse.
stage.placeholder
        lda   #STAGE_ID
        sta   bench.spawnStage
        ldd   bench.spawns
        addd  #1
        std   bench.spawns
        jsr   UnloadObject_u
        rts
