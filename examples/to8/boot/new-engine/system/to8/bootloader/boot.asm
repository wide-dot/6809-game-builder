;*******************************************************************************
; FD Boot loader
; Original code from Prehisto
; Benoit Rousseau 07/2023 (memory ext. check)
; ------------------------------------------------------------------------------
; A fully featured boot loader
;*******************************************************************************

        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"

* Disk boot
        org    $6200
        setdp  $60

* Freeze interrupts
        orcc  #$50

* Check computer type
        leax  <mess1,pcr   ; Error message
        ldd   #$0260       ; Load code
        cmpa  >$fff0       ; Check machine code
        bhs   err          ; Error if not TO+

* Check computer memory
        IFDEF builder.CHECKMEMORYEXT
        ldx   #mess2       ; Error message
        lda   #$10
        sta   map.CF74021.DATA
        ldu   #$A000
        lda   #$55
        sta   ,u
        cmpa  ,u
        bne   err          ; Error if no memory ext.
        ENDC

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
        jmp   runloader

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

* Location message
mess0   fcb   $1f,$21,$21
        fcb   $1f,$11,$13     ; 3 lines (11-13)
        fcb   $1b,$47         ; font : white
        fcb   $1b,$51         ; background : red
        fcb   $0c             ; cls
        fcb   $1f,$4c,$4b+$80 ; locate for MO

        IFGT *-$6278
        ERROR "boot code part 1 is too large !"
        ENDC

        align $6278
@magicNumber
        fcn   "BASIC2"
        fcb   $00                                ; checksum (set at build stage)
secnbr  fcb   (builder.lwasm.size.loader/256)+1 ; number of sectors to read

* Error messages
mess1   fcs   "Only for TO8/8D/9+"
mess2   fcs   "Requires 256Ko ext."
mess3   fcs   "     I/O|Error"

* Interleave table
blist   fcb   $0f,$0d,$0b     ; first value is omitted ($01 : boot sector)
        fcb   $09,$07,$05,$03
        fcb   $08,$06,$04,$02
        fcb   $10,$0e,$0c,$0a

runloader
        ; set system stack
        lds   #$9F00

        ; load direntries
        ldd   #$0000 ; D: [diskid] [face]
        ldx   #$000E ; X: [track] [sector]
        jsr   $6300  ; load direntries

        ; load files
        ldx   #$0000 ; X: [file number]
        ldb   #$04   ; B: [destination - page number]
        ldu   #$A000 ; U: [destination - address]
        jsr   $6303  ; load file

        ldx   #$0003 ; X: [file number]
        ldb   #$04   ; B: [destination - page number]
        ldu   #$B000 ; U: [destination - address]
        jsr   $6303  ; load file

        ; uncompress files
        ldx   #$0000 ; X: [file number]
        ldb   #$04   ; B: [destination - page number]
        ldu   #$A000 ; U: [destination - address]
        jsr   $6306  ; uncompress file

        ldx   #$0003 ; X: [file number]
        ldb   #$04   ; B: [destination - page number]
        ldu   #$B000 ; U: [destination - address]
        jsr   $6306  ; uncompress file

        ; test DMA
        jmp   $6309  ;

        ; run
        ;jmp   $A000  ; run program

        IFGT *-$6300
        ERROR "boot code part 2 is too large !"
        ENDC
