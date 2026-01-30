;*******************************************************************************
; YM2608 (OPNA) Interface for 6809
; ------------------------------------------------------------------------------
; Low-level interface routines for YM2608 sound chip
; Provides register write, initialization, and basic sound functions
;*******************************************************************************

ym2608.init       EXPORT
ym2608.write      EXPORT
ym2608.silence    EXPORT
ym2608.note.on    EXPORT
ym2608.note.off   EXPORT
ym2608.set.volume EXPORT
ym2608.load.voice EXPORT
ym2608.ssg.note.on EXPORT
ym2608.calc.fnum  EXPORT
ym2608.adpcm.play EXPORT
ym2608.rhythm.play EXPORT

; External hardware interface (system-specific)
ym2608.PORT_0_ADDR EXTERNAL                    ; Port 0 Address Register
ym2608.PORT_0_DATA EXTERNAL                    ; Port 0 Data Register  
ym2608.PORT_1_ADDR EXTERNAL                    ; Port 1 Address Register
ym2608.PORT_1_DATA EXTERNAL                    ; Port 1 Data Register

        IFNDEF engine.sound.ym2608.const.asm
        INCLUDE "engine/sound/mucom88/ym2608.const.asm"
        ENDC

 SECTION code

;*******************************************************************************
; YM2608 Low-Level Interface
;*******************************************************************************

;-------------------------------------------------------------------------------
; ym2608.write - Write to YM2608 register
;-------------------------------------------------------------------------------
; input REG : [A] register number
; input REG : [B] data value
; input REG : [X] port (0 or 1)
;-------------------------------------------------------------------------------

ym2608.write

        cmpx  #0
        beq   ym2608_write_port0
        
        ; Port 1 write
        sta   ym2608.PORT_1_ADDR
        nop                                     ; Wait cycle
        nop
        stb   ym2608.PORT_1_DATA
        nop                                     ; Wait cycle
        nop
        rts
        
ym2608_write_port0  ; Port 0 write
        sta   ym2608.PORT_0_ADDR
        nop                                     ; Wait cycle
        nop
        stb   ym2608.PORT_0_DATA
        nop                                     ; Wait cycle
        nop
        rts

;-------------------------------------------------------------------------------
; ym2608.init - Initialize YM2608 to silent state
;-------------------------------------------------------------------------------
ym2608.init
        ; Initialize FM channels (silence all)
        jsr   ym2608.init.fm
        
        ; Initialize SSG channels
        jsr   ym2608.init.ssg
        
        ; Initialize ADPCM
        jsr   ym2608.init.adpcm
        
        ; Initialize Rhythm
        jsr   ym2608.init.rhythm
        
        rts

;-------------------------------------------------------------------------------
; ym2608.init.fm - Initialize FM channels
;-------------------------------------------------------------------------------

ym2608.init.fm

        ; Turn off all FM channels
        ldx   #0                                ; Port 0
        lda   #ym2608.REG_KEY_ON
        clrb                                    ; All keys off
        jsr   ym2608.write
        
        ; Set default instrument parameters for all 6 channels
        clrb                                    ; Channel counter (0-5)
        
ym2608_init_fm_channel_loop
        pshs  b                                 ; Save channel number
        
        ; Set default algorithm and feedback
        lda   #ym2608.REG_FB_ALGO
        adda  ,s                                ; Add channel offset
        pshs  a                                 ; Save register number
        lda   1,s                               ; Get channel number for port selection
        cmpa  #3
        blo   ym2608_init_fm_port0_fb
        ldx   #1                                ; Port 1 for channels 3-5
        lda   ,s                                ; Get register number
        suba  #3                                ; Adjust register for port 1
        bra   ym2608_init_fm_write_fb

ym2608_init_fm_port0_fb
        ldx   #0                                ; Port 0 for channels 0-2
        lda   ,s                                ; Get register number

