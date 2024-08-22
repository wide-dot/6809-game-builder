map.MEA8000.D EXTERNAL ; DONN
map.MEA8000.A EXTERNAL ; RCOM

 SECTION code

; read a list of mea frames
; first word is data length (this word included)
; first data byte is pitch
; next data are frames made of 4 bytes each
; when a frame with amplitude of 0 is read, data is ignored and a STOP command is emmitted
; reading continue with pitch byte and so on ...
;
; input: [X] addr of data
mea8000.digitalized.read
        pshs  d,x
        tfr   x,d
        addd  ,x++
        std   @dataEnd
@nextFrameGroup
        ldb   #$1A
        stb   map.MEA8000.A ; MEA STOP
        cmpx  #0
@dataEnd equ *-2
        blo   >
        puls  d,x,pc
!       lda   ,x+
        sta   map.MEA8000.D ; pitch
!       tst   map.MEA8000.A ; pooling
        bpl   <
@nextFrame
        ldd   2,x           ; check for STOP command (ampl=0)
        _asld   
        anda  #%00001111
        bne   >
        leax  4,x
        bra   @nextFrameGroup
!
        lda   #4
@nextByte
        ldb   ,x+
        stb   map.MEA8000.D ; frame data
!       tst   map.MEA8000.A
        bpl   <
        deca
        bne   @nextByte
        bra   @nextFrame

 ENDSECTION