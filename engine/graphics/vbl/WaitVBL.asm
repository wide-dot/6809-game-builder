* ---------------------------------------------------------------------------
* WaitVBL
* -------
* Waits for the beam to leave the screen, then swaps the two screen buffers
* (pages 2 and 3) : the one drawn is shown ($E7DD, the border colour
* gfxlock.screenBorder.color), the other goes to the data window ($E7E5) and
* its half page 0 to the screen window ($E7C3, bit 0). Then counts the frames
* the IRQ counted since the last swap into gfxlock.frameDrop.count, capped at
* Vint_Main_runcount_cap. Every register kept.
*
* A game that must not wait (a loop of several frames) uses gfxlock
* (engine/graphics/buffer/gfxlock.asm) : the swap at the VBL's interrupt.
* V2-DEVIATION : past 255 frames the count is the cap (v1 kept the low byte) ;
* V2-DEVIATION 2026-10-21 : v1's DO_NOT_WAIT_VBL (no wait when two frames or
* more went by, the swap at once, the screen torn) removed.
* ---------------------------------------------------------------------------

WaitVBL
        pshs  d
!       tst   $E7E7
        bpl   <                        ; while the beam is out of the screen
!       tst   $E7E7
        bmi   <                        ; while it is in
        ldb   WaitVBL.buffer
        andb  #$40                     ; page 2 or 3 shown
        orb   #$80
gfxlock.screenBorder.color equ *-1     ; (dynamic) bits 0-3 : the border colour
        stb   $E7DD
        com   WaitVBL.buffer
        ldb   #$00
WaitVBL.buffer equ *-1                 ; (dynamic) $00 or $FF
        andb  #$01
        stb   gfxlock.backBuffer.id
        orb   #$02                     ; the other page to the data window
        stb   $E7E5
        ldb   $E7C3
        eorb  #$01                     ; and its half page 0 to the screen window
        stb   $E7C3
        inc   gfxlock.bufferSwap.count+1
        bne   >
        inc   gfxlock.bufferSwap.count
!       ldd   gfxlock.frame.count      ; the frames since the last swap
        subd  gfxlock.frame.lastCount
        tsta
        bne   >                        ; 256 or more : the cap
        cmpb  Vint_Main_runcount_cap
        bls   @drop
!       ldb   Vint_Main_runcount_cap
@drop   stb   gfxlock.frameDrop.count
        ldd   gfxlock.frame.count
        std   gfxlock.frame.lastCount
        puls  d,pc

gfxlock.bufferSwap.count  fdb   0 ; the swaps
gfxlock.frame.count       fdb   0 ; the frames, counted by the IRQ
gfxlock.frame.lastCount   fdb   0 ; at the last swap
gfxlock.frameDrop.count_w fcb   0 ; so the count reads as a word
gfxlock.frameDrop.count   fcb   0 ; the frames between the last two swaps
Vint_Main_runcount_cap    fcb   -1 ; their cap
gfxlock.backBuffer.id     fcb   0 ; the buffer drawn (0 or 1)
