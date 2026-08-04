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
        ; Les vies vivent dans le bloc `globals`, pas dans le moteur : c'est la
        ; variable de la v1 (main.asm:127), celle que le HUD dessine. Deux, comme
        ; elle — le compteur du banc en faisait trois sans raison.
        ldb   #2
        stb   globals.lives
        ldx   #bench.magic                 ; cf. bench.SIZE : la zone n'est chargée
        ldb   #bench.SIZE                  ; par personne, un témoin non posé lirait
        clra                               ; sinon $FF au lieu de $00
!       sta   ,x+
        decb
        bne   <
        lda   #bench.MAGIC
        sta   bench.magic
stage.stateKept

        lda   #STAGE_ID
        sta   bench.stage

        ; Les variables inter-main que la chaine de tir lit. Elles vivent dans
        ; la zone RESERVEE, donc dans de la RAM que rien ne charge : leur
        ; contenu au demarrage est ce que la machine y avait. La v1 les pose au
        ; meme endroit, dans l'init de son main (main.asm:103 et 121-130) —
        ; laisser la difficulte sale ferait indexer la table de presets de
        ; tir 64 octets plus loin par cran, hors de ses donnees.
        clr   globals.difficulty
        ldd   #0
        std   globals.score
        stb   globals.score+2              ; le 3e octet du score 24 bits

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

        ; COLLISION TERRAIN : desactivee PAR DEFAUT. Un stage sans unite de
        ; collision laisserait les operandes de terrainCollision.do a zero, et
        ; la routine sauterait en $0000 de la fenetre cartouche, page 0 NUE —
        ; le cold-start de la ROM basic512 (vecu). Le stage qui a sa carte
        ; (stage.setup) pose l'init et leve le drapeau.
        lda   #1
        sta   terrainCollision.disabled

        jsr   stage.setup                  ; cartes, largeur, wave, collision : le stage

        ; Le champ d'etoiles remet ses offsets a zero. La v1 l'initialise ici,
        ; avant la trame d'amorce et InitScroll.
        lda   #map.RAM_OVER_CART+overlay.page
        ldx   #starfield.init
        jsr   paged.call

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

        ; Le pre-scroll d'ouverture, juste apres InitScroll comme en v1 : il
        ; repeint le viewport ENTIER dans les deux tampons, en rejouant le
        ; defilement. C'est lui qui pose le ciel en nibble $F, sans quoi le
        ; champ d'etoiles n'a rien ou dessiner. Position d'entree : le debut.
        lda   #0
        jsr   stage.preScroll

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

        ; L'OST DU JOUEUR, en page directe. Il faut le nettoyer AVANT de lancer
        ; l'objet : son premier champ lu est `routine`, qui indexe une table de
        ; sauts de cinq entrees — laisse-le sale et le tout premier appel saute
        ; n'importe ou (vecu : PC en $9F2B, soit dans l'OST lui-meme). La v1 fait
        ; les deux memes gestes dans checkpoint.load.
        jsr   ObjectDp_Clear
        lda   #ObjID_Player1
        sta   player1+id

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
; La boucle est un AIGUILLAGE A ETATS, comme la v1 (LevelMainLoop) : RUNNING
; joue, DEAD deroule la mort (le joueur y bascule a la fin de son explosion),
; CHECKPOINT recharge puis repart. La variable vit ici, dans le stage — le
; joueur l'ecrit a travers le lien.
;
; Deux pieges, tous deux vecus (PC parti en VRAM, page directe ecrasee) :
;   - les constantes d'etat sont DEJA des decalages en mots (0, 2, 4), comme en
;     v1 : pas d'asla. Le doubler envoie DEAD sur l'entree CHECKPOINT et
;     CHECKPOINT deux mots apres la table ;
;   - la variable et la table sont APRES le jmp, jamais avant. Le code d'init
;     tombe dans stage.loop par passage, et un octet de donnee sur ce chemin
;     est execute — la v1 y echappait parce qu'elle SAUTE a LevelMainLoop.
;
; Cas de migration : docs/lang/en/migration/loop-fallthrough.md
stage.loop
        lda   mainloop.state
        ldx   #stage.states
        jmp   [a,x]
stage.states
        fdb   stage.state.running
        fdb   stage.state.dead
        fdb   stage.state.checkpoint
mainloop.state fcb 0

