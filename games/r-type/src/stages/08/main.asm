;*******************************************************************************
; Stage 8 — mis en place avec sa carte (chantier stages 3-8)
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

STAGE_ID equ 8
; La scène de CE stage — voir stage 1 : le sortant décharge, jamais l'entrant.
STAGE_SCENE equ scenes.stage8
; La carte de ce stage est en colonnes creuses (<tilecols> dans le config) :
; stage-main.asm appelle ScrollCols/DrawTilesCols et pose tilemap.mode.
stage.TILES_COLS equ 1
; LA PRIORITE PAR CELLULE : le mur bleu du fond de la salle du noyau (les huit
; dernieres colonnes de cellules du plan arcade) est derriere les sprites a la
; borne, le reste devant — seconde table peinte avant (stage.frame.tilesBack).
stage.TILES_PRIO equ 1
; Ce stage peint DEVANT ses tuiles : la tete et les tentacules du Bydo sont
; des patchs du plan de fond arcade a bit de priorite (devant les sprites),
; et nos tuiles passent apres les sprites. stage-main.asm appelle
; stage.frameFront juste apres elles (crochet opt-in, les autres stages n'en
; paient rien).
stage.FRONT equ 1
; Ce stage termine le JEU : apres le fondu, la sequence de fin de la borne
; (src/stages/08/ending/) — pas de HUD, des etoiles, la flotte, le generique.
stage.ENDING equ 1

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
map.even.behind   EXTERNAL
map.odd.behind    EXTERNAL

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
adr_viewport_ND0  EXTERNAL
credits.Draw      EXTERNAL
ending.ClearField EXTERNAL
; L'effacement du champ de jeu, meme page : peint en tete de trame.
adr_playfield_clear_ND0 EXTERNAL
playfield.clearBlast    EXTERNAL

; Le champ d'etoiles, meme page que le masque. Trois routines sans etat, visees
; directement : pas d'ObjID, pas de commande en registre.
; Le HUD, meme page que le masque et les etoiles : une routine sans etat,
; visee par son symbole.
hud.normal        EXTERNAL
; Cite par la boucle commune (phase 4 de la sequence de fin) ; le stage 2 n'y
; passe jamais, mais le symbole doit se resoudre.
hud.readout       EXTERNAL
; L'ecran CONTINUE, meme page : il partage la police du releve de fin.
hud.continue      EXTERNAL
; L'attente qui tient GAME OVER a l'ecran le temps de son morceau.
hud.gameOverWait  EXTERNAL

starfield.init    EXTERNAL
starfield.kill    EXTERNAL
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
sounds.level8.ymm EXTERNAL
stage.music       equ sounds.level8.ymm
stage.music.page  equ stage8.music.ymm.page

; Le sequenceur de fin generique (protocole du stage 1, objet commun monte
; au boot). Pas de jingle au stage 8 : son bloc musical n'a pas la place.
endlevel.Object       EXTERNAL

; Le marqueur de musique du boss, seme par la wave : il pose le drapeau que
; stage.endTick releve pour changer de morceau.
bossmusic.Object      EXTERNAL

; Le BOSS, dans son propre direntry (stage8.bydo) : le noyau (toute sa
; famille, en repere arcade) et le renderer groupe de ses Win. Ses boites,
; ses creneaux et ses deux boucles de dessin sont RESIDENTS (plus bas).
bydo.Object       EXTERNAL
bydo.Render       EXTERNAL
bydo.boxes        EXPORT
bydo.slots        EXPORT
bydo.DrawAll      EXPORT

; LE MIKUN, dans son propre direntry (stage8.mikun) : l'emetteur invisible de
; la wave et le mikun qu'il pond.
mikun.Object      EXTERNAL
mikun.Unit        EXTERNAL

; LA FIN DU JEU, dans son propre direntry (stage8.ending) : le directeur du
; generique et la flotte, en repere arcade. Ce qui doit etre RESIDENT vit
; ici (plus bas) : l'etat que la boucle lit, et le texte, que le dessin lit
; avec la page du HUD montee.
ending.Object     EXTERNAL
ending.Render     EXTERNAL
ending.rowText    EXPORT
ending.textY      EXPORT
ending.hudOff     EXPORT
ending.done       EXPORT
ending.Slots      EXPORT
ending.clock      EXPORT
ending.gc0        EXPORT
ending.black      EXPORT
ending.music      EXPORT
sounds.ending.ymm EXTERNAL
sounds.boss.ymm   EXTERNAL

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
groundlaser.Object EXTERNAL
counterairreflect.Object EXTERNAL

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
        ; player1.equ : forcepod_attached, que la restauration d'armement du
        ; corps commun pose pour faire renaitre le pod ACCROCHE.
        INCLUDE "src/common/player/player1.equ"

        ; Les variables inter-main, en equates absolues de la zone reservee
        ; `globals` : la boucle les remet a zero a l'entree du stage, comme la
        ; v1 le fait dans l'init de son main.
        INCLUDE "src/common/state/variables.asm"

        INCLUDE "gen/layout.asm"
        INCLUDE "src/common/bench.const.asm"
        INCLUDE "gen/stages/08/map/map.const.asm"

 opt c,ct

        INCLUDE "src/stages/stage-main.asm"

