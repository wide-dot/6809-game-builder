;*******************************************************************************
; The resident engine — loaded once, never swapped
;
; This is the "common" half of the stage boundary. It holds the mechanisms
; (frame loop, scroll, object manager, waves, collision) and the state that has
; to outlive a stage change (score, lives). It does NOT hold the main loop :
; policy belongs to the stage, which is what lets the boundary be drawn without
; guessing at hooks.
;
; Two directions cross the boundary here :
;   - out : api.asm, included with ENGINE_RESIDENT set, so every name in it is
;           EXPORTed. A stage includes the same file and gets EXTERNALs.
;   - in  : stage-tables.asm, the tables the engine reads back from whichever
;           stage is loaded. They are EXTERNAL references, and the loader's
;           global relink repoints them at every scene.load — that repointing
;           is the whole stage exchange mechanism.
;*******************************************************************************

ENGINE_RESIDENT equ 1

 SECTION code

        INCLUDE "src/common/engine/api.asm"
        INCLUDE "src/common/engine/stage-tables.asm"

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/log/log.const.asm"
        INCLUDE "engine/log/log.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

        INCLUDE "gen/layout.asm"
        INCLUDE "engine/sound/ymm.const.asm"

; The scroll reads these two when InitScroll works out its default camera cap.
; A stage overrides the cap by writing scroll_max afterwards, which is how a
; per stage map width escapes an engine assembled once (the boss already used
; that door in v1, to freeze the camera at bossStopX).
tile_size       equ 12
viewport_width  equ 12*tile_size
map_width       equ 24*tile_size

 opt c,ct

;*******************************************************************************
; State that outlives a stage
;
; It lives here rather than in a stage precisely because a stage is swapped :
; anything the stage unit held would be overwritten by the next one. No
; ceremony is needed beyond that — the engine's region is never a load
; destination after boot, so these bytes are simply never written again.
;*******************************************************************************
; game.lives N'EST PLUS ici : les vies sont `globals.lives`, dans le bloc
; reserve, comme en v1 — c'est la variable que le HUD dessine, et deux
; compteurs de vies dans deux endroits n'en font pas un.
game.score      fdb   0
game.stage      fcb   0
; les effets des cheats du title : ecrits par title.cheat.launch a CHAQUE
; depart (0 = pas de cheat), lus par player1 (invincible) et par le semis de
; premiere entree (vies). Un banc les force par write_memory — l'ancien
; define invincible est retire.
cheat.invincible fcb   0
cheat.extraLives fcb   0
; Les continues consommes de la partie en cours. Le quota est fixe a
; l'assemblage du HUD par le define `game.continue.MAX` (defaut 1, la regle
; arcade ; 0 = jamais, $FF = infini) — voir hud.asm. Le compteur vit ici, avec
; le stage et le score, pour la meme raison qu'eux — il doit survivre a
; l'echange de stage, et le bloc reserve `globals` est plein a l'octet pres.
game.continueUsed fcb 0

;*******************************************************************************
; game.music.play — armer un morceau DEPUIS DU CODE PAGINE
;
; `_ymm.obj.play` monte la page du lecteur. Une unite paginee qui l'appellerait
; se retirerait le sol sous les pieds : son propre code vit dans la fenetre
; qu'elle commuterait. Ce relais est RESIDENT, donc il peut commuter la fenetre
; et la rendre.
;
; C'est `paged.call` en sens inverse — mais paged.call ne sait pas passer de
; parametres : il se sert de X pour l'adresse d'entree et ecrase B. Le lecteur
; veut les deux. D'ou ce relais plutot qu'un appel generique.
;
; Reentrant : la page de l'appelant et le mode de boucle vivent sur la pile,
; pas dans un operande auto-modifie.
;
; L'IRQ EST RENDUE au retour : `ymm.obj.play` la coupe (`jsr irq.off`) et ne la
; rend jamais — c'est a son appelant de le faire, et les deux sites du corps de
; stage le font plus loin dans leur sequence. Un appelant qui l'ignore reste
; muet : c'est l'IRQ utilisateur qui appelle `_ymm.frame.play`, donc le morceau
; est arme et jamais joue. Vecu sur l'ecran continue.
;
; CE RELAIS NE MEMORISE RIEN. `ymm.restart` relance ce qui est ARME, donc un
; appelant qui arme un morceau de passage doit rendre sa place au precedent —
; et c'est le STAGE qui le fait, en re-armant `stage.music` : lui seul sait
; quel morceau est le sien. Voir la branche du continue accepte dans
; stage-main.asm.
;
; Entree : X = donnees du morceau, B = ymm.LOOP ou ymm.NO_LOOP
; Sortie : A, B, X, Y appartiennent au lecteur ; la page de l'appelant est
;          rendue, et l'IRQ tourne.
;*******************************************************************************
game.music.play EXPORT
game.music.play
        pshs  b                        ; 1,s apres le prochain push : le mode
        _GetCartPageB
        pshs  b                        ; 0,s : la page de l'appelant
        lda   #map.RAM_OVER_CART+engine.sound.ymm.page
        _SetCartPageA                  ; A reste la page des donnees : le lecteur la range
        ldb   1,s                      ; le mode demande
        ldy   #ymm.NO_CALLBACK
        jsr   ymm.obj.play
        puls  b
        _SetCartPageB                  ; sa page a l'appelant
        leas  1,s                      ; le mode, dont personne n'a plus besoin
        jmp   irq.on


