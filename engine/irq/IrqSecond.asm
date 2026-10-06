* ---------------------------------------------------------------------------
* IrqSecond
* ---------------
* IRQ Subroutine to count elapsed seconds
* ---------------------------------------------------------------------------

        ;setdp $E7 ; V2-DEVIATION: setdp neutralized (not permitted in lwasm
                  ; obj target) ; no direct operand below
                  ; (migration/setdp-obj-target.md)
IrqSecond
        lda   glb_timer_frame
        inca
        cmpa  #50
        bne   @skip
        ldd   glb_timer
        incb
        cmpb  #60
        bne   >
        ldb   #0
        inca
!       std   glb_timer
        lda   #0
@skip   sta   glb_timer_frame
	rts

        ;setdp dp/256 ; V2-DEVIATION: setdp neutralized (see above)