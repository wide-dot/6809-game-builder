;*******************************************************************************
; FD Boot loader
; Original code from Prehisto (Mission: Liftoff)
; Benoit Rousseau 07/2023 (lwasm syntax)
; ------------------------------------------------------------------------------
; A fully featured boot loader
;*******************************************************************************

        INCLUDE "./engine/constants.asm"
        INCLUDE "./engine/system/to8/map.const.asm"

* Disk boot
        org    $6200
        setdp  $60

* Freeze interrupts
        orcc  #$50

* Check computer type
        leax  <mess1,pcr ; Error message
        lda   #$02       ; Load code
        cmpa  >$fff0     ; Check machine code
        bhs   err        ; Error if not TO+

        jsr   checkmemoryext

* Switch to Basic 1.0 if necessary
        ldb   #$60
        cmpb  >$001a  ; Skip if
        beq   boot1   ; BASIC1.0
        ldu   #boot0  ; Switch to
        jmp   >$ec03  ; BASIC 1.0
boot0   jmp   [$001e] ; Reset cartridge

* Prepare to load
* Initialize system
boot1   lds   #$60cc  ; System stack
* Load loader sectors
        ldd   #$6300       ; Loading
        std   <map.DK.BUF  ; address
        stb   <$60ff       ; Cold reset
        lda   #$02         ; >read code
        std   <map.DK.OPC  ; Read/Head 0
        ldu   #blist       ; Interleave list
        ldx   #mess3       ; Error message
boot2   lda   b,u          ; Get sector
        sta   <map.DK.SEC  ; number
        jsr   >map.DKCONT  ; Load sector
        bcc   boot3        ; Skip if no error
        jsr   >map.DKCONT  ; Reload sector
        bcs   err          ; Skip if error
boot3   inc   <map.DK.BUF  ; Move sector ptr
        incb               ; Sector+1
        dec   >secnbr      ; Next
        bne   boot2        ; sector
        clra               ; Load first
        jmp   $0000        ; program

* Display error message
err     leau  <mess0,pcr ; Location
        bsr   err2       ; Display location
        leau  ,x         ; Message pointer
        bsr   err2       ; Display message
err0    bra   err0       ; Infinite loop

* Display message
err1    bsr   err3     ; Display char
err2    ldb   ,u+      ; Read char
        bpl   err1     ; Next if not last
        andb  #$7f     ; Mask char
err3    tfr   dp,a     ; Read DP
        asla           ; Check if MO or TO
        lbmi  map.PUTC ; Display for TO - PUTC
        swi            ; Display for MO
        fcb   $82      ; Display for MO - PUTC parameter

        IFGT *-$6278
        ERROR "boot code part 1 is too large !"
        ENDC

        align $6278
@magicNumber
        fcn   "BASIC2"
        fcb   $00     ; checksum (set at build stage)

secnbr  fcb   $00     ; Sector number (set at build stage)

* Error messages
mess1   fcs   "Only for TO8/8D/9+"
mess2   fcs   "Requires 256Ko ext."
mess3   fcs   "     I/O|Error"

* Check computer memory
checkmemoryext
        ldx   #mess2  ; Error message
        lda   #$10
        sta   map.CF74021.DATA
        ldu   #$A000
        lda   #$55
        sta   ,u
        cmpa  ,u
        bne   err     ; Error if no memory ext.
        rts

* Location message
mess0   fcb   $1f,$21,$21
        fcb   $1f,$11,$13     ; 3 lines (11-13)
        fcb   $1b,$47         ; font : white
        fcb   $1b,$51         ; background : red
        fcb   $0c             ; cls
        fcb   $1f,$4c,$4b+$80 ; locate for MO

* Interleave table
blist   equ   *
        fcb   $0f,$0d,$0b
        fcb   $09,$07,$05,$03
        fcb   $08,$06,$04,$02
        fcb   $10,$0e,$0c,$0a

        IFGT *-$6300
        ERROR "boot code part 2 is too large !"
        ENDC
