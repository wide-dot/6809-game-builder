_firq.pcm.init MACRO
        ldd   #firq.pcm.sample.play
        std   map.FIRQPT
 ENDM

_firq.pcm.play MACRO
        orcc  #$40           ; deactivate FIRQ
        ldd   \1
        std   firq.pcm.sample
        ldd   \2
        std   map.MPLUS.TIMER
        lda   #%00001111
                             ; Bit 4: RW Timer - IRQ select (0=FIRQ, 1=IRQ)
                             ; Bit 3: RW Timer - (F)IRQ enable
                             ; Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
                             ; Bit 1: RW Timer - enable countdown of counter
                             ; Bit 0: -W Timer - reset timer (0=do nothing, 1=reload period to counter)
        sta   map.MPLUS.CTRL
        andcc #$BF           ; activate FIRQ
 ENDM