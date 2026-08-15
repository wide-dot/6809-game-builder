;*******************************************************************************
; Stage 5 — mis en place avec sa carte (chantier stages 3-8)
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

STAGE_ID equ 5
; La scène de CE stage — voir stage 1 : le sortant décharge, jamais l'entrant.
STAGE_SCENE equ scenes.stage5

Obj_Index_Page    EXPORT
Obj_Index_Address EXPORT
Ani_Page_Index    EXPORT
Ani_Asd_Index     EXPORT
Img_Page_Index    EXPORT
; L'etat de la boucle : le joueur (page $11) l'ecrit a travers le lien.
mainloop.state    EXPORT
; La palette de noir, membre palette de CE direntry : la sequence de fin
; commune l'installe avant de rendre la main.
Pal_black         EXPORT

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
sounds.level5.ymm EXTERNAL
sounds.boss.ymm   EXTERNAL
sounds.clearstage.ymm EXTERNAL
stage.music       equ sounds.level5.ymm

; Le sequenceur de fin generique et le jingle qu'il demande au stage de
; jouer (protocole du stage 1, objet commun monte au boot).
endlevel.Object       EXTERNAL

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

; La bibliotheque d'ennemis de ce stage (lots charges par l'engine).
cancer.Object     EXTERNAL
mid.Object        EXTERNAL

 SECTION code

        INCLUDE "src/common/engine/api.asm"
        INCLUDE "src/common/cast.const.asm"
        INCLUDE "src/common/flow/endlevel/endlevel.const.asm"

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
        INCLUDE "gen/stages/05/map/map.const.asm"

 opt c,ct

        INCLUDE "src/stages/stage-main.asm"

;*******************************************************************************
; Ce qui distingue ce stage
;*******************************************************************************
; Les points de reprise de CE stage, en tuiles de collision (24 px), la
; sentinelle -1 en butoir. La source est la WAVE : l'arcade seme un objet
; checkpoint ($0C80,ObjID_checkpoint dans wave.asm) et sa position est son
; horodatage divise par 128 — 128 trames par tuile, l'inverse exact de la
; vitesse de scroll (cf. src/common/flow/checkpoint.unit.asm). ATTENTION : la
; table de reference v1 (src/common/state/checkpoint/checkpoint-data.asm) dit
; $0358 « 35*24px » pour ce stage — c'est une coquille ($0258 transpose). Les
; positions ABSOLUES arcade qu'elle cite en commentaire ($3AC0-$3480 = $640,
; puis x3/8 pour passer en pixels TO8) donnent 600 = 25 tuiles, d'accord avec
; l'horodatage de la wave (3200/128 = 25).
checkpoint.positions EXPORT
checkpoint.positions
        fcb   0
        fcb   25
        fcb   -1

; Ce stage n'a pas de sequence d'ouverture : le banc y entre par un echange,
; pas par un debut de partie. Le corps commun l'appelle quand meme — chaque
; stage repond, quitte a ne rien faire.
stage.openingSequence
        rts

; ---------------------------------------------------------------------------
; Les trois rendez-vous de la boucle commune, servis par l'objet commun
; endlevel (le protocole du stage 1) : le fondu pixel dans le verrou, la
; phase de surimpression publiée, et la fin décidée par la séquence —
; combat de substitution (caméra au bout + timeout → boss réputé battu),
; jingle, autopilote, fondu, relevé de score.
; ---------------------------------------------------------------------------
stage.frameBlit
        _Obj_RunB ObjID_endstage,#endstage.BLIT
        rts

; La phase publiée est directement la variable résidente que l'objet écrit.
stage.overlayPhase equ main.endstage.phase

; L'état résident de la séquence : l'objet endlevel l'écrit, la boucle
; commune lit la phase, le HUD arme et rend le relevé de score. Les noms
; sont ceux du stage 1 — les mains sont des alternatives à la même
; destination, leurs exports partagent les noms.
main.endstage.counter    EXPORT
main.endstage.phase      EXPORT
main.endstage.scoreArmed EXPORT
main.endstage.scoreDone  EXPORT
main.endstage.counter    fdb 0  ; compte a rebours de fin (0 : pas arme)
main.endstage.phase      fcb 0  ; 0 jeu, 1 jingle+autopilote, 2 glissee, 3 fondu, 4 releve
main.endstage.scoreArmed fcb 0  ; 1 : le HUD (re)seme le releve du score du stage
main.endstage.scoreDone  fcb 0  ; 1 : releve fini -> la sequence quitte le niveau

