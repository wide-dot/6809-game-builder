monitor.print EXPORT

 SECTION code

; send an array of codes to putc with bit 7 of the final byte set
; input: [X] addr of string
monitor.print
!       ldb   ,x+
        bmi   @lastC
        jsr   map.PUTC
        bra   <
@lastC  andb  #%01111111
        jmp   map.PUTC                 ; print last char and return

monitor.printHex8
        bsr   >
        exg   a,b
!       lda   #$10
        mul
        adda  #$90
        daa
        adca  #$40
        daa
        exg   a,b
        jmp   map.PUTC

monitor.printHex16
        pshs  b
        exg   a,b
        jsr   monitor.printHex8
        puls  b
        jmp   monitor.printHex8

 ENDSECTION

