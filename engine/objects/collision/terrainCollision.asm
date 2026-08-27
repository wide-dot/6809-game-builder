; ---------------------------------------------------------------------------
; Terrain Collision
; -----------------
; input : U ptr to object
;         B map id
; 
; return zero (no collision) or not zero (collision) in B
; ---------------------------------------------------------------------------

        INCLUDE "./engine/macros.asm"

        jmp   terrainCollision.checkPosition
        jmp   terrainCollision.checkXaxisRight
        jmp   terrainCollision.checkXaxisLeft
        jmp   terrainCollision.updateByte

terrainCollision.loadMap
        ldx   #terrainCollision.maps
        aslb
        stb   terrainCollision.bgFlag  ; 0 = background, 2 = foreground (boss-follow offset)
        ldy   b,x                      ; set ptr to map in x
        ; V2-DEVIATION : le plan background peut etre ATTACHE A UNE COUCHE
        ; mscroll (stage 3 :
        ; la silhouette du battleship suit la camera de la couche, pas le
        ; scroll principal). Drapeau a zero = comportement historique intact.
        tst   terrainCollision.bgFlag
        bne   terrainCollision.loadMap.main
        tst   terrainCollision.bgLayer
        lbne  terrainCollision.bgAttached
terrainCollision.loadMap.main

        ldx   #terrainCollision.yOffset
        ldd   terrainCollision.sensor.y
        _asld
        ldd   d,x                      ; load precomputed y position in map
        leay  d,y                      ; apply

        ldx   #terrainCollision.xOffset
        ldd   terrainCollision.sensor.x
        subd  glb_camera_x_pos
        addb  scroll_tile_pos_offset24
        abx
        lda   ,x                       ; load precomputed x position in map
        adda  scroll_tile_pos          ; get already scrolled x collision tiles

        ldx   #terrainCollision.xMask
        abx
        ldb   ,x                       ; read precomputed mask

        ; background only: shift the lookup right by the boss advance so the boss solid
        ; collision follows it while the scroll is held. foreground (bgFlag=2) is skipped;
        ; byteOff/bitShift are 0 outside the boss advance -> no-op otherwise. a=col, b=mask
        tst   terrainCollision.bgFlag
        bne   @done                    ; foreground -> no offset
        adda  terrainCollision.bgByteOff
        sta   terrainCollision.bgColTmp
        lda   terrainCollision.bgBitShift
        beq   @loadCol                 ; no sub-byte (3px) shift
@shift  lsrb                           ; move the mask one 3px tile to the right
        bne   @noWrap
        ldb   #$80                     ; wrapped past the byte -> next column, tile 0
        inc   terrainCollision.bgColTmp
@noWrap deca
        bne   @shift
@loadCol
        lda   terrainCollision.bgColTmp
@done
        rts

terrainCollision.checkPosition
        jsr   terrainCollision.loadMap
        andb  a,y                      ; read collision data and apply against precomputed mask
        rts

