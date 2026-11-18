;*******************************************************************************
; bootfade : the loader's default scene. Fades the TO8 menu to black, shows
; a loading bar in page 3, then loads scenes.main over itself and jumps to
; it.
;*******************************************************************************

        org   $6100

bootfade
        ldu   #palette.to8.monitor        ; the menu's palette, to black :
        ldd   #$0000                      ; 15 frames, the VBL polled (no IRQ
        jsr   palette.fade                ; yet)

        ; page 3 (no file of the boot loads there) cleared in BM16 and shown,
        ; a grey track in its middle, the loader's own bar drawn over it
        _gfxmode.setBM16
        lda   map.CF74021.CART            ; the mapping kept
        pshs  a
        lda   #map.RAM_OVER_CART+3        ; page 3 over the cartridge, writable
        sta   map.CF74021.CART
        ldx   #$0000                      ; both banks black
        ldd   #$0000
@clear  std   ,x++
        cmpx  #$4000
        blo   @clear
        ldx   #boot.BAR_ADDR              ; the track : colour 1, both banks
        lda   #boot.BAR_HEIGHT
@line   ldb   #boot.BAR_WIDTH/4
@byte   pshs  b
        ldb   #$11
        stb   ,x
        stb   $2000,x
        puls  b
        leax  1,x
        decb
        bne   @byte
        leax  40-boot.BAR_WIDTH/4,x
        deca
        bne   @line
        puls  a
        sta   map.CF74021.CART
@vbl1   tst   map.CF74021.SYS1            ; the palette written in the VBL : a
        bpl   @vbl1                       ;   write while the screen is drawn
@vbl2   tst   map.CF74021.SYS1            ;   shows a dot on a real TO8
        bmi   @vbl2
        lda   #1*2                        ; entry 1 : the track
        sta   map.EF9369.A
        ldd   #boot.TRACK_GR*256+boot.TRACK_B
        sta   map.EF9369.D
        stb   map.EF9369.D
        ldd   #boot.BAR_GR*256+boot.BAR_B ; entry 2 : the bar
        sta   map.EF9369.D
        stb   map.EF9369.D
        lda   #%11000000                  ; page 3 on screen, border 0
        sta   map.CF74021.SYS2
        _ram.data.set #loader.PAGE        ; the loader's page, in the data window
        ldx   #bootfade.loadbar
        jsr   loader.ADDRESS+loader.loadbar.set.IDX
        ldx   #$6100                      ; scene.load's return : main's entry,
        pshs  x                           ; loaded over this code
        ldx   #scenes.main
        jmp   loader.ADDRESS+loader.scene.load.IDX

bootfade.loadbar                          ; loader.loadbar.set's parameters
        fcb   3                           ; page 3, shown
        fdb   boot.BAR_ADDR
        fcb   boot.BAR_WIDTH,boot.BAR_HEIGHT
        fcb   $22                         ; colour 2

        INCLUDE "engine/palette/palette-fade.asm"
