;*******************************************************************************
; Stage 3 — mis en place avec sa carte (chantier stages 3-8)
;
; Même structure que le stage 1, mêmes exports, contenu entièrement différent :
; sa carte est celle du niveau 2 (une caverne, bien plus dense en tuiles), sa
; wave n'a que les entrées dont les ennemis existent encore, et son index
; d'objets ne compte que deux identifiants contre seize.
;
; C'est cette différence de contenu sous une interface identique qui donne sa
; valeur au banc : si le moteur n'était pas repointé sur les tables de CE
; stage, il lirait un index de seize entrées là où il n'y en a que deux.
;*******************************************************************************

STAGE_ID equ 3
; La scène de CE stage — voir stage 1 : le sortant décharge, jamais l'entrant.
STAGE_SCENE equ scenes.stage3

Obj_Index_Page    EXPORT
Obj_Index_Address EXPORT
Ani_Page_Index    EXPORT
Ani_Asd_Index     EXPORT
Img_Page_Index    EXPORT
; L'etat de la boucle : le joueur (page $11) l'ecrit a travers le lien.
mainloop.state    EXPORT

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
; il n'a ni etat ni OST, sa page est une equate (common.overlay.page) et son adresse
; ce symbole — paged.call suffit a l'atteindre. Les deux stages partagent
; stage-main.asm, donc les deux le declarent.
adr_playfield_mask_ND0 EXTERNAL

; Le champ d'etoiles, meme page que le masque. Trois routines sans etat, visees
; directement : pas d'ObjID, pas de commande en registre.
; Le HUD, meme page que le masque et les etoiles : une routine sans etat,
; visee par son symbole.
hud.normal        EXTERNAL
; Cite par la boucle commune (phase 4 de la sequence de fin) ; le stage 2 n'y
; passe jamais, mais le symbole doit se resoudre.
hud.readout       EXTERNAL

starfield.init    EXTERNAL
starfield.erase   EXTERNAL
starfield.draw    EXTERNAL

; Le joueur, dans sa page a lui : l'index d'objets du stage y renvoie pour les
; trois tables — objet, animation et images.
Player            EXTERNAL

; Les flammes de reacteur de la sequence d'ouverture, dans leur page.
engineflames.Object   EXTERNAL

; Le son : le lecteur et le pilote de bruitages vivent dans leurs pages, le
; morceau de CE stage dans celle des donnees musicales.
ymm.obj.play      EXTERNAL
ymm.frame.play    EXTERNAL
soundfx.frame     EXTERNAL
; Le morceau de CE stage, charge par sa scene au creneau musical de la page
; $1A (music/ymm.unit.asm — le choix du fichier v1 y est justifie).
sounds.level3.ymm EXTERNAL
sounds.boss.ymm   EXTERNAL
stage.music       equ sounds.level3.ymm

; Le marqueur de musique du boss, seme par la wave : il pose le drapeau que
; stage.endTick releve pour changer de morceau.
bossmusic.Object      EXTERNAL

; Le fondu de palette : un objet monte comme un autre depuis le 04/08 — le
; stage l'arme a l'ouverture et le fait tourner dans sa boucle.
PaletteFade           EXTERNAL

; La chaine de tir ennemi, page $14 : deux sous-routines paginees que l'ennemi
; atteint par RunPgSubRoutine, et le projectile qu'elles font naitre.
createFoeFire         EXTERNAL
loadFirePreset.Object EXTERNAL
foefire.Object        EXTERNAL

; L'explosion, dans sa page a elle : treize sprites compiles, dont cinq de
; 24x48. Tout ce qui meurt la fait naitre par l'index d'objets.
explosion.Object  EXTERNAL

; Les bonus, communs a tous les stages : le POW que la wave seme, et la boite a
; option qu'il fait naitre en mourant. Deux unites, deux pages.
pow.Object          EXTERNAL
powOptionbox.Object EXTERNAL
bitdevice.Object    EXTERNAL

; L'armement : le force pod et ses trois armes, une unite chacun.
forcepod.Object        EXTERNAL
simplefire.Object      EXTERNAL
reboundlaser.Object    EXTERNAL
counterairlaser.Object EXTERNAL

; Le cast d'ennemis, un direntry chacun.
bug.Object      EXTERNAL
bink.Object     EXTERNAL
blaster.Object  EXTERNAL
messages.Object   EXTERNAL   ; READY / GAME OVER, monte par _Obj_Mount
        INCLUDE "src/common/hud/messages/messages.const.asm"

