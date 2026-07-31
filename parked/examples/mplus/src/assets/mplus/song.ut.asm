sounds.ym.music EXTERN
sounds.sn.music EXTERN

assets.sounds.ym.music$PAGE EXTERN
assets.sounds.sn.music$PAGE EXTERN

song.ut.test EXPORT

  SECTION code

; ----------------------------------------------------------------------------
; song.ut.test
; ----------------------------------------------------------------------------

song.ut.test
        _irq.init
        _irq.set50Hz
        _irq.setRoutine #song.ut.test.irq
        lda   map.MPLUS.CTRL
        anda  #%11111110 ; TI clock enable
        sta   map.MPLUS.CTRL

        _ymm.obj.play #assets.sounds.ym.music$PAGE,#sounds.ym.music,#ymm.LOOP,#ymm.NO_CALLBACK
        _vgc.obj.play #assets.sounds.sn.music$PAGE,#sounds.sn.music,#vgc.LOOP,#vgc.NO_CALLBACK
        _irq.on

        _time.ms.wait #500
 IFDEF TO8
        _keyboard.fast.waitKey
 ENDC
 IFDEF MO6
        _keyboard.fast.waitKey #scancode.ENTER
 ENDC

        ; reinit state
        _irq.off
        _ym2413.init
        _sn76489.init
        lda   map.MPLUS.CTRL
        ora   #%00000001 ; TI clock disable
        sta   map.MPLUS.CTRL
        andcc #%11111110
        rts

song.ut.test.irq
        _ymm.frame.play #assets.sounds.ym.music$PAGE
        _vgc.frame.play #assets.sounds.sn.music$PAGE
        rts

 ENDSECTION 