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

; Le moteur résident y saute par le LIEN (`jmp stage.main` dans
; game.stage.switch) : nom commun aux deux stages, le re-link de chaque
; scene.load le repointe sur le stage fraîchement chargé.
stage.main EXPORT
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
        ; La base du score DU STAGE : le decompte de fin affiche
        ; globals.score moins cette base. La v1 la seme ici meme
        ; (main.asm:124) ; sans elle le decompte partirait de ce que la RAM
        ; reservee contenait.
        std   globals.stageScoreBase
        stb   globals.stageScoreBase+2

        ; LES OST STATIQUES, mis a zero. La v1 n'a pas ce geste a faire : chez
        ; elle `palettefade` et ses voisins sont de la DONNEE du binaire du game
        ; mode (`fcb ObjID_fade / fill 0,object_size-1`), donc ils arrivent du
        ; disque a zero, identifiant pose. En v2 ils vivent dans un bloc
        ; `<reserved>` que rien ne charge : leur contenu au demarrage est ce que
        ; la RAM avait. Ca passait inapercu tant que la zone tombait sous la
        ; pile systeme, donc a zero ; en la deplacant on est tombe sur du $FF, et
        ; `o_fade_unload` a $FF fait appeler UnloadObject_u sur un OST HORS pool
        ; — palette en vrac et pool corrompu (vecu).
        ; Efface par MOTS : `std ,x++` (5+3) et `cmpx` (4) coutent les memes 15
        ; cycles que `clr ,x+` (6+2) et `subd` (4), mais pour deux octets — 3 510
        ; cycles au lieu de 7 020, a taille de code egale (13 octets).
        ;
        ; object_size est IMPAIR (117) : le bloc n'est de taille paire que si
        ; nb_static_objects l'est. On borne donc la boucle au dernier mot entier
        ; et on rattrape l'octet restant a l'assemblage — sans quoi le `cmpx`
        ; serait enjambe et la boucle partirait dans les globales.
statics.SIZE  equ nb_static_objects*object_size
        ldx   #palettefade
        ldd   #0
