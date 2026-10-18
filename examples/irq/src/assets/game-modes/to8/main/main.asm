;*******************************************************************************
; IRQ, VBL, palette and the small routines — bench
;
; The 50 Hz IRQ runs (IrqInit, IrqSet50Hz) with a user routine that counts
; its calls ; WaitVBL swaps the screen buffers. The palette routines are
; checked on their RAM side : toje does not read the palette chip back.
;
; Witnesses at $9C00 (docs/lang/en/benches.md) : $CA, TESTS, $0D once done,
; a byte per test ($01 pass), a word per test.
;   t01 the IRQ counts a frame a VBL, and runs the user routine as many times
;   t02 WaitVBL swaps the buffers : backBuffer.id, bufferSwap.count
;   t03 the frames between two swaps (3 or 4 after 3 counted), capped
;   t04 past 255 frames the count is the cap
;   t05 IrqPause / IrqUnpause : the IRQ off then back on ; off stays off
;   t06 IrqSecond : the seconds, then the minute
;   t07 PalUpdateNow runs only when PalRefresh asks, and sets it back
;   t08 PalCycling : the first three colours turn every PalCyc_frames_init
;   t09 palette.fade.to : black to a palette in its largest distance's
;       frames ; palette.fade : to one colour
;   t10 Mul9x16 : the signs, the bounds, the fraction floored
;   t11 CalcSine at the quarter turns (word : the sine of 32)
;   t12 RandomNumber from a seed (word : a hash of 16 numbers)
;   t13 ClearDataMem fills the data window, the stack and U kept
;   t14 GetImgIdA : the image's id read in its page, the caller's page back
;*******************************************************************************

data.img1       EXTERNAL
data.img2       EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/thomson/graphics/mode/gfxmode.macro.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "engine/system/to8/ram/ram.macro.asm"
        INCLUDE "engine/system/thomson/bootloader/loader.macro.asm"

 opt c,ct

TESTS     equ 14
res.magic equ $9C00
res.count equ $9C01
res.done  equ $9C02
res.base  equ $9C03
res.sums  equ res.base+TESTS

R.t01 equ res.base+0
R.t02 equ res.base+1
R.t03 equ res.base+2
R.t04 equ res.base+3
R.t05 equ res.base+4
R.t06 equ res.base+5
R.t07 equ res.base+6
R.t08 equ res.base+7
R.t09 equ res.base+8
R.t10 equ res.base+9
R.t11 equ res.base+10
R.t12 equ res.base+11
R.t13 equ res.base+12
R.t14 equ res.base+13
W.t11 equ res.sums+2*10
W.t12 equ res.sums+2*11

bench.irqs  equ $9B00                  ; word : the user routine's calls
bench.f0    equ $9B02                  ; word
bench.i0    equ $9B04                  ; word
bench.w     equ $9B06                  ; word
bench.t     equ $9B08
bench.n     equ $9B09
bench.sys   equ $9B0A                  ; word
bench.pal   equ $9B10                  ; 32 bytes : a palette in RAM
bench.work  equ $9B30                  ; 32 bytes
bench.obj   equ $9B50                  ; an object's first 32 bytes

main
        jsr   InitGlobals
        _gfxmode.setBM16
        _ram.data.set #2               ; a screen buffer at the data window
        ldx   #res.magic
        ldb   #3+3*TESTS
!       clr   ,x+
        decb
        bne   <
        lda   #$CA
        sta   res.magic
        lda   #TESTS
        sta   res.count
        ldd   #0
        std   bench.irqs
        ldd   #bench.irq
        std   Irq_user_routine
        jsr   IrqInit
        jsr   IrqSet50Hz

; t01 : a frame a VBL, the user routine a frame
        jsr   WaitVBL
        jsr   bench.snap
        ldb   #10
!       jsr   WaitVBL
        decb
        bne   <
        orcc  #$10
        ldd   gfxlock.frame.count
        subd  bench.f0
        std   bench.w                  ; the frames counted
        ldd   bench.irqs
        subd  bench.i0
        andcc #$EF
        cmpd  bench.w                  ; as many calls
        bne   >
        ldd   bench.w
        cmpd  #9
        blo   >
        cmpd  #11
        bhi   >
        lda   #1
        sta   R.t01
