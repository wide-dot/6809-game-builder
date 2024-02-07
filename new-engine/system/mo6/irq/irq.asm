
;*******************************************************************************
; irq
; ------------------------------------------------------------------------------
; IRQ Manager
;
; Special mode (glb_Page==0) is when page switching does not need to test
; if RAM or ROM is in use. In this case RAM is always expected as page type.
; This allows the use of <$E6 register without calling engine macro for
; page switch, thus it reduces the cycles cost. Used in tile rendering.
;
;*******************************************************************************

irq.on             EXPORT
irq.off            EXPORT
irq.userRoutine    EXPORT

 SECTION code

irq.userRoutine fdb 0                  ; user irq routine called by irq.manage 
    
;-----------------------------------------------------------------
; irq.on
;
; reset REG : [a]
;-----------------------------------------------------------------
; set irq active
;-----------------------------------------------------------------
irq.on
        lda   #1
        sta   map.IRQSEMAPHORE
        andcc #$EF                     ; tell 6809 to activate irq
!       rts

;-----------------------------------------------------------------
; irq.off
;
; reset REG : [a]
;-----------------------------------------------------------------
; set irq inactive
;-----------------------------------------------------------------
irq.off 
        clr   map.IRQSEMAPHORE
        orcc  #$10                     ; tell 6809 to inactivate irq
!       rts

;-----------------------------------------------------------------
; irq.manage
;
; input REG : [dp] $20 (set by the monitor)
; reset REG : [none]
;-----------------------------------------------------------------
; This routine run all requested engine code before and after
; the user irq routine
;-----------------------------------------------------------------

irq.manage
        lda   #map.EXTPORT
        tfr   a,dp
        sts   @stack                   ; backup system stack
        lds   #irq.systemStack         ; set tmp system stack for IRQ 
        inc   gfxlock.frame.count+1
        bne   >
        inc   gfxlock.frame.count
!
        tst   glb_Page                 ; test special mode (glb_Page==0)
        beq   @smode                   ; branch if rendering tiles - force RAM use instead of testing ROM or RAM
        _GetCartPageB
        stb   @page                    ; backup data page normally
        jsr   [irq.userRoutine]
        lda   #0                       ; (dynamic)
@page   equ   *-1
        _SetCartPageA                  ; restore data page
@end    lds   #0                       ; (dynamic) restore system stack   
@stack  equ   *-2
        lda   #map.REG.DP
        tfr   a,dp
        rti                            ; return to caller
@smode
        ldb   <map.STATUS
        stb   @page2                   ; backup data page
        jsr   [irq.userRoutine]
        anda  #0
        sta   glb_Page                 ; restore special page mode
        lda   #0                       ; (dynamic)
@page2  equ   *-1
        sta   <map.STATUS              ; restore data page
        bra   @end

; This space allow the use of system stack inside IRQ calls
; otherwise the writes in sys stack will erase data when S is in use
; (outside of IRQ) for another task than sys stack, ex: stack blast copy 
        fill  0,32
irq.systemStack

 ENDSECTION