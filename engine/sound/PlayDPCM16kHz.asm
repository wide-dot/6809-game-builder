* ---------------------------------------------------------------------------
* PlayDPCM16kHz
* -------------
* Plays a delta PCM sample at 16 kHz : a 6 bit DAC value a sample, encoded as
* a 4 bit index in a delta table ; 62.5 cycles between two samples (62 and 63
* in turn), cycle exact. No IRQ : everything else stops meanwhile.
* The DAC's init from Mission: Liftoff (thanks to Prehisto)
*
* input REG : [y] Pcm_ index to play
* reset REG : none
*
* Pcm_ index point to a data structure that store location of sample data:
* page[b], start address[w], end address[w]
* page[b], start address[w], end address[w]
* ...
* $00
*
* ---------------------------------------------------------------------------

PlayDPCM16kHz
        pshs  d,x,y,u
        _GetCartPageA
        sta   @RestorePage+1
        ldd   #$fb3f                   ; muted by CRA, so that writing $e7cd
        anda  $e7cf                    ; makes no sound
        sta   $e7cf
        stb   $e7cd                    ; the full sound line
        ora   #$04                     ; unmuted
        sta   $e7cf
        ldu   #@DACDecodeTbl
        lda   #32                      ; init delta value
        sta   @smplh+1
        sta   @smpll+1
@ReadChunk
        lda   sound_page,y             ; [4] load memory page
        beq   @End                     ; [3]
        _SetCartPageA                  ; a page switch lags the stream : 3 cycles in RAM, 73 in ROM
        ldx   sound_start_addr,y       ; [6] Chunk start addr
@Loop      
        lda   ,x                       ; [4] load data byte
        lsra                           ; [2]
        lsra                           ; [2]
        lsra                           ; [2]
        lsra                           ; [2]
        ldb   a,u                      ; [5] read high nibble sample
@smplh  addb  #00                      ; [2]
        stb   @smpll+1                 ; [5]
        stb   $e7cd                    ; [5] send byte to DAC
        lda   ,x+                      ; [6] reload data byte
        anda  #$0F                     ; [2]
        ldb   a,u                      ; [5] read low nibble sample
@smpll  addb  #00                      ; [2]
        stb   @smplh+1                 ; [5]
        exg   a,b                      ; [38] wait
        exg   a,b                      ; ...                                       
        exg   a,b                      ; ...                                       
        exg   a,b                      ; ...                                       
        brn   *                        ; ...        
        brn   *                        ; ...                                                
        stb   $e7cd                    ; [5] send byte to DAC
        cmpx  sound_end_addr,y         ; [7]
        beq   @NextChunk               ; [3]
        exg   a,b                      ; [20] wait        
        exg   a,b                      ; ...
        nop                            ; ...                
        nop                            ; ...                        
        bra   @Loop                    ; [3]
@NextChunk
        leay  sound_meta_size,y        ; [5]
        bra   @ReadChunk               ; [3]
@End
        lda   #$00
        sta   $e7cd
        ldd   #$fbfc                   ; muted by CRA, so that writing $e7cd
        anda  $e7cf                    ; makes no sound
        sta   $e7cf
        andb  $e7cd                    ; the joystick port back
        stb   $e7cd
        ora   #$04                     ; unmuted
        sta   $e7cf
@RestorePage        
        lda   #$00
        _SetCartPageA
        puls  d,x,y,u,pc
@DACDecodeTbl
        fcb   0,1,2,4,8,12,16,24,-32,-1,-2,-4,-8,-12,-16,-24
        ; this table use same values as the one used by pcm2dpcm at encoding stage but /4
        ; so there is no need to downsample from 8-bit to 6-bit