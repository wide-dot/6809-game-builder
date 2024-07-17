map.MEA8000.D EXTERNAL ; DONN
map.MEA8000.A EXTERNAL ; RCOM

 SECTION code

; read a list a phonemes
; input: [Y] addr of a list (offsets to phonemes 3.3 table)
mea8000.read
        pshs  d,x,y,u
        lda   #$1A
        sta   map.MEA8000.A ; MEA init to STOP-SLOW and REQ inactive
        lda   #$3C
        sta   map.MEA8000.D ; Default speech tonality (TODO set as parameter)
        

        pshs  d,x,y,u,pc

 ENDSECTION