;*******************************************************************************
; Ce qui distingue ce stage
;*******************************************************************************
; Les points de reprise de CE stage, en tuiles de collision (24 px), la
; sentinelle -1 en butoir. La wave arcade de ce stage ne seme AUCUN objet
; checkpoint (comme sa table de reference v1, reduite au point de depart) :
; on repart du debut du niveau a chaque mort.
checkpoint.positions EXPORT
checkpoint.positions
        fcb   0
        fcb   -1

; Ce stage n'a pas de sequence d'ouverture : le banc y entre par un echange,
; pas par un debut de partie. Le corps commun l'appelle quand meme — chaque
; stage repond, quitte a ne rien faire.
stage.openingSequence
        ; Pas de vol d'intro ici (arcade : le record du joueur survit a la
        ; transition et garde la position du stage cleared) — l'index de CE
        ; stage pointe ObjID_initlevel1 sur stage.parked, qui replace le
        ; vaisseau au point de ralliement une fois l'Init du joueur passe.
        jsr   LoadObject_x
        beq   >                            ; pool plein : on ouvre sans repose
        lda   #ObjID_initlevel1
        sta   id,x
!       rts

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
main.endstage.rallyX     EXPORT
main.endstage.rallyY     EXPORT
main.endstage.duration   EXPORT
main.endstage.fadeMode   EXPORT
main.endstage.counter    fdb 0  ; compte a rebours de fin (0 : pas arme)
main.endstage.phase      fcb 0  ; 0 jeu, 1 jingle+autopilote, 2 glissee, 3 pre-fondu (2 rendus), 4 fondu, 5 releve
main.endstage.scoreArmed fcb 0  ; 1 : le HUD (re)seme le releve du score du stage
main.endstage.scoreDone  fcb 0  ; 1 : releve fini -> la sequence quitte le niveau
; Le point de ralliement de l'autopilote, publie par LE STAGE : l'objet
; endlevel est un binaire commun, il ne peut pas porter une valeur par stage.
; Le stage 8 ne s'acheve pas, il TERMINE LE JEU : pas de stage cleared,
; mais la sequence de fin. Le vaisseau y est place pour la scene finale et
; non rallie au centre pour un releve de score (drapeau 0x0F en 0x40:C21C). Table arcade complete : endlevel.const.asm.
main.endstage.rallyX     fdb endstage.RALLY_X_ENDING
main.endstage.rallyY     fdb endstage.RALLY_Y_ENDING
; La duree armee par bossDefeated et la voie du fondu, publiees par LE
; STAGE (endlevel.const.asm) : le compte du Dobkeratops, le fondu par
; tramage — les valeurs d'avant le 08/09/2026.
main.endstage.duration   fdb endstage.DURATION_LATCHED ; le Bydo leve le drapeau a l'heure arcade
main.endstage.fadeMode   fcb endstage.FADE_ENDING ; le tramage, puis la sequence de fin

stage.endTick
        ; LES MUSIQUES DU BOSS ET DE LA FIN : le noyau pose les drapeaux a
        ; l'heure arcade (0x19 en 40:C2F0, 0x1A en 40:C210), le stage change
        ; de morceau — le lecteur ne se monte pas depuis un objet pagine.
        lda   globals.nextGameMode
        beq   >
        clr   globals.nextGameMode
        jsr   IrqOff
        _GetCartPageB
        pshs  b
        _ymm.obj.play #map.RAM_OVER_CART+common.music.ymm.page,#sounds.boss.ymm,#ymm.LOOP,#ymm.NO_CALLBACK
        puls  b
        _SetCartPageB
        jsr   IrqOn
!       ldb   ending.music              ; 1 : la musique de fin, $FF : le
        beq   >                         ; silence (les instants mesures sur
        clr   ending.music              ; la borne, voir bydo/obj.asm)
        jsr   IrqOff                    ; (rend B intact)
        incb
        bne   @play
        jsr   ymm.stop
        bra   @on
@play   _GetCartPageB
        pshs  b
        _ymm.obj.play #map.RAM_OVER_CART+stage8.music.ymm.page,#sounds.ending.ymm,#ymm.NO_LOOP,#ymm.NO_CALLBACK
        puls  b
        _SetCartPageB
