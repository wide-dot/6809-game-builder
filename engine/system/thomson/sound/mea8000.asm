map.MEA8000.D EXTERNAL ; DONN
map.MEA8000.A EXTERNAL ; RCOM

 SECTION code

; read a list a phonemes
; input: [A] tonality
; input: [X] addr of phonemes 3.3 lookup
; input: [Y] addr of txt to read
mea8000.read
        pshs  d,x,y,u
        ldb   #$1A
        stb   map.MEA8000.A ; MEA init to STOP-SLOW and REQ inactive
        sta   map.MEA8000.D ; Default speech tonality
@nextPhoneme
        lda   ,y+
        bpl   >
        puls  d,x,y,u,pc
!       lsla
        ldu   a,x
        lda   ,u+ ; nb of bytes for this phoneme
@nextByte
        ldb   ,u+
!       tst   map.MEA8000.A ; pooling
        bpl   <
        stb   map.MEA8000.D
        deca
        beq   @nextPhoneme
        bra   @nextByte

 ENDSECTION