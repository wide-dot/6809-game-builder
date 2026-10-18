; ---------------------------------------------------------------------------
; CalcSine - B an angle (256 a turn) -> D 255 * its sine, X 255 * its cosine
; ---------------------------------------------------------------------------

CalcSine
        ldx   #Sine_Data
        clra
        aslb
        rola
        leax  d,x
        ldd   ,x     ; sin
        leax  $80,x
        ldx   ,x     ; cos : a quarter turn on
        rts

Sine_Data
        INCLUDEBIN "./engine/math/sinewave.bin"     