;*******************************************************************************
; FD Boot loader - Benoit Rousseau 04/2023
; ------------------------------------------------------------------------------
; A simple boot loader
;*******************************************************************************

boot.sector.end EXTERNAL

 SECTION code
        INCLUDE "./engine/constants.asm"
        INCLUDE "./engine/system/to8/map.const.asm"

        orcc  #$50                     ; stop irq
        lds   #glb_system_stack        ; set system stack
        lda   #$7B 
        sta   map.CF74021.LGAMOD       ; set video mode to bm16 (160x200x16)

        ; init ram settings
        ldb   map.CF74021.SYS1.R       ; hold $E7E7 state
        orb   #$10
        stb   map.CF74021.SYS1.R
        stb   map.CF74021.SYS1         ; $A000-$DFFF can now be recovered by RAM
        ldb   #$64                     ; $0000-$3FFF set RAM page 4
        stb   map.CF74021.CART
 
        ; read floppy disk and load default program
        lda   #$60
        tfr   a,dp
   
        ldd   #$0000
        std   <map.DK.BUF              ; DK.BUF $0000 data destination
        sta   <map.DK.DRV              ; DK.DRV $00
        std   <map.DK.TRK              ; DK.TRK $00
        lda   #$02                     ; start reading after boot sector
        sta   <map.DK.SEC              ; DK.SEC $02
        sta   <map.DK.OPC              ; DK.OPC $02 set operation to read
@loop   jsr   map.DKCO                 ; run operation
        inc   <map.DK.SEC              ; next sector
        lda   <map.DK.SEC
        cmpa  #$10                     ; if sector is <= 16
        bls   >                        ; continue
        lda   #$01                     ; else
        sta   <map.DK.SEC              ; init sector to 1
        inc   <map.DK.TRK+1            ; move to next track
        lda   <map.DK.TRK+1
        cmpa  #$4F                     ; if track <= 79
        bls   >                        ; continue
        clr   <map.DK.TRK+1            ; else set track to 0
        inc   <map.DK.DRV              ; move to next drive (face)
!       inc   <map.DK.BUF              ; move to next data destination (by 256 bytes)
        ldd   <map.DK.BUF
        cmpd  #boot.sector.end         ; end of data ?
        bls   @loop

        ; wait spot to be out of display area
!       tst   map.CF74021.SYS1
        bpl   <
!       tst   map.CF74021.SYS1
        bmi   <

        ; set video pages
        ldd   #$C002
        sta   map.CF74021.SYS2         ; display RAM page 3 on screen
        stb   map.CF74021.DATA         ; set RAM page 2 in $A000-$DFFF

        ; run the loader
        jmp   $0000

        align $0078
@magicNumber
        fcn   "BASIC2"
        fcb   $00                      ; checksum

        jmp   @test
        jmp   fd.test
        nop
fd.test fdb   0
@test   fcb   0

 ENDSECTION