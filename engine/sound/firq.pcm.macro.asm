_firq.pcm.init MACRO
        ldd   #firq.pcm.sample.play
        std   map.FIRQPT
 ENDM

_firq.pcm.play MACRO
        ldd   \1
        std   firq.pcm.sample
        ldd   \2
        std   map.MPLUS.TIMER
        lda   #%10011110
                             ; Bit 7: R- Timer - INT requested by timer (0=NO, 1=YES)
                             ;        -W Timer - reset timer by reloading period to counter
                             ; Bit 6: -------  - Unused
                             ; Bit 5: -------  - Unused
                             ; Bit 4: RW Timer - INT select (0=IRQ, 1=FIRQ)
                             ; Bit 3: RW Timer - (F)IRQ (0=disabled, 1=enabled)
                             ; Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
                             ; Bit 1: RW Timer - countdown of timer (0=disabled, 1=enabled)
                             ; Bit 0: RW TI    - TI clock disable (0=enabled, 1=disabled)
                             ; Notes : - Timer F/IRQ ack by CPU is done by reading this control register
                             ;         - TI clock enable will be effective only after the first write to TI data register
        sta   map.MPLUS.CTRL
        andcc #%10111111     ; unmask firq
 ENDM

_firq.pcm.freezePlay MACRO
        _firq.pcm.play \1,\2
!       lda   [firq.pcm.sample]
        bpl   <
 ENDM