ym2608_init_fm_write_fb
        leas  1,s                               ; Clean register from stack
        ldb   #$00                              ; Algorithm 0, no feedback
        jsr   ym2608.write
        
        ; Set default total levels (volume off) - optimized with single channel load
        ldb   ,s                                ; Get channel number from stack
        lda   #$7F                              ; Maximum attenuation value
        pshs  a                                 ; Save attenuation value
        
        ; Set TL for all 4 operators
        lda   #ym2608.REG_TL_OP1
        adda  1,s                               ; Add channel offset
        ldb   ,s                                ; Get attenuation value
        jsr   ym2608.write
        
        lda   #ym2608.REG_TL_OP2
        adda  1,s                               ; Add channel offset
        ldb   ,s                                ; Get attenuation value
        jsr   ym2608.write
        
        lda   #ym2608.REG_TL_OP3
        adda  1,s                               ; Add channel offset
        ldb   ,s                                ; Get attenuation value
        jsr   ym2608.write
        
        lda   #ym2608.REG_TL_OP4
        adda  1,s                               ; Add channel offset
        ldb   ,s+                               ; Get attenuation value and clean stack
        jsr   ym2608.write
        
        puls  b                                 ; Restore channel number
        incb                                    ; Next channel
        cmpb  #6                                ; Check if all 6 channels done
        blo   ym2608_init_fm_channel_loop
        
        rts

;-------------------------------------------------------------------------------
; ym2608.init.ssg - Initialize SSG channels
;-------------------------------------------------------------------------------
ym2608.init.ssg
        ldx   #0                                ; SSG registers are on port 0
        
        ; Set all SSG volumes to 0
        lda   #ym2608.REG_SSG_VOL_A
        clrb    
        jsr   ym2608.write
        
        lda   #ym2608.REG_SSG_VOL_B
        clrb    
        jsr   ym2608.write
        
        lda   #ym2608.REG_SSG_VOL_C
        clrb    
        jsr   ym2608.write
        
        ; Set mixer to disable all channels
        lda   #ym2608.REG_SSG_MIXER
        ldb   #$FF                              ; All channels off
        jsr   ym2608.write
        
        rts

;-------------------------------------------------------------------------------
; ym2608.init.adpcm - Initialize ADPCM
;-------------------------------------------------------------------------------
ym2608.init.adpcm
        ldx   #1                                ; ADPCM registers are on port 1
        
        ; Reset ADPCM
        lda   #ym2608.REG_ADPCM_CTRL
        ldb   #ym2608.ADPCM_RESET
        jsr   ym2608.write
        
        ; Set ADPCM level to 0
        lda   #ym2608.REG_ADPCM_LEVEL
        clrb    
        jsr   ym2608.write
        
        rts

;-------------------------------------------------------------------------------
; ym2608.init.rhythm - Initialize rhythm section
;-------------------------------------------------------------------------------
ym2608.init.rhythm
        ldx   #1                                ; Rhythm registers are on port 1
        
        ; Turn off all rhythm instruments
        lda   #ym2608.REG_RHYTHM_CTRL
        clrb    
        jsr   ym2608.write
        
        rts

;*******************************************************************************
; YM2608 High-Level Functions
;*******************************************************************************

;-------------------------------------------------------------------------------
; ym2608.silence - Silence all channels
;-------------------------------------------------------------------------------
ym2608.silence
        ; Optimized silence - minimize register loads and calls
        clrb                                    ; B=0 for most writes
        
        ; Turn off all FM keys
        ldx   #0                                ; Port 0
        lda   #ym2608.REG_KEY_ON
        jsr   ym2608.write
        
        ; Silence SSG channels - optimized loop
        lda   #ym2608.REG_SSG_VOL_A             ; Start with channel A
        pshs  a                                 ; Save start register
        ldb   #3                                ; 3 SSG channels
        
@ssg_loop
        lda   ,s                                ; Get current register
        clrb                                    ; Volume = 0
        jsr   ym2608.write
        inc   ,s                                ; Next SSG register
        decb                                    ; Decrement counter
        bne   @ssg_loop
        puls  a                                 ; Clean stack
        
        ; Stop ADPCM and rhythm - batch operations
        ldx   #1                                ; Port 1
        lda   #ym2608.REG_ADPCM_CTRL
        ldb   #ym2608.ADPCM_RESET
        jsr   ym2608.write
        
        lda   #ym2608.REG_RHYTHM_CTRL
        clrb    
        jsr   ym2608.write
        
        rts