; Le score du jeu, sur 24 bits par centaines de points comme en v1, et sa
; table de recompenses. AwardScore vit ici parce que le score survit aux
; stages, exactement comme les vies.
;
; globals.score n'est PAS une etiquette de cette unite : c'est une equate de la
; zone reservee `globals`, comme en v1. Elle valait une etiquette tant que le
; moteur etait seul a la lire ; des que la chaine de tir a eu besoin de
; globals.difficulty depuis SA page, il a fallu une adresse absolue partagee a
; l'assemblage plutot qu'un symbole de lien — c'est exactement ce que la zone
; reservee est. Voir docs/lang/en/migration/equates-link-boundary.md.
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/state/score.asm"

;*******************************************************************************
; Le son : la boite aux lettres, et le pont d'IRQ des lecteurs
;
; _soundFX.play est un MACRO : il s'expanse dans la page de l'objet qui joue un
; bruitage et ecrit ces deux mots. Ils sont donc RESIDENTS, comme les listes de
; collision et pour la meme raison — la v1 les met au meme endroit.
;
; Le pont irq.on/irq.off : les lecteurs YMM et VGC sont des modules v2 conserves
; (KEPT-V2) qui resolvent ces deux noms AU LIEN. Un symbole absent vaut zero en
; silence, soit un jsr $0000 — c'est la cause racine qui avait coute le pilote
; M2. Deux equates exportees, zero octet emis.
; Cas de migration : docs/lang/en/migration/irq-bridge.md
;*******************************************************************************
; $FF00 est la sentinelle d'inactivite du pilote (soundFX.NO_SOUND) : semees a
; zero, les deux boites demanderaient le son 0 a chaque trame.
soundFX.curSound             fdb   $FF00
soundFX.newSound             fdb   $FF00

; Le contrat v2 de `irq.on`/`irq.off` est de PRESERVER LES REGISTRES —
; engine/system/to8/irq/irq.asm le dit en toutes lettres (« and preserve
; registers ») et l'obtient par pshs a / puls a,pc. Les routines v1 IrqOn et
; IrqOff, elles, ecrasent A : elles lisent le registre STATUS dedans.
;
; Un simple `equ` sur les routines v1 tient donc la promesse du NOM sans tenir
; celle du CONTRAT. Le lecteur YMM appelle `jsr irq.off` au beau milieu de la
; sequence ou A porte la page des donnees musicales, juste avant
; `sta ymm.data.page` : avec l'alias nu il rangeait $00, montait la page 0 au
; lieu de la sienne, y depaquetait du bruit, et le depaqueteur ne trouvait
; jamais sa fin de flux — IRQ jamais rendue, machine partie.
;
; Le sas est ici et pas dans Irq.asm : c'est NOTRE pont vers le dialecte v2, et
; les quatre exemples qui incluent engine/irq/Irq.asm doivent rester au bit pres.
irq.on  EXPORT
irq.on  pshs  a
        jsr   IrqOn
        puls  a,pc

irq.off EXPORT
irq.off pshs  a
        jsr   IrqOff
        puls  a,pc

; Les listes de boites de collision. Elles sont resideNtes : un objet s'y
; inscrit a sa creation et s'en retire a sa mort, et le jeu en entier partage
; les memes quatre listes.
AABB_list_friend             fdb   0,0
AABB_list_ennemy             fdb   0,0
AABB_list_ennemy_unkillable  fdb   0,0
AABB_list_player             fdb   0,0
AABB_list_bonus              fdb   0,0
AABB_list_foefire            fdb   0,0
AABB_list_forcepod           fdb   0,0

; Leur remise a zero en bloc, au rechargement d'un checkpoint. Porte du game
; mode v1 (Collision_ClearLists, main.asm) : les listes vivent ici, leur
; nettoyage aussi.
Collision_ClearLists
        ldd   #0
        ldy   #AABB_list_friend
        ldx   #7*2                     ; sept listes de deux mots
