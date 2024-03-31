_firq.pcm.init MACRO
        ldd   #firq.pcm.sample.play
        std   map.FIRQPT
 ENDM

_firq.pcm.play MACRO
        orcc  #$40           ; deactivate FIRQ
        ldd   \1
        std   firq.pcm.sample
        ldd   \2
        sta   map.MPLUS.TIMER
        stb   map.MPLUS.TIMER+1
        lda   map.MPLUS.CTRL
        anda  #%11101111
                             ; unset Bit 4: RW Timer - IRQ select (0=FIRQ, 1=IRQ)
        ora   #%00001111
                             ; set   Bit 3: RW Timer - (F)IRQ enable
                             ; set   Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
                             ; set   Bit 1: RW Timer - enable countdown of counter
                             ; set   Bit 0: -W Timer - reset timer (0=do nothing, 1=reload period to counter)
        sta   map.MPLUS.CTRL
        andcc #$BF           ; activate FIRQ
 ENDM