!       std   ,x++
        cmpx  #palettefade+(statics.SIZE/2)*2
        bne   <
 ifne statics.SIZE-(statics.SIZE/2)*2
        clr   ,x
 endc
        lda   #ObjID_fade
        sta   palettefade+id

        ; Les identifiants des trois autres slots statiques, et leur routine de
        ; veille. La v1 seme les identifiants dans le BINAIRE de son game mode
        ; (ram_data.asm : `fcb ObjID_forcepod` suivi d'un fill), puis pose les
        ; routines Dormant a la fin de son init (main.asm:174-182) — deux
        ; endroits pour un seul geste, parce que son bloc arrive du disque.
        ; Ici la zone est `<reserved>`, donc rien ne la charge : les deux se
        ; font ensemble, juste apres l'effacement.
        ;
        ; Sans la routine de veille, un slot mis a zero part en routine 0 —
        ; l'Init de l'objet — et le force pod comme les bit devices naitraient
        ; tout seuls a l'ouverture du stage, sans avoir ete ramasses.
        lda   #ObjID_forcepod
        sta   forcepodOST+id
        lda   #rtnid.Dormant
        sta   forcepodOST+routine
        lda   #ObjID_bitdevice
        sta   bitdevTopOST+id
        sta   bitdevBotOST+id
        lda   #bitdev.rtnid.Dormant
        sta   bitdevTopOST+routine
        sta   bitdevBotOST+routine

        ; LE POINTEUR DE LA TRAINEE DU JOUEUR. La v1 l'initialise depuis le
        ; binaire de son game mode (`fdb player_pos_ring_buffer`) ; ici la
        ; trainee vit dans le bloc reserve `globals`, que rien ne charge — donc
        ; c'est a l'init de le semer. Sans lui, le force pod suit une adresse
        ; batie sur ce que la RAM contenait.
        ; Cf. docs/lang/en/migration/reserved-ram-is-not-zeroed.md
        ldd   #player_pos_ring_buffer
        std   player_pos_ring_buffer_ptr

        ; Le stage OUVRE SUR LE NOIR, comme la v1 : la palette du jeu n'arrive
        ; que par le fondu arme plus bas, une fois le premier ecran peint. Sans
        ; ca le niveau apparait d'un coup, et l'ecran de chargement se voit.
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow

        ; Les deux tampons ne sont PAS effacés ici : c'est `checkpoint.load`,
        ; appelé en fin d'init comme en v1, qui les met au noir — et il le fait
        ; en nibble $F, le ciel vierge du champ d'étoiles.

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

        ; LE CHAMP D'ETOILES est arme par la WAVE, comme dans l'arcade :
        ; ObjID_starfield -> stage.starfieldSpawner -> starfield.init, le
        ; variant dans l'entree de wave. L'entree de stage, elle, le REMET A
        ; MORT : son etat vit en page overlay chargee au boot et survit aux
        ; echanges — sans ce geste, revenir au stage 1 herite de la vie d'un
        ; passage precedent. Tous les stages le font, meme sans etoiles :
        ; c'est precisement eux qui ont un etat etranger a neutraliser.
        lda   #map.RAM_OVER_CART+common.starfield.page
        ldx   #starfield.kill
        jsr   paged.call

        ; PURGER le pool AVANT la trame d'amorce. La v1 n'avait pas ce geste :
        ; sa RAM objets faisait partie du binaire du game mode, rechargee a
        ; zero a chaque entree. Le pool v2 est RESIDENT — un echange de stage
        ; arrive avec les objets VIVANTS du stage sortant, et la trame d'amorce
        ; les ferait tourner contre les tables du NOUVEAU stage : identites
        ; croisees, et un id au-dela de la table courte lit n'importe quoi
        ; (vecu a l'echange 4->5 : la liste de priorite du dessin devenait
        ; circulaire, DrawSprites ne rendait plus la main — le title, lui,
        ; purgeait deja avant sa trame d'amorce).
        jsr   InitStack
        jsr   ManagedObjects_ClearAll
        jsr   InitDrawSprites

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

        ; moveByScript garde la page et l'adresse de la table de scripts dans
        ; des operandes auto-modifiees — il y en a DEUX pour la page, une par
        ; routine qui monte. Le moteur a la routine qui les pose toutes : elle
        ; les lit dans l'index d'objets, a l'identifiant de l'objet animation.
        ldb   #objid.animation
        jsr   moveByScript.register

        jsr   InitRNG

        ; LE CHECKPOINT, dernier geste de l'init — la v1 fait exactement le meme
        ; (`_Obj_Run ObjID_checkpoint`, main.asm:145), et c'est LUI qui rend
        ; l'ecran d'ouverture : il efface les deux tampons en nibble $F, rejoue
        ; le defilement jusqu'a la position de reprise (zero a l'ouverture,
        ; puisque `scroll_tile_pos` y vaut zero), ressort le joueur, arme le
        ; fondu d'entree et cale la vague sur l'horloge.
        ;
        ; Ne rien remettre ici de ce qu'il fait deja : notre portage avait
        ; duplique son effacement, son `player1+id`, son `ObjectDp_Clear`, son
        ; fondu et son `ObjectWave_Init` — et les deux copies avaient divergé.
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.load
        jsr   paged.call

        ; LA MUSIQUE. Armee avant IrqInit, comme la v1 (main.asm:151) : le
        ; lecteur coupe les interruptions le temps de s'initialiser, et il vaut
        ; mieux que ce soit avant qu'elles ne servent. Le morceau est celui du
        ; stage — la v1 passait un index dans une table, la v2 nomme le symbole.
        ; `_ymm.obj.play` MONTE la page du lecteur et ne la rend pas : le macro
        ; est ecrit pour un appelant qui possede deja la fenetre. Sous IRQ cela
        ; passe — IrqManager encadre la routine utilisateur d'un
        ; _GetCartPageB/_SetCartPageA — mais ici on est dans l'init du stage, et
        ; tout ce qui suit heriterait de la page du lecteur.
        _GetCartPageB
        pshs  b
        _ymm.obj.play #map.RAM_OVER_CART+engine.sound.ymm.page,#stage.music,#ymm.LOOP,#ymm.NO_CALLBACK
        puls  b
        _SetCartPageB

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

        ; LA SEQUENCE D'OUVERTURE. Un slot du pool, un identifiant, et
        ; RunObjects la deroule ensuite seule jusqu'a ce qu'elle se supprime.
        ; APRES IrqOn, comme la v1 (main.asm:171) : l'objet compte des trames,
        ; et l'ensemencer avant la trame d'amorce lui ferait consommer d'un coup
        ; le frame-drop du chargement de scene.
        ; C'est le stage qui la nomme : chaque niveau a la sienne, ou n'en a pas.
        jsr   stage.openingSequence
        

;*******************************************************************************
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
;*******************************************************************************
stage.loop
        ; la fenetre de commande de la lane (bench.request, cf. bench.const) :
        ; non nul = mort du joueur, le geste exact de la fin d'explosion. Sept
        ; cycles par tour, la controlabilite du chemin de mort en echange.
        lda   bench.request
        beq   >
        clr   bench.request
        lda   #mainloop.state.DEAD
        sta   mainloop.state
!
        lda   mainloop.state
        ldx   #stage.states
        jmp   [a,x]
stage.states
        fdb   stage.state.running
        fdb   stage.state.dead
        fdb   stage.state.checkpoint
mainloop.state EXPORT
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
        lda   #map.RAM_OVER_CART+common.collisionpass.page
        ldx   #Collision_Run
        jsr   paged.call
        ; Le fondu, avant les objets du pool : c'est un objet hors pool, avec
        ; son OST a lui, donc RunObjects ne le voit pas.
        _Obj_RunU ObjID_fade,#palettefade
        ; Le joueur, avant les objets du pool comme en v1 : son OST est en page
        ; directe, donc lui aussi echappe a RunObjects.
        _Obj_RunU ObjID_Player1,#player1
        ; Les trois slots statiques d'armement, juste apres le joueur comme en
        ; v1 (main.asm:225-227). Ils dorment (routine Dormant) tant qu'une
        ; boite a option ne les a pas reveilles, et RunObjects ne les voit pas :
        ; leur OST est hors pool.
        _Obj_RunU ObjID_forcepod,#forcepodOST
        _Obj_RunU ObjID_bitdevice,#bitdevTopOST
        _Obj_RunU ObjID_bitdevice,#bitdevBotOST
        jsr   RunObjects
        jsr   CheckSpritesRefresh
        jsr   gfxlock.on
        jsr   EraseSprites

        ; Ce que CE stage peint dans le verrou graphique, juste apres
        ; l'effacement des sprites et avant les tuiles : sur le niveau 1, les
        ; bandes noires du boss et le rectangle de la salle. La v1 l'appelle
        ; exactement ici (main.asm:236), pour que le noir recouvre le fond
        ; restaure et que les sauvegardes de fond capturent le resultat noirci.
        jsr   stage.frameBlit

        jsr   UnsetDisplayPriority
        jsr   DrawTiles

        ; Les etoiles s'effacent ICI, entre les tuiles et les sprites : le fond
        ; vient d'etre restaure. Et elles se tracent APRES DrawSprites, pour que
        ; les fonds sauvegardes n'en contiennent jamais — sinon un sprite
        ; immobile puis remis en mouvement reinjecte des etoiles perimees.
        ;
        ; Garde a l'assemblage : stages 1 et 4 (le boss Compiler a son champ,
        ; variant 1). Le stage 8 a son entree de wave commentee ; l'activer =
        ; elargir les DEUX gardes erase/draw + celle du spawner (le produit
        ; est nul si STAGE_ID vaut l'un des stages a etoiles), et decommenter
        ; sa wave.
 IFEQ (STAGE_ID-1)*(STAGE_ID-4)
        lda   #map.RAM_OVER_CART+common.starfield.page
        ldx   #starfield.erase
        jsr   paged.call
 ENDC

        ; L'effaceur de la rotonde, ICI comme en v1 (main.asm:243) : entre les
        ; etoiles et DrawSprites, le fond venant d'etre restaure. C'est un
        ; objet hors pool — pas d'OST, RunObjects ne le voit pas — qui relit la
        ; table que les shells remplissent. Les stages sans rotonde n'en
        ; souffrent pas : la table y est vide, la boucle ne blitte rien.
        _Obj_Run ObjID_shellEraser

        jsr   DrawSprites

 IFEQ (STAGE_ID-1)*(STAGE_ID-4)
        lda   #map.RAM_OVER_CART+common.starfield.page
        ldx   #starfield.draw
        jsr   paged.call
 ENDC

        ; Les surimpressions, selon la phase de fin de niveau que CE stage
        ; publie (0 hors sequence). La v1 fait le meme aiguillage dans son main
        ; (main.asm:248) : phases 0-2 le masque et le HUD normal ; phase 3, le
        ; fondu pixel possede l'ecran entier, bandeau compris, et on ne peint
        ; rien ; phase 4, le releve de score centre, seul.
        lda   stage.overlayPhase
        cmpa  #3
        blo   stage.overlay.normal
        cmpa  #4
        beq   stage.overlay.readout
        bra   stage.overlay.off

stage.overlay.normal
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
        lda   #map.RAM_OVER_CART+common.overlay.page
        ldx   #adr_playfield_mask_ND0
        jsr   paged.call

        ; Le HUD par-dessus le masque, dans l'ordre de la v1 (main.asm:255-256) :
        ; le masque couvre les bandes ou le scroll laisse ses artefacts, le HUD
        ; peint dedans. Il a sa page a lui — 5 184 octets ne tenaient pas dans
        ; la fin de celle des overlays — donc une montee de plus par trame.
        lda   #map.RAM_OVER_CART+common.hud.page
        ldx   #hud.normal
        jsr   paged.call
        bra   stage.overlay.off

stage.overlay.readout
        lda   #map.RAM_OVER_CART+common.hud.page
        ldx   #hud.readout
        jsr   paged.call

stage.overlay.off
        jsr   gfxlock.off

        inc   bench.frames
        ldd   glb_camera_x_pos
        std   bench.camera

        ; Comment CE stage se termine. Un stage sans sequence de fin compare la
        ; camera au bout de la carte ; le niveau 1, lui, a un boss, et c'est sa
        ; sequence de fin qui decide — elle cale d'ailleurs scroll_max sur la
        ; salle du boss pendant le combat, ce qui ferait mordre le test de
        ; camera en plein milieu. Le geste appartient donc au stage.
        jsr   stage.endTick

        jsr   gfxlock.loop
        lbra  stage.loop

stage.userIRQ
        jsr   gfxlock.bufferSwap.check
        ; Une direction par TRAME 50 Hz, pas par tour de boucle : c'est la
        ; compensation de frame-drop du deplacement joueur. ApplyJoypadInput
        ; consomme tout l'arriere et applique UN PAS PAR ENTREE — pousse
        ; depuis la boucle, le vaisseau va frame-drop fois trop lentement
        ; (vecu). La v1 l'appelle exactement ici, dans UserIRQ.
        jsr   PalUpdateNow
        jsr   joypad.buffer.addDirection

        ; Le son, dans l'IRQ comme la v1 (main.asm:406-410) : une trame de
        ; musique, puis le pilote de bruitages qui depile la boite aux lettres.
        ; La ligne SN76489 de la v1 est commentee chez elle aussi — voir la
        ; region vgc.* du layout.
        _ymm.frame.play #map.RAM_OVER_CART+engine.sound.ymm.page
        ;_vgc.frame.play #map.RAM_OVER_CART+vgc.player.page
        lda   #map.RAM_OVER_CART+common.soundfx.page
        ldx   #soundfx.frame
        jmp   paged.call

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

; L'objet ephemere de la wave pour le champ d'etoiles : il nait comme un
; ennemi (slot du pool, identifiant, subtype), transmet le variant au module
; pagine et rend son slot dans la meme trame. C'est la transposition du
; starfield_spawner de l'arcade (0x40:E430) — a ceci pres que l'arcade garde
; son orchestrateur vivant (il fait naitre les etoiles une a une), quand le
; notre passe la main a un champ permanent : l'objet n'a donc plus rien a
; faire une fois la duree armee.
 IFEQ (STAGE_ID-1)*(STAGE_ID-4)
stage.starfieldSpawner
        ldb   subtype_w+1,u            ; le variant, seme par l'octet 5 de la wave
        clra
        tfr   d,y                      ; via Y : paged.call detruit B, preserve Y
        lda   #map.RAM_OVER_CART+common.starfield.page
        ldx   #starfield.init
        jsr   paged.call
        jsr   UnloadObject_u           ; one-shot : le slot est rendu
        rts
 ENDC

; Le bouchon des invocations À CRU : pour les identifiants que le moteur ou la
; boucle appellent SANS OST (le shellEraser tourne chaque trame entre DrawTiles
; et DrawSprites, sans slot du pool). Le bouchon standard s'auto-supprime par
; UnloadObject_u — legitime pour un objet que la wave a alloue, fatal ici : U ne
; porte aucun OST, chaque passage rendait un slot fantome et la pile de slots
; debordait sous elle ($6628 vers le bas), labourant object_list_first/last puis
; le code residant — la machine mourait ~50 trames apres l'entree du stage 2.
; Regle : dans l'index d'un stage, un identifiant invoque sans OST pointe ICI.
stage.placeholder.raw
        rts

;*******************************************************************************
; La mort et le rechargement de checkpoint
;
; Ce bloc a ete essaye en unite montee — 467 octets qui ne tournent qu'a la mort
; du joueur, c'etait tentant. Il est RESTE RESIDENT, et la raison merite d'etre
; ecrite : il appelle RunFrozenObjects, CheckSpritesRefresh, EraseSprites,
; DrawSprites et Obj_Run, qui montent tous la page de l'objet ou du sprite
; qu'ils servent SANS rendre celle de l'appelant. Le fichier de macros d'objet
; le dit d'ailleurs en toutes lettres : « a n'utiliser que depuis la page
; residente ». Depuis une page montee, le premier de ces appels fait perdre au
; bloc sa propre page et le CPU continue dans une autre — ecran fige au premier
; crash du joueur (vecu). Un sas par appel serait fragile et couterait plus que
; les octets gagnes.
;*******************************************************************************
stage.state.dead
        _Obj_RunU ObjID_fade,#palettefade
        _Obj_RunU ObjID_Player1,#player1
        jsr   RunFrozenObjects
        jsr   CheckSpritesRefresh
        jsr   gfxlock.on
        jsr   EraseSprites
        jsr   UnsetDisplayPriority
        jsr   DrawSprites
        ldd   #$A000
        std   <glb_screen_location_1
        ldu   #$C000
        lda   #map.RAM_OVER_CART+common.overlay.page
        ldx   #adr_playfield_mask_ND0
        jsr   paged.call
        jsr   gfxlock.off
        jsr   gfxlock.loop
        _waitFrames #83
        lda   #mainloop.state.CHECKPOINT
        sta   mainloop.state
        lbra  stage.loop

;*******************************************************************************
; Le rechargement — la routine checkpoint de la v1, reduite a ce qui est porte
;
; L'ordre est celui de la v1 (main.asm:340-378) : on decompte la vie, on AFFICHE
; le message, on attend, on noircit, et seulement ensuite on decide entre reprise
; et game over. Les separer est ce qui rendait la mort invisible, donc indebogable.
;
; V2-DEVIATION vs v1, ce qui manque encore et pourquoi : pas de re-seed forcepod
; / bitdevice / shellEraseTable / endstage — ces objets ne sont pas portes ; et
; le GAME OVER ne revient pas a l'ecran-titre, qui ne l'est pas non plus. Il
; recharge la scene du stage 1 avec `game.stage` remis a zero, ce qui equivaut a
; une premiere entree — voir stage.gameOver.
;*******************************************************************************
stage.state.checkpoint
        jsr   stage.paletteFadeOut
@loop   ; attendre la fin du fondu au noir
        _Obj_RunU ObjID_fade,#palettefade
        jsr   gfxlock.on
        jsr   gfxlock.off
        jsr   gfxlock.loop
        ldu   #palettefade
        lda   routine,u
        cmpa  #o_fade_routine_idle
        bne   @loop

        _waitFrames #40

        ; L'ECRAN EST EFFACE avant le message, comme la v1 (main.asm:319-320 :
        ; `ldx #$0000 / jsr ClearDataMem`). Sans ca le decor du stage reste
        ; visible derriere READY — la v1 ne l'eteint pas par la palette, elle
        ; efface les 16 Ko de la fenetre donnees.
        ldu   #$0000
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.clearData
        jsr   paged.call

        ; READY / GAME OVER — la sequence de la v1 (main.asm:340-378), remise
        ; dans son ordre : on decompte la vie, on AFFICHE le message, on attend,
        ; on noircit, et seulement ensuite on decide entre reprise et game over.
        ; L'objet messages n'a ni OST ni routine : _Obj_Mount monte sa page et
        ; rend son adresse dans X, l'index du message va dans B.
        _Obj_Mount ObjID_messages
        dec   globals.lives
        bmi   >
        ldb   #messages.READY
        jsr   ,x
        bra   @displaymessage
