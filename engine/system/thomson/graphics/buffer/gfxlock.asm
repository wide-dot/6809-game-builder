;******************************************************************************
; Double buffering gfx write lock
; -----------------------------------------------------------------------------
;
; Swap buffers with a 50hz irq.
; Irq must be in sync with VBL to avoid palette change artifacts.
;
; To tell engine when gfx rendering begins or ends, the user uses macros :
; _gfxlock.init : should be called before irq starts
; _gfxlock.on   : should be called before entering rendering routines
; _gfxlock.off  : should be called as soon as rendering is over for a frame
; _gfxlock.loop : should be called just before the end of main loop
; _gfxlock.swap : should be called at the start of the user 50Hz IRQ
;
; A wait routine will only runs if a second gfx rendering lock is set during
; a single screen frame.
;
; User can set a back process routine during wait :
; _gfxlock.backProcess.on  <routine_addr>
; _gfxlock.backProcess.off
;
;******************************************************************************
gfxlock.init                EXPORT
gfxlock.on                  EXPORT
gfxlock.status              EXPORT
gfxlock.loop                EXPORT
gfxlock.bufferSwap.check    EXPORT

gfxlock.backProcess.routine EXPORT
gfxlock.backProcess.status  EXPORT
gfxlock.frameDrop.count_w   EXPORT
gfxlock.frameDrop.count     EXPORT
gfxlock.frame.count         EXPORT
gfxlock.frame.lastCount     EXPORT

 SECTION code

; =============================================================================
; variables
; =============================================================================

gfxlock.status             fcb   0 ; 1: gfx rendering is running
gfxlock.bufferSwap.status  fcb   0 ; -1: a swap buffer was made
gfxlock.backProcess.status fcb   0 ; 1: a back process is active during wait

gfxlock.bufferSwap.count   fdb   0 ; buffer swap counter
gfxlock.backBuffer.id      fcb   0 ; back buffer set to read operations (0 or 1)

gfxlock.frameDrop.count_w  fcb   0 ; zero pad
gfxlock.frameDrop.count    fcb   0 ; elapsed 50Hz frames since last main loop
gfxlock.frame.count        fdb   0 ; elapsed 50Hz frames since init
gfxlock.frame.lastCount    fdb   0 ; elapsed 50Hz frames at last main loop

gfxlock.halfPage.swap.auto fdb   0 ; status of half page autoswap

; =============================================================================
; routines
; =============================================================================

gfxlock.bufferSwap.check
        lda   gfxlock.status
        bne   >
        jsr   gfxlock.bufferSwap.do    ; swap only when gfx was redered
        lda   #-1
        sta   gfxlock.status
!       rts

gfxlock.bufferSwap.do
        ldb   gfxlock.backBuffer.status
        andb  #%01000000               ; set bit 6 based on flip/flop
        orb   #%10000000               ; set bit 7=1, bit 0-3=frame color
gfxlock.screenBorder.color equ *-1
        stb   map.CF74021.SYS2         ; set visible video buffer (2 or 3)
        com   gfxlock.backBuffer.status
        ldb   #$00                     ; always 0 or -1 (flip/flop)
gfxlock.backBuffer.status equ   *-1
        andb  #%00000001               ; set bit 0 based on flip/flop
        orb   #%00000010               ; value should be 2 or 3
        stb   map.CF74021.DATA         ; mount working video buffer in RAM
        ldb   gfxlock.halfPage.swap.auto
        bne   >
        ldb   map.HALFPAGE
        eorb  #%00000001               ; swap half-page in $4000 $5FFF
        stb   map.HALFPAGE
!
        inc   gfxlock.bufferSwap.count+1
        bne   >
        inc   gfxlock.bufferSwap.count
!
        com   gfxlock.bufferSwap.status
        rts

gfxlock.bufferSwap.wait
        clr   gfxlock.bufferSwap.status
@loop   tst   gfxlock.backProcess.status
        beq   >
        jsr   $1234                     ; do some back processing
gfxlock.backProcess.routine equ *-2
!       lda   gfxlock.status
        bne   >
        tst   gfxlock.bufferSwap.status
        beq   @loop                     ; loop until irq make a swap
!       rts

gfxlock.screenBorder.update
        andb  #$0F
        orb   #%10000000
        stb   gfxlock.screenBorder.color
        rts

gfxlock.init
        jsr   gfxlock.bufferSwap.do
        lda   #-1
        sta   gfxlock.status
        lda   gfxlock.backBuffer.status ; init backBuffer.id based on backBuffer.status
        anda  #%00000001
        sta   gfxlock.backBuffer.id     ; id is 0 or 1
        rts

gfxlock.on
        lda   gfxlock.status
        bne   >
        jsr   gfxlock.bufferSwap.wait  ; wait if second gfx frame is reached
!       lda   #1
        sta   gfxlock.status
        rts

gfxlock.loop
        lda   gfxlock.backBuffer.id    ; switch id at the end of gfxlock
        eora  #%00000001
        sta   gfxlock.backBuffer.id
        ldd   gfxlock.frame.count
        subd  gfxlock.frame.lastCount
        stb   gfxlock.frameDrop.count  ; store the number of elapsed 50Hz frames since last main game loop
        ldd   gfxlock.frame.count
        std   gfxlock.frame.lastCount
        rts

 ENDSECTION