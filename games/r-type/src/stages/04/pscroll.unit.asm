;*******************************************************************************
; pscroll.unit — le champ de gommes du stage 4, en couche PERSISTANTE
;
; CE QUE CA REMPLACE. Jusqu'ici le stage 4 effaçait tout le champ de jeu
; (playfield.clearBlast, ~22 400 cycles) puis REPEIGNAIT toutes ses gommes
; (pellet.blast) — a chaque trame, meme quand rien n'avait bouge. pscroll ne
; repeint rien : le champ vit grave dans un ruban de code, et la trame se
; contente de l'executer. Le meme passage efface le fond ET pose les gommes,
; puisque le creux d'une gomme EST le fond. C'est donc pscroll.do qui remplace
; le clear screen, pas seulement la couche de gommes.
;
; OU CA VIT. Le code fait ~14 Ko avec ses tables gravees : il ne tient pas dans
; la bande residente de la page 1 (il y reste ~4,7 Ko une fois le commun et le
; stage places). Il a donc SA page, montee a l'appel par paged.call — comme
; overlay, starfield ou le decor. Ses quatre buffers de ruban sont de la RAM de
; travail dans la fenetre cartouche : le code, en fenetre donnee, peut donc les
; ecrire sans se demonter lui-meme.
;
; LE BITFIELD EST EN RAM FIXE, ET C'EST UN CONTRAT. setCell et clearCell le
; lisent ET l'ecrivent pendant que la page d'un buffer est montee : il ne peut
; pas vivre dans une page. Il prend la place que pellet.blast laisse dans la
; bande residente (1 564 octets liberes, 1 440 necessaires) et le stage l'y
; recopie au demarrage depuis la carte de collision.
;*******************************************************************************

pscroll.field.map   EXPORT              ; le bitfield, en RAM FIXE
pscroll.stage4.init EXPORT
pscroll.stage4.frame EXPORT
pscroll.grow        EXPORT
pscroll.MAP_BYTES   EXPORT

; --- la geometrie du stage 4 -------------------------------------------------
; Elle se DERIVE de la carte generee par leanscroll : une tuile fait 12 px
; larges, donc la carte en fait map.COLS * 12. Rien a tenir a jour a la main.
        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "gen/layout.asm"
        INCLUDE "gen/stages/04/map/map.const.asm"
field.MAP_W        equ map.COLS*12      ; 1 152 px pour ce stage
field.VP_Y         equ 11               ; premiere ligne ecran du champ de jeu
pscroll.CELL_W     equ 3                ; largeur d'une gomme, en px larges
pscroll.BAND_LINES equ 180              ; 30 rangees de 6 lignes
pscroll.MAP_WIDTH  equ field.MAP_W      ; le module verifie son budget avec
pscroll.MAX_SEAMS  equ 8                ; ceil(1152 / 160)

 SECTION code

        INCLUDE "engine/graphics/tilemap/pscroll/pscroll.asm"
        INCLUDE "src/stages/04/pscroll-rows.asm"

; -----------------------------------------------------------------------------
; pscroll.stage4.init — poser la couche, puis graver les dix bandes
; -----------------------------------------------------------------------------
; input REG : [d] la position camera de depart (px larges)
;
; Appele UNE fois a l'ouverture du stage et au checkpoint. La gravure des dix
; bandes coute ~160 000 cycles : c'est le prix d'entree, jamais paye en jeu.
; -----------------------------------------------------------------------------
pscroll.stage4.init
        pshs  d
        lda   #map.RAM_OVER_CART+pscroll.buf0.page
        sta   pscroll.buf.page
        lda   #map.RAM_OVER_CART+pscroll.buf1.page
        sta   pscroll.buf.page+1
        lda   #map.RAM_OVER_CART+pscroll.buf2.page
        sta   pscroll.buf.page+2
        lda   #map.RAM_OVER_CART+pscroll.buf3.page
        sta   pscroll.buf.page+3
        ldd   #$0000                   ; les quatre buffers a $0000 de leur page
        std   pscroll.buf.address
        std   pscroll.buf.address+2
        std   pscroll.buf.address+4
        std   pscroll.buf.address+6
        ; La fin de bande : l'octet APRES la derniere ligne. Le blast empile
        ; vers le bas, sa premiere poussee peint donc la ligne d'avant.
        ldd   #$A000+(field.VP_Y+pscroll.BAND_LINES)*40
        std   pscroll.viewport.ram
        ldd   #field.MAP_W-160
        std   pscroll.camera.x.max
        ldd   #pscroll.field.map
        std   pscroll.map.address
        puls  d
        jmp   pscroll.init