!       ldb   #messages.GAME           ; deux mots a poser, GAME puis OVER
        jsr   ,x
        ldb   #messages.OVER
        jsr   ,x
@displaymessage
        clra                           ; le message est en 320x200x16c
        sta   map.CF74021.LGAMOD
        ldd   #Pal_messages
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow             ; le message devient visible
        tst   globals.lives
        bmi   @waitGameOver            ; vies < 0 : GAME OVER, trois secondes
        _waitFrames #50                ; READY : une seconde
        bra   @msgBlackout
@waitGameOver
        _waitFrames #150
@msgBlackout
        ldd   #Pal_black
        std   Pal_current
        clr   PalRefresh
        jsr   PalUpdateNow             ; on noircit le message
        lda   #$7B                     ; retour en 160x200x16c
        sta   map.CF74021.LGAMOD

        ldd   #bench.SCROLL_VEL
        std   scroll_vel
        lda   #mainloop.state.RUNNING
        sta   mainloop.state
        tst   globals.lives
        bpl   >
        jmp   stage.gameOver
!
        ; IRQ COUPEE le temps du rechargement, comme la v1 — qui rechargeait
        ; tout le game mode et ne rearmait l'IRQ qu'a la fin de son init. Le
        ; rejeu de la vague (ObjectWave_Init) marche PLUS D'UNE TRAME dans la
        ; fenetre cartouche ; or apres le premier DrawTiles, glb_Page reste a
        ; zero (mode special) et l'IRQ ne restaure PAS cette fenetre : une
        ; interruption au milieu du rejeu laisse la page du son montee, la
        ; marche continue sur une page etrangere et le contenu de celle-ci
        ; decide de la suite — vecu : la vague est sortie de la fenetre, a
        ; seme des objets dans les temoins du banc et la machine est partie
        ; dans le decor. Une roulette de phase d'IRQ : la partition des
        ; repertoires n'a fait que deplacer le tirage perdant.
        jsr   IrqOff
        lda   #map.RAM_OVER_CART+common.checkpoint.page
        ldx   #checkpoint.load
        jsr   paged.call
        ; Le clignotement / l'invincibilite de la reapparition. Il faut le
        ; reposer APRES le chargement : ObjectDp_Clear vient d'effacer la page
        ; directe, donc le subtype que le joueur s'etait pose en mourant. La v1
        ; fait le meme geste au meme endroit.
        lda   #1
        sta   player1+subtype
        ; La musique repart, comme la v1 (main.asm:383) et au meme endroit :
        ; apres le chargement du checkpoint, avant de rendre la main a la
        ; boucle. Elle reprend a son point de bouclage, pas au debut.
        lda   #map.RAM_OVER_CART+engine.sound.ymm.page
        ldx   #ymm.restart
        jsr   paged.call
        jsr   IrqOn
        lbra  stage.loop

