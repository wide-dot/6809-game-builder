;*******************************************************************************
; keyboard.fast : the keyboard's 6804 frames, read by the game (TO8)
;
; The monitor reads each frame under its CP1 interrupt and keeps the character
; alone. keyboard.fast turns that interrupt off and reads the 9-bit frame
; itself : bit 8 CNT, bit 7 Shift, bits 6-0 the key number (scancode.const).
; Manual : docs/lang/en/keyboard.md
;*******************************************************************************

 INCLUDE "engine/system/to8/controller/keyboard.fast.macro.asm"
 INCLUDE "engine/system/to8/controller/scancode.const.asm"

keyboard.fast.init    EXPORT
keyboard.fast.poll    EXPORT
keyboard.fast.read    EXPORT
keyboard.fast.frame   EXPORT
keyboard.fast.count   EXPORT
keyboard.fast.pressed EXPORT
keyboard.fast.held    EXPORT

 SECTION code

keyboard.fast.frame   fdb   $FFFF      ; the last frame read
keyboard.fast.count   fcb   0          ; frames read, modulo 256
keyboard.fast.pressed fdb   $FFFF      ; the frame of a key just pressed, $FFFF : none
keyboard.fast.held    fdb   $FFFF      ; the frame of the key down, $FFFF : none
keyboard.fast.seen    fcb   0          ; count at the last read

;-------------------------------------------------------------------------------
; keyboard.fast.init : the 6804's frames for the game, caps lock off (the
; Shift bit is then the Shift key alone). Again after any monitor keyboard
; call (GETC turns its interrupt back on).
; destroys A, B, X
;-------------------------------------------------------------------------------
keyboard.fast.init
        pshs  cc
        orcc  #$50
        lda   map.MC6846.PCR
        anda  #$FF-map.MC6846.PCR.CP1_IRQ-map.MC6846.PCR.CP1_RISE
        sta   map.MC6846.PCR           ; CP1 : no interrupt, falling edge
        bsr   keyboard.fast.poll       ; a frame already waiting goes first
        lbsr  keyboard.fast.capsOff
        puls  cc,pc

;-------------------------------------------------------------------------------
; keyboard.fast.read : once a main loop pass
; out : C = 1, D = the frame read since the last call (a press, or the 6804's
;       repeat of the key held) ; C = 0, D = $FFFF : none
;       keyboard.fast.pressed : the frame if not the key held, else $FFFF
;       keyboard.fast.held    : the last frame while a key is down (KTEST)
; destroys X
;-------------------------------------------------------------------------------
keyboard.fast.read
        bsr   keyboard.fast.poll
        pshs  cc
        orcc  #$50                     ; the frame and its count : one piece
        ldx   #$FFFF
        stx   keyboard.fast.pressed
        lda   map.MC6821.PRA
        lsra                           ; KTEST : a key down ?
        bcs   >
        stx   keyboard.fast.held
!       lda   keyboard.fast.count
        cmpa  keyboard.fast.seen
        beq   @none
        sta   keyboard.fast.seen
        ldd   keyboard.fast.frame
        cmpd  keyboard.fast.held
        beq   >                        ; the key held : the 6804's repeat
        std   keyboard.fast.pressed
        std   keyboard.fast.held
!       puls  cc
        orcc  #$01
        rts
@none   tfr   x,d
        puls  cc
        andcc #$FE
        rts

;-------------------------------------------------------------------------------
; keyboard.fast.poll : the frame the 6804 has waiting, read now ; from
; keyboard.fast.read, or first thing in the IRQ routine (docs)
; out : C = 1 a frame was read (keyboard.fast.frame, keyboard.fast.count + 1)
; destroys A, B, X
;-------------------------------------------------------------------------------
keyboard.fast.poll
        pshs  cc
        orcc  #$50                     ; no other reader between check and read
        lda   map.MC6846.CSR
        bita  #map.MC6846.CSR.CP1      ; the 6804 calls ?
        bne   @read
        puls  cc
        andcc #$FE
        rts
