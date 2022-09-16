* DAC uninit from Mission: Liftoff (Prehisto)
UninitDAC
        ldd   #$fbfc  ! Mute by CRA to
        anda  $e7cf   ! avoid sound when ; clear bit2 on CRB
        sta   $e7cf   ! $e7cd is written ; Data Direction Register selected
        andb  $e7cd   ! Activate         ; clear bit 0 and bit1
        stb   $e7cd   ! joystick port    ; ???
        ora   #$04    ! Disable mute by  ; set bit2 on CRB
        sta   $e7cf   ! CRA + joystick   ; Output Register selected
	rts