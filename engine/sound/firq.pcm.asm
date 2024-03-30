; ------------------------------------------------------------------------------
; PCM playback system for 6809
; ------------------------------------------------------------------------------
; Play a pcm sample by firq
;
; by Bentoc March 2024
;
; Maximum sample rate : 15873Hz = 63 cycles
; Total cycles : 56 (63 each 256 bytes read)
; ------------------------------------------------------------------------------

firq.pcm.sample.play EXPORT

 SECTION code

firq.pcm.sample.play
                                       ; [12] FIRQ (equivalent to pshs pc,cc | jmp $FFF6)
                                       ; [8]  ROM jmp to user address
        sta   @a                       ; [5]  backup register value
        lda   >$0000                   ; [5]  read sample byte
firq.pcm.sample equ *-2
        sta   map.DAC                  ; [5]  send byte to DAC
        bpl   >                        ; [3]  skip if no end marker
        lda   #$40                     ; --- [3] inactivate firq
        ora   ,s                       ; --- [-] by updating
        sta   ,s                       ; --- [-] cc register in stack
!       inc   firq.pcm.sample+1        ; [7]  move to next sample
        bne   >                        ; [3]  skip if no LSB rollover
        inc   firq.pcm.sample          ; --- [7]  move to next sample
!       lda   #0                       ; [2]  restore register value
@a      equ   *-1
        rti                            ; [6]  RTI (equivalent to puls pc,cc)

 ENDSECTION