;-------------------------------------------------------------------------------
; ym2608.note.on - Turn on note for FM channel
;-------------------------------------------------------------------------------
; input REG : [A] note number (0-127)
; input REG : [B] channel number (0-5)
;-------------------------------------------------------------------------------
ym2608.note.on
        pshs  a,b
        
        ; Calculate F-Number from note
        jsr   ym2608.calc.fnum                  ; Returns F-Number in D, Block in A
        
        ; Set F-Number low
        puls  x                                 ; Get note and channel back
        pshs  a,b,d                             ; Save block and F-Number
        
        ; Determine port and register offset
        cmpb  #3
        blo   ym2608_note_on_port0_fnum
        ldx   #1                                ; Port 1 for channels 3-5
        subb  #3                                ; Adjust channel for port 1
        bra   ym2608_note_on_write_fnum
ym2608_note_on_port0_fnum
        ldx   #0                                ; Port 0 for channels 0-2
        
ym2608_note_on_write_fnum
        ; Write F-Number low
        lda   #ym2608.REG_FNUM_L
        adda  1,s                               ; Add channel offset
        ldb   3,s                               ; F-Number low byte
        jsr   ym2608.write
        
        ; Write F-Number high and block
        lda   #ym2608.REG_FNUM_H
        adda  1,s                               ; Add channel offset  
        ldb   2,s                               ; F-Number high byte
        orb   ,s                                ; OR with block
        aslb                                    ; Shift block to correct position
        aslb
        aslb
        jsr   ym2608.write
        
        ; Turn on key
        ldx   #0                                ; Key on register is always port 0
        lda   #ym2608.REG_KEY_ON
        ldb   1,s                               ; Channel number
        orb   #ym2608.KEY_ALL_OP                ; Turn on all operators
        jsr   ym2608.write
        
        puls  a,b,d,pc

;-------------------------------------------------------------------------------
; ym2608.note.off - Turn off note for FM channel
;-------------------------------------------------------------------------------
; input REG : [B] channel number (0-5)
;-------------------------------------------------------------------------------
ym2608.note.off
        ldx   #0                                ; Key on register is always port 0
        lda   #ym2608.REG_KEY_ON
        ; B already contains channel number
        ; Don't OR with operator bits to turn off
        jsr   ym2608.write
        rts

;-------------------------------------------------------------------------------
; ym2608.set.volume - Set volume for channel
;-------------------------------------------------------------------------------
; input REG : [A] volume (0-127)
; input REG : [B] channel number
;-------------------------------------------------------------------------------
ym2608.set.volume
        ; Convert volume to total level (inverted)
        nega
        adda  #127
        lsra                                    ; Scale to YM2608 range (0-127)
        
        pshs  a,b
        
        ; Determine if FM or SSG channel
        cmpb  #6
        bhs   ym2608_set_volume_ssg_volume
        
        ; FM volume (set total level for carrier operators)
        ; For now, just set operator 4 (carrier in algorithm 0)
        cmpb  #3
        blo   ym2608_set_volume_port0_vol
        ldx   #1
        subb  #3
        bra   ym2608_set_volume_write_vol
ym2608_set_volume_port0_vol
        ldx   #0
        
ym2608_set_volume_write_vol
        lda   #ym2608.REG_TL_OP4
        adda  1,s                               ; Add channel offset
        ldb   ,s                                ; Volume value
        jsr   ym2608.write
        bra   ym2608_set_volume_done
        
ym2608_set_volume_ssg_volume
        ; SSG volume
        ldx   #0                                ; SSG registers on port 0
        subb  #6                                ; Convert to SSG channel (0-2)
        lda   #ym2608.REG_SSG_VOL_A
        adda  1,s                               ; Add SSG channel offset
        ldb   ,s                                ; Volume value
        lsrb                                    ; Scale to SSG range (0-15)
        lsrb
        lsrb
        jsr   ym2608.write
        
ym2608_set_volume_done   puls  a,b,pc

