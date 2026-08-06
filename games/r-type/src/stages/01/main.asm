;*******************************************************************************
; Stage 1 — l'unité échangeable
;
; Elle porte tout ce qui est propre au niveau 1 : la boucle, les deux cartes,
; la wave réelle de l'arcade, l'index d'objets. Le moteur, lui, est résident et
; n'est jamais rechargé — le stage l'atteint par les EXTERNAL d'api.asm.
;
; Ce que le stage EXPORTe, c'est son interface : les deux tables que le moteur
; relit. La région du layout est déclarée interface="true", donc le builder
; exige des deux stages la même liste d'exports.
;*******************************************************************************

STAGE_ID equ 1

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

; Les ennemis propres au niveau, ranges eux aussi dans le comblement des
; pagesets de tuiles (scant cote impair, son tir cote pair).
scant.Object      EXTERNAL
scantfire.Object  EXTERNAL

; La table des scripts d'animation, commune a tous les stages et dans sa
; propre page : moveByScript la lit par page montee.
Ani_Asd_common    EXTERNAL

; Le masque du champ de jeu, dans la page des overlays. Ce n'est pas un objet :
; il n'a ni etat ni OST, sa page est une equate (common.overlay.page) et son adresse
; ce symbole — paged.call suffit a l'atteindre.
adr_playfield_mask_ND0 EXTERNAL

; Le champ d'etoiles, meme page que le masque. Trois routines sans etat, visees
; directement : pas d'ObjID, pas de commande en registre.
; Le HUD, meme page que le masque et les etoiles : une routine sans etat,
; visee par son symbole.
hud.normal        EXTERNAL

starfield.init    EXTERNAL
starfield.erase   EXTERNAL
starfield.draw    EXTERNAL

; Le joueur, dans sa page a lui : l'index d'objets du stage y renvoie pour les
; trois tables — objet, animation et images.
Player            EXTERNAL

; L'unite de collision terrain du stage, dans sa page : quatre points d'entree
; a +0/+3/+6/+9, que terrainCollision.init.do adresse par l'index d'objets.
terrainCollision.unit EXTERNAL

; Les flammes de reacteur de la sequence d'ouverture, dans leur page.
engineflames.Object   EXTERNAL

; Le son : le lecteur et le pilote de bruitages vivent dans leurs pages, le
; morceau de CE stage dans celle des donnees musicales.
ymm.obj.play      EXTERNAL
ymm.frame.play    EXTERNAL
soundfx.frame     EXTERNAL
sounds.level1.ymm EXTERNAL
stage.music       equ sounds.level1.ymm

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
pstaff.Object   EXTERNAL
cancer.Object   EXTERNAL
shell.Object    EXTERNAL
tabrok.Object   EXTERNAL
; Ce que ces deux-la font naitre ou servent : le canon du tabrok, cree par le
; tank, et l'effaceur de la rotonde, que la boucle de trame appelle.
tabrokcanon.Object EXTERNAL
shellEraser.Object EXTERNAL
; Le missile et sa flamme : mutualises entre les ennemis et l'arme du joueur.
commonmissile.Object      EXTERNAL
commonmissileflame.Object EXTERNAL
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
        INCLUDE "gen/stages/01/pages.asm"
        INCLUDE "gen/stages/01/pages-even.asm"
        ; Les pages du cast commun, publiees par son pageset : l'index
        ; d'objets lit <symbole>.page pour chaque ennemi range.
        INCLUDE "gen/enemies/cast-pages.asm"
        INCLUDE "src/stages/01/map/intro/map.const.asm"

 opt c,ct

        ; le loader saute sur le premier octet de la région : la boucle d'abord
        INCLUDE "src/stages/stage-main.asm"

;*******************************************************************************
; Ce qui distingue ce stage
;*******************************************************************************
; Les points de reprise de CE stage, en tuiles de collision (24 px), la
; sentinelle -1 en butoir — la table du game mode v1.
checkpoint.positions EXPORT
checkpoint.positions
        fcb   0
        fcb   3
        fcb   18
        fcb   39
        fcb   -1

; La sequence d'ouverture de CE stage : un slot du pool, l'identifiant, et
; RunObjects fait le reste. La v1 ensemence exactement de meme (main.asm:171).
stage.openingSequence
        jsr   LoadObject_x
        beq   >                            ; pool plein : on ouvre sans intro
        lda   #ObjID_initlevel1
        sta   id,x
