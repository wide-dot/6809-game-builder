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
