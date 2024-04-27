_monitor.chr.CRLF MACRO
        fcb $0A,$0D
 ENDM

_monitor.str.CRLF MACRO
        fcb $0A,$0D+$80
 ENDM

_monitor.print MACRO
        ldx   \1
        jsr   monitor.print ; print a string with putc
 ENDM

_monitor.printHex8 MACRO
        ldb   \1
        jsr   monitor.printHex8
 ENDM

_monitor.printHex16 MACRO
        ldd   \1
        jsr   monitor.printHex16
 ENDM

_monitor.putc MACRO
        ldb   \1
        jsr   map.PUTC
 ENDM

_monitor.console.set80C MACRO
        _monitor.print #_monitor.console.set80C.data ; print a string with putc
        bra   _monitor.console.set80C.end
_monitor.console.set80C.data
        fcb   $14         ; hide cursor
        fcb   $1B,$41     ; ink color
        fcb   $1B,$50     ; background color
        fcb   $1B,$60     ; frame color
        fcb   $0C         ; clear screen
        fcb   $1B,$5B+$80 ; 80 col gfx mode
_monitor.console.set80C.end
 ENDM

_monitor.console.set40C MACRO
        _monitor.print #_monitor.console.set40C.data ; print a string with putc
        bra   _monitor.console.set40C.end
_monitor.console.set40C.data
        fcb   $14         ; hide cursor
        fcb   $1B,$47     ; ink color
        fcb   $1B,$50     ; background color
        fcb   $1B,$60     ; frame color
        fcb   $0C         ; clear screen
        fcb   $1B,$5A+$80 ; 40 col gfx mode
_monitor.console.set40C.end
 ENDM

_monitor.setp MACRO
        lda   \1
        ldx   \2
        ldy   \3
        jsr   map.SETP ; set palette
 ENDM