@on     jsr   IrqOn
        ; La sequence de fin decide, pas la camera — voir le commentaire des
        ; trois rendez-vous.
!       lda   ending.on
        bne   stage.endTick.ending
        _Obj_RunB ObjID_endstage,#endstage.TICK
        cmpb  #endstage.STATUS_JINGLE
        beq   stage.endTick.jingle
        cmpb  #endstage.STATUS_ENDING
        beq   stage.endTick.start
        cmpb  #endstage.STATUS_DONE
        beq   stage.endTick.done
        rts

stage.endTick.start
        ; LA FIN DU JEU (16/10/2026). Le tramage est fini, le vaisseau seul
        ; sur le noir : l'objet commun s'arrete la et le stage reprend
        ; l'ecran — la boucle repeint (phase 0), sans decor (plainBackdrop :
        ; le noir et les etoiles), sans HUD, et l'objet de fin deroule la
        ; chronologie de la borne. Le vaisseau reste gare au point de
        ; ralliement, comme sur la borne.
        lda   #1
        sta   ending.on
        sta   ending.hudOff
        sta   globals.plainBackdrop
        clr   main.endstage.phase
        jsr   LoadObject_x
        beq   >
        lda   #ObjID_ending
        sta   id,x
!       rts

stage.endTick.ending
        lda   ending.black              ; 40:EF89 le noir
        beq   >
        clr   ending.black
        jsr   ending.FadeBlack
!       lda   ending.done               ; 40:EF9D, le directeur est fini
        beq   @rts
        ldb   palettefade+routine       ; ... et le noir est complet
        cmpb  #o_fade_routine_idle
        bne   @rts
        deca                            ; 1 : le bonus game
        lbeq  stage.handOver
        clr   globals.lives             ; 2 : 40:EF5D, le second tour finit
        lda   #mainloop.state.CHECKPOINT ; au GAME OVER du corps de stage (vies
        sta   mainloop.state            ; a zero, que le decompte rend
@rts    rts                             ; negatives ; continue refuse)

; le noir de la fin : la palette vers le noir, 16 pas de 4 trames
ending.FadeBlack
        pshs  u
        ldu   #palettefade
        clr   routine,u
        lda   #1                        ; chronometre : par trame VIDEO
        sta   o_fade_drop,u
        ldx   #Pal_black
        stx   o_fade_dst,u
        lda   #4
        sta   o_fade_wait,u
        ldd   Pal_current
        std   o_fade_src,u
        ldd   #0
        std   o_fade_sleep,u
        std   o_fade_callback,u
        puls  u,pc

stage.endTick.jingle
        ; Pas de jingle : la fin du jeu joue deja sa musique (le noyau l'a
        ; lancee au nettoyage de la salle). L'autopilote prend le vaisseau,
        ; qui ne peut plus mourir — le terrain est coupe : le defilement
        ; repart sur la queue blanche de la carte, que la collision ne
        ; connait pas.
        lda   #1
        sta   terrainCollision.disabled
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
        lda   #map.RAM_OVER_CART+stage8.maps.page
        sta   scroll_map_page_even
        sta   scroll_map_page_odd

        ldd   #stage.wave
        std   object_wave_data
        std   object_wave_data_start
        lda   #map.RAM_OVER_CART+stage8.wave.page
        sta   object_wave_data_page

        ; Le sequencement de fin : remis a zero par l'objet commun, a
        ; l'ouverture ET au rechargement de checkpoint — stage.setup couvre
        ; les deux, comme au stage 1.
        _Obj_RunB ObjID_endstage,#endstage.INIT
        ; la fin du jeu n'a pas commence (ouverture et retour au checkpoint)
        clr   ending.on
        clr   ending.music
        clr   ending.hudOff
        clr   ending.done
        clr   ending.black
        ldx   #ending.rowText
        ldb   #64
!       clr   ,x+
        decb
        bne   <
        ; CE STAGE A SON BOSS : le Bydo core leve lui-meme le drapeau de fin
        ; (40:C21C, 0x180 trames apres sa mort), jamais le compteur de
        ; substitution.
        lda   #1
        sta   globals.realBoss
        ; Ses creneaux sont residents et le crochet avant les lit a chaque
        ; trame : eteints a l'ouverture ET au rechargement de checkpoint.
        ldx   #bydo.slots
!       clr   ,x
        leax  6,x
        cmpx  #bydo.slotsEnd
        blo   <
        rts