stage.endTick
        ; La musique du boss : le marqueur seme par la wave pose ce drapeau, et
        ; c'est ici qu'on change de morceau — la v1 fait de meme (main.asm:270),
        ; le lecteur ne pouvant pas etre monte depuis l'objet marqueur.
        lda   globals.nextGameMode
        beq   stage.endTick.noBossMusic
        jsr   IrqOff
        _GetCartPageB
        pshs  b
        ; Relancer en plein flux est SAIN : ymm.obj.play fait table rase
        ; complete. Les gels attribues un temps au relancement etaient l'IRQ
        ; tombant dans la pile privee du depaqueteur — corrige dans le module
        ; (docs/lang/en/migration/ymm-private-stack-irq.md).
        _ymm.obj.play #map.RAM_OVER_CART+engine.sound.ymm.page,#sounds.boss.ymm,#ymm.LOOP,#ymm.NO_CALLBACK
        puls  b
        _SetCartPageB
        jsr   IrqOn
        clr   globals.nextGameMode
stage.endTick.noBossMusic
        ; La sequence de fin decide, pas la camera — voir le commentaire des
        ; trois rendez-vous.
        _Obj_RunB ObjID_endstage,#endstage.TICK
        cmpb  #endstage.STATUS_JINGLE
        beq   stage.endTick.jingle
        cmpb  #endstage.STATUS_DONE
        beq   stage.endTick.done
        rts

stage.endTick.jingle
        ; Le jingle de fin — l'objet ne peut pas monter le lecteur depuis sa
        ; page, donc c'est le stage qui le fait, comme au stage 1.
        jsr   IrqOff
        _GetCartPageB
        pshs  b
        _ymm.obj.play #map.RAM_OVER_CART+engine.sound.ymm.page,#sounds.clearstage.ymm,#ymm.NO_LOOP,#ymm.NO_CALLBACK
        puls  b
        _SetCartPageB
        jsr   IrqOn
        rts

stage.endTick.done
        jmp   stage.handOver

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
        lda   #map.RAM_OVER_CART+stage5.maps.page
        sta   scroll_map_page_even
        sta   scroll_map_page_odd

        ldd   #stage.wave
        std   object_wave_data
        std   object_wave_data_start
        lda   #map.RAM_OVER_CART+stage5.wave.page
        sta   object_wave_data_page

        ; Le sequencement de fin : remis a zero par l'objet commun, a
        ; l'ouverture ET au rechargement de checkpoint — stage.setup couvre
        ; les deux, comme au stage 1.
        _Obj_RunB ObjID_endstage,#endstage.INIT
        rts

; Fin du stage 5 : on enchaîne sur le stage 6. La campagne remonte
; jusqu'au stage 8, qui rend la main au title.
stage.handOver
        jsr   IrqOff
        ; Même geste qu'au stage 1 : la musique s'arrête avant l'échange, voir
        ; le commentaire de son handOver.
        lda   #map.RAM_OVER_CART+engine.sound.ymm.page
        ldx   #ymm.stop
        jsr   paged.call

        lda   #5
        sta   game.stage
        ldx   #STAGE_SCENE                 ; ce stage rend ce qu'il avait pris
        jsr   game.stage.unload
        ldx   #scenes.stage6
        ldy   #scenes.stage6.dir
        ldu   #cast.stage6                  ; les lots d'ennemis de la cible
        jmp   game.stage.switch

;*******************************************************************************
; L'index d'objets et la wave — les données réelles du niveau 2
;*******************************************************************************
        INCLUDE "src/stages/05/objid.const.asm"
        INCLUDE "src/stages/05/objid.index.asm"


 ENDSECTION
