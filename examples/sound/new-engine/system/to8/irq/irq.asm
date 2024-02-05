
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

irq.set50Hz        EXPORT
irq.on             EXPORT
irq.off            EXPORT
irq.syncScreenLine EXPORT
irq.userRoutine    EXPORT

 SECTION code

irq.userRoutine fdb 0                  ; user irq routine called by irq.manage 

;-----------------------------------------------------------------
; irq.set50Hz
;
; reset REG : [d]
;-----------------------------------------------------------------
; set irq to call at 50Hz frequency
;-----------------------------------------------------------------
irq.set50Hz
        ldb   #$42
        stb   map.MC6846.TCR           ; timer precision x8
        ldd   #irq.ONE_FRAME           ; on every frame
        std   map.MC6846.TMSB
        jsr   irq.on   
        rts
       
;-----------------------------------------------------------------
; irq.on
;
; reset REG : [a]
;-----------------------------------------------------------------
; set irq active
;-----------------------------------------------------------------
irq.on
        lda   map.STATUS
        bita  #$20
        bne   >
        ora   #$20
        sta   map.STATUS
        andcc #$EF                     ; tell 6809 to activate irq
!       rts

;-----------------------------------------------------------------
; irq.on
;
; reset REG : [a]
;-----------------------------------------------------------------
; set irq inactive
;-----------------------------------------------------------------
irq.off 
        lda   map.STATUS                           
        bita  #$20
        beq   >
        anda  #$DF
        sta   map.STATUS
        orcc  #$10                     ; tell 6809 to inactivate irq
!       rts

;-----------------------------------------------------------------
; irq.syncScreenLine
;
; input REG : [d] screen line (0-311)
;             [x] timer value
; reset REG : [d] [y]
;-----------------------------------------------------------------
; This routine sync irq timer with a desired screen line
; line 0 is the first one in visible area, lines 200-311 are
; bottom followed by top border
;-----------------------------------------------------------------
irq.syncScreenLine
        _asld                          ; ligne * 64 (cycles per line) / 8 (nb tempo loop cycles)
        _asld
        _asld
        tfr   d,y
        ldb   #$42
        stb   map.MC6846.TCR
        leay  -32,y                    ; manual adjustment
!
        tst   map.CF74021.SYS1         ;
        bmi   <                        ; while spot is in a visible screen line        
!       tst   map.CF74021.SYS1         ;
        bpl   <                        ; while spot is not in a visible screen line
!       leay  -1,y                     ;
        bne   <                        ; wait until desired line
                                       ; spot is at the end of desired line
        stx   map.MC6846.TMSB          ; set timer
        rts  

;-----------------------------------------------------------------
; irq.manage
;
; input REG : [dp] $E7 (set by the monitor)
; reset REG : [none]
;-----------------------------------------------------------------
; This routine run all requested engine code before and after
; the user irq routine
;-----------------------------------------------------------------

irq.manage
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
        jmp   map.IRQ.EXIT             ; return to caller
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