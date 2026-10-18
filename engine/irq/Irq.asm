* ---------------------------------------------------------------------------
* IRQ Manager
* ---------------------------------------------------------------------------
*
* IrqInit             the monitor's timer vector on IrqManager
* IrqSet50Hz          the timer on every frame, the IRQ on ; trashes d
* IrqOn / IrqOff      the timer's IRQ on / off ; trashes a
* IrqPause            the IRQ off if it was on, remembered for IrqUnpause,
* IrqUnpause          which puts it back on ; every register kept
* IrqSync             the timer synced on a screen line : A the line (0-255),
*                     X the period (usually Irq_one_frame) ; trashes d, y
*                     (feature request : lines 0-311)
* IrqManager          the IRQ : counts the frame, runs Irq_user_routine with
*                     the caller's page kept ; DP $E7 (the monitor's), its
*                     own stack (Irq_sys_stack)
*
* IRQ_SPLIT (define, opt-in) : a second interrupt a frame, at a line of the
* display, for a palette change there (a game's water surface). The VBL's
* interrupt keeps its phase : the timer runs with TCR4 set (a latch write does
* not restart the counter), each period loaded by the chip itself at the
* expiry, the latch written one interrupt ahead. The split's interrupt counts
* no frame and runs no user routine : Irq_split_routine alone (DP $E7, the
* system stack). The game sets Irq_split_line : the line of the display
* (0-199) where the next frames split, $FF none ; the change shows where
* Irq_split_routine's writes land, a few lines after (the monitor's IRQ code
* first). Cost when no split : the scheduling, ~60 cycles a frame ; one more
* interrupt a frame when split.
*
* glb_Page at 0 is the tile loop's mode : the page register is used as is,
* RAM always (no ROM to tell apart), and glb_Page is put back to 0.
*
* User routines (may be grouped in a subroutine) : PalUpdateNow, PalCycling,
* PalRaster_1c, MusicFrame, PSGFrame, IrqObjSmps, IrqSecond.
* Irq_one_frame and Irq_one_line are constants of engine/constants.asm
* (migration/equates-link-boundary.md).
* ---------------------------------------------------------------------------

Irq_user_routine fdb 0                 ; the user routine IrqManager calls
 IFDEF IRQ_SPLIT
Irq_split_routine fdb 0                ; the split's routine (DP $E7, the system stack)
Irq_split_line    fcb $FF              ; the next frames' split : a line of the display, $FF none
Irq_split_cur     fdb 0                ; this frame's : cycles from the VBL's interrupt, 0 none
Irq_split_next    fcb 0                ; the next interrupt is the split
Irq_sync_line     fdb 0                ; the line IrqSync set the VBL's interrupt on
 ENDC

IrqInit
        ldd   #IrqManager
        std   TIMERPT
        rts

IrqSet50Hz
        ldb   #$42
        stb   MC6846.TCR               ; timer precision x8
        ldd   #Irq_one_frame           ; on every frame
        std   MC6846.TMSB
IrqOn
        lda   $6019
        ora   #$20
        sta   $6019                    ; STATUS : the timer's IRQ
        andcc #$EF                     ; the 6809's IRQ on
        rts

IrqOff
        lda   $6019
        anda  #$DF
        sta   $6019
        orcc  #$10
        rts

IrqPause
        pshs  a
        lda   $6019
        anda  #$20
        sta   IrqPause.state           ; on : to put back
        beq   >
        jsr   IrqOff
!       puls  a,pc

IrqUnpause
        pshs  a
        tst   IrqPause.state
        beq   >
        clr   IrqPause.state
        jsr   IrqOn
!       puls  a,pc

IrqPause.state fcb 0

IrqSync
 IFDEF IRQ_SPLIT
        sta   Irq_sync_line+1          ; the VBL's line, the splits are counted from it
        clr   Irq_sync_line
        clr   Irq_split_next
        clr   Irq_split_cur            ; no split until IrqManager schedules one
        clr   Irq_split_cur+1
 ENDC
        ldb   #$42
        stb   MC6846.TCR
        ldb   #8                       ; the line * 64 cycles / 8, the wait loop's
        mul
        tfr   d,y
        leay  -32,y                    ; adjusted by hand
