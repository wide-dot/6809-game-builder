dac.mute              EXPORT
dac.unmute            EXPORT

 SECTION code

; PCR4 and PCR5 are expected to be set to 1
; for CP2 to work as a programmable output
; thoses bits are set to 1 when boot/reboot
; no need to set thoses bits at runtime

dac.mute
        lda   map.MC6846.PCR
        ora   #%00001000
        sta   map.MC6846.PCR
        rts

dac.unmute
        lda   map.MC6846.PCR
        anda  #%11110111
        sta   map.MC6846.PCR
        rts

 ENDSECTION
