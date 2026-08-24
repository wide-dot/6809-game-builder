;*******************************************************************************
; pscroll.res — la part RESIDENTE du champ de gommes du stage 4
;
; Ce qui doit rester en RAM fixe, et rien de plus :
;   - `do`, qui peint la fenetre depuis le ruban. Il lui faut l'ECRAN monte en
;     $A000 ; la page du module n'y est donc pas a cet instant ;
;   - `runBuffer`, qu'il appelle ;
;   - TOUTES les variables du module, pour la meme raison : `do` ne peut pas
;     lire une variable qui vivrait dans une page non montee.
;
; Le reste — gravure, scroll, ajout, effacement — vit dans pscroll.edit, une
; page montee en $A000 le temps de l'appel. C'est possible parce qu'aucune de
; ces phases n'a besoin de l'ecran.
;*******************************************************************************

pscroll.stage4.frame EXPORT
pscroll.gum.set      EXPORT              ; les relais pour le CODE OBJET
pscroll.gum.clear    EXPORT
pscroll.gum.rect     EXPORT
pscroll.gum.grow     EXPORT
pscroll.half.on      EXPORT              ; l'init de la part cartouche en a
pscroll.half.off     EXPORT              ; besoin : elle appelle la part $4000

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "gen/layout.asm"
        INCLUDE "gen/stages/04/map/map.const.asm"
field.MAP_W        equ map.COLS*12
field.VP_Y         equ 11
pscroll.CELL_W     equ 3
pscroll.BAND_LINES equ 180
pscroll.MAP_WIDTH  equ field.MAP_W
pscroll.MAX_SEAMS  equ 8
PSCROLL_PART       equ 0                ; la part residente

pscroll.move       EXTERNAL              ; la part CARTOUCHE
pscroll.setCell    EXTERNAL
pscroll.clearCell  EXTERNAL
pscroll.clearRect  EXTERNAL
pscroll.grow       EXTERNAL
paged.call         EXTERNAL

 SECTION code

        INCLUDE "engine/graphics/tilemap/pscroll/pscroll.asm"

; -----------------------------------------------------------------------------
; pscroll.stage4.frame — la trame : s'y rendre, puis peindre
; -----------------------------------------------------------------------------
; input REG : [d] LA position camera du moteur (glb_camera_x_pos), en px
;
; Le champ de gommes n'a pas de camera a lui : il va ou la camera du moteur
; est.
;
; MOVE D'ABORD, DO ENSUITE — et c'est ce qui met le plan en phase avec le reste
; de la trame. `do` peint a pscroll.camera.x ; tant que `move` passait apres,
; il peignait la position du TOUR PRECEDENT pendant que DrawTiles et
; BuildSprites, plus loin dans le meme verrou gfxlock, travaillaient sur le
; glb_camera_x_pos du tour courant. Le plan de gommes trainait donc d'un tour
; entier derriere la tuilerie — cinq a huit pixels au regime observe du stage,
; et un decalage qui bougeait avec le frame drop. D'ou l'impression d'une
; couche « qui a sa propre vie ».
;
; Cet ordre est aussi le bon vis-a-vis du ruban : `move` grave la bande qui
; entre AVANT que `do` ne la peigne.
;
; L'ECRAN NE BOUGE PAS. La fenetre DONNEES garde sa page ecran d'un bout a
; l'autre : la part cartouche n'en a pas besoin, et rien de pscroll ne vit
; plus en $A000 — le bitfield tient dans la page cartouche avec le code qui
; le lit. C'est la coupe « qui monte un buffer » qui rend ca possible.
;
; paged.call monte bien dans la fenetre CARTOUCHE, celle que pscroll commute
; pour ses buffers — mais plus rien ne s'y demonte : les routines qui montent
; un buffer vivent en RAM FIXE ($4000) et REMONTENT pscroll.cart.page avant
; leur rts. C'est ce qui a coute le PC $4F43 du 23/08.
; -----------------------------------------------------------------------------
pscroll.stage4.frame
        std   pscroll.camera.next
        ; LA PAGE DE L'APPELANT, SAUVEE AVANT `do`. `do` commute la fenetre
        ; cartouche vers ses buffers et ne rend rien — c'est son droit, il est
        ; resident. Mais l'appelant, lui, est stage-main, qui VIT dans cette
        ; fenetre : sans cette sauvegarde, le `rts` final revient dans une page
        ; buffer. Et paged.call ne peut pas y suppleer — il relit $E7E6 APRES
        ; `do`, donc il sauverait la page du dernier buffer en croyant sauver
        ; celle de l'appelant. Le stage tournait 10 trames puis deraillait
        ; (DP=$E7, page cartouche 00), 24/08.
        _GetCartPageB
        pshs  b
        bsr   pscroll.half.on              ; la part $4000 doit etre VISIBLE
        lda   #map.RAM_OVER_CART+pscroll.edit.page
        sta   pscroll.cart.page            ; ce que la part $4000 remontera
        ldx   #pscroll.move                ; apres chaque commutation de buffer
        jsr   paged.call                   ; monte, appelle, rend sa page
        bsr   pscroll.half.off
        jsr   pscroll.do                   ; peindre LA position du tour courant
        puls  b                            ; et l'appelant retrouve la sienne
        _SetCartPageB
        rts

