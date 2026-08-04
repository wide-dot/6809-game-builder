;*******************************************************************************
; The engine interface — one list, both sides
;
; The resident engine unit and every stage unit include this same file. The
; engine defines ENGINE_RESIDENT before including it and gets EXPORT lines ;
; a stage gets EXTERNAL lines for the same names. The two sides cannot drift,
; because there is only one list.
;
; This is lane 2 of the stage boundary (see
; docs/lang/fr/analyse-frontiere-stage-2026-08.md) : what a stage calls in the
; engine. Lane 3 — the tables the engine reads back from the stage — is the
; other direction and lives in stage-tables.asm.
;
; Adding a name here costs four bytes of link data in the engine's direntry and
; a linear search per reference at load time, so the list stays deliberately
; short : the engine offers mechanisms, the stage holds the policy.
;*******************************************************************************

_api    macro
  ifdef ENGINE_RESIDENT
\1 EXPORT
  else
\1 EXTERNAL
  endif
        endm

        ; --- boot and frame ---
        _api InitGlobals
        _api IrqInit
        _api IrqOn
        _api IrqOff
        _api IrqSync
        _api Irq_user_routine
        ; Irq_one_frame N'EST PAS ici : c'est une constante absolue (312*64-1),
        ; pas une adresse. La faire passer par le lien la faisait rebaser de
        ; $4DFF a $AEFF, soit une periode d'IRQ 2,24 fois trop longue — le jeu
        ; tournait a 22 Hz. Elle est partagee a l'assemblage par
        ; engine/constants.asm.

        ; --- double buffer ---
        ;
        ; La liste est longue pour une seule raison : _gfxlock.on/off/loop sont
        ; des MACROS, donc elles s'assemblent dans le stage et y référencent
        ; directement l'état du verrou. La voie compile-time et la voie de
        ; liaison se rejoignent ici — une macro qui touche une variable du
        ; moteur oblige à exporter cette variable. Les rendre routines
        ; échangerait ces exports contre des appels ; le choix v1 (macros, pour
        ; le coût par trame) est conservé tel quel.
        _api gfxlock.bufferSwap.check
        _api gfxlock.bufferSwap.do
        _api gfxlock.bufferSwap.wait
        _api gfxlock.status
        _api gfxlock.backBuffer.id
        _api gfxlock.backBuffer.status
        _api gfxlock.backProcess.status
        _api gfxlock.frame.count
        _api gfxlock.frame.lastCount
        _api gfxlock.frame.gameCount
        _api gfxlock.frameDrop.count
        _api gfxlock.frameDrop.count_w
        _api gfxlock.frameDrop.max

        ; --- palette ---
        _api Pal_current
        _api PalRefresh
        _api PalUpdateNow

        ; --- screen clear ---
        _api ClearInterlacedEvenDataMemory
        _api ClearInterlacedOddDataMemory

        ; --- tilemap scroll : the routines, then the state a stage sets up ---
        _api InitScroll
        _api Scroll
        _api DrawTiles
        _api scroll_map_even
        _api scroll_map_odd
        _api scroll_map_page_even
        _api scroll_map_page_odd
        _api scroll_vp_h_tiles
        _api scroll_vp_v_tiles
        _api scroll_tile_width
        _api scroll_tile_height
        _api scroll_vp_x_pos
        _api scroll_vp_y_pos
        _api scroll_vel
        _api scroll_max
        _api scroll_tile_pos
        _api scroll_tile_pos_offset24
        ; L'etat interne du scroll, que le PRE-SCROLL d'ouverture pilote a la
        ; main : il rembobine la camera et repeint le viewport colonne par
        ; colonne. Ce sont des etiquettes de variables dans l'unite residente,
        ; donc de vraies adresses — elles traversent le lien a bon droit.
        _api scroll_tile_pos_offset
        _api scroll_map_pos
        _api buffer_x_pos
        _api glb_camera_x_pos_old
        _api tile_buffer
        _api tile_buffer_page

        ; --- object manager ---
        _api InitStack
        _api ManagedObjects_ClearAll
        _api RunObjects
        ; Le gel de la mort : redessine les objets sans derouler leur logique.
        _api RunFrozenObjects
        _api LoadObject_x
        _api LoadObject_u
        _api UnloadObject_u
        _api Obj_Mount
        ; Obj_RunB N'EST PLUS AU CONTRAT : plus personne ne s'en sert. Il
        ; portait une commande dans B parce qu'un objet ne s'atteignait que par
        ; l'index ; en v2 une routine sans etat se vise par son symbole, via
        ; paged.call, sans registre de commande ni table de routage — voir le
        ; champ d'etoiles. Obj_Run reste : le fondu, lui, a bien un OST.
        _api Obj_Run
        ; Ce que le JOUEUR appelle en plus. ObjectMove n'y est PAS : il est
        ; inclus dans l'unite du joueur, comme en v1, donc resolu localement.
        _api gfxlock.screenBorder.update

        ; --- manette : les trois paires d'octets du module resident ---
        ; Les MASQUES, eux, sont des constantes partagees a l'assemblage par
        ; joypad.const.asm — ils ne franchissent pas le lien.
        _api joypad.init
        _api joypad.read
        ; La lecture qui fait du clavier un bouton B : les manettes Thomson
        ; n'en ont qu'un, et le rappel du force pod en demande un second.
        _api joypad.readKbd
        _api joypad.state.dpad
        _api joypad.state.fire
        _api joypad.held.dpad
        _api joypad.held.fire
        _api joypad.pressed.dpad
        _api joypad.pressed.fire
        _api joypad.buffer.addDirection
        _api joypad.buffer.getDirection
        ; PaletteFade N'EST PLUS ici : le fondu est un objet MONTE, comme en
        ; v1. Le stage declare son adresse en EXTERNAL lui-meme, au meme titre
        ; que l'explosion — ce n'est pas une routine du moteur.
        ; Pal_buffer, en revanche, y entre : le fondu y compose depuis sa page.
        _api Pal_buffer
        _api ObjectDp_Clear
        _api ObjectMoveSync
        _api RunPgSubRoutine
        _api PSR_Page
        _api PSR_Address
        _api PSR_Param

        ; --- enemy waves ---
        _api ObjectWave
        _api ObjectWave_Init
        _api object_wave_data
        _api object_wave_data_start
        _api object_wave_data_page

        ; --- terrain collision : the resident half, the stage mounts the map ---
        _api terrainCollision.init.do
        _api terrainCollision.do
        _api terrainCollision.xAxis.doRight
        _api terrainCollision.sensor.x
        _api terrainCollision.sensor.y
        _api terrainCollision.impact.x
        _api terrainCollision.disabled
        _api terrainCollision.bgFlag
        _api terrainCollision.bgByteOff
        _api terrainCollision.bgBitShift
        _api terrainCollision.bgColTmp

        ; --- sprites : ce qu'un objet de jeu appelle pour se montrer ---
        _api DisplaySprite
        _api DeleteObject
        _api CheckSpritesRefresh
        _api EraseSprites
        _api DrawSprites
        _api UnsetDisplayPriority
        _api BgBufferAlloc
        _api InitDrawSprites
        _api DisplaySprite_ClearAll
        _api EraseSprites_ClearAll
        _api AnimateSprite
        _api AnimateSpriteSync

        ; --- appel d'une routine paginee (overlays sans etat) ---
        _api paged.call

        ; --- animation par script ---
        ; Les routines seules franchissent la frontiere. callback, anim.end et
        ; anim.loops sont des equates de page directe, pas des etiquettes : ils
        ; sont partages a l'assemblage par engine/constants.asm (voie 1). Les
        ; lister ici les faisait rebaser par le linker, $9FA9 -> $00A9.
        _api moveByScript.initialize
        _api moveByScript.runByB
        _api moveByScript.runByFrameDrop
        _api moveByScript.register

        ; --- collisions AABB : les routines, puis les listes que le jeu
        ; partage. Un objet s'inscrit dans l'une d'elles a sa creation ---
        _api Collision_Do
        ; La passe de detection complete — toutes les paires de listes, dans
        ; l'ordre de la v1. Un seul export : les operandes auto-modifiees que
        ; le macro _Collision_Do ecrit restent chez le moteur.
        _api Collision_Run
        _api Collision_AddAABB
        _api Collision_RemoveAABB
        _api Collision_ClearLists
        ; _Collision_RemoveAABB est une macro : elle ecrit dans les operandes
        ; auto-modifiees du moteur depuis la page de l'objet, donc ces trois
        ; adresses traversent la frontiere — meme mecanique que gfxlock.
        _api Collision_Remove_1
        _api Collision_Remove_2
        _api Collision_Remove_3
        _api AABB_list_friend
        _api AABB_list_ennemy
        _api AABB_list_ennemy_unkillable
        _api AABB_list_player
        _api AABB_list_bonus
        _api AABB_list_foefire

        ; --- la chaine de tir ennemi : residente, comme dans le main v1
        ; (main.asm:565-568). tryFoeFire est appele par l'ennemi, qui tourne
        ; en page montee ; setDirectionTo par createFoeFire, monte lui aussi.
        ; FoeFireTarget est la cible que tryFoeFire pose avant de tirer ---
        _api tryFoeFire
        _api tryFoeFireShell
        _api setDirectionTo
        _api FoeFireTarget
        _api moveXPos8.8
        _api moveYPos8.8

        ; --- score, qui survit aux stages comme les vies ---
        ; globals.score N'EST PAS ici : c'est une equate absolue de la zone
        ; reservee `globals`, partagee a l'assemblage par variables.asm. La
        ; faire passer par le lien la ferait rebaser.
        _api AwardScore

        ; --- alea ---
        _api InitRNG
        _api RandomNumber

        ; --- controllers ---
        _api joypad.init
        _api joypad.read
        _api joypad.held.dpad

        ; --- state that outlives a stage : the engine holds it, so a stage
        ; swap cannot take it with it ---
        _api game.score
        _api game.stage

        ; --- l'échange lui-même : il doit être résident, puisqu'il survit à
        ; l'écrasement de la région du stage qui l'appelle ---
        _api game.stage.switch