; L'armement, quatre unites sur la page $13 : le tir de base, la charge, le
; beam et l'eclair d'emission. Le joueur les cree par l'index d'objets.
Weapon              EXTERNAL
Beamcharge          EXTERNAL
Beam                EXTERNAL
emitterFlash.Object EXTERNAL

 SECTION code

        INCLUDE "src/common/engine/api.asm"
        INCLUDE "src/common/cast.const.asm"

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/graphics/buffer/gfxlock.macro.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/pack/ymm.asm"
        INCLUDE "engine/object-management/Obj_Run.macro.asm"
        ; Les offsets d'OST du fondu : le stage arme l'objet, le moteur le fait
        ; tourner. Le fichier est garde par IFNDEF, donc inclus des deux cotes.
        INCLUDE "engine/objects/palette/fade/fade.equ"
        ; La routine de veille des bit devices : le corps commun amorce leurs
        ; deux OST statiques a l'ouverture du stage. Garde par IFNDEF.
        INCLUDE "src/common/weapons/bitdevice/bitdevice.equ"
        ; Les identifiants de routine du force pod : le corps commun amorce son
        ; OST statique en veille a l'ouverture du stage.
        INCLUDE "src/common/weapons/forcepods/forcepod.equ"

        ; Les variables inter-main, en equates absolues de la zone reservee
        ; `globals` : la boucle les remet a zero a l'entree du stage, comme la
        ; v1 le fait dans l'init de son main.
        INCLUDE "src/common/state/variables.asm"

        INCLUDE "gen/layout.asm"
        INCLUDE "src/common/bench.const.asm"
        INCLUDE "gen/stages/03/map/map.const.asm"

 opt c,ct

        INCLUDE "src/stages/stage-main.asm"

;*******************************************************************************
; Ce qui distingue ce stage
;*******************************************************************************
; Les points de reprise de CE stage, en tuiles de collision (24 px), la
; sentinelle -1 en butoir — la table du game mode v1.
checkpoint.positions EXPORT
checkpoint.positions
        fcb   0
        fcb   -1

; Ce stage n'a pas de sequence d'ouverture : le banc y entre par un echange,
; pas par un debut de partie. Le corps commun l'appelle quand meme — chaque
; stage repond, quitte a ne rien faire.
stage.openingSequence
        rts

; ---------------------------------------------------------------------------
; Les trois rendez-vous de la boucle commune. Le stage 2 n'a ni boss ni
; sequence de fin : il ne peint rien de plus dans le verrou, ne change pas de
; surimpression, et se termine au bout de la carte.
; ---------------------------------------------------------------------------
stage.frameBlit
        rts

stage.overlayPhase fcb 0

stage.endTick
        ; La musique du boss : le marqueur seme par la wave pose ce drapeau, et
        ; c'est ici qu'on change de morceau — la v1 fait de meme (main.asm:270),
        ; le lecteur ne pouvant pas etre monte depuis l'objet marqueur.
        lda   globals.nextGameMode
        beq   stage.endTick.noBossMusic
        jsr   IrqOff
        _GetCartPageB
        pshs  b
        ; Arreter le flux AVANT de relancer : le stage 4 a montre que relancer
        ; `ymm.obj.play` sur un lecteur en cours de flux desynchronise l'anneau
        ; (plus aucun wait vu, ~1 trame/s) — le meme phenomene que le handOver.
        ; Le stage 1 s'en passe sur SON boss : roulette de phase, pas un modele.
        lda   #map.RAM_OVER_CART+engine.sound.ymm.page
        ldx   #ymm.stop
        jsr   paged.call
        _ymm.obj.play #map.RAM_OVER_CART+engine.sound.ymm.page,#sounds.boss.ymm,#ymm.LOOP,#ymm.NO_CALLBACK
        puls  b
        _SetCartPageB
        jsr   IrqOn
        clr   globals.nextGameMode
stage.endTick.noBossMusic
        ldd   glb_camera_x_pos
        cmpd  scroll_max
        lbhs  stage.handOver
        rts

stage.setup
        ; La collision terrain : le resident pointe ses operandes sur l'unite
        ; de CE stage, et le drapeau disabled (pose par defaut dans le corps
        ; commun) tombe — le vaisseau heurte le decor.
        ldb   #ObjID_collision
        jsr   terrainCollision.init.do
        clr   terrainCollision.disabled
        ldd   #map.even
        std   scroll_map_even
        ldd   #map.odd
        std   scroll_map_odd
        lda   #map.RAM_OVER_CART+stage3.maps.page
        sta   scroll_map_page_even
        sta   scroll_map_page_odd

        ldd   #stage.wave
        std   object_wave_data
        std   object_wave_data_start
        lda   #map.RAM_OVER_CART+stage3.wave.page
        sta   object_wave_data_page
        rts

; Fin du stage 3 : on enchaîne sur le stage 4. La campagne remonte
; jusqu'au stage 8, qui rend la main au title.
stage.handOver
        jsr   IrqOff
        ; Même geste qu'au stage 1 : la musique s'arrête avant l'échange, voir
        ; le commentaire de son handOver.
        lda   #map.RAM_OVER_CART+engine.sound.ymm.page
        ldx   #ymm.stop
        jsr   paged.call

        lda   #3
        sta   game.stage
        ldx   #STAGE_SCENE                 ; ce stage rend ce qu'il avait pris
        jsr   game.stage.unload
        ldx   #scenes.stage4
        ldy   #scenes.stage4.dir
        ldu   #cast.stage4                  ; les lots d'ennemis de la cible
        jmp   game.stage.switch

;*******************************************************************************
; L'index d'objets et la wave — les données réelles du niveau 2
;*******************************************************************************
        INCLUDE "src/stages/03/objid.const.asm"
        INCLUDE "src/stages/03/objid.index.asm"


 ENDSECTION