!       std   ,y++
        leax  -1,x
        bne   <
        rts

; La passe de detection, elle, a quitte le resident : elle vit dans l'unite
; montee `collisionpass`, comme la v1 la met dans obj_mainext. Du calcul pur sur
; ces listes, donc page-neutre, et un seul appelant — la boucle de stage, une
; fois par trame. Ses 184 octets sont alles au pool d'objets.
; Voir docs/lang/fr/analyse-residente-2026-08.md, etape 5 du chemin vers 50.

;*******************************************************************************
; L'échange de stage
;
; Résident pour la même raison. Le retour du scene.load se ferait sinon dans du
; code qui n'existe plus.
;
; x = identifiant de fichier de la scène à charger.
;*******************************************************************************
;*******************************************************************************
; Le déchargement d'une scène
;
; Résident pour la même raison que l'échange : c'est le stage SORTANT qui
; appelle, et sa région est sur le point d'être écrasée.
;
; Volontairement SÉPARÉ de `game.stage.switch`, et à n'appeler qu'explicitement.
; Une routine qui recollerait le déchargement et le chargement retirerait au
; stage la maîtrise de sa séquence : lui seul sait ce qu'il a pris, ce qu'il
; laisse au suivant, et quand il peut s'en défaire. Le stage entrant, lui, ne
; sait rien de ce que le sortant occupait.
;
; Le déchargement DÉSINDEXE : il rend les données de lien au pool et retire les
; fichiers de l'index. Il n'efface pas la RAM — le code qui appelle continue
; donc de tourner jusqu'à ce que le chargement suivant l'écrase.
;
; x = identifiant de fichier de la scène à décharger.
;*******************************************************************************
game.stage.unload
        _ram.data.set #loader.PAGE         ; même fenêtre à monter que pour charger
        jmp   loader.ADDRESS+loader.scene.unload.IDX

;*******************************************************************************
; L'échange de stage — la suite du commentaire ci-dessus
;*******************************************************************************
; Le lecteur YMM, dans sa page : le relais game.music.play l'y atteint.
ymm.obj.play EXTERNAL

