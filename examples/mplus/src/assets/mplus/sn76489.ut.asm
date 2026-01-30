; data address
sounds.sn                       EXTERNAL
sounds.sn.noise                 EXTERNAL

; memory page based on file id
assets.sounds.sn$PAGE        EXTERNAL
assets.sounds.sn.noise$PAGE  EXTERNAL

sn76489.ut.testSN76489       EXPORT
sn76489.ut.testSN76489.440Hz EXPORT

 SECTION code

 ; ----------------------------------------------------------------------------
 ; testSN76489
 ; ----------------------------------------------------------------------------

sn76489.ut.testSN76489.lock fcb 0

sn76489.ut.testSN76489
        _irq.init

        ; select vgm to play
        tst   sn76489.ut.testSN76489.lock
        beq   >
        clr   sn76489.ut.testSN76489.lock
        _irq.setRoutine #sn76489.ut.testSN76489.noise.irq
        _vgc.obj.play #assets.sounds.sn.noise$PAGE,#sounds.sn.noise,#vgc.NO_LOOP,#sn76489.ut.testSN76489.callback
        bra   @on
!       
        _irq.setRoutine #sn76489.ut.testSN76489.irq
        _vgc.obj.play #assets.sounds.sn$PAGE,#sounds.sn,#vgc.NO_LOOP,#sn76489.ut.testSN76489.callback
@on     
        ; start irq
        _irq.set50Hz
        lda   map.MPLUS.CTRL
        anda  #%11111110 ; TI clock enable
        sta   map.MPLUS.CTRL
        _irq.on

        ; blocking code until callback is called
!       lda   sn76489.ut.testSN76489.lock
        beq   <

        ; reinit state
        _sn76489.init
        lda   map.MPLUS.CTRL
        ora   #%00000001 ; TI clock disable
        sta   map.MPLUS.CTRL
        andcc #%11111110
        rts

sn76489.ut.testSN76489.callback
        _irq.off
        lda   #1
        sta   sn76489.ut.testSN76489.lock
        rts

sn76489.ut.testSN76489.irq
        _vgc.frame.play #assets.sounds.sn$PAGE
        rts

sn76489.ut.testSN76489.noise.irq
        _vgc.frame.play #assets.sounds.sn.noise$PAGE
        rts

 ; ----------------------------------------------------------------------------
 ; testSN76489.440Hz - Test 440Hz A note on SN76489 channel 0
 ; ----------------------------------------------------------------------------

sn76489.ut.testSN76489.440Hz
        ; Initialize SN76489 to silent state
        _sn76489.init
        lda   map.MPLUS.CTRL
        anda  #%11111110 ; TI clock enable
        sta   map.MPLUS.CTRL

        ; Calculate frequency value for 440Hz
        ; SN76489 frequency = clock / (32 * freq_value)
        ; For 3.579545MHz clock: freq_value = 3579545 / (32 * 440) = 254 (decimal) = $00FE (hex)
        ; SN76489 uses 10-bit frequency values: bits 9-0
        
        ; Set Channel 0 frequency (440Hz)
        ; First byte: $80 | (freq_low_4bits) = $80 | $0E = $8E
        lda   #$8E                     ; Channel 0 frequency low nibble (bits 3-0 of freq)
        sta   map.SN76489.D
        nop                            ; Timing delay for SN76489
        nop
        
        ; Second byte: freq_high_6bits = $00FE >> 4 = $0F
        lda   #$0F                     ; Channel 0 frequency high 6 bits (bits 9-4 of freq)
        sta   map.SN76489.D
        nop                            ; Timing delay for SN76489
        nop
        
        ; Set Channel 0 volume to full volume (0 attenuation)
        ; $90 | volume_attenuation = $90 | $00 = $90
        lda   #$90                     ; Channel 0 volume (0 = full volume)
        sta   map.SN76489.D
        nop                            ; Timing delay for SN76489
        nop
        
        ; Wait for any key press to stop the 440Hz tone
        ; Display message to user
        _monitor.print #sn76489.ut.440Hz.pressKey

        _time.ms.wait #500
 IFDEF TO8
        _keyboard.fast.waitKey
 ENDC
 IFDEF MO6
        _keyboard.fast.waitKey #scancode.ENTER
 ENDC
        
        ; Silence Channel 0 by setting maximum attenuation
        lda   #$9F                     ; Channel 0 maximum attenuation (silent)
        sta   map.SN76489.D
        nop                            ; Timing delay for SN76489
        nop
        
        lda   map.MPLUS.CTRL
        ora   #%00000001 ; TI clock disable
        sta   map.MPLUS.CTRL
        andcc #%11111110               ; Clear carry flag (OK status)
        rts

; SN76489 test messages
sn76489.ut.440Hz.pressKey fcc "Playing SN76489 440Hz - press enter to stop..."
                          _monitor.str.CRLF

 ENDSECTION 