stage.state.running
        ; La manette, en tete de tour comme la v1 (ReadJoypadsKbd) :
        ; joypad.readKbd alimente held/pressed (le tir) et fait de n'importe
        ; quelle touche du clavier le bouton B — c'est exactement ce que la v1
        ; appelle ici. addDirection, LUI, est dans l'IRQ — voir stage.userIRQ.
        jsr   joypad.readKbd
        jsr   Scroll
        jsr   ObjectWave
        ; La passe de collision, ici et pas ailleurs : elle marque les
        ; potentiels (AABB.p) AVANT que les objets ne tournent, chacun lisant
        ; le sien pour savoir s'il vient d'etre touche. La v1 l'appelle au meme
        ; endroit, par son objet mainext.
        jsr   Collision_Run
        ; Le fondu, avant les objets du pool : c'est un objet hors pool, avec
        ; son OST a lui, donc RunObjects ne le voit pas.
        _Obj_RunU ObjID_fade,#palettefade
        ; Le joueur, avant les objets du pool comme en v1 : son OST est en page
        ; directe, donc lui aussi echappe a RunObjects.
        _Obj_RunU ObjID_Player1,#player1
        jsr   RunObjects
        jsr   CheckSpritesRefresh
        _gfxlock.on
        jsr   EraseSprites
        jsr   UnsetDisplayPriority
        jsr   DrawTiles

        ; Les etoiles s'effacent ICI, entre les tuiles et les sprites : le fond
        ; vient d'etre restaure. Et elles se tracent APRES DrawSprites, pour que
        ; les fonds sauvegardes n'en contiennent jamais — sinon un sprite
        ; immobile puis remis en mouvement reinjecte des etoiles perimees.
        lda   #map.RAM_OVER_CART+overlay.page
        ldx   #starfield.erase
        jsr   paged.call

        jsr   DrawSprites

        lda   #map.RAM_OVER_CART+overlay.page
        ldx   #starfield.draw
        jsr   paged.call

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

        ; Le HUD par-dessus le masque, dans l'ordre de la v1 (main.asm:255-256) :
        ; le masque couvre les bandes ou le scroll laisse ses artefacts, le HUD
        ; peint dedans. Il a sa page a lui — 5 184 octets ne tenaient pas dans
        ; la fin de celle des overlays — donc une montee de plus par trame.
        lda   #map.RAM_OVER_CART+hud.page
        ldx   #hud.normal
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
        ; Une direction par TRAME 50 Hz, pas par tour de boucle : c'est la
        ; compensation de frame-drop du deplacement joueur. ApplyJoypadInput
        ; consomme tout l'arriere et applique UN PAS PAR ENTREE — pousse
        ; depuis la boucle, le vaisseau va frame-drop fois trop lentement
        ; (vecu). La v1 l'appelle exactement ici, dans UserIRQ.
        jsr   joypad.buffer.addDirection
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
; La mort — la routine dead de la v1, sans les morceaux non portes
;
; L'ecran se fige (ni Scroll ni DrawTiles : le decor s'arrete), seuls le fondu,
; le joueur (son explosion) et le REDESSIN des objets geles tournent — la v1
; appelle RunFrozenObjects, qui repeint sans derouler la logique. Puis 83
; trames de pause et l'etat passe a CHECKPOINT.
; V2-DEVIATION vs v1 : pas de hud dynamique (non porte) ; le masque, lui, est
; notre overlay paged.call.
;*******************************************************************************
stage.state.dead
        _Obj_RunU ObjID_fade,#palettefade
        _Obj_RunU ObjID_Player1,#player1
        jsr   RunFrozenObjects
        jsr   CheckSpritesRefresh
        _gfxlock.on
        jsr   EraseSprites
        jsr   UnsetDisplayPriority
        jsr   DrawSprites
        ldd   #$A000
        std   <glb_screen_location_1
        ldu   #$C000
        lda   #map.RAM_OVER_CART+overlay.page
        ldx   #adr_playfield_mask_ND0
        jsr   paged.call
        _gfxlock.off
        _gfxlock.loop
        _waitFrames #83
        lda   #mainloop.state.CHECKPOINT
        sta   mainloop.state
        lbra  stage.loop