!       tst   $E7E7
        bmi   <                        ; while the beam is in a visible line
!       tst   $E7E7
        bpl   <                        ; while it is not
!       leay  -1,y
        bne   <                        ; up to the line
        stx   MC6846.TMSB              ; the beam at the line's end
 IFDEF IRQ_SPLIT
        ldb   #$52                     ; TCR4 : a latch write no longer restarts the counter
        stb   MC6846.TCR               ; (IrqManager writes it one interrupt ahead)
 ENDC
        rts

 IFDEF OverlayMode
* the half page $4000-$5FFF the main thread had, read and put back exactly
* (never toggled : migration/relative-toggles-on-shared-registers.md) ;
* half 0, the objects, for the user routine
_irq.half.save MACRO
        lda   map.HALFPAGE
        anda  #%00000001
        sta   \1
        lda   map.HALFPAGE
        anda  #%11111110
        sta   map.HALFPAGE
 ENDM
_irq.half.restore MACRO
        lda   map.HALFPAGE             ; read again : bits 1-7 are live I/O
        anda  #%11111110
        ora   #0
\1      equ   *-1                      ; (dynamic) the half
        sta   map.HALFPAGE
 ENDM
 ENDC

IrqManager
        sts   @stack
        lds   #Irq_sys_stack
 IFDEF IRQ_SPLIT
        tst   Irq_split_next           ; the split's interrupt : its routine alone
        beq   @vbl
        clr   Irq_split_next
        jsr   [Irq_split_routine]
        jsr   IrqSplit_Schedule        ; then the next frame's, before its VBL
        bra   @end
@vbl    ldd   Irq_split_cur            ; the latch, for the interrupt after the next
        beq   @single
        inc   Irq_split_next           ; this frame's split comes next, then the VBL
        ldd   #Irq_one_frame
        subd  Irq_split_cur
        std   MC6846.TMSB
        bra   @count
@single jsr   IrqSplit_Schedule        ; no split this frame : the next one's
@count
 ENDC
        inc   gfxlock.frame.count+1
        bne   >
        inc   gfxlock.frame.count
!       tst   glb_Page
        beq   @smode                   ; the tile loop's mode
        _GetCartPageB
        stb   @page
 IFDEF OverlayMode
        _irq.half.save IrqManager.half
 ENDC
        jsr   [Irq_user_routine]
 IFDEF OverlayMode
        _irq.half.restore IrqManager.half
 ENDC
        lda   #0
@page   equ   *-1                      ; (dynamic) the caller's page
        _SetCartPageA
@end    lds   #0
@stack  equ   *-2                      ; (dynamic) the caller's stack
        jmp   $E830                    ; the monitor's IRQ return
@smode  ldb   <$E6
        stb   @page2
 IFDEF OverlayMode
        _irq.half.save IrqManager.half2
 ENDC
        jsr   [Irq_user_routine]
 IFDEF OverlayMode
        _irq.half.restore IrqManager.half2
 ENDC
        clr   glb_Page                 ; the tile loop's mode back
        lda   #0
@page2  equ   *-1                      ; (dynamic)
        sta   <$E6
        bra   @end

 IFDEF IRQ_SPLIT
* IrqSplit_Schedule - the next frame's split (Irq_split_line) : its period
* from the VBL's interrupt into the latch, loaded at that interrupt
IrqSplit_Schedule
        ldb   Irq_split_line
        cmpb  #200
        bhs   @none
        clra
        addd  #312                     ; lines from the VBL's interrupt
        subd  Irq_sync_line
        cmpd  #312
        blo   >
        subd  #312
!       aslb                           ; 64 cycles a line
        rola
        aslb
        rola
        aslb
        rola
        aslb
        rola
        aslb
        rola
        aslb
        rola
        std   Irq_split_cur
        subd  #1                       ; the timer counts to -1
        bra   >
@none   ldd   #0
        std   Irq_split_cur
        ldd   #Irq_one_frame
!       std   MC6846.TMSB
        rts
 ENDC

; the IRQ's own stack : the main thread may use S for something else than a
; stack (a stack blast copy) when the IRQ comes
        fill  0,32
Irq_sys_stack