;*******************************************************************************
; YM2608 Utility Functions
;*******************************************************************************

;-------------------------------------------------------------------------------
; ym2608.calc.fnum - Calculate F-Number and Block from note number
;-------------------------------------------------------------------------------
; input REG : [A] note number (0-127, MIDI compatible)
; output REG: [D] F-Number (9-bit value)
; output REG: [A] Block (octave, 0-7)
;-------------------------------------------------------------------------------
ym2608.calc.fnum
        ; Optimized MUCOM88 compatible note calculation
        ; Uses optimized division and lookup table
        
        ; Fast division by 12 using multiplication method
        tfr   a,b                               ; Save original note in B
        lda   #21                               ; 256/12 ≈ 21.33
        mul                                     ; D = note * 21
        tfr   a,a                               ; A = (note * 21) / 256 ≈ note / 12
        cmpa  #7                                ; Limit to 7 octaves max
        bls   @oct_ok
        lda   #7                                ; Clamp to max octave
        ldb   #11                               ; Use highest note
@oct_ok
        ; Calculate note within octave: note - (octave * 12)
        pshs  a                                 ; Save original note
        lda   #12
        mul                                     ; D = octave * 12
        tfr   d,d                               ; Check if result fits in B
        puls  a                                 ; Get original note
        pshs  b                                 ; Save B on stack
        suba  ,s+                               ; A = original_note - (octave * 12)
        tfr   a,b                               ; B = note within octave
        
        ; Optimized table lookup - B contains note (0-11)
        lslb                                    ; B = note * 2 (2 bytes per entry)
        ldx   #ym2608.fnum.table
        ldd   b,x                               ; Get F-Number from table
        
        puls  a                                 ; Get octave back
        rts

;-------------------------------------------------------------------------------
; ym2608.load.voice - Load FM voice data
;-------------------------------------------------------------------------------
; input REG : [A] voice number
; input REG : [B] channel number (0-5)
;-------------------------------------------------------------------------------
ym2608.load.voice
        ; Voice loading is implemented in mub.load.voice
        ; This function is kept for compatibility but redirects to the main implementation
        ; For now, just return (will be linked with mub.asm)
        rts

;-------------------------------------------------------------------------------
; ym2608.ssg.note.on - Play note on SSG channel
;-------------------------------------------------------------------------------
; input REG : [A] note number
; input REG : [B] SSG channel (0-2)
;-------------------------------------------------------------------------------
ym2608.ssg.note.on
        ; Calculate SSG frequency from note
        jsr   ym2608.calc.ssg.freq              ; Returns frequency in D
        
        ; Send to SSG registers
        pshs  b                                 ; Save channel
        lslb                                    ; Channel * 2 for register offset
        
        ; Send low byte
        ldx   #0                                ; SSG registers on port 0
        tfr   b,a                               ; Register = channel * 2
        ldb   1,s                               ; Get frequency low byte
        jsr   ym2608.write
        
        ; Send high byte  
        lda   1,s                               ; Get channel
        lslb                                    ; Channel * 2
        inca                                    ; High frequency register
        tfr   d,b                               ; Get frequency high byte
        jsr   ym2608.write
        
        puls  b,pc                              ; Restore and return

;-------------------------------------------------------------------------------
; ym2608.calc.ssg.freq - Calculate SSG frequency from note
;-------------------------------------------------------------------------------
; input REG : [A] note number
; output REG: [D] SSG frequency value
;-------------------------------------------------------------------------------
ym2608.calc.ssg.freq
        ; Simple SSG frequency calculation
        ; Real implementation would use proper frequency table
        tfr   a,b
        clra    
        ; Invert for SSG (higher values = lower frequency)
        coma
        comb
        addd  #$100                             ; Add base offset
        rts

