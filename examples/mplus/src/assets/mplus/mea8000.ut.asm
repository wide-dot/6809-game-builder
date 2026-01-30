sounds.mea8000               EXTERNAL
assets.sounds.mea8000$PAGE   EXTERNAL

mea8000.ut.testMEA8000       EXPORT
mea8000.ut.testMEA8000.440Hz EXPORT
mea8000.ut.detectMEA8000     EXPORT

 SECTION code

 ; ----------------------------------------------------------------------------
 ; testMEA8000
 ; ----------------------------------------------------------------------------

; phonemes
mea8000.ut.testMEA8000
        ; Test MEA8000 presence before running IRQ test
        jsr   mea8000.ut.detectMEA8000
        bcc   @mea8000Present           ; Carry clear = MEA8000 detected
        ;MEA8000 not present - display message and skip test
        _monitor.print #mea8000.ut.notDetected
        andcc #%11111110 ; OK
        rts
@mea8000Present
        _monitor.print #mea8000.ut.detected
        _ram.cart.set #assets.sounds.mea8000$PAGE
        lda   #$3C
        ldx   #mea8000.phonemes
        ldy   #sounds.mea8000
        jsr   mea8000.phonemes.read
        andcc #%11111110 ; OK
        rts

 ; ----------------------------------------------------------------------------
 ; testMEA8000.440Hz - Test MEA8000 with sustained vowel approximating 440Hz
 ; ----------------------------------------------------------------------------

mea8000.ut.testMEA8000.440Hz
        ; Test MEA8000 presence before running test
        jsr   mea8000.ut.detectMEA8000
        bcc   @mea8000Present           ; Carry clear = MEA8000 detected
        ; MEA8000 not present - display message and skip test
        _monitor.print #mea8000.ut.notDetected
        _monitor.print #main.str.CRLF
        andcc #%11111110 ; OK
        rts
@mea8000Present
        ; Display message to user
        _monitor.print #mea8000.ut.mea440Hz.pressKey
        _time.ms.wait #500
        
        ; Initialize MEA8000
        ldb   #map.MEA8000.STOP_SLOW
        stb   map.MEA8000.A
        lda   #$DC ; pitch 440Hz
        sta   map.MEA8000.D
        
        ; Generate sustained "AH" vowel sound using real phoneme data
        ; Using just the first frame: $86,$B3,$CD,$C0 (repeated as needed)
!       tst   map.MEA8000.A
        bpl   <
        ldd   #$00F0
        sta   map.MEA8000.D
        stb   map.MEA8000.D
        ldd   #$87E0
        sta   map.MEA8000.D
        stb   map.MEA8000.D
 IFDEF TO8
        _keyboard.fast.check
 ENDC
 IFDEF MO6
        _keyboard.fast.check #scancode.ENTER
 ENDC
        beq   <

        ; Stop MEA8000 with STOP command
        ldb   #map.MEA8000.STOP_IMMEDIATE
        stb   map.MEA8000.A
        andcc #%11111110               ; Clear carry flag (OK status)
        rts

; MEA8000 Detection Routine
; Based on standard polling pattern from mea8000.phonemes.read.asm
; Uses same sequence: STOP-SLOW + tonality, then wait for REQ=1
; output: Carry flag: 0=present, 1=not present
mea8000.ut.detectMEA8000
        pshs  d,x
        ; Send standard MEA8000 initialization sequence (same as phonemes.read)
        ldb   #map.MEA8000.STOP_SLOW    ; $1A - STOP-SLOW command
        stb   map.MEA8000.A             ; Send command to MEA8000
        lda   #$3C                      ; Default tonality (same as phonemes.read)
        sta   map.MEA8000.D             ; Send tonality
        ; 32ms of silence $86,$B3,$C8,$40
        ldd   #$86B3
        sta   map.MEA8000.D
        stb   map.MEA8000.D
        ldd   #$C840
        sta   map.MEA8000.D
        stb   map.MEA8000.D
        ldx   #$FFFF                    ; timeout counter
        ldb   map.MEA8000.A
        cmpb  #$80
        ;beq   @notPresent               ; ready signal is given too early (comment for DCMOTO testing)
@wait
        leax  -1,x
        beq   @notPresent               ; timeout
        tst   map.MEA8000.A             ; pooling
        bpl   @wait
@present
        andcc #$FE                      ; Clear carry = present
        puls  d,x,pc
@notPresent
        orcc  #$01                      ; Set carry = not present
        puls  d,x,pc

mea8000.ut.notDetected fcs "MEA8000 UNDETECTED "
mea8000.ut.detected fcs "DETECTED "

; MEA8000 test messages
mea8000.ut.mea440Hz.pressKey fcc "Playing MEA8000 sustained vowel (440Hz) - press enter to stop..."
                             _monitor.str.CRLF

 ENDSECTION 