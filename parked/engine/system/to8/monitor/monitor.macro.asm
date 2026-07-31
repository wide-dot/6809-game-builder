 IFNDEF to8.monitor.macro.asm
to8.monitor.macro.asm equ 1

_monitor.jsr.ktst MACRO
        jsr   map.KTST
 ENDM

_monitor.jsr.getc MACRO
        jsr   map.GETC
 ENDM

_monitor.jsr.putc MACRO
        jsr   map.PUTC
 ENDM

_monitor.jsr.putc.invoke MACRO
        ldb   \1
        _monitor.jsr.putc
 ENDM

_monitor.jsr.setp MACRO
        jsr   map.SETP
 ENDM

_monitor.jsr.setp.invoke MACRO
        lda   \1
        ldx   \2
        ldy   \3
        _monitor.jsr.setp
 ENDM

_monitor.jmp.ktst MACRO
        jmp   map.KTST
 ENDM

_monitor.jmp.getc MACRO
        jmp   map.GETC
 ENDM

_monitor.jmp.putc MACRO
        jmp   map.PUTC
 ENDM

_monitor.jmp.putc.invoke MACRO
        ldb   \1
        _monitor.jmp.putc
 ENDM

_monitor.jmp.setp MACRO
        jmp   map.SETP
 ENDM

_monitor.jmp.setp.invoke MACRO
        lda   \1
        ldx   \2
        ldy   \3
        _monitor.jmp.setp
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

 ENDC