;*******************************************************************************
; Le rechargement — la routine checkpoint de la v1, reduite a ce qui est porte
;
; V2-DEVIATION vs v1 : pas de messages READY / GAME OVER (l'objet messages
; n'est pas porte, la transition reste noire) ; pas de re-seed forcepod /
; bitdevice / shellEraseTable / endstage (non portes) ; et le GAME OVER ne
; renvoie pas a l'ecran-titre (pas porte non plus) — il ressert trois vies et
; recharge le checkpoint, marquage en attendant le titre.
;*******************************************************************************
stage.state.checkpoint
        jsr   stage.paletteFadeOut
@loop   ; attendre la fin du fondu au noir
        _Obj_RunU ObjID_fade,#palettefade
        _gfxlock.on
        _gfxlock.off
        _gfxlock.loop
        ldu   #palettefade
        lda   routine,u
        cmpa  #o_fade_routine_idle
        bne   @loop

        _waitFrames #40

        dec   globals.lives
        bpl   >
        ; GAME OVER — V2-DEVIATION : on ressert deux vies et on repart, faute
        ; d'ecran-titre ou revenir.
        ldb   #2
        stb   globals.lives
!
        ldd   #bench.SCROLL_VEL
        std   scroll_vel
        lda   #mainloop.state.RUNNING
        sta   mainloop.state
        jsr   stage.checkpointLoad
        ; Le clignotement / l'invincibilite de la reapparition. Il faut le
        ; reposer APRES le chargement : ObjectDp_Clear vient d'effacer la page
        ; directe, donc le subtype que le joueur s'etait pose en mourant. La v1
        ; fait le meme geste au meme endroit.
        lda   #1
        sta   player1+subtype
        lbra  stage.loop

;*******************************************************************************
; Le chargement de checkpoint — porte de checkpoint.load (v1 global/checkpoint)
;
; Trouve le dernier point de reprise <= la position atteinte, nettoie tout ce
; qui vit (objets, sprites, listes de collision, les deux tampons), rejoue le
; pre-scroll a cette position, ressort le joueur, arme le fondu d'entree et
; RECALE LA VAGUE : l'horloge de niveau redevient position x 128 — 128 trames
; par tuile de 24 px, l'inverse exact de la vitesse de scroll (24 / 0,1875).
;*******************************************************************************
stage.checkpointLoad
        clrb
        ldx   #checkpoint.positions
@loop   lda   b,x
        cmpa  scroll_tile_pos
        bhi   >
        incb
        bra   @loop
!       decb
        lda   b,x
        sta   stage.ckpt.pos
        sta   stage.ckpt.pos2

        jsr   ObjectDp_Clear
        jsr   ManagedObjects_ClearAll
        jsr   InitStack
        jsr   DisplaySprite_ClearAll
        jsr   EraseSprites_ClearAll
        jsr   Collision_ClearLists

        ; les deux tampons au noir, comme a l'ouverture du stage
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

        lda   #0
stage.ckpt.pos equ *-1
        jsr   stage.preScroll

        lda   #ObjID_Player1
        sta   player1+id

        jsr   stage.paletteFadeIn

        ; la vague sur l'horloge de la position retrouvee
        lda   #128
        ldb   #0
stage.ckpt.pos2 equ *-1
        mul
        std   gfxlock.frame.count
        std   gfxlock.frame.lastCount
        std   gfxlock.frame.gameCount
        jmp   ObjectWave_Init

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

stage.paletteFadeOut
        ldu   #palettefade
        ldx   #Pal_black
        lda   #1
        bra   stage.paletteFadeCommon

;*******************************************************************************
; Le PRE-SCROLL d'ouverture — porte de checkpoint.scroll (v1, global/checkpoint)
;
; Sans lui le viewport n'est jamais peint EN ENTIER : le premier DrawTiles ne
; trace que les colonnes de la position courante, et la rangee verticale de
; fond — celle qui porte le ciel en nibble $F — n'atteint pas l'ecran. Le champ
; d'etoiles, dont tout le test tient sur « ce pixel vaut-il $F », ne dessine
; alors rien du tout.
;
; Le principe est de REJOUER le defilement : on part d'un viewport large de zero
; colonne, cale a droite, et on avance de 4 px vers la gauche en elargissant
; d'une colonne tous les trois pas — dans LES DEUX tampons. Chaque colonne est
; donc peinte a chacune de ses sous-positions, exactement comme si elle etait
; entree par la droite.
;
; La v1 s'en sert aussi aux checkpoints, avec une position d'entree ; ici elle
; vaut toujours zero, mais le parametre est conserve pour le jour ou les
; checkpoints seront portes.
;
; Cas de migration : docs/lang/en/migration/init-prescroll.md
;
; A = position d'entree, en tuiles de collision (24 px)
;*******************************************************************************
stage.preScroll
        sta   scroll_tile_pos              ; les tuiles de collision font 24 px
        asla                               ; les tuiles tracees en font 12
        sta   @a
        ldb   scroll_vp_v_tiles
        aslb
        addb  scroll_vp_v_tiles            ; position x hauteur x 3 o (page, adresse)
        mul
        std   scroll_map_pos
        lda   #0
@a      equ   *-1
        ldb   scroll_tile_width
        mul
        std   glb_camera_x_pos
        std   glb_camera_x_pos_old
        subd  #1
        std   buffer_x_pos
        std   buffer_x_pos+2

        lda   scroll_vp_h_tiles            ; on emprunte les deux parametres de
        ldb   scroll_vp_x_pos              ; viewport, rendus a la fin
        std   @d
        lda   #0
        sta   scroll_vp_h_tiles
        sta   scroll_tile_pos_offset
        sta   scroll_tile_pos_offset24
        lda   #8+144-4                     ; cale a droite du viewport
        sta   scroll_vp_x_pos
        lda   scroll_map_page_even
        sta   tile_buffer_page
        ldx   scroll_map_even
        stx   tile_buffer
@loop1
        lda   #3
        sta   @cpt
        inc   scroll_vp_h_tiles
@loop2
        lda   #1
        sta   glb_camera_move
        jsr   DrawTiles
        _SwitchScreenBuffer
        jsr   DrawTiles
        _SwitchScreenBuffer
        lda   scroll_vp_x_pos
        suba  #4
        sta   scroll_vp_x_pos
        dec   @cpt
        bne   @loop2
        cmpa  #4
        bne   @loop1
        ldd   #0
@d      equ   *-2
        sta   scroll_vp_h_tiles
        stb   scroll_vp_x_pos
        rts
@cpt    fcb   0