; -----------------------------------------------------------------------------
; pscroll.stage4.frame — la trame : peindre, puis avancer
; -----------------------------------------------------------------------------
; input REG : [d] la vitesse camera 8.8 de la trame
;
; do PEINT la fenetre depuis le ruban — c'est lui qui remplace l'effacement —
; et move avance la camera en gravant ce qui entre. Dans cet ordre : do peint
; la bande ou la camera EST, move l'amene ou elle va.
; -----------------------------------------------------------------------------
pscroll.stage4.frame
        std   pscroll.camera.speedx
        jsr   pscroll.do
        jmp   pscroll.move

; -----------------------------------------------------------------------------
; pscroll.grow — faire repousser UNE gomme, en coordonnees ECRAN
; -----------------------------------------------------------------------------
; input REG : [x] x ecran du point sonde, [b] ligne ecran
; sortie    : cc.Z = 1 si rien n'a pousse
;
; C'est la signature de cytron (run_cytron etape 5, 0x40:69F8) : l'arcade sonde
; la tuile sous un point et n'ecrit QUE si elle lit TILE_EMPTY — donc jamais
; dans le terrain dur. Ici la meme regle s'obtient gratuitement : setCell refuse
; une cellule deja pleine, et le terrain dur du stage 4 EST du plein dans le
; champ. Reste a passer de l'ecran a la cellule.
;
; L'ancien pellet.grow faisait ses deux divisions par soustractions successives.
; On garde le principe : au plus 53 et 30 tours, une fois par trame et par
; cytron.
; -----------------------------------------------------------------------------
pscroll.grow
        stx   pscroll.grow.x
        stb   pscroll.grow.y
        subb  #field.VP_Y              ; la rangee : (ligne - VP_Y) / 6
        blo   pscroll.grow.no          ; au-dessus du champ
        clra
pscroll.grow.rd
        cmpb  #pscroll.CELL_H
        blo   pscroll.grow.rok
        subb  #pscroll.CELL_H
        inca
        bra   pscroll.grow.rd
pscroll.grow.rok
        cmpa  #pscroll.ROWS
        bhs   pscroll.grow.no          ; sous le champ
        sta   pscroll.grow.row
        ldd   pscroll.grow.x           ; la cellule : (x ecran + camera) / 3
        addd  pscroll.camera.x
        bmi   pscroll.grow.no
        std   pscroll.grow.px
        ldx   #0
pscroll.grow.cd
        ldd   pscroll.grow.px
        cmpd  #pscroll.CELL_W
        blo   pscroll.grow.cok
        subd  #pscroll.CELL_W
        std   pscroll.grow.px
        leax  1,x
        bra   pscroll.grow.cd
pscroll.grow.cok
        ldb   pscroll.grow.row
        jmp   pscroll.setCell          ; il refuse hors ruban et deja pleine
pscroll.grow.no
        orcc  #$04                     ; Z = 1 : rien n'a pousse
        rts

pscroll.grow.x   fdb 0
pscroll.grow.y   fcb 0
pscroll.grow.row fcb 0
pscroll.grow.px  fdb 0

pscroll.MAP_BYTES equ pscroll.MAP_STRIDE*pscroll.ROWS

; LE BITFIELD DES GOMMES — en RAM fixe (voir l'en-tete). Le stage l'emplit au
; demarrage depuis collisionMapForeground ; ensuite il vit ici, mute par les
; armes (clearRect/clearCell) et par cytron (setCell).
        SECTION resident
pscroll.field.map
        fill  0,pscroll.MAP_STRIDE*pscroll.ROWS
        ENDSECTION