;-------------------------------------------------------------------------------
; terrainCollision.bgAttached — le plan background dans le repere de la COUCHE
; V2-DEVIATION : routine sans equivalent v1 (la v1 n'a ni mscroll ni plan
; attache) — ajoutee le 26/08/2026 pour le battleship du stage 3.
;
; Meme contrat de sortie que loadMap : [y] la ligne de carte, [a] l'octet,
; [b] le masque. Exact a la cellule (3 x 6 px), les deux axes :
;   layer_x = (sensor.x - camera principale) + bgLayer.x
;   layer_y = (sensor.y - 11)               + bgLayer.y     (11 = haut du champ)
; HORS CARTE = VIDE (masque 0) : la couche est un objet fini DANS le champ —
; l'inverse du decor du niveau, dont les tables bordent l'ecran et pour lequel
; hors carte doit rester solide.
;
; Les divisions sont les reciproques exactes usuelles :
;   /3 sur 16 bits : 256H+L = 3*85*H + (H+L)  ->  q = 85H + (H+L)/3,
;     et (x*171)>>9 = x/3, exact jusqu'a 255 (avec le report si H+L >= 256) ;
;   /6 sur 8 bits  : >>1 puis (x*171)>>9.
; bgByteOff/bgBitShift (le boss-follow du stage 1) ne s'appliquent PAS ici :
; ce chemin remplace tout le repere, pas seulement un decalage x.
;-------------------------------------------------------------------------------
terrainCollision.bgAttached
        ; --- la ligne d'abord (elle ne consomme que D)
        ldd   terrainCollision.sensor.y
        subd  #11
        addd  terrainCollision.bgLayer.y
        cmpd  #(terrainCollision.bgAttached.rows*6)  ; negatif compris (non signe)
        bhs   terrainCollision.bgAttached.empty
        lsrb                           ; layer_y < 256 : tient dans B ; /2
        lda   #171
        mul
        lsra                           ; A = ligne (0..29)
        ldb   #lvlMapWidth
        mul
        leay  d,y                      ; Y = la ligne (Y portait la base bg)
        ; --- la colonne
        ldd   terrainCollision.sensor.x
        subd  glb_camera_x_pos
        addd  terrainCollision.bgLayer.x
        cmpd  #lvlMapWidth*24          ; largeur en px ; negatif compris
        bhs   terrainCollision.bgAttached.empty
        std   terrainCollision.bgAttached.t     ; H, L
        clrb
        adda  terrainCollision.bgAttached.t+1   ; A = H+L
        bcc   >
        inca                           ; H+L-255...
        ldb   #85                      ; ...et 85 de report
!       stb   terrainCollision.bgAttached.t+2
        ldb   #171
        mul
        lsra                           ; A = (H+L)/3
        adda  terrainCollision.bgAttached.t+2
        sta   terrainCollision.bgAttached.t+2   ; bas du quotient
        lda   terrainCollision.bgAttached.t     ; H
        ldb   #85
        mul                            ; D = 85H
        addb  terrainCollision.bgAttached.t+2
        adca  #0                       ; D = cellule (0..383)
        stb   terrainCollision.bgAttached.t     ; le bas, pour le bit
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb                           ; B = octet (0..47)
        tfr   b,a                      ; A = octet — le contrat de sortie
        ldb   terrainCollision.bgAttached.t
        andb  #7
        ldx   #terrainCollision.bgAttached.mask
        ldb   b,x                      ; B = masque
        rts
terrainCollision.bgAttached.empty
        clra                           ; octet 0 : a,y lit la carte, pas au-dela
        clrb                           ; masque 0 : aucun mur
        rts

terrainCollision.bgAttached.rows equ 30
terrainCollision.bgAttached.t
        fcb   0,0,0
terrainCollision.bgAttached.mask
        fcb   $80,$40,$20,$10,$08,$04,$02,$01

terrainCollision.checkXaxisRight
        ; scans all the tiles in the current row
        ; and stops at the first solid tile

        jsr   terrainCollision.loadMap
        lslb                           ; set all bits on the right ...
        decb                           ; ... of bit set to 1
        andb  a,y                      ; read collision data and apply against precomputed mask
        bne   @impact
        inca
        ldb   a,y
        bne   @impact
        inca
        ldb   a,y
        bne   @impact
        inca
        ldb   a,y
        bne   @impact
        inca
        ldb   a,y
        bne   @impact
        inca
        ldb   a,y
        bne   @impact
        inca
        ldb   a,y
        bne   @impact
        bra   @noImpact
@impact
        ; compute x_pos of left edge of solid tile
        ; from value in a (tile block index) and b (in-block tile index)
        stb   @inBlockTileIndex
        ldb   #24 ; a block is 24px wide
        mul
        std   @tileBlockOffset
        lda   #0
@inBlockTileIndex equ *-1
        ; inverted bsr to get position in tile block
        clrb
        bita  #$f0
        bne   >
        addb  #4
        lsla
        lsla
        lsla
        lsla
