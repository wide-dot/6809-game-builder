map.MEA8000.D EXTERNAL ; DONN
map.MEA8000.A EXTERNAL ; RCOM

 SECTION code

; read a list of MEA8000 frames
; first word is data length (this word included)
; first data byte is pitch
; next data are frames made of 4 bytes each
; when a frame with amplitude of 0 is read, a STOP command is emmitted at the end of frame
; reading continue with new pitch byte and so on ...
;
; input: [X] addr of data
mea8000.digitalized.read
        pshs  d,x
        tfr   x,d
        addd  ,x++
        std   @dataEnd
@nextFrameGroup
        ldb   #$1A
        stb   map.MEA8000.A ; MEA STOP (silent mode), STOP-SLOW procedure, REQ inactive
        cmpx  #0
@dataEnd equ *-2
        blo   >
        puls  d,x,pc
!       ldb   ,x+
        stb   map.MEA8000.D ; pitch
!       tst   map.MEA8000.A ; pooling
        bpl   <
@nextFrame
        ldd   ,x++
        sta   map.MEA8000.D ; frame data b1, min of 3 cycles btw each byte, pooling is unnecessary
        stb   map.MEA8000.D ; frame data b2
        ldd   ,x++
        sta   map.MEA8000.D ; frame data b3
        stb   map.MEA8000.D ; frame data b4
!       tst   map.MEA8000.A ; pooling to wait during frame processing (8, 16, 32, 64 ms)
        bpl   <
        _asld               ; check for ampl=0 (will throw a STOP command)
        anda  #%00001111
        beq   @nextFrameGroup
        bra   @nextFrame

 ENDSECTION