stage.main EXTERNAL
cast.converge EXTERNAL
; X = id de la scène cible, Y = id de son RÉPERTOIRE (l'equate <scène>.dir
; du fichier d'ids généré), U = masque des lots de la bibliothèque d'ennemis
; que la cible charge (src/common/cast.const.asm — 0 : aucun cast commun).
; Les répertoires sont partitionnés par unité de chargement : la scène cible
; se résout dans le sien, qu'il faut monter en mémoire AVANT scene.load —
; l'appelant a déjà déchargé l'ancienne scène, pendant que l'ancien
; répertoire était encore là (l'ordre qui permet au loader de relire les
; étendues à rendre). Y et pas A ou B : la macro de montage de page les
; détruit tous les deux ; U pour le masque, même raison.
;
; La phase de cast converge la bibliothèque AVANT le montage du répertoire
; cible : les lots vivent dans le répertoire 0, un lot = une scène de lot.
; On décharge les lots que la cible ne veut pas, on charge ceux qui lui
; manquent — ce que deux stages consécutifs partagent reste en RAM, sans
; relecture disque. C'est le point qui a fait choisir le masque contre une
; scène de cast par stage : décharger puis recharger une scène entière
; aurait relu du disque tout ce qu'elle conservait.
game.stage.switch
        jsr   IrqOff                       ; le chargement parle au contrôleur disque
        ; Le loader vit dans une page commutée de la fenêtre DATA : il faut la
        ; monter pour l'atteindre. Le stage vient d'y effacer ses tampons
        ; d'écran, donc c'est une autre page qui est en place.
        _ram.data.set #loader.PAGE
        ; La convergence vit dans sa propre unité résidente (région `cast`,
        ; marge de la page résidente) : la fenêtre du moteur est pleine à
        ; 45 octets près, seul l'appel loge ici.
        pshs  x,y                          ; la cible attendra la fin de la phase
        tfr   u,d                          ; B = masque des lots de la cible
        jsr   cast.converge
        puls  x,y
        tfr   y,d                          ; l'id de répertoire, bas de Y
        tfr   b,a
        pshs  x                            ; dir.load ne préserve pas X
        jsr   loader.ADDRESS+loader.dir.load.IDX
        puls  x
        jsr   loader.ADDRESS+loader.scene.load.IDX
        ; nom commun exporté par les deux mains : la référence reste au lien
        ; (plusieurs fournisseurs), le re-link du scene.load ci-dessus vient
        ; de la repointer sur le stage fraîchement chargé
        jmp   stage.main

;*******************************************************************************
; Terrain collision : mounting the per stage map
;
; The resident half reaches the mounted unit through self modified operands.
; v1 patched them from a macro expanded in the game mode ; here the patching
; is a resident routine, so those operands stay private to the engine and the
; interface keeps four names instead of a dozen.
;
; b = object id of the terrain unit in the stage's object index.
;*******************************************************************************
terrainCollision.init.do
        ldx   #Obj_Index_Page
        abx
        lda   ,x
        sta   terrainCollision.main.page
        sta   terrainCollision.main.xAxis.doRight.page
        sta   terrainCollision.main.xAxis.doLeft.page
        sta   terrainCollision.main.update.page
        ldx   #Obj_Index_Address
        aslb
        abx
        ldd   ,x
        std   terrainCollision.main.address
        addd  #3
        std   terrainCollision.main.xAxis.doRight.address
        addd  #3
        std   terrainCollision.main.xAxis.doLeft.address
        addd  #3
        std   terrainCollision.main.update.address
        rts

;*******************************************************************************
; The engine proper
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.asm"
; L'effacement des tampons de donnees est parti en unite montee (clear) : cent
; octets pour un travail qui n'arrive qu'a l'ouverture d'un stage et au
; rechargement d'un checkpoint. Voir src/common/lib/clear.unit.asm.
        INCLUDE "engine/graphics/tilemap/horizontal-scroll/scroll-map-buffered-even.asm"
        INCLUDE "engine/objects/collision/terrainCollision.main.asm"
        INCLUDE "engine/object-management/RunObjects.asm"
        INCLUDE "engine/object-management/ObjectWave-subtype.asm"
        ; L'appel d'objet factorise : un stage lance un objet nomme par son
        ; identifiant (le joueur, le HUD, la carte…) sans que chaque site
        ; d'appel reexpanse le montage de page.
        INCLUDE "engine/object-management/Obj_Run.asm"
        ; L'espace utilisateur de la page directe, ou vit l'OST du joueur :
        ; ObjectDp_Clear le remet a zero de dp a dp_extreg.
        INCLUDE "engine/object-management/ObjectDp.asm"
        INCLUDE "engine/object-management/ObjectMoveSync.asm"
        ; L'appel de sous-routine paginee, dont depend toute la chaine de tir
        ; (loadFirePreset, createFoeFire).
        INCLUDE "engine/object-management/RunPgSubRoutine.asm"
        ; L'appel de routine paginee de la v2 : page en immediat, adresse par
        ; le lien, aucune operande auto-modifiee. C'est par la que passent les
        ; overlays (masque, hud) qui n'ont ni etat ni OST.
        INCLUDE "engine/system/paged-call.asm"
        INCLUDE "engine/log/log.asm"
        ; Le deplacement en 8.8 et la chaine de tir ennemi. La v1 les inclut
        ; toutes quatre dans son main (main.asm:565-568) : elles sont donc
        ; RESIDENTES, et c'est de la qu'elles traversent la frontiere.
        ; setDirectionTo l'est aussi, alors que createFoeFire qui l'appelle est
        ; un objet monte — le lien remet les deux bouts en face.
        ; tryFoeFire cite ObjID_createFoeFire : le RESIDENT depend donc d'une
        ; numerotation d'objets, alors qu'elle est par stage. C'est tenable
        ; parce que gen_objid.py seme les identifiants du commun AVANT de lire
        ; la wave — les treize premiers portent le meme numero dans tous les
        ; stages, et c'est cet invariant qui autorise la ligne ci-dessous.
        ; Le joueur et pata-pata font deja le meme emprunt.
        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/common/lib/object.const.asm"
        INCLUDE "src/common/lib/moveXPos8.8.asm"
        INCLUDE "src/common/lib/moveYPos8.8.asm"
        INCLUDE "src/common/lib/projectile.asm"
        INCLUDE "src/common/lib/setDirectionTo.asm"
        INCLUDE "engine/math/RandomNumber.asm"
        INCLUDE "engine/graphics/animation/AnimateSprite.asm"
        INCLUDE "engine/graphics/animation/AnimateSpriteSync.asm"
        INCLUDE "engine/graphics/animation/moveByScript.asm"
        INCLUDE "engine/collision/collision.asm"
; OVERLAY : le pack de sprites est celui de l'overlay (BuildSprites — dessin
; seul, pas de sauvegarde de fond, pas d'effacement). L'ancien pack
; background-erase reste dans l'engine, choisi par l'absence du define
; OverlayMode ; ce jeu-ci le pose dans son config.xml.
; Le codec zx0 n'est toujours pas inclus (aucune image rle/zx0 dans ce jeu).
        INCLUDE "engine/graphics/sprite/sprite-overlay-pack.asm"

; ---------------------------------------------------------------------------
; Compagnons du pack overlay — code du JEU, pas de l'engine.
; Le pack v1 ne fournit que DisplaySprite/BuildSprites/DeleteObject ; les
; quatre routines ci-dessous couvrent ce que le reste du jeu attend encore.
; ---------------------------------------------------------------------------

; ATTENTION, la convention CHANGE avec le pack. En background-erase les
; offsets camera portent le cadre ecran (48/28) : CheckSpritesRefresh convertit
; playfield -> cadre 48-207, puis DRS_XYToAddress retranche 48/28. Le
; BuildSprites overlay, lui, calcule l'adresse DIRECTEMENT depuis
; x_pos - camera + offset : l'offset y est une MARGE hors-ecran (sonic v1 met
; 12/20), et R-Type, dont toute la logique suppose la fenetre visible
; [camera, camera+160], veut ZERO. Les poser a 48/28 decale chaque sprite
; playfield de +48/+28 avec wrap au bord (vecu : logo du title coupe en deux).
; InitGlobals ne les pose que sous ifdef DrawSprites (pack bg-erase) — il
; savait deja que la convention change ; ce talon les fixe explicitement.
InitDrawSprites
        ldd   #0
        std   glb_camera_x_offset
        std   glb_camera_y_offset
        rts