!
; t02 : the buffers swapped
        lda   gfxlock.backBuffer.id
        sta   bench.t
        ldd   gfxlock.bufferSwap.count
        std   bench.w
        jsr   WaitVBL
        lda   gfxlock.backBuffer.id
        eora  bench.t
        cmpa  #1                       ; the other buffer
        bne   >
        ldd   gfxlock.bufferSwap.count
        subd  bench.w
        cmpd  #1
        bne   >
        jsr   WaitVBL
        lda   gfxlock.backBuffer.id
        cmpa  bench.t                  ; and back
        bne   >
        lda   #1
        sta   R.t02
!
; t03 : the frames between two swaps, then capped at 2
        jsr   WaitVBL
        jsr   bench.spin3
        jsr   WaitVBL
        lda   gfxlock.frameDrop.count
        cmpa  #3
        blo   t03ko
        cmpa  #4
        bhi   t03ko
        lda   #2
        sta   Vint_Main_runcount_cap
        jsr   WaitVBL
        jsr   bench.spin3
        jsr   WaitVBL
        lda   gfxlock.frameDrop.count
        cmpa  #2
        bne   t03ko
        lda   #1
        sta   R.t03
t03ko   lda   #-1
        sta   Vint_Main_runcount_cap
; t04 : 258 frames and more : the cap
        lda   #5
        sta   Vint_Main_runcount_cap
        orcc  #$10
        ldd   gfxlock.frame.count
        subd  #258
        std   gfxlock.frame.lastCount
        andcc #$EF
        jsr   WaitVBL
        lda   gfxlock.frameDrop.count
        cmpa  #5
        bne   >
        lda   #1
        sta   R.t04
!       lda   #-1
        sta   Vint_Main_runcount_cap
; t05 : IrqPause, IrqUnpause
        jsr   IrqPause
        lda   $6019
        anda  #$20
        bne   t05ko                    ; off
        ldd   gfxlock.frame.count
        std   bench.w
        jsr   WaitVBL
        jsr   WaitVBL
        jsr   WaitVBL
        ldd   gfxlock.frame.count
        cmpd  bench.w
        bne   t05ko                    ; nothing counted
        jsr   IrqUnpause
        lda   $6019
        anda  #$20
        beq   t05ko                    ; on again
        jsr   WaitVBL
        jsr   WaitVBL
        ldd   gfxlock.frame.count
        cmpd  bench.w
        beq   t05ko                    ; counting
        jsr   IrqOff                   ; paused while off : off after
        jsr   IrqPause
        jsr   IrqUnpause
        lda   $6019
        anda  #$20
        bne   t05ko
        lda   #1
        sta   R.t05
t05ko   jsr   IrqOn
; t06 : IrqSecond
        lda   #48
        sta   glb_timer_frame
        ldd   #$013A                   ; 1 min 58 s
        std   glb_timer
        jsr   IrqSecond
        jsr   IrqSecond                ; the 50th frame : a second
        ldd   glb_timer
        cmpd  #$013B
        bne   >
        lda   glb_timer_frame
        bne   >
        lda   #50
        sta   bench.n
t06l    jsr   IrqSecond
        dec   bench.n
        bne   t06l
        ldd   glb_timer
        cmpd  #$0200                   ; 2 min 0 s
        bne   >
        lda   #1
        sta   R.t06
!
; t07 : PalUpdateNow and PalRefresh
        jsr   bench.palCopy
        ldd   #bench.pal
        std   Pal_current
        lda   #$FF
        sta   PalRefresh
        jsr   PalUpdateNow
        lda   PalRefresh
        cmpa  #$FF
        bne   >
        clr   PalRefresh               ; asked
        jsr   PalUpdateNow
        lda   PalRefresh
        cmpa  #$FF                     ; done
        bne   >
        lda   #1
        sta   R.t07