!       bita  #$c0
        bne   >
        addb  #2
        lsla
        lsla
!       bmi   >
        incb
!
        lda   #3 ; a tile is 3px wide
        mul
        addd  #0
@tileBlockOffset equ *-2
        addd  #8 ; screen border offset
        cmpd  #map_width
        bls   >
@noImpact
        ldd   #0
!       std   terrainCollision.impact.x
        rts

terrainCollision.checkXaxisLeft
        ; scans all the tiles in the current row
        ; and stops at the first solid tile

        jsr   terrainCollision.loadMap
        decb                           ; set all bits on the left ...
        comb                           ; ... of bit set to 1
        andb  a,y                      ; read collision data and apply against precomputed mask
        bne   @impact
        deca
        bmi   @noImpact
        ldb   a,y
        bne   @impact
        deca
        bmi   @noImpact
        ldb   a,y
        bne   @impact
        deca
        bmi   @noImpact
        ldb   a,y
        bne   @impact
        deca
        bmi   @noImpact
        ldb   a,y
        bne   @impact
        deca
        bmi   @noImpact
        ldb   a,y
        bne   @impact
        deca
        bmi   @noImpact
        ldb   a,y
        bne   @impact
        bra   @noImpact
@impact
        ; compute x_pos of right edge of solid tile
        ; from value in a (tile block index) and b (in-block tile index)
        stb   @inBlockTileIndex
        ldb   #24 ; a block is 24px wide
        mul
        std   @tileBlockOffset
        lda   #0
@inBlockTileIndex equ *-1
        ; inverted ctz to get position in tile block
        ldb   #7
        bita  #$0f
        bne   >
        subb  #4
        lsra
        lsra
        lsra
        lsra
!       bita  #$03
        bne   >
        subb  #2
        lsra
        lsra
!       bita  #$01
        bne   >
        decb
!
        lda   #3 ; a tile is 3px wide
        mul
        addd  #0
@tileBlockOffset equ *-2
        addd  #8+3-1 ; screen border offset + tile width -1
        bra   >
@noImpact
        ldd   #0
!       std   terrainCollision.impact.x
        rts