; -----------------------------------------------------------------------------
; pscroll.half.on / .off — RENDRE LA PART $4000 VISIBLE, ET LA RENDRE
; -----------------------------------------------------------------------------
; $4000-$5FFF n'est PAS de la RAM fixe inconditionnelle : c'est une demi-page,
; choisie par le bit 0 de $E7C3 (MC6846 PDR). _gfxlock.init l'epingle a 0 sous
; OverlayMode — et la demi-page 0, c'est le POOL D'OBJETS (Dynamic_Object_RAM
; = $4000, 60 slots + 4 OST statiques). La part $4000 de pscroll vit donc dans
; la demi-page 1, celle que la config declare libre, et il faut la MONTER pour
; l'atteindre. Sans ca on tombe sur le pool : le stage tournait 10 trames puis
; marchait dans des zeros ($4F4B, 2 octets par instruction), 24/08.
;
; ON NE POSE QUE LE BIT 0, JAMAIS L'OCTET. La version d'avant sauvait $E7C3
; entier a l'entree et le reecrivait entier a la sortie — invalide deux fois :
; les bits 1-7 sont de l'I/O VIVANTE (timer, clavier, disque), donc les remettre
; a une valeur lue plus tot rejoue du perime dans le materiel ; et l'octet sauve
; etait un global unique, donc deux montages imbriques auraient rendu la
; demi-page 1 au lieu de la 0. Il n'y a rien a sauver : le jeu tourne demi-page
; 0 par contrat (InitGlobals l'epingle au premier geste du game mode), donc
; « rendre » c'est remettre le bit a 0. C'est exactement ce que font les macros
; _gfxlock.halfPage.set0/.set1 du gfxlock thomson.
; -----------------------------------------------------------------------------
pscroll.half.on
        lda   map.HALFPAGE
        ora   #$01                         ; demi-page 1 : la notre
        sta   map.HALFPAGE
        rts

pscroll.half.off
        lda   map.HALFPAGE
        anda  #%11111110                   ; demi-page 0 : celle du pool
        sta   map.HALFPAGE
        rts

; -----------------------------------------------------------------------------
; pscroll.gum.set / .clear / .rect — LE CHAMP, VU DU CODE OBJET
; -----------------------------------------------------------------------------
; input REG : set/clear   [x] la colonne, [b] la rangee
;             rect        les bornes, dans pscroll.rect.* (poses par l'appelant)
;
; POURQUOI DES RELAIS. Une arme, le cytron, un tir : chacun vit dans SA page
; cartouche. Toucher le champ demande d'y monter celle de pscroll — donc de
; DEMONTER l'appelant, dont le code disparait le temps de l'appel. Le trajet
; complet ne peut donc se faire que depuis la RAM fixe, et c'est ici.
;
; LE CAS QUI A COUTE LA SOIREE DU 24/08 : le cytron appelait `pscroll.grow`
; en DIRECT (`jmp pscroll.grow`, un EXTERNAL resolu par le loader a l'adresse
; de pscroll.edit) SANS monter la page de pscroll.edit — le cytron vit dans
; SA propre page (arena stage4.gfx). Le jmp sautait donc a l'offset resolu,
; mais la fenetre cartouche montrait toujours la page du cytron : le CPU
; executait les octets de LA PAGE DU CYTRON a cet offset — du hasard qui
; RESSEMBLE a du code (ANDB/ORB/STD…) jusqu'a corrompre l'OST courant. Track
; complet : RunObjects dispatche le cytron (ObjID 39) -> jmp pscroll.grow non
; monte -> execution dans la page du cytron -> STD ,U ecrit n'importe quoi
; dans l'OST du cytron lui-meme (U) -> la trame suivante redispatche cet OST
; avec un id devenu garbage -> jsr [,x] saute dans une table -> marche dans
; les zeros -> gel. Chasse aux breakpoints/watchpoints, jamais reproduite au
; premier coup : voir la session du 24/08 pour la methode.
;
; Le trajet, en entier :
;   1. la page de l'appelant est relue ($E7E6 se relit) et mise de cote ;
;   2. la page pscroll est montee, et posee dans pscroll.cart.page — c'est
;      elle que les routines de la part $4000 remonteront apres avoir commute
;      la fenetre vers un buffer ;
;   3. la routine cartouche fait le travail (elle appelle $4000, qui monte le
;      buffer, ecrit, et remonte pscroll.cart.page avant son rts) ;
;   4. la page de l'appelant revient, et SES REGISTRES AVEC — U EN PARTICULIER
;      (c'est l'OST de l'objet : le code appelant ne survit pas a sa perte),
;      plus Y et DP.
;
; CC N'EST PAS RESTAURE : clearRect rend son verdict dedans (C = refus, Z =
; champ inchange). Les relais le laissent passer tel quel.
;
; B est pousse AVANT _GetCartPageB, qui l'ecrase : c'est la rangee.
; -----------------------------------------------------------------------------
pscroll.gum.set
        pshs  u,y,dp,b
        bsr   pscroll.gum.enter
        puls  b                            ; la rangee revient
        jsr   pscroll.setCell
        bra   pscroll.gum.leave

pscroll.gum.clear
        pshs  u,y,dp,b
        bsr   pscroll.gum.enter
        puls  b
        jsr   pscroll.clearCell
        bra   pscroll.gum.leave

pscroll.gum.rect
        pshs  u,y,dp,b
        bsr   pscroll.gum.enter
        puls  b
        jsr   pscroll.clearRect
        bra   pscroll.gum.leave

; input REG : [x] la position ecran (pscroll.grow.x), [b] la ligne ecran
pscroll.gum.grow
        pshs  u,y,dp,b
        bsr   pscroll.gum.enter             ; ne touche pas X : x survit
        puls  b
        jsr   pscroll.grow
        bra   pscroll.gum.leave

; monter pscroll en gardant de quoi revenir
pscroll.gum.enter
        bsr   pscroll.half.on              ; meme raison que dans la trame
        _GetCartPageB
        stb   pscroll.gum.caller
        lda   #map.RAM_OVER_CART+pscroll.edit.page
        sta   pscroll.cart.page            ; ce que la part $4000 remontera
        _SetCartPageA
        rts

; rendre sa page a l'appelant, puis ses registres — CC intact
pscroll.gum.leave
        pshs  cc
        bsr   pscroll.half.off
        ldb   pscroll.gum.caller
        _SetCartPageB
        puls  cc
        puls  dp,y,u,pc

pscroll.gum.caller  fcb 0