; F-Number lookup table for notes (C, C#, D, D#, E, F, F#, G, G#, A, A#, B)
ym2608.fnum.table
        fdb   $269                              ; C
        fdb   $28E                              ; C#
        fdb   $2B6                              ; D
        fdb   $2E1                              ; D#
        fdb   $30F                              ; E
        fdb   $33C                              ; F
        fdb   $36D                              ; F#
        fdb   $3A0                              ; G
        fdb   $3D5                              ; G#
        fdb   $40E                              ; A
        fdb   $449                              ; A#
        fdb   $487                              ; B

;-------------------------------------------------------------------------------
; ym2608.adpcm.play - Play ADPCM sample
;-------------------------------------------------------------------------------
; input REG : [X] pointer to parameter block (start, end, delta-n, flags)
;-------------------------------------------------------------------------------
ym2608.adpcm.play
        ; Save parameter pointer
        pshs  x
        
        ; Stop any current ADPCM playback
        ldx   #1                                ; Port 1
        lda   #ym2608.REG_ADPCM_CTRL
        ldb   #ym2608.ADPCM_RESET
        jsr   ym2608.write
        
        ; Get parameter pointer back
        ldx   ,s                                ; Get parameter block address
        
        ; Set start address
        lda   #ym2608.REG_ADPCM_START_L
        ldd   ,x                                ; Get start address
        pshs  d                                 ; Save on stack
        ldb   1,s                               ; Low byte
        ldx   #1                                ; Port 1
        jsr   ym2608.write
        
        lda   #ym2608.REG_ADPCM_START_H
        ldb   ,s                                ; High byte
        jsr   ym2608.write
        
        ; Set end address
        ldx   2,s                               ; Get parameter block address
        lda   #ym2608.REG_ADPCM_END_L
        ldd   2,x                               ; Get end address
        std   ,s                                ; Reuse stack space
        ldb   1,s                               ; Low byte
        ldx   #1                                ; Port 1
        jsr   ym2608.write
        
        lda   #ym2608.REG_ADPCM_END_H
        ldb   ,s                                ; High byte
        jsr   ym2608.write
        
        ; Set delta-N (frequency)
        ldx   2,s                               ; Get parameter block address
        lda   #ym2608.REG_ADPCM_DELTA_L
        ldd   4,x                               ; Get delta-N
        std   ,s                                ; Reuse stack space
        ldb   1,s                               ; Low byte
        ldx   #1                                ; Port 1
        jsr   ym2608.write
        
        lda   #ym2608.REG_ADPCM_DELTA_H
        ldb   ,s                                ; High byte
        jsr   ym2608.write
        
        ; Set level (volume)
        ldx   2,s                               ; Get parameter block address
        lda   #ym2608.REG_ADPCM_LEVEL
        ldd   6,x                               ; Get flags/level
        ldb   1,s                               ; Get level from low byte
        ldx   #1                                ; Port 1
        jsr   ym2608.write
        
        ; Set L/R output
        ldx   2,s                               ; Get parameter block address
        lda   #ym2608.REG_ADPCM_L_R
        ldb   6,x                               ; Get flags from high byte
        andb  #$C0                              ; Keep only L/R bits
        ldx   #1                                ; Port 1
        jsr   ym2608.write
        
        ; Start playback
        lda   #ym2608.REG_ADPCM_CTRL
        ldb   #ym2608.ADPCM_PLAY
        jsr   ym2608.write
        
        leas  4,s                               ; Clean stack (parameter pointer + temp data)
        rts

;-------------------------------------------------------------------------------
; ym2608.rhythm.play - Play rhythm instrument
;-------------------------------------------------------------------------------
; input REG : [A] rhythm instrument number
; input REG : [B] volume
;-------------------------------------------------------------------------------
ym2608.rhythm.play
        ; Send rhythm command to YM2608
        ldx   #1                                ; Port 1
        pshs  a,b                               ; Save parameters
        
        ; Set rhythm volume
        lda   #ym2608.REG_RHYTHM_VOL
        ldb   1,s                               ; Get volume
        jsr   ym2608.write
        
        ; Trigger rhythm instrument
        lda   #ym2608.REG_RHYTHM_CTRL
        ldb   ,s                                ; Get instrument number
        orb   #ym2608.RHYTHM_ON                 ; Set rhythm on bit
        jsr   ym2608.write
        
        puls  a,b,pc                            ; Restore and return

 ENDSECTION
