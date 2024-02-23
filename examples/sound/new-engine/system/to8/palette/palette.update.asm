; ---------------------------------------------------------------------------
; palette.update
; ----------------
; Subroutine to update palette (unrolled loop version)
;
; input REG : none
; reset REG : [d] [x] [y]
; ---------------------------------------------------------------------------

palette.update  EXPORT
palette.status  EXPORT
palette.current EXPORT
palette.buffer  EXPORT

 SECTION code

palette.status  fcb   palette.REFRESH_OFF
palette.current fdb   palette.buffer
palette.buffer  fill  0,$20

palette.update
        tst   palette.status
        beq   >                        ; update only if state is ready
        rts
!       pshs  dp
        ldd   #map.REG.DP              ; implicit load of [a]=0
        tfr   b,dp  
        ldx   palette.current
        sta   <map.EF9369.A            ; color index 0
!       ldd   ,x                       ; load color
        sta   <map.EF9369.D            ; set green and red
        stb   <map.EF9369.D            ; set blue
        ldd   2,x                      ; repeat for each color
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   4,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   6,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   8,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   10,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   12,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   14,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   16,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   18,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   20,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   22,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   24,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   26,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   28,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        ldd   30,x
        sta   <map.EF9369.D
        stb   <map.EF9369.D
        com   palette.status
        puls dp,pc

 ENDSECTION