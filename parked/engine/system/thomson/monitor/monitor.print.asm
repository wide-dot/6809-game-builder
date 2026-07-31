monitor.print EXPORT

 SECTION code

; send an array of codes to putc with bit 7 of the final byte set
; input: [X] addr of string
monitor.print
!       ldb   ,x+
        bmi   @lastC
        _monitor.jsr.putc
        bra   <
@lastC  andb  #%01111111
        _monitor.jmp.putc

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
        _monitor.jmp.putc

monitor.printHex16
        pshs  b
        exg   a,b
        jsr   monitor.printHex8
        puls  b
        jmp   monitor.printHex8

 ENDSECTION