; Remise a zero de la structure de priorite (les deux tables de tetes de
; liste du pack overlay). L'equivalent du DisplaySprite_ClearAll du pack
; background-erase, pour les transitions de mode et le checkpoint.
DisplaySprite_ClearAll
        ldx   #Tbl_Priority_First_Entry
        ldb   #(2+nb_priority_levels*2)*2   ; First + Last, contigus
!       clr   ,x+
        decb
        bne   <
        rts

; Il n'y a plus de cellules de fond a rendre : la routine ne fait rien, et
; les sites d'appel (title, checkpoint) restent intacts.
; OVERLAY-TODO : purger les appels puis retirer ce talon.
EraseSprites_ClearAll
        rts

; xy ecran -> adresses des deux plans. Copie du DRS_XYToAddress du pack
; background-erase (DrawSpritesExtEnc.asm) : les effaceurs a la main
; (rotonde de shells, queue du boss) s'en servent toujours.
DRS_XYToAddress
        suba  #$30
        bcc   DRS_XYToAddressPositive
        suba  #$60                          ; get x position one line up, skipping (160-255)
        decb
DRS_XYToAddressPositive
        subb  #$1C                          ; TODO same thing as x for negative case
        lsra                                ; x=x/2, sprites moves by 2 pixels on x axis
        lsra                                ; x=x/2, RAMA RAMB enterlace
        bcs   DRS_XYToAddressRAM2First      ; Branch if write must begin in RAM2 first
DRS_XYToAddressRAM1First
        sta   DRS_dyn1+2
        lda   #$28                          ; 40 bytes per line in RAMA or RAMB
        mul
DRS_dyn1
        addd  #$C000                        ; (dynamic)
        std   <glb_screen_location_2
        subd  #$2000
        std   <glb_screen_location_1
        rts
DRS_XYToAddressRAM2First
        sta   DRS_dyn2+2
        lda   #$28                          ; 40 bytes per line in RAMA or RAMB
        mul
DRS_dyn2
        addd  #$A000                        ; (dynamic)
        std   <glb_screen_location_2
        addd  #$2001
        std   <glb_screen_location_1
        rts
        ; L'historique des 16 dernieres directions, que le force pod du joueur
        ; relit pour le suivre avec du retard. Fichier v1 SANS section : il va
        ; DANS celle de l'hote, contrairement au joypad v2 juste apres, qui
        ; porte la sienne.
        ; Cas de migration : docs/lang/en/migration/v1-file-sections.md
        INCLUDE "engine/system/to8/controller/joypad.buffer.asm"

 ENDSECTION

; a v2 module, which brings its own section
        INCLUDE "engine/system/to8/controller/joypad.asm"
; La lecture qui fait de n'importe quelle touche le bouton B — les manettes
; Thomson n'en ont qu'un, et le rappel du force pod en demande un second. Elle
; a son propre fichier, comme ReadJoypadsKbd en v1 : les exemples qui n'en
; veulent pas incluent joypad.asm seul et ne la paient pas.
        INCLUDE "engine/system/to8/controller/joypad.kbd.asm"