!
; t08 : PalCycling every 3 calls
        lda   #3
        sta   PalCyc_frames_init
        sta   PalCyc_frames
        jsr   PalCycling
        jsr   PalCycling
        ldd   bench.pal
        cmpd  bench.palsrc
        bne   >                        ; not yet
        jsr   PalCycling
        ldd   bench.pal
        cmpd  bench.palsrc+4           ; 0 <- 2
        bne   >
        ldd   bench.pal+2
        cmpd  bench.palsrc             ; 1 <- 0
        bne   >
        ldd   bench.pal+4
        cmpd  bench.palsrc+2           ; 2 <- 1
        bne   >
        lda   PalRefresh
        cmpa  #$FF
        bne   >
        lda   PalCyc_frames
        cmpa  #3
        bne   >
        lda   #1
        sta   R.t08
!
; t09 : palette.fade.to, black to bench.palsrc (a 15 distance) ; palette.fade
        ldx   #bench.work
        ldd   #0
!       std   ,x++
        cmpx  #bench.work+32
        blo   <
        jsr   bench.snap
        ldu   #bench.work
        ldx   #bench.palsrc
        jsr   palette.fade.to
        orcc  #$10
        ldd   gfxlock.frame.count
        andcc #$EF
        subd  bench.f0
        cmpd  #15                      ; 15 steps and the frame that sees none
        blo   t09ko
        cmpd  #17
        bhi   t09ko
        ldx   #bench.work
        ldu   #bench.palsrc
!       ldd   ,x++
        cmpd  ,u++
        bne   t09ko
        cmpx  #bench.work+32
        blo   <
        ldu   #bench.work
        ldd   #$FF0F                   ; white
        jsr   palette.fade
        ldx   #bench.work
!       ldd   ,x++
        cmpd  #$FF0F
        bne   t09ko
        cmpx  #bench.work+32
        blo   <
        ldu   #bench.work
        ldd   #$FF00                   ; white without blue : blue alone moving,
        jsr   palette.fade             ; it alone keeps the fade going
        ldx   #bench.work
!       ldd   ,x++
        cmpd  #$FF00
        bne   t09ko
        cmpx  #bench.work+32
        blo   <
        ldu   #bench.work
        ldd   #$FF0F                   ; and back
        jsr   palette.fade
        ldx   #bench.work
!       ldd   ,x++
        cmpd  #$FF0F
        bne   t09ko
        cmpx  #bench.work+32
        blo   <
        lda   #1
        sta   R.t09
t09ko
; t10 : Mul9x16
        ldy   #t10.cases
!       ldd   ,y
        ldx   2,y
        pshs  y
        jsr   Mul9x16
        puls  y
        cmpd  4,y
        bne   t10ko
        leay  6,y
        cmpy  #t10.end
        blo   <
        lda   #1
        sta   R.t10
t10ko
; t11 : CalcSine
        ldy   #t11.cases
!       ldb   ,y
        pshs  y
        jsr   CalcSine
        puls  y
        cmpd  1,y                      ; the sine
        bne   t11ko
        cmpx  3,y                      ; the cosine
        bne   t11ko
        leay  5,y
        cmpy  #t11.end
        blo   <
        ldb   #32
        jsr   CalcSine
        std   W.t11
        lda   #1
        sta   R.t11
t11ko
; t12 : RandomNumber from a seed
        ldd   #$1234
        std   RNG_seed
        ldd   #0
        std   bench.w
        std   bench.f0                 ; the previous number
        lda   #16
        sta   bench.n
t12l    jsr   RandomNumber
        cmpd  bench.f0
        beq   t12ko                    ; stuck
        std   bench.f0
        ldd   bench.w
        aslb
        rola
        adcb  #0
        addd  bench.f0
        std   bench.w
        dec   bench.n
        bne   t12l
        ldd   bench.w
        std   W.t12
        lda   #1
        sta   R.t12
t12ko
; t13 : ClearDataMem
        ldu   #$1357
        sts   bench.sys
        ldx   #$A55A
        jsr   ClearDataMem
        cmps  bench.sys
        bne   t13ko
        cmpu  #$1357
        bne   t13ko
        ldx   #$A000
!       ldd   ,x++
        cmpd  #$A55A
        bne   t13ko
        cmpx  #$E000
        blo   <
        lda   #1
        sta   R.t13
