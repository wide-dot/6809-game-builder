* ---------------------------------------------------------------------------
* IrqSecond
* ---------
* An IRQ user routine counting the time : glb_timer_frame the frames (0-49),
* glb_timer the minutes then the seconds (0-59)
* ---------------------------------------------------------------------------

IrqSecond
        lda   glb_timer_frame
        inca
        cmpa  #50
        bne   >
        ldd   glb_timer
        incb                           ; a second
        cmpb  #60
        bne   @store
        clrb
        inca                           ; a minute
@store  std   glb_timer
        clra
!       sta   glb_timer_frame
        rts
