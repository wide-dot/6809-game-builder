;*******************************************************************************
; Read joypad state, any keyboard key acting as button B
;
; Thomson pads mostly carry a single button. A game that needs a second one —
; R-Type recalls its force pod with it — would be unplayable on them, so KTEST
; (system PIA $E7C8 bit 0 : at least one key held) is injected into the RAW
; button B bit of joypad 0, BEFORE the edge detection. joypad.pressed.fire and
; joypad.held.fire then behave exactly like a real button B : a clean edge, and
; no rattling while the key stays down.
;
; Its own file, next to joypad.asm rather than inside it : a game that does not
; want the keyboard in its pad state includes joypad.asm alone and pays nothing.
; Ported from v1 engine/joypad/ReadJoypadsKbd.asm, same intent and same shape.
;
; Needs joypad.asm in the same unit : the three pairs of bytes are its.
;*******************************************************************************

joypad.readKbd      EXPORT

 SECTION code

        INCLUDE "engine/system/to8/controller/joypad.const.asm"

joypad.readKbd

        ldd   map.MC6821.PRA1          ; Read joypad physical state
        coma
        comb

        pshs  a                        ; keep the dpad out of the way
        lda   map.MC6821.PRA           ; system PIA, KTEST in bit 0
        lsra                           ; bit 0 -> C
        bcc   >                        ; C=0 : no key held, nothing to inject
        orb   #joypad.0.B              ; C=1 : at least one key -> button B
!       puls  a

        std   joypad.state
        ldd   joypad.held
        eora  joypad.state.dpad        ; Toggle off buttons that were previously being held
        eorb  joypad.state.fire
        anda  joypad.state.dpad
        andb  joypad.state.fire
        std   joypad.pressed           ; Put pressed controller input
        ldd   joypad.state
        std   joypad.held              ; Put raw controller input (for held buttons)
        rts

 ENDSECTION
