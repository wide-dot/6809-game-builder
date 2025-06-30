dac.mute              EXPORT
dac.unmute            EXPORT

 SECTION code

; PCR4 and PCR5 are expected to be set to 1
; for CP2 to work as a programmable output
; thoses bits are set to 1 when boot/reboot
; no need to set thoses bits at runtime

dac.mute
        lda   map.DAC_MUTE
        ora   #map.bit.DAC_MUTE
        sta   map.DAC_MUTE
        rts

dac.unmute
        lda   map.DAC_MUTE
        anda  #^map.bit.DAC_MUTE
        sta   map.DAC_MUTE
        rts

 ENDSECTION
