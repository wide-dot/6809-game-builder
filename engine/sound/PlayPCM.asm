* ---------------------------------------------------------------------------
* PlayPCM
* ------------
* Subroutine to play a PCM sample at 16kHz
* This will freeze anything running
*
* input REG : [y] Pcm_ index to play
* reset REG : [d] [x] [y]
* ---------------------------------------------------------------------------
        setdp dp
PlayPCM 

        _GetCartPageA
        sta   PlayPCM_RestorePage+1
        
PlayPCM_ReadChunk
        lda   sound_page,y                    ; load memory page
        beq   PlayPCM_End
        _SetCartPageA                
        ldx   sound_start_addr,y              ; Chunk start addr
       
PlayPCM_Loop      
        lda   ,x+
        sta   CORE.DAC                        ; send byte to DAC
        cmpx  sound_end_addr,y
        beq   PlayPCM_NextChunk        
        mul                                   ; tempo for 16hHz
        mul
        mul
        tfr   a,b
        bra   PlayPCM_Loop                    ; loop is 63 cycles instead of 62,5
         
PlayPCM_NextChunk
        leay  sound_meta_size,y
        mul                                   ; tempo for 16kHz
        nop
        bra   PlayPCM_ReadChunk
        
PlayPCM_End
        lda   #$00
        sta   CORE.DAC
                
PlayPCM_RestorePage        
        lda   #$00
        _SetCartPageA
        
        rts   
