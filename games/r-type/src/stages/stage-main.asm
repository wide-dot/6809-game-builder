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

        ; Le stage OUVRE SUR LE NOIR, comme la v1 : la palette du jeu n'arrive
        ; que par le fondu arme plus bas, une fois le premier ecran peint. Sans
        ; ca le niveau apparait d'un coup, et l'ecran de chargement se voit.
        ldd   #Pal_black
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

        ; une trame d'amorce avant le scroll, comme la v1 : le double tampon
        ; bascule une fois et les objets deja inscrits tournent, de sorte que
        ; InitScroll parte d'un etat coherent
        jsr   gfxlock.bufferSwap.do
        jsr   RunObjects

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

        ; Le fondu d'ouverture : on part du noir pose plus haut et on monte
        ; vers la palette du stage. L'objet est arme ici et tourne dans la
        ; boucle ; il se met en veille tout seul une fois arrive.
        jsr   stage.paletteFadeIn

        ldd   #stage.userIRQ
        std   Irq_user_routine
        jsr   IrqInit
        lda   #255
        ldx   #Irq_one_frame
        jsr   IrqSync
        _gfxlock.init
        ; PLAFOND DE FRAME-DROP. _gfxlock.init le remet a zero — « pas de
        ; plafond par defaut » — et sans lui la premiere iteration qui suit un
        ; chargement de scene voit des centaines de trames ecoulees. Tout ce
        ; qui avance « par frame drop » les consomme d'un coup :
        ; moveByScript.runByFrameDrop sort alors par le bout de son script.
        ; La v1 pose 8 ici, pour la trainee d'effacement des tuiles.
        lda   #8
        sta   gfxlock.frameDrop.max
        jsr   IrqOn

; L'ordre de la v1 : Scroll et ObjectWave hors du verrou, DrawTiles dedans.
; Seul le second touche l'écran.
; L'ordre est celui de la v1 : effacer avant de repeindre les tuiles, dessiner
; les sprites apres — sinon un sprite est recouvert par le decor de sa trame.
stage.loop
        jsr   Scroll
        jsr   ObjectWave
        ; Le fondu, avant les objets du pool : c'est un objet hors pool, avec
        ; son OST a lui, donc RunObjects ne le voit pas.
        _Obj_RunU ObjID_fade,#palettefade
        jsr   RunObjects
        jsr   CheckSpritesRefresh
        _gfxlock.on
        jsr   EraseSprites
        jsr   UnsetDisplayPriority
        jsr   DrawTiles
        jsr   DrawSprites

        ; Le masque, par-dessus tout le reste — c'est l'ordre de la v1, ou il
        ; venait apres DrawSprites. Il couvre les bandes ou le scroll laisse
        ; ses artefacts, donc il doit etre le dernier a peindre.
        ;
        ; Le sprite compile prend le plan FORME dans U et le plan COULEUR dans
        ; glb_screen_location_1, puis avance de 8000 et empile vers le bas. Les
        ; deux bases sont fixes : c'est la PAGE derriere la fenetre $A000-$DFFF
        ; qui alterne au double tampon, pas l'adresse.
        ldd   #$A000
        std   <glb_screen_location_1
        ldu   #$C000
        lda   #map.RAM_OVER_CART+overlay.page
        ldx   #adr_playfield_mask_ND0
        jsr   paged.call

        _gfxlock.off

        inc   bench.frames
        ldd   glb_camera_x_pos
        std   bench.camera

        ; La main se passe A LA FIN DE LA CARTE, comme dans le jeu. Scroll
        ; borne la camera a scroll_max exactement (cap applique par tampon,
        ; pour que les deux s'arretent au meme endroit), donc elle l'atteint
        ; et s'y tient : le test se declenche pile.
        ;
        ; C'etait une horloge de niveau (800 trames), qu'il fallait recaler a
        ; chaque changement de longueur de niveau ou de vitesse de scroll — et
        ; qui, a la vitesse reelle du jeu, passait la main apres un dixieme du
        ; niveau 1. La fin de carte s'adapte d'elle-meme aux deux.
        ldd   glb_camera_x_pos
        cmpd  scroll_max
        lbhs  stage.handOver               ; long : handOver vit apres la boucle

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

;*******************************************************************************
; L'ouverture en fondu — la forme de la v1 (Palette_FadeIn du game mode 01)
;
; L'objet ne recoit pas la palette de depart : il lit Pal_current, donc c'est
; a l'appelant d'avoir pose le noir avant. o_fade_wait est le nombre de trames
; entre deux paliers de couleur ; la v1 monte en 4 et descend en 1.
;*******************************************************************************
stage.paletteFadeIn
        ldu   #palettefade
        ldx   #Pal_stage
        lda   #4
stage.paletteFadeCommon
        clr   routine,u
        stx   o_fade_dst,u
        sta   o_fade_wait,u
        ldd   Pal_current
        std   o_fade_src,u
        ldd   #0
        std   o_fade_sleep,u
        ldd   #stage.paletteFadeDone
        std   o_fade_callback,u
        rts

stage.paletteFadeDone
        rts