terrainCollision.yOffset equ *-22 ; minus vertical viewport position * 2
        fdb   00*lvlMapWidth,00*lvlMapWidth,00*lvlMapWidth,00*lvlMapWidth,00*lvlMapWidth,00*lvlMapWidth
        fdb   01*lvlMapWidth,01*lvlMapWidth,01*lvlMapWidth,01*lvlMapWidth,01*lvlMapWidth,01*lvlMapWidth
        fdb   02*lvlMapWidth,02*lvlMapWidth,02*lvlMapWidth,02*lvlMapWidth,02*lvlMapWidth,02*lvlMapWidth
        fdb   03*lvlMapWidth,03*lvlMapWidth,03*lvlMapWidth,03*lvlMapWidth,03*lvlMapWidth,03*lvlMapWidth
        fdb   04*lvlMapWidth,04*lvlMapWidth,04*lvlMapWidth,04*lvlMapWidth,04*lvlMapWidth,04*lvlMapWidth
        fdb   05*lvlMapWidth,05*lvlMapWidth,05*lvlMapWidth,05*lvlMapWidth,05*lvlMapWidth,05*lvlMapWidth
        fdb   06*lvlMapWidth,06*lvlMapWidth,06*lvlMapWidth,06*lvlMapWidth,06*lvlMapWidth,06*lvlMapWidth
        fdb   07*lvlMapWidth,07*lvlMapWidth,07*lvlMapWidth,07*lvlMapWidth,07*lvlMapWidth,07*lvlMapWidth
        fdb   08*lvlMapWidth,08*lvlMapWidth,08*lvlMapWidth,08*lvlMapWidth,08*lvlMapWidth,08*lvlMapWidth
        fdb   09*lvlMapWidth,09*lvlMapWidth,09*lvlMapWidth,09*lvlMapWidth,09*lvlMapWidth,09*lvlMapWidth
        fdb   10*lvlMapWidth,10*lvlMapWidth,10*lvlMapWidth,10*lvlMapWidth,10*lvlMapWidth,10*lvlMapWidth
        fdb   11*lvlMapWidth,11*lvlMapWidth,11*lvlMapWidth,11*lvlMapWidth,11*lvlMapWidth,11*lvlMapWidth
        fdb   12*lvlMapWidth,12*lvlMapWidth,12*lvlMapWidth,12*lvlMapWidth,12*lvlMapWidth,12*lvlMapWidth
        fdb   13*lvlMapWidth,13*lvlMapWidth,13*lvlMapWidth,13*lvlMapWidth,13*lvlMapWidth,13*lvlMapWidth
        fdb   14*lvlMapWidth,14*lvlMapWidth,14*lvlMapWidth,14*lvlMapWidth,14*lvlMapWidth,14*lvlMapWidth
        fdb   15*lvlMapWidth,15*lvlMapWidth,15*lvlMapWidth,15*lvlMapWidth,15*lvlMapWidth,15*lvlMapWidth
        fdb   16*lvlMapWidth,16*lvlMapWidth,16*lvlMapWidth,16*lvlMapWidth,16*lvlMapWidth,16*lvlMapWidth
        fdb   17*lvlMapWidth,17*lvlMapWidth,17*lvlMapWidth,17*lvlMapWidth,17*lvlMapWidth,17*lvlMapWidth
        fdb   18*lvlMapWidth,18*lvlMapWidth,18*lvlMapWidth,18*lvlMapWidth,18*lvlMapWidth,18*lvlMapWidth
        fdb   19*lvlMapWidth,19*lvlMapWidth,19*lvlMapWidth,19*lvlMapWidth,19*lvlMapWidth,19*lvlMapWidth
        fdb   20*lvlMapWidth,20*lvlMapWidth,20*lvlMapWidth,20*lvlMapWidth,20*lvlMapWidth,20*lvlMapWidth
        fdb   21*lvlMapWidth,21*lvlMapWidth,21*lvlMapWidth,21*lvlMapWidth,21*lvlMapWidth,21*lvlMapWidth
        fdb   22*lvlMapWidth,22*lvlMapWidth,22*lvlMapWidth,22*lvlMapWidth,22*lvlMapWidth,22*lvlMapWidth
        fdb   23*lvlMapWidth,23*lvlMapWidth,23*lvlMapWidth,23*lvlMapWidth,23*lvlMapWidth,23*lvlMapWidth
        fdb   24*lvlMapWidth,24*lvlMapWidth,24*lvlMapWidth,24*lvlMapWidth,24*lvlMapWidth,24*lvlMapWidth
        fdb   25*lvlMapWidth,25*lvlMapWidth,25*lvlMapWidth,25*lvlMapWidth,25*lvlMapWidth,25*lvlMapWidth
        fdb   26*lvlMapWidth,26*lvlMapWidth,26*lvlMapWidth,26*lvlMapWidth,26*lvlMapWidth,26*lvlMapWidth
        fdb   27*lvlMapWidth,27*lvlMapWidth,27*lvlMapWidth,27*lvlMapWidth,27*lvlMapWidth,27*lvlMapWidth
        fdb   28*lvlMapWidth,28*lvlMapWidth,28*lvlMapWidth,28*lvlMapWidth,28*lvlMapWidth,28*lvlMapWidth
        fdb   29*lvlMapWidth,29*lvlMapWidth,29*lvlMapWidth,29*lvlMapWidth,29*lvlMapWidth,29*lvlMapWidth
        
terrainCollision.xOffset equ *-8 ; minus horizontal viewport position
        fcb   0,0,0 ; x_pos 0
        fcb   0,0,0
        fcb   0,0,0
        fcb   0,0,0
        fcb   0,0,0
        fcb   0,0,0
        fcb   0,0,0
        fcb   0,0,0
        fcb   1,1,1 ; x_pos 24
        fcb   1,1,1
        fcb   1,1,1
        fcb   1,1,1
        fcb   1,1,1
        fcb   1,1,1
        fcb   1,1,1
        fcb   1,1,1
        fcb   2,2,2 ; x_pos 48
        fcb   2,2,2
        fcb   2,2,2
        fcb   2,2,2
        fcb   2,2,2
        fcb   2,2,2
        fcb   2,2,2
        fcb   2,2,2
        fcb   3,3,3 ; x_pos 72
        fcb   3,3,3
        fcb   3,3,3
        fcb   3,3,3
        fcb   3,3,3
        fcb   3,3,3
        fcb   3,3,3
        fcb   3,3,3
        fcb   4,4,4 ; x_pos 96
        fcb   4,4,4
        fcb   4,4,4
        fcb   4,4,4
        fcb   4,4,4
        fcb   4,4,4
        fcb   4,4,4
        fcb   4,4,4
        fcb   5,5,5 ; x_pos 120
        fcb   5,5,5
        fcb   5,5,5
        fcb   5,5,5
        fcb   5,5,5
        fcb   5,5,5
        fcb   5,5,5
        fcb   5,5,5
        fcb   6,6,6 ; x_pos 144
        fcb   6,6,6
        fcb   6,6,6
        fcb   6,6,6
        fcb   6,6,6
        fcb   6,6,6
        fcb   6,6,6
        fcb   6,6,6

terrainCollision.xMask equ *-8 ; minus horizontal viewport position
        fcb   $80,$80,$80 ; x_pos 0
        fcb   $40,$40,$40
        fcb   $20,$20,$20
        fcb   $10,$10,$10
        fcb   $08,$08,$08
        fcb   $04,$04,$04
        fcb   $02,$02,$02
        fcb   $01,$01,$01
        fcb   $80,$80,$80 ; x_pos 24
        fcb   $40,$40,$40
        fcb   $20,$20,$20
        fcb   $10,$10,$10
        fcb   $08,$08,$08
        fcb   $04,$04,$04
        fcb   $02,$02,$02
        fcb   $01,$01,$01
        fcb   $80,$80,$80 ; x_pos 48
        fcb   $40,$40,$40
        fcb   $20,$20,$20
        fcb   $10,$10,$10
        fcb   $08,$08,$08
        fcb   $04,$04,$04
        fcb   $02,$02,$02
        fcb   $01,$01,$01
        fcb   $80,$80,$80 ; x_pos 72
        fcb   $40,$40,$40
        fcb   $20,$20,$20
        fcb   $10,$10,$10
        fcb   $08,$08,$08
        fcb   $04,$04,$04
        fcb   $02,$02,$02
        fcb   $01,$01,$01
        fcb   $80,$80,$80 ; x_pos 96
        fcb   $40,$40,$40
        fcb   $20,$20,$20
        fcb   $10,$10,$10
        fcb   $08,$08,$08
        fcb   $04,$04,$04
        fcb   $02,$02,$02
        fcb   $01,$01,$01
        fcb   $80,$80,$80 ; x_pos 120
        fcb   $40,$40,$40
        fcb   $20,$20,$20
        fcb   $10,$10,$10
        fcb   $08,$08,$08
        fcb   $04,$04,$04
        fcb   $02,$02,$02
        fcb   $01,$01,$01
        fcb   $80,$80,$80 ; x_pos 144
        fcb   $40,$40,$40
        fcb   $20,$20,$20
        fcb   $10,$10,$10
        fcb   $08,$08,$08
        fcb   $04,$04,$04
        fcb   $02,$02,$02
        fcb   $01,$01,$01

terrainCollision.updateByte
        ldy   #terrainCollision.maps
        asla
        stb   @b
        ldd   a,y ; load adress of terrain collision bitfield in d
        leax  d,x ; add offset (position) already loaded in x 
        ldb   #0
@b      equ   *-1        
        stb   ,x  ; update bitfield with new value
        rts