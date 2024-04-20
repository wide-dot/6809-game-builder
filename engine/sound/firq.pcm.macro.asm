_firq.pcm.init MACRO
        ldd   #firq.pcm.sample.play
        std   map.FIRQPT
 ENDM

_firq.pcm.play MACRO
        ldd   \1
        std   firq.pcm.sample
        ldd   \2
        std   map.MPLUS.TIMER
        andcc #%10111111    ; unmask firq
        lda   #%10011111
                            ; Control/status register
                            ;   Bit 7: R- Timer - INT requested by timer (0=NO, 1=YES)
                            ;          -W Timer - reset timer (0=do nothing, 1=reload period to counter)
                            ;   Bit 6: -------  - Unused
                            ;   Bit 5: -------  - Unused
                            ;   Bit 4: RW Timer - INT select (0=IRQ, 1=FIRQ)
                            ;   Bit 3: RW Timer - (F)IRQ enable (0=NO, 1=YES)
                            ;   Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
                            ;   Bit 1: RW Timer - enable countdown of timer (0=OFF, 1=ON)
                            ;   Bit 0: RW TI    - TI clock disable (0=enabled, 1=disabled)
                            ;   Note: Timer F/IRQ ack by CPU is done by reading this control register
        sta   map.MPLUS.CTRL
 ENDM