t13ko
; t14 : GetImgIdA
        _ram.cart.set #5
        lda   $E7E6
        sta   bench.t                  ; the caller's page
        ldu   #bench.obj
        lda   #1
        sta   id,u
        ldd   #data.img1
        std   image_set,u
        jsr   GetImgIdA
        cmpa  #$3C
        bne   t14ko
        lda   $E7E6
        cmpa  bench.t
        bne   t14ko
        lda   #2
        sta   id,u
        ldd   #data.img2
        std   image_set,u
        jsr   GetImgIdA
        cmpa  #$A5
        bne   t14ko
        lda   #1
        sta   R.t14
t14ko
        lda   #$0D
        sta   res.done
done    bra   done

;*******************************************************************************
; bench helpers
;*******************************************************************************

; the IRQ's user routine : counts its calls (DP $E7 : extended addressing)
bench.irq
        inc   bench.irqs+1
        bne   >
        inc   bench.irqs
!       rts

; bench.f0, bench.i0 <- the frames and the calls now
bench.snap
        orcc  #$10
        ldd   gfxlock.frame.count
        std   bench.f0
        ldd   bench.irqs
        std   bench.i0
        andcc #$EF
        rts

; until 3 frames are counted since the last swap
bench.spin3
!       orcc  #$10
        ldd   gfxlock.frame.count
        subd  gfxlock.frame.lastCount
        andcc #$EF
        cmpd  #3
        blo   <
        rts

; bench.pal <- bench.palsrc
bench.palCopy
        ldx   #bench.palsrc
        ldu   #bench.pal
!       ldd   ,x++
        std   ,u++
        cmpx  #bench.palsrc+32
        blo   <
        rts

; 16 entries GGGGRRRR, 0000BBBB : the largest distance from black is 15
bench.palsrc
        fdb   $0F00,$F000,$000F,$1203,$4507,$890A,$BC0D,$EF0F
        fdb   $FF0F,$7707,$330A,$AA03,$0102,$1001,$2002,$0F0E

; Mul9x16 : the multiplier, the multiplicand, the product / 256 floored
t10.cases
        fdb   $0100,$2000,$2000        ; 256 * 8192
        fdb   $FF00,$1234,$EDCC        ; -256 * 4660
        fdb   $0080,$1000,$0800        ; 128 * 4096
        fdb   $FF80,$1000,$F800        ; -128 * 4096
        fdb   $0040,$F000,$FC00        ; 64 * -4096
        fdb   $FFC0,$F000,$0400        ; -64 * -4096
        fdb   $0003,$0101,$0003        ; 3 * 257
        fdb   $FFFD,$0101,$FFFC        ; -3 * 257
        fdb   $0003,$FEFF,$FFFC        ; 3 * -257
        fdb   $FFFD,$FEFF,$0003        ; -3 * -257
        fdb   $0000,$FFFB,$0000        ; 0 * -5
        fdb   $00FF,$7FFF,$7F7F        ; 255 * 32767
        fdb   $FF01,$7FFF,$8080        ; -255 * 32767
        fdb   $0001,$FFFF,$FFFF        ; 1 * -1
t10.end

; CalcSine : the angle, 256 * its sine, 256 * its cosine
t11.cases
        fcb   0
        fdb   0,256
        fcb   64
        fdb   256,0
        fcb   128
        fdb   0,-256
        fcb   192
        fdb   -256,0
t11.end

; GetImgIdA's page index : object 1 and 2's images in the data unit
Img_Page_Index
        fcb   0
        fcb   map.RAM_OVER_CART+assets.data.page
        fcb   map.RAM_OVER_CART+assets.data.page

;*******************************************************************************
; engine
;*******************************************************************************
        INCLUDE "engine/InitGlobals.asm"
        INCLUDE "engine/irq/Irq.asm"
        INCLUDE "engine/irq/IrqSecond.asm"
        INCLUDE "engine/graphics/vbl/WaitVBL.asm"
        INCLUDE "engine/palette/PalUpdateNow.asm"
        INCLUDE "engine/palette/PalCycling.asm"
        INCLUDE "engine/palette/palette-fade.asm"
        INCLUDE "engine/math/Mul9x16.asm"
        INCLUDE "engine/math/CalcSine.asm"
        INCLUDE "engine/math/RandomNumber.asm"
        INCLUDE "engine/ram/ClearDataMemory.asm"
        INCLUDE "engine/graphics/image/GetImgIdA.asm"

 ENDSECTION
