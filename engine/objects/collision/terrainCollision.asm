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

 IFDEF BG_OWN_CAMERA
        ; V2-ADDITION (2026-08-26) : le plan 0 de ce stage a SA camera, sur les
        ; DEUX axes — la couche battleship du stage 3. On lit alors le fond par
        ; les registres de cette camera au lieu de ceux du scroll d'avant-plan :
        ; l'exacte symetrie du chemin normal, et la formulation de l'arcade
        ; (probe_foreground_and_background_tiles 40:1eb5, qui replie
        ; x/y_background_camera avec leur reste sous-tuile).
        ; Les restes bgSubX/bgSubY entrent dans l'index AVANT la quantification
        ; des tables — d'ou l'exactitude au pixel sans une division.
        ; Doc : doc/bship-collision-plan.md
        tstb                           ; B = 0 (fond) ou 2 (avant-plan)
        bne   terrainCollision.loadMap.fg
        ldx   #terrainCollision.yOffset
        ldd   terrainCollision.sensor.y
        addb  terrainCollision.bgSubY  ; + le reste sous-ligne de la camera
        adca  #0
        _asld
        ldd   d,x
        addd  terrainCollision.bgRowBase ; + sa base de ligne (rembourrage compris)
        leay  d,y

        ldx   #terrainCollision.xOffset
        ldd   terrainCollision.sensor.x
        subd  glb_camera_x_pos         ; -> x ecran, le repere de la couche
        addb  terrainCollision.bgSubX  ; + le reste sous-tuile de la camera
        abx
        lda   ,x
        adda  terrainCollision.bgColBase
        ldx   #terrainCollision.xMask
        abx
        ldb   ,x
        rts                            ; pas de decalage boss ici : on EST la camera
terrainCollision.loadMap.fg
 ENDC
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
 IFDEF BG_OWN_CAMERA
        tst   terrainCollision.bgFlag   ; plan 0 ? le resultat est dans le
        bne   >                         ; repere de la couche, pas dans le monde
        addd  terrainCollision.bgWorldAdj
!
 ENDC
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
 IFDEF BG_OWN_CAMERA
        tst   terrainCollision.bgFlag   ; idem a gauche
        bne   >
        addd  terrainCollision.bgWorldAdj
!
 ENDC
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
 IFDEF BG_OWN_CAMERA
        ; le reste sous-ligne de la camera de fond (0..5) s'ajoute a l'index
        ; AVANT la quantification : la derniere ligne deborde d'autant
        fdb   30*lvlMapWidth,30*lvlMapWidth,30*lvlMapWidth,30*lvlMapWidth,30*lvlMapWidth,30*lvlMapWidth
 ENDC
        
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
 IFDEF BG_OWN_CAMERA
        fcb   7,7,7 ; x_pos 168 — le reste sous-tuile de la camera de fond
        fcb   7,7,7
        fcb   7,7,7
        fcb   7,7,7
        fcb   7,7,7
        fcb   7,7,7
        fcb   7,7,7
        fcb   7,7,7
 ENDC

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
 IFDEF BG_OWN_CAMERA
        fcb   $80,$80,$80 ; x_pos 168 — meme bloc que xOffset ci-dessus
        fcb   $40,$40,$40
        fcb   $20,$20,$20
        fcb   $10,$10,$10
        fcb   $08,$08,$08
        fcb   $04,$04,$04
        fcb   $02,$02,$02
        fcb   $01,$01,$01
 ENDC

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