@read   bsr   keyboard.fast.receive
        std   keyboard.fast.frame
        inc   keyboard.fast.count
        andb  #$FF-scancode.SHIFT
        cmpb  #scancode.CAPS_LOCK
        bne   >
        bsr   keyboard.fast.capsOff    ; caps lock stays off
!       puls  cc
        orcc  #$01
        rts

;-------------------------------------------------------------------------------
; keyboard.fast.receive : the waiting frame, read as the monitor's receiver
; reads it (bank 1 $F08E-$F0F4, the same timed instructions) : ACK low, then
; nine pulses told apart by their width, 38 us a 0, 56 us a 1 (~1.5 ms)
; interrupts masked, CSR read by the caller ; out : D = the frame
;-------------------------------------------------------------------------------
keyboard.fast.receive
        ldd   #$0080                   ; a marker, out after the ninth bit
        pshs  d
        lda   map.MC6846.PDR           ; CP1 flag cleared
        anda  #$FF-map.MC6846.PDR.ACK
        sta   map.MC6846.PDR           ; ACK low : the 6804 sends
@bit    lda   #map.MC6846.PCR.CP1_RISE
        ora   map.MC6846.PCR
        sta   map.MC6846.PCR           ; CP1 : rising edge, a pulse starts
        clrb
        lda   #map.MC6846.CSR.CP1
@rise   bita  map.MC6846.CSR
        beq   @rise
        lda   map.MC6846.PDR           ; CP1 flag cleared
        lda   map.MC6846.PCR
        anda  #$FF-map.MC6846.PCR.CP1_RISE
        sta   map.MC6846.PCR           ; CP1 : falling edge, the pulse ends
        lda   #map.MC6846.CSR.CP1
@width  incb                           ; 10 cycles a count
        bita  map.MC6846.CSR
        beq   @width
        lda   map.MC6846.PDR           ; CP1 flag cleared
        cmpb  #3                       ; 3 counts or more : a 1, C = 0
        rol   1,s                      ; the bit, complemented
        rol   ,s
        bcc   @bit                     ; until the marker comes out
        lda   map.MC6846.PDR
        ora   #map.MC6846.PDR.ACK
        sta   map.MC6846.PDR           ; ACK high : received
        lda   map.MC6846.PCR
        anda  #$FF-map.MC6846.PCR.CP1_IRQ-map.MC6846.PCR.CP1_RISE
        sta   map.MC6846.PCR           ; CP1 : no interrupt (the monitor's : on)
        puls  d
        eora  #$01                     ; the nine bits, uncomplemented
        eorb  #$FF
        rts

;-------------------------------------------------------------------------------
; keyboard.fast.capsOff : the 6804's caps lock off request, as the monitor
; sends it (GETC $EFE5-$F048, B = $FA) : ACK low for three units of 645 cycles
; once the 6804 answers ; interrupts masked ; destroys A, B, X
;-------------------------------------------------------------------------------
keyboard.fast.capsOff
        ldb   #40
!       lda   map.MC6846.CSR           ; the 6804 ends a frame first
        decb
        bne   <
        lda   map.MC6846.PDR
        anda  #$FF-map.MC6846.PDR.ACK
        ora   #map.MC6846.PDR.LOWER
        sta   map.MC6846.PDR           ; ACK low : a request (P3 : lower case)
        lda   #3                       ; three units : caps lock off
        ldb   map.MC6846.PDR           ; CP1 flag cleared
        ldb   map.MC6846.PCR
        andb  #$FF-map.MC6846.PCR.CP1_RISE
        stb   map.MC6846.PCR           ; CP1 : falling edge
        ldx   #1250                    ; 20 ms for the 6804 to answer
        ldb   #map.MC6846.CSR.CP1
@answer bitb  map.MC6846.CSR           ; the 6804 answers : CP1 low
        bne   @unit
        leax  -1,x
        bne   @answer
        bra   @end                     ; no answer : nothing sent
@unit   ldb   #$80                     ; 645 cycles a unit
!       decb
        bne   <
        deca
        bne   @unit
@end    lda   map.MC6846.PDR           ; CP1 flag cleared
        ora   #map.MC6846.PDR.ACK
        sta   map.MC6846.PDR           ; ACK high : the request ends
        rts

 ENDSECTION
