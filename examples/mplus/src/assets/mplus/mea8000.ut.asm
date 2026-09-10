sounds.mea8000               EXTERNAL
assets.sounds.mea8000$PAGE   EXTERNAL
sounds.mea8000.vocabulary    EXTERNAL
assets.sounds.mea8000.vocabulary$PAGE EXTERNAL

mea8000.ut.testMEA8000       EXPORT
mea8000.ut.testMEA8000.440Hz EXPORT
mea8000.ut.testFiles         EXPORT
 IFDEF TO8
mea8000.ut.testFileIrq       EXPORT
 ENDC
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
        jsr   dac.enable
        _ram.cart.set #assets.sounds.mea8000$PAGE
        lda   #$3C
        ldx   #mea8000.phonemes
        ldy   #sounds.mea8000
        jsr   mea8000.phonemes.read
        jsr   dac.disable
        andcc #%11111110 ; OK
        rts

 ; ----------------------------------------------------------------------------
 ; testFiles - play every file of the vocabulary image (polling player)
 ; ----------------------------------------------------------------------------
 ; The image mixes two Cedic-Nathan words of 1985 (bonjour, bienvenue) with
 ; files produced by the mea8000 encoder: the same player reads both.

mea8000.ut.testFiles
        jsr   mea8000.ut.detectMEA8000
        bcc   @mea8000Present
        _monitor.print #mea8000.ut.notDetected
        andcc #%11111110 ; OK
        rts
@mea8000Present
        _monitor.print #mea8000.ut.detected
        jsr   dac.enable     ; the chip's output rides the sound line: open it
        _ram.cart.set #assets.sounds.mea8000.vocabulary$PAGE
        ldx   #sounds.mea8000.vocabulary
        clrb                 ; file number
@next
        pshs  b
        clra
        lslb
        rola
        ldd   d,x            ; offset table entry, $FFFF ends the table
        cmpd  #$FFFF
        puls  b
        beq   @done
        jsr   mea8000.rom.read
        incb
        bra   @next
@done
        jsr   dac.disable
        andcc #%11111110 ; OK
        rts

 ; ----------------------------------------------------------------------------
 ; testFileIrq - play the first file with the interrupt-driven player (TO8)
 ; ----------------------------------------------------------------------------

 IFDEF TO8
mea8000.ut.testFileIrq
        jsr   mea8000.ut.detectMEA8000
        bcc   @mea8000Present
        _monitor.print #mea8000.ut.notDetected
        andcc #%11111110 ; OK
        rts
@mea8000Present
        _monitor.print #mea8000.ut.detected
        jsr   dac.enable
        _ram.cart.set #assets.sounds.mea8000.vocabulary$PAGE
        ldx   #sounds.mea8000.vocabulary
        ldd   ,x             ; first file
        leax  d,x
        jsr   mea8000.file.read.irq.start
        jsr   mea8000.file.read.irq.wait
        jsr   dac.disable
        andcc #%11111110 ; OK
        rts
 ENDC

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
 IFDEF TO8
        jsr   joypad.init    ; pad readable (see main.checkButton)
 ENDC
        
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
        jsr   main.checkButton
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
mea8000.ut.mea440Hz.pressKey fcc "Playing MEA8000 sustained vowel (440Hz) - press a key or button 2 to stop..."
                             _monitor.str.CRLF

 ENDSECTION 