vgm.ym                       EXTERNAL
vgm.ym.rythm                 EXTERNAL

ym2413.ut.testYM2413         EXPORT
ym2413.ut.testYM2413.440Hz   EXPORT

  SECTION code

 ; ----------------------------------------------------------------------------
 ; testYM2413
 ; ----------------------------------------------------------------------------

page.ymm equ map.RAM_OVER_CART+5
page.ymm.rythm equ map.RAM_OVER_CART+6
ym2413.ut.testYM2413.lock fcb 0

ym2413.ut.testYM2413
        _irq.init
        _irq.setRoutine #ym2413.ut.testYM2413.irq
        _irq.set50Hz

        lda   ym2413.ut.testYM2413.lock
        beq   >
        clr   ym2413.ut.testYM2413.lock
        _ymm.obj.play #page.ymm,#vgm.ym.rythm,#ymm.NO_LOOP,#ym2413.ut.testYM2413.callback
        bra   @on
!       _ymm.obj.play #page.ymm,#vgm.ym,#ymm.NO_LOOP,#ym2413.ut.testYM2413.callback
@on     _irq.on
!       lda   ym2413.ut.testYM2413.lock
        beq   <
        _ym2413.init
        andcc #%11111110
        rts

ym2413.ut.testYM2413.callback
        _irq.off
        lda   #1
        sta   ym2413.ut.testYM2413.lock
        rts

ym2413.ut.testYM2413.irq
        _cart.setRam #page.ymm
        _ymm.frame.play
        rts

 ; ----------------------------------------------------------------------------
 ; testYM2413.440Hz - Test 440Hz A note on YM2413 channel 0
 ; ----------------------------------------------------------------------------

ym2413.ut.testYM2413.440Hz
        ; Initialize YM2413 to silent state
        _ym2413.init
        
        ; Flush keyboard buffer to prevent immediate termination
@flushKeyboard
        jsr   map.KTST                 ; Test if a key is in buffer
        bcc   @keyboardFlushed         ; No key, buffer is empty
        jsr   map.GETC                 ; Read and discard the key
        bra   @flushKeyboard           ; Check for more keys
@keyboardFlushed
        
        ; Configure YM2413 for 440Hz on channel 0
        ; YM2413 frequency formula: freq = (fMaster / 72) * fNumber / 2^(19-octave)
        ; Rearranged: fNumber = freq * 2^(19-octave) / (fMaster / 72)
        ; For 440Hz at octave 4: fNumber = 440 * 2^(19-4) / (3579545 / 72)
        ; fNumber = 440 * 32768 / 49715.9 = 290 (decimal) = $0122 (hex)
        
        ; Set instrument on channel 0 (use built-in instrument 8 - organ, clear tone)
        lda   #$30                     ; Register $30 = channel 0 instrument/volume
        sta   map.YM2413.A
        nop                            ; Wait cycles between register writes
        nop
        lda   #$80                     ; Instrument 8 (Organ) + maximum volume (0)
        sta   map.YM2413.D
        nop
        nop
        
        ; Set F-Number low byte for channel 0 ($22 from $0122)
        lda   #$10                     ; Register $10 = channel 0 F-Number low
        sta   map.YM2413.A
        nop
        nop
        lda   #$22                     ; F-Number low byte = $22 (from $0122)
        sta   map.YM2413.D
        nop
        nop
        
        ; Set F-Number high byte + octave + key on for channel 0
        lda   #$20                     ; Register $20 = channel 0 F-Number high + octave + key
        sta   map.YM2413.A
        nop
        nop
        ; Key ON (bit 4) + Octave 4 (bits 3-1) + F-Number high bit ($01 from $0122)
        ; %00010000 (Key ON) + %00001000 (Octave 4) + %00000001 (F-Number bit 8) = $19
        lda   #$19                     ; Key ON + Octave 4 + F-Number high bit
        sta   map.YM2413.D
        nop
        nop
        
        ; Wait for any key press to stop the 440Hz tone
        ; Display message to user
        _monitor.print #ym2413.ut.440Hz.pressKey
@waitForKey
        jsr   map.KTST                 ; Test if a key is pressed
        bcc   @waitForKey              ; No key pressed, continue waiting
        
        ; Clear the keyboard buffer by reading the key
        jsr   map.GETC                 ; Read and discard the pressed key
        
        ; Turn off the note (key off)
        lda   #$20                     ; Register $20 = channel 0 F-Number high + octave + key
        sta   map.YM2413.A
        nop
        nop
        lda   #$09                     ; Key OFF (bit 4 = 0) + Octave 4 + F-Number high bit = $09
        sta   map.YM2413.D            ; %00001001 = Key OFF + Octave 4 + F-Number high bit
        nop
        nop
        
        ; Re-initialize YM2413 to ensure clean silence
        _ym2413.init
        
        andcc #%11111110               ; Clear carry flag (OK status)
        rts

; YM2413 test messages
ym2413.ut.440Hz.pressKey fcc "Playing YM2413 440Hz - Press any key to stop..."
                         _monitor.str.CRLF
 ENDSECTION 