;*******************************************************************************
; LE BYDO — ce qui doit etre RESIDENT (src/enemies/bydo/obj.asm)
;
; Ses boites (Collision_Do les parcourt avec une autre page montee), ses
; creneaux de dessin et les deux boucles qui les dessinent : les Win par leur
; renderer groupe (bydo.DrawAll, dans BuildSprites), la tete et les
; tentacules par le crochet avant (stage.frameFront, apres les tuiles).
;*******************************************************************************
bydo.boxes
        fill  0,5*9                    ; 4 Win, la bouche
bydo.slots                             ; [on, x, y, imageset(2), page]
        fill  0,4*6                    ; les Win
bydo.slotsFront
        fill  0,2*6                    ; les tentacules, puis la tete
bydo.slotsEnd

bydo.DrawAll
        ldd   #bydo.slotsFront
        std   bydo.DrawSlots.end
        lda   #1                         ; the wins have their shifted variant
        sta   bydo.DrawSlots.shift
        ldx   #bydo.slots
        bra   bydo.DrawSlots
stage.frameFront
        ldd   #bydo.slotsEnd
        std   bydo.DrawSlots.end
        clr   bydo.DrawSlots.shift       ; the patches sit on even columns
        ldx   #bydo.slotsFront
; X = the first slot, bydo.DrawSlots.end the end: every lit slot, its page
; mounted (Y untouched: BuildSprites calls the first entry)
bydo.DrawSlots
        _GetCartPageA
        sta   @page
@loop   lda   ,x
        beq   @next
        stx   @slot
        lda   5,x                        ; the picture's page
        _SetCartPageA
        ldd   1,x
        ldx   3,x                        ; its imageset
        pshs  a,b
        _sprite.cull bydo.DrawSlots.off
        lda   ,s
        suba  imgset.center,x
        ldb   1,s
        pshs  x
        jsr   DRS_XYToAddress
        puls  x
        ; a win moves by ONE pixel: the variant shifted by 1 px (ND1, its
        ; routine at 17) on the odd x, as BuildSprites picks it (x ^ centre)
        lda   #0
bydo.DrawSlots.shift equ *-1
        beq   @nd0
        lda   ,s
        eora  imgset.center,x
        bita  #1
        beq   @nd0
        ldx   17,x                       ; ND1
        bra   @draw
@nd0    ldx   14,x                       ; ND0
@draw   ldu   <glb_screen_location_2
        jsr   ,x
bydo.DrawSlots.off
        leas  2,s
        ldx   #0
@slot   equ   *-2
@next   leax  6,x
        cmpx  #0
bydo.DrawSlots.end equ *-2
        blo   @loop
        lda   #0
@page   equ   *-1
        _SetCartPageA
        rts

; Fin du stage 8 : la fin du jeu jouee, « ENJOY THE BONUS GAME AGAIN » —
; la borne repart au stage 1 (le second tour), score garde.
stage.handOver
        jsr   IrqOff
        ; Même geste qu'au stage 1 : la musique s'arrête avant l'échange, voir
        ; le commentaire de son handOver.
        jsr   ymm.stop                    ; lecteur resident : appel direct

        ; le second tour : son compteur et sa difficulte sont poses par la
        ; fin du jeu (ending/obj.asm, 40:EE7B)
        clr   game.stage                   ; le second tour : le stage 1
        ldb   #1
        jmp   game.stage.switch

;*******************************************************************************
; LA FIN DU JEU — ce qui doit etre RESIDENT (src/stages/08/ending/obj.asm)
;
; L'etat que la boucle lit (HUD coupe, noir, fin), les lignes ecrites par le
; directeur (une case par ligne de tilemap arcade : rang de chaine + 1, 0 =
; vide) et le defilement du texte. Le dessin vit dans l'unite de la fin, avec
; sa police (ending.DrawText).
;*******************************************************************************
ending.on      fcb   0
ending.music   fcb   0                 ; 1 : la musique de fin, $FF : le silence
ending.hudOff  fcb   0
ending.done    fcb   0
ending.black   fcb   0
ending.gc0     fdb   0                 ; la trame arcade du fondu (le noyau l'ecrit)
ending.textY   fdb   0                 ; le Y du texte, entier 9 bits
ending.rowText fill  0,64
; la flotte : ses 18 creneaux [allume, x, y, image (2), -], remplis par
; fleet.unit a chaque rendu et dessines par le rendu groupe de la fin ;
; l'horloge de la fin qu'il lit
ending.Slots   fill  0,18*6
ending.clock   fdb   0


;*******************************************************************************
; L'index d'objets et la wave — les données réelles du niveau 2
;*******************************************************************************
        INCLUDE "src/stages/08/objid.const.asm"
        INCLUDE "src/stages/08/objid.index.asm"


 ENDSECTION