!       rts

; `stage.setup`
; RESTE ici : il consomme map.even/odd et stage.wave, fournis par un pageset et
; un block qui n'emettent pas de donnees de lien — une unite passant par le
; loader ne peut donc pas les atteindre.
stage.setup
        ; Le decor de FOND arrete les projectiles sur ce niveau — la v1 le pose
        ; a 1 dans l'init de son main (main.asm:130). C'est par stage : les
        ; niveaux 5 et 7 le mettent a zero.
        lda   #1
        sta   globals.backgroundSolid

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
        lda   #map.RAM_OVER_CART+maps.page
        sta   scroll_map_page_even
        sta   scroll_map_page_odd

        ldd   #stage.wave
        std   object_wave_data
        std   object_wave_data_start
        lda   #map.RAM_OVER_CART+stage.wave.page
        sta   object_wave_data_page

        ; La table d'effacement de la rotonde part vide : un slot non nul
        ; herite de la partie precedente et efface un shell qui n'existe pas.
        ; La v1 fait le meme geste a l'ouverture ET au checkpoint
        ; (main.asm:101 et 324) ; ici stage.setup couvre les deux, il est
        ; rejoue a chaque entree dans le niveau.
        ldx   #shellEraseTable
!       clr   ,x+
        cmpx  #shellEraseTable_end
        blo   <
        rts
; Deux passages : à l'aller on sème l'état et on part sur le stage 2 ; au
; retour on constate que l'échange est réversible et on exerce le checkpoint.
stage.handOver
        jsr   IrqOff

        lda   game.stage
        cmpa  #2
        beq   stage1.secondVisit

        ; --- premier passage ---
        ldd   bench.spawns
        beq   stage1.noSpawn                     ; la wave n'a rien peuplé : témoin muet
        std   bench.stage1Spawns
        lda   #$01
        sta   bench.t1
stage1.noSpawn
        lda   #1
        sta   game.stage
        ldx   #scenes.stage2
        jmp   game.stage.switch

        ; --- retour, après le stage 2 ---
stage1.secondVisit
        lda   #$01
        sta   bench.t4

        ; Checkpoint sans disque : on rembobine la wave et on demande à
        ; ObjectWave_Init de la recaler sur l'horloge de jeu. Elle doit
        ; retrouver exactement la position que la lecture normale avait
        ; atteinte — c'est le mécanisme de reprise en cours de niveau.
        ldd   object_wave_data
        pshs  d
        ldd   object_wave_data_start
        std   object_wave_data
        jsr   ObjectWave_Init
        ldd   object_wave_data
        cmpd  ,s++
        bne   stage1.noCheckpoint
        lda   #$01
        sta   bench.t5
stage1.noCheckpoint

stage1.idle   bra   stage1.idle

;*******************************************************************************
; L'index d'objets et la wave — les données réelles du niveau 1
;*******************************************************************************
; La sequence d'ouverture : le vaisseau entre en autopilote par la gauche,
; flammes allumees, puis rend la main. C'est un objet de CE stage (la v1 le
; range dans objects/player1/initlevel1 mais le declare par game mode), donc il
; L'init du niveau est un OBJET MONTE, comme en v1 (_Obj_Run ObjID_LevelInit) :
; region `stageinit`, page du terrain. Son entree traverse le lien.
initlevel1.Object EXTERNAL

        INCLUDE "src/stages/01/objid.const.asm"
        INCLUDE "src/stages/01/objid.index.asm"

; La table d'effacement de la rotonde : 14 emplacements de deux positions (un
; par tampon), que chaque shell remplit et que l'effaceur relit. Elle vit dans
; le stage — c'est de la RAM propre au niveau 1, comme en v1 (ram_data.asm) —
; et traverse la frontiere de lien vers les deux unites qui la partagent.
;
; Elle DOIT etre remise a zero a l'ouverture du niveau et au rechargement de
; checkpoint, sinon des positions fantomes s'effacent sur des shells absents.
shellEraseTable     EXPORT
shellEraseTable_end EXPORT
shellEraseTable
        fill  0,14*4
shellEraseTable_end


 ENDSECTION

; Les deux cartes sont générées par les éléments <tilemap> de la config, dans
; leur propre section map.static : leurs références de tuiles sont cuites au
; build contre la région déclarée du tileset, donc elles ne coûtent aucune
; donnée de lien au chargement.
