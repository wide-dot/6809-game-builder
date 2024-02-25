********************************************************************************
* Get Keyboard codes
*
********************************************************************************

MapKeyboardToJoypads
        ldb   Dpad_Press
        lda   Key_Press
        cmpa  #8
        bne   >
        orb   #joypad.0.LEFT
        bra   @saveDpad
!       cmpa  #9
        bne   >
        orb   #joypad.0.RIGHT
        bra   @saveDpad
!       cmpa  #10
        bne   >
        orb   #joypad.0.DOWN
        bra   @saveDpad
!       cmpa  #11
        bne   >
        orb   #joypad.0.UP
        bra   @saveDpad
!       ldb   Fire_Press
        cmpa  #13
        bne   >
        orb   #joypad.0.A
        bra   @saveFire
!       cmpa  #32
        bne   >
        orb   #joypad.0.B
        bra   @saveFire
        rts
@saveDpad
        stb   Dpad_Press
        rts
@saveFire
        stb   Fire_Press
        rts