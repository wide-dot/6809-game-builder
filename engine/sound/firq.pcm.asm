; ------------------------------------------------------------------------------
; PCM playback system for 6809
; ------------------------------------------------------------------------------
; Play a pcm sample by firq
;
; by Bentoc March 2024
;
; Maximum sample rate : approx. 16000Hz
; Total cycles : 61 (68 each 256 bytes read)
; ------------------------------------------------------------------------------

firq.pcm.sample      EXPORT
firq.pcm.sample.play EXPORT

 SECTION code

firq.pcm.sample.play
                                       ; [12] FIRQ (equivalent to pshs pc,cc | jmp $FFF6)
                                       ; [8]  ROM jmp to user address
        sta   @a                       ; [5]  backup register value
        lda   map.MPLUS.CTRL           ; [5]  FIRQ acknowledge by reading ctrl register
        lda   >$0000                   ; [5]  read sample byte
firq.pcm.sample equ *-2
        sta   map.DAC                  ; [5]  send byte to DAC
        bpl   @move                    ; [3]  skip if no end marker
        lda   #$40                     ; --- [2] inactivate firq => TODO a remplacer par coupure timer mplus
        ora   ,s                       ; --- [4] by updating
        sta   ,s                       ; --- [4] cc register in stack
        bra   @exit                    ; --- [3] do not make any move in buffer
@move
        inc   firq.pcm.sample+1        ; [7]  move to next sample (LSB)
        bne   @exit                    ; [3]  skip if no LSB rollover
        inc   firq.pcm.sample          ; --- [7]  move to next sample (MSB)
@exit   lda   #0                       ; [2]  restore register value
@a      equ   *-1
        rti                            ; [6]  RTI (equivalent to puls pc,cc)

 ENDSECTION