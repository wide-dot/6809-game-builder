
; Init SN76489 sound chip to a default (silent) state
; ----------------------------------------------------

map.SN76489.D EXTERNAL

 SECTION code

 IFNDEF sn76489.init
sn76489.init
        lda   #$9F
        sta   map.SN76489.D
        nop
        nop
        lda   #$BF
        sta   map.SN76489.D
        nop
        nop
        lda   #$DF
        sta   map.SN76489.D
        nop
        nop
        lda   #$FF
        sta   map.SN76489.D
	    rts
 ENDC
 ENDSECTION