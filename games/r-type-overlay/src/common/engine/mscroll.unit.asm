;*******************************************************************************
; mscroll résident — le scroll multidirectionnel par buffer de code
;
; La couche battleship du stage 3 : une carte 2D défile librement sur les
; deux axes derrière la tilemap (qui garde le premier plan, nuages ici —
; l'ordre arcade). Le module vit en RÉSIDENT parce que ses appels par trame
; (do/move) commutent eux-mêmes la fenêtre cartouche : du code paginé s'y
; retirerait le sol sous les pieds. Sa place est celle que le pool d'objets
; a rendue en déménageant dans la demi-page 0 (2026-08-20).
;
; Sur les stages sans couche mobile le module est INERTE : personne n'appelle
; do/move, il n'occupe que sa RAM. Réutilisable plus tard pour des fonds.
;
; IMPORTANT (décision auteur) : sur un stage à mscroll, le clear du playfield
; (clearblast/clearWindow) est DÉSACTIVÉ — le blast mscroll repeint chaque
; pixel de la bande à chaque trame, c'est lui l'effaceur. Le branchement se
; fait dans stage-main.asm sous STAGE_MSCROLL.
;
; La frontière avec un stage tient en HUIT noms (discipline api.asm) :
;   mscroll.setup          init complet depuis un bloc de paramètres (X)
;   mscroll.do             le blast (entre _gfxlock.on et .off, AVANT DrawTiles)
;   mscroll.move           caméra + feeds (après le blast)
;   mscroll.camera.speed   vitesse y 8.8 (mode vitesse : intégrée x trames)
;   mscroll.camera.speedx  vitesse x 8.8
;   mscroll.camera.impulse déplacement exact 8.8 (X=dx, D=dy) — mode pilote :
;                          l'appelant dépile lui-même les trames écoulées et
;                          pousse la somme, vitesses laissées à zéro
;   mscroll.camera.x       position x (le spawn script du warship s'y compare)
;   mscroll.camera.y       position y
;
; Bloc de paramètres de mscroll.setup (14 octets, pointé par X) :
;   +0  objid carte            (byte — Obj_Index du stage)
;   +1  objid tileset plan A   (byte)
;   +2  objid tileset plan B   (byte)
;   +3  objid buffer plan A    (byte)
;   +4  objid buffer plan B    (byte)
;   +5  hauteur map en px      (word, multiple de 16)
;   +7  largeur map en px      (word)
;   +9  rowshift               (byte, log2 du stride)
;  +10  camera y0              (word)
;  +12  viewport y             (byte, ligne écran du haut de bande)
;  +13  viewport height        (byte)
; camera x0 = 0 imposé : le buffer de départ généré par <mscroll> couvre la
; vue (0, y0). Les tilesets sont tile-major (une page par plan, format
; produit par l'élément <mscroll> du builder).
;*******************************************************************************

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/graphics/tilemap/mscroll/mscroll.macro.asm"

 opt c,ct

; --- la frontière ---
mscroll.setup         EXPORT
mscroll.do            EXPORT
mscroll.move          EXPORT
mscroll.camera.speed  EXPORT
mscroll.camera.speedx EXPORT
mscroll.camera.impulse EXPORT
mscroll.camera.x      EXPORT
mscroll.camera.y      EXPORT

; l'horloge de compensation du moteur, et les tables d'objets du stage
; courant — le re-link global les repointe à chaque échange de stage,
; la porte que le moteur emprunte déjà (stage-tables.asm)
gfxlock.frameDrop.count EXTERNAL
Obj_Index_Page          EXTERNAL
Obj_Index_Address       EXTERNAL

; la géométrie du buffer, figée pour le jeu : le viewport r-type (180 lignes,
; posé dans le masque HUD) + la ligne trash cachée sous le masque du haut
mscroll.BUFFER_LINES  equ 181

        INCLUDE "engine/graphics/tilemap/mscroll/mscroll.asm"

;*******************************************************************************
; mscroll.setup — l'init complet depuis un bloc de paramètres
;
; Entrée : X = bloc (voir l'en-tête). Sort avec les vitesses à zéro, la
; caméra en (0, y0), le cursor ancré sur le buffer de départ généré.
; Les macros _mscroll.set* restent la source de vérité : la façade copie le
; bloc dans un scratch et les invoque avec des opérandes mémoire.
;*******************************************************************************
mscroll.setup.blk     fill  0,14

mscroll.setup
        ; RAM FROIDE : tout l'etat du module part de zero avant les macros —
        ; elles n'initialisent que ce qu'elles possedent, et un accumulateur
        ; 8.8 residuel survit meme a setCameraSpeed #0 (il ne purge que les
        ; negatifs). Vecu : un accumulateur poubelle a projete la camera de
        ; +375 px a l'ouverture du stage. Deux plages, car la table constante
        ; slot.off vit au milieu des variables.
        pshs  x
        lda   #0
        ldx   #mscroll.obj.map.page
!       sta   ,x+
        cmpx  #mscroll.slot.off        ; taille impaire : effacement par
        blo   <                        ; octets, la table constante juste
        ldx   #mscroll.viewport.height.w ; derriere ne doit pas etre mordue
!       sta   ,x+
        cmpx  #mscroll.camera.lastY+2
        blo   <
        puls  x
        ldu   #mscroll.setup.blk
        ldb   #14
!       lda   ,x+
        sta   ,u+
        decb
        bne   <
        _mscroll.setMap       mscroll.setup.blk+0
        _mscroll.setMapHeight mscroll.setup.blk+5
        _mscroll.setMapWidth  mscroll.setup.blk+7
        _mscroll.setMapRowShift mscroll.setup.blk+9
        ; tilesets tile-major : une page par plan — les 16 paires de lignes
        ; de mscroll.obj.tile.pages portent toutes le même couple (A,B)
        ldx   #Obj_Index_Page
        ldb   mscroll.setup.blk+1
        lda   b,x                      ; page du plan A
        ldb   mscroll.setup.blk+2
        pshs  a
        lda   b,x                      ; page du plan B
        tfr   a,b
        puls  a                        ; d = (page A, page B)
        ldx   #mscroll.obj.tile.pages
!       std   ,x++
        cmpx  #mscroll.obj.tile.pages+32
        bne   <
        _mscroll.setTileLut
        _mscroll.setBuffer    mscroll.setup.blk+3,mscroll.setup.blk+4
        _mscroll.setCameraSpeed  #0
        _mscroll.setCameraSpeedX #0
        _mscroll.setCameraPos mscroll.setup.blk+10
        _mscroll.setCameraPosX #0
        _mscroll.setViewport  mscroll.setup.blk+12,mscroll.setup.blk+13
        rts

 ENDSECTION
