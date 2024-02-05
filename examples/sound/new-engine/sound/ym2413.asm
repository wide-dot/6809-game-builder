
; Reset YM2413 sound chip to a default (silent) state
; ----------------------------------------------------

map.YM2413.A EXTERNAL
map.YM2413.D EXTERNAL

 SECTION code

 IFNDEF ym2413.init
ym2413.init
        ldd   #$200E
        stb   map.YM2413.A
        nop                            ; (wait of 2 cycles)
        ldb   #0                       ; (wait of 2 cycles)
        sta   map.YM2413.D             ; note off for all drums     
        lda   #$20                     ; (wait of 2 cycles)
        brn   *                        ; (wait of 3 cycles)
@c      exg   a,b                      ; (wait of 8 cycles)                                      
        exg   a,b                      ; (wait of 8 cycles)                                      
        sta   map.YM2413.A
        nop
        inca
        stb   map.YM2413.D
        cmpa  #$29                     ; (wait of 2 cycles)
        bne   @c                       ; (wait of 3 cycles)
        rts  
 ENDC

 ENDSECTION