;*******************************************************************************
; GAME OVER — porte de la v1 (main.asm:374-377)
;
;   tst   globals.lives
;   bpl   >
;   jsr   IrqOff
;   jmp   Level01_Start           ; GAME OVER: restart level 1
;
; La v1 revient a l'ecran-titre au bout des vies — et le title est porte
; (chantier 1) : le geste v1 est restaure. L'ancienne V2-DEVIATION (recharger
; le stage 1 faute de title) tombe avec le chantier 2.
;
; `game.stage` remis a zero par acquit : c'est le press start du title
; (title.launchGame) qui le fait foi pour la partie suivante.
;*******************************************************************************
stage.gameOver
        jsr   IrqOff
        clr   game.stage
        ; Le corps est partagé : il ne sait pas dans quel stage il tourne, mais
        ; chaque stage a nommé sa scène. Décharger la sienne avant de charger
        ; celle du title — l'index rendu puis repris est la séquence honnête.
        ldx   #STAGE_SCENE
        jsr   game.stage.unload
        ldx   #scenes.title
        ldy   #scenes.title.dir
        ldu   #cast.title                  ; les lots d'ennemis de la cible
        jmp   game.stage.switch

;*******************************************************************************
; Le checkpoint et le pré-scroll vivent dans l'UNITÉ MONTÉE `checkpoint`, comme
; l'objet checkpoint de la v1 qui porte les deux. 262 octets rendus au budget.
;*******************************************************************************

;*******************************************************************************
; L'ouverture en fondu — la forme de la v1 (Palette_FadeIn du game mode 01)
;
; L'objet ne recoit pas la palette de depart : il lit Pal_current, donc c'est
; a l'appelant d'avoir pose le noir avant. o_fade_wait est le nombre de trames
; entre deux paliers de couleur ; la v1 monte en 4 et descend en 1.
;*******************************************************************************
stage.paletteFadeIn EXPORT   ; l'unite checkpoint l'appelle apres rechargement
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

; Le rappel de fin du fondu. Il etait EXPORTe pour l'objet fadetotunnel, retire
; le 16/08/2026 avec la palette de tunnel ; il reste le point de sortie commun
; des fondus du stage.
stage.paletteFadeDone
        rts

stage.paletteFadeOut
        ldu   #palettefade
        ldx   #Pal_black
        lda   #1
        bra   stage.paletteFadeCommon

;*******************************************************************************
; Les trois enveloppes gfxlock — la forme de la v1 (main.asm:386-396)
;
; Le macro est expanse UNE fois, ici, et tous les sites appellent par `jsr`.
; C'est exactement ce que fait la v1, et c'est ce que notre portage avait perdu :
; nous appelions le macro a chaque site, soit 292 octets d'expansions dans une
; region qui n'en a plus. Trois enveloppes et neuf `jsr` en rendent la moitie.
;*******************************************************************************
gfxlock.on
        _gfxlock.on
        rts

gfxlock.off
        _gfxlock.off
        rts

gfxlock.loop
        _gfxlock.loop
        rts
