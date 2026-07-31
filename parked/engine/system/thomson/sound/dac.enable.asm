dac.disable           EXPORT
dac.enable            EXPORT

 SECTION code

dac.disable
        ldd    #$fbfc               ; ! Mute by CRA to
        anda   map.MC6821.CRA2      ; ! avoid sound when
        sta    map.MC6821.CRA2      ; ! $e7cd is written
        rts

dac.enable
        ldd    #$fb3f               ; ! Mute by CRA to
        anda   map.MC6821.CRA2      ; ! avoid sound when
        sta    map.MC6821.CRA2      ; ! $e7cd written
        stb    map.MC6821.PRA2      ; Full sound line
        ora    #$04                 ; ! Disable mute by
        sta    map.MC6821.CRA2      ; ! CRA and sound
        rts

 ENDSECTION
