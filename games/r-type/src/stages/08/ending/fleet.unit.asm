;*******************************************************************************
; fleet — the ending's 18 R-9, PRECOMPUTED, its own direntry (stage8.fleet)
;
; The fleet's flight (40:FB10 / FB53) depends on nothing but the ending's
; clock: tools/gen_ending.py flies it frame by frame from the ROM and keeps
; only its screen changes (fleet.asm: per ship {x, y, pose << 6 | n}, n
; frames before the next record). At run time a ship costs a comparison when
; nothing changed, a few loads and stores when it did — whatever the number
; of frames the render covered: no frame-by-frame replay (the author's rule,
; « boucles par trame = multiplications »).
;
; fleet.Init (paged.call, at the ending's start) and fleet.Update (once per
; render, the clock in ending.clock) fill the resident slots ending.Slots
; that the fleet's renderer draws: [on, x, y, imageset (2), -].
; The entry is the FIRST byte of the unit
; (docs/lang/en/migration/unit-entry-point.md).
;*******************************************************************************

fleet.Init   EXPORT
fleet.Update EXPORT

; resident, in the stage 8 main
ending.Slots      EXTERNAL
ending.clock      EXTERNAL
; the pictures, in the ending's direntry (gfxcomp index)
set_fleet_0  EXTERNAL
set_fleet_1  EXTERNAL
set_fleet_2  EXTERNAL
set_fleet_3  EXTERNAL
set_fleet_4  EXTERNAL
set_fleet_5  EXTERNAL
set_fleet_6  EXTERNAL
set_fleet_7  EXTERNAL
set_fleet_8  EXTERNAL
set_fleet_9  EXTERNAL
set_fleet_10 EXTERNAL
set_fleet_11 EXTERNAL
set_fleet_12 EXTERNAL
set_fleet_13 EXTERNAL
set_fleet_14 EXTERNAL
set_fleet_15 EXTERNAL
set_fleet_16 EXTERNAL
set_fleet_17 EXTERNAL

 SECTION code

F.rec   equ 0                           ; the record due (0: the ship is gone)
F.next  equ 2                           ; the clock it falls due
F.col   equ 4                           ; its colour rank x 3
F.SZ    equ 5

fleet.Update
        ldx   #ending.Slots
        ldu   #fleet.State
@ship   ldy   F.rec,u                   ; gone?
        beq   @next
        ldd   ending.clock              ; nothing due: nothing to do
        cmpd  F.next,u
        blo   @next
@rec    sty   fleet.r                   ; the record due, then the ones the
        ldb   2,y                       ; clock has already passed
        andb  #63
        beq   @last                     ; n = 0: the last one, the ship goes
        clra
        addd  F.next,u
        std   F.next,u
        leay  3,y
        ldd   ending.clock
        cmpd  F.next,u
        bhs   @rec
        bra   @keep
@last   ldy   #0
@keep   sty   F.rec,u
        ldy   fleet.r                   ; its slot: x, y, picture
        ldd   ,y
        std   1,x
        lda   2,y
        anda  #$C0
        cmpa  #$C0
        beq   @off                      ; off the screen (or gone)
        lsra
        lsra
        lsra
        lsra
        lsra
        lsra
        adda  F.col,u                   ; colour x 3 + pose
        asla
        ldy   #fleet.Sets
        ldd   a,y
        std   3,x
        lda   #1
        sta   ,x
        bra   @next
@off    clr   ,x
@next   leax  6,x
        leau  F.SZ,u
        cmpu  #fleet.StateEnd
        blo   @ship
        rts

fleet.Init
        ldx   #ending.Slots
        ldb   #fleet.N*6
@clr    clr   ,x+
        decb
        bne   @clr
        ldu   #fleet.State
        ldy   #fleet.Ships
        ldx   #fleet.Cols
@s      ldd   ,y++
        std   F.rec,u
        ldd   #fleet.T0                 ; ending.T_FLEET: the fleet appears
        std   F.next,u
        lda   ,x+
        sta   F.col,u
        leau  F.SZ,u
        cmpu  #fleet.StateEnd
        blo   @s
        rts

fleet.r       fdb   0
fleet.State   fill  0,18*F.SZ
fleet.StateEnd

; the pictures: colour * 3 + pose (images/fleet)
fleet.Sets
        fdb   set_fleet_0,set_fleet_1,set_fleet_2,set_fleet_3,set_fleet_4,set_fleet_5
        fdb   set_fleet_6,set_fleet_7,set_fleet_8,set_fleet_9,set_fleet_10,set_fleet_11
        fdb   set_fleet_12,set_fleet_13,set_fleet_14,set_fleet_15,set_fleet_16,set_fleet_17

        INCLUDE "src/stages/08/ending/fleet.asm"

 ENDSECTION
