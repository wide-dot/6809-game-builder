;*******************************************************************************
; MUCOM88 MUB Player for 6809
; ------------------------------------------------------------------------------
; MUB (MUCOM88 Binary) format player
; Based on MUCOM88 original by Yuzo Koshiro
; 6809 port for Thomson/Tandy systems
        ;
; This player handles:
; - MUB file format parsing and validation
; - Multi-channel music playback (11 channels)
; - YM2608 (OPNA) sound chip interface
; - Channel management and timing
; - MML command interpretation
; - Voice data management
;*******************************************************************************

irq.on       EXTERNAL
irq.off      EXTERNAL
ym2608.write EXTERNAL                           ; YM2608 register write routine
ym2608.init  EXTERNAL                           ; YM2608 initialization
ym2608.silence EXTERNAL                         ; YM2608 silence all channels
ym2608.ssg.note.on EXTERNAL                     ; YM2608 SSG note on
ym2608.note.on EXTERNAL                         ; YM2608 FM note on
ym2608.note.off EXTERNAL                        ; YM2608 note off
ym2608.set.volume EXTERNAL                      ; YM2608 set volume
ym2608.adpcm.play EXTERNAL                      ; YM2608 ADPCM playback
ym2608.rhythm.play EXTERNAL                     ; YM2608 rhythm playback

mub.play       EXPORT
mub.obj.play   EXPORT
mub.frame.play EXPORT
mub.stop       EXPORT
mub.pause      EXPORT
mub.resume     EXPORT
mub.get.status EXPORT
mub.set.tempo  EXPORT
mub.apply.se.lfo.to.operators EXPORT
        ;
        IFNDEF engine.sound.mub.const.asm
        INCLUDE "engine/sound/mucom88/mub.const.asm"
        ENDC
        ;
        IFNDEF engine.sound.ym2608.const.asm
        INCLUDE "engine/sound/mucom88/ym2608.const.asm"
        ENDC
        ;
 SECTION code
        ;
        IFNDEF engine.6809.macros.asm
        INCLUDE "engine/6809/macros.asm"
        ENDC
        ;
;*******************************************************************************
; MUB Player Variables
;*******************************************************************************
        ;
; Player State
mub.status               fcb   mub.STATUS_STOP  ; Player status
mub.loop                 fcb   mub.NO_LOOP      ; Loop flag
mub.callback             fdb   mub.NO_CALLBACK  ; Callback routine address
mub.data                 fdb   0                ; MUB data address
mub.data.page            fcb   0                ; Memory page of MUB data
mub.header               fdb   0                ; MUB header address
        ;
; Music Data Pointers
mub.music.data           fdb   0                ; Start of music data
mub.music.size           fdb   0                ; Size of music data
mub.tag.data             fdb   0                ; Start of tag data
mub.tag.size             fdb   0                ; Size of tag data
mub.pcm.data             fdb   0                ; Start of PCM data
mub.pcm.size             fdb   0                ; Size of PCM data
        ;
; Timing Variables
mub.tempo                fcb   mub.DEFAULT_TEMPO ; Current tempo (BPM)
mub.timer.b              fcb   0                ; Timer B value from MUB
mub.tick.counter         fdb   0                ; Tick counter
mub.tick.divider         fdb   0                ; Tick divider for tempo
mub.frame.wait           fcb   1                ; Frame wait counter
        ;
; Channel Data Structure (based on MUCOM88 original)
; Extended to 48 bytes for additional MUCOM88 features
        ;
; Channel data offsets (EXACT match with MUCOM88 original CH1DAT structure)
mub.ch.length            equ   0                ; LENGTH counter (1 byte) - IX+0
mub.ch.vnum              equ   1                ; Voice number (1 byte) - IX+1
mub.ch.wadr              equ   2                ; Data address work (2 bytes) - IX+2,3
mub.ch.tadr              equ   4                ; Data top address (2 bytes) - IX+4,5
mub.ch.volume            equ   6                ; Volume data (1 byte) - IX+6
mub.ch.alg               equ   7                ; Algorithm number (1 byte) - IX+7
mub.ch.chnum             equ   8                ; Channel number (1 byte) - IX+8
mub.ch.detune            equ   9                ; Detune data (2 bytes) - IX+9,10
mub.ch.work11            equ   11               ; Work area (1 byte) - IX+11
mub.ch.reverb_param      equ   12               ; For reverb (1 byte) - IX+12
mub.ch.soft_env          equ   13               ; Soft envelope (5 bytes) - IX+13-17
mub.ch.gate_counter      equ   18               ; Gate time counter (1 byte) - IX+18
mub.ch.lfo_delay         equ   19               ; LFO delay (1 byte) - IX+19
mub.ch.lfo_work1         equ   20               ; LFO work (1 byte) - IX+20
mub.ch.lfo_counter       equ   21               ; LFO counter (1 byte) - IX+21
mub.ch.lfo_work2         equ   22               ; LFO work (1 byte) - IX+22
mub.ch.lfo_increment     equ   23               ; LFO increment (2 bytes) - IX+23,24
mub.ch.lfo_work34        equ   25               ; LFO work (2 bytes) - IX+25,26
mub.ch.lfo_peak          equ   27               ; LFO peak level (1 byte) - IX+27
mub.ch.lfo_work5         equ   28               ; LFO work (1 byte) - IX+28
mub.ch.fnum1             equ   29               ; F-Number 1 data (1 byte) - IX+29
mub.ch.fnum2             equ   30               ; Block/F-Number 2 data (1 byte) - IX+30
mub.ch.flags1            equ   31               ; Main flags (1 byte) - IX+31
                                                ; bit 7 = LFO FLAG
                                                ; bit 6 = KEYOFF FLAG (RESET = TIE active)
                                                ; bit 5 = LFO CONTINUE FLAG  
                                                ; bit 4 = TIE FLAG
                                                ; bit 3 = MUTE FLAG
                                                ; bit 2 = LFO 1SHOT FLAG
                                                ; bit 1 = Reserved
                                                ; bit 0 = 1LOOPEND FLAG
mub.ch.before_code       equ   32               ; Before code (1 byte) - IX+32
mub.ch.flags2            equ   33               ; Extended flags (1 byte) - IX+33
                                                ; bit 7 = HARD ENVELOPE FLAG
                                                ; bit 6 = Reserved
                                                ; bit 5 = REVERB FLAG  
                                                ; bit 4 = REVERB MODE
                                                ; bit 3-0 = HARD ENVELOPE TYPE
mub.ch.work_area         equ   34               ; Work area (2 bytes) - IX+34,35
mub.ch.reserved          equ   36               ; Reserved (2 bytes) - IX+36,37
        ;
; EXACT channel size matching original MUCOM88
mub.CHANNEL_SIZE         equ   38               ; Size of each channel data structure (MUCOM88 original)
        ;
; Extended data for our implementation (beyond original)
mub.ch.repeat_stack      equ   38               ; Repeat stack pointer (2 bytes)
mub.ch.repeat_count      equ   40               ; Current repeat count (2 bytes)
mub.ch.octave            equ   42               ; Current octave (0-7) (1 byte)
mub.ch.note_length       equ   43               ; Default note length (1 byte)
        ;
; Total size with extensions
mub.CHANNEL_SIZE_EXT     equ   44               ; Extended size for our features
        ;
; Channel Status Flags (stored in high byte of length)
mub.CH_ACTIVE            equ   %00000001        ; Channel is active
mub.CH_NOTE_ON           equ   %00000010        ; Note is currently on
mub.CH_MUTED             equ   %00000100        ; Channel is muted
mub.CH_LOOP              equ   %00001000        ; Channel in loop
mub.CH_END               equ   %00010000        ; Channel ended
        ;
; Channel Data Arrays (11 channels total)
mub.channels             fill  0,mub.MAX_CHANNELS*mub.CHANNEL_SIZE_EXT
        ;
; Repeat Stack Arrays (per channel)
mub.repeat.stacks        fill  0,mub.MAX_CHANNELS*mub.REPEAT_STACK_SIZE*mub.REPEAT_STACK_ENTRY_SIZE
        ;
; Voice Data Buffer (FM voice parameters)
mub.voice.buffer         fill  0,mub.VOICE_BUFFER_SIZE
mub.voice.data.addr      fdb   0                ; Address of voice data in MUB
        ;
; Global Music Variables
mub.music.num            fcb   0                ; Current music number
mub.maxch                fcb   mub.MAX_CHANNELS ; Maximum channels
mub.total.volume         fcb   $0F              ; Total volume
        ;
; MUCOM88 System Variables (matching original)
mub.drmf1                fcb   0                ; Drum mode flag
mub.pcmflg               fcb   0                ; PCM mode flag  
mub.ssgf1                fcb   0                ; SSG mode flag
mub.pvmode               fcb   0                ; PCM volume mode
mub.pcmlr                fcb   0                ; PCM L/R control
mub.flgadr               fcb   0                ; Flag address
mub.escape               fcb   0                ; Escape flag
mub.volint               fcb   0                ; Volume interrupt
        ;
; SE Mode Variables
mub.detdat               fill  0,4              ; SE mode detune data (4 operators)
        ;
; PSG Register Buffer (matching PREGBF)
mub.pregbf               fill  0,16             ; PSG register buffer
mub.fade.counter         fcb   0                ; Fade counter
mub.fade.speed           fcb   16               ; Fade speed
        ;
;*******************************************************************************
; MUB Player Main Routines
;*******************************************************************************

;-------------------------------------------------------------------------------
; mub.play - Initialize and start MUB playback
;-------------------------------------------------------------------------------
; input REG : [A] memory page of MUB data
; input REG : [B] loop flag (0=no loop, 1=loop)
; input REG : [X] MUB data address
; input REG : [Y] callback routine address (0=no callback)
;-------------------------------------------------------------------------------
mub.play
        _GetCartPageA
        sta   @a
        _SetCartPageA
        jsr   mub.obj.play
        lda   #0
@a      equ   *-1
        _SetCartPageA
        rts

;-------------------------------------------------------------------------------
; mub.obj.play - Object-based MUB player initialization
;-------------------------------------------------------------------------------
mub.obj.play
        pshs  u                                 ; Save U register (needed by RunObjects)
        jsr   irq.off                           ; Disable interrupts during setup
        ;
        ; Store parameters
        stb   mub.loop
        sty   mub.callback
        sta   mub.data.page
        stx   mub.data
        ;
        ; Validate MUB file header
        jsr   mub.validate.header
        bne   @error
        ;
        ; Initialize player state
        lda   #mub.STATUS_PLAY
        sta   mub.status
        lda   #1
        sta   mub.frame.wait
        ;
        ; Parse MUB header and setup channels
        jsr   mub.parse.header
        jsr   mub.init.channels
        ;
        ; Initialize YM2608
        jsr   ym2608.init
        ;
        puls  u,pc
        ;
@error  ; Error handling - set status to stop
        clr   mub.status
        puls  u,pc

;-------------------------------------------------------------------------------
; mub.frame.play - Process one frame of MUB playback
;-------------------------------------------------------------------------------
; Should be called every 1/60th second (NTSC) or 1/50th second (PAL)
;-------------------------------------------------------------------------------
mub.frame.play
        lda   mub.status
        cmpa  #mub.STATUS_PLAY
        bne   @rts                              ; Exit if not playing
        ;
        dec   mub.frame.wait
        bne   @rts                              ; Wait for next frame
        ;
        lda   mub.data.page
        _SetCartPageA
        ;
        ; Process all active channels
        jsr   mub.process.channels
        ;
        ; Check for end of music
        jsr   mub.check.end
        ;
@rts    rts

;-------------------------------------------------------------------------------
; mub.stop - Stop MUB playback
;-------------------------------------------------------------------------------
mub.stop
        clr   mub.status                        ; Set status to stop
        jsr   ym2608.silence                    ; Silence all channels
        rts

;-------------------------------------------------------------------------------
; mub.pause - Pause MUB playback
;-------------------------------------------------------------------------------
mub.pause
        lda   mub.status
        cmpa  #mub.STATUS_PLAY
        bne   @rts
        lda   #mub.STATUS_PAUSE
        sta   mub.status
@rts    rts

;-------------------------------------------------------------------------------
; mub.resume - Resume MUB playback
;-------------------------------------------------------------------------------
mub.resume
        lda   mub.status
        cmpa  #mub.STATUS_PAUSE
        bne   @rts
        lda   #mub.STATUS_PLAY
        sta   mub.status
@rts    rts

;*******************************************************************************
; MUB File Format Handling
;*******************************************************************************

;-------------------------------------------------------------------------------
; mub.validate.header - Validate MUB file header
;-------------------------------------------------------------------------------
; input REG : [X] MUB data address
; output REG: [A] 0=valid, non-zero=invalid
;-------------------------------------------------------------------------------
mub.validate.header
        ; Check magic number "MUB8" - optimized with 16-bit operations
        ldd   mub.HDR_MAGIC,x                   ; Load first 2 bytes "MU"
        cmpd  #'M'*256+'U'                      ; Compare with "MU" as 16-bit
        bne   @invalid
        ldd   mub.HDR_MAGIC+2,x                 ; Load last 2 bytes "B8"
        cmpd  #'B'*256+'8'                      ; Compare with "B8" as 16-bit
        bne   @invalid
        ;
        ; Validate data offset is reasonable
        ldd   mub.HDR_DATA_OFFSET,x
        cmpd  #mub.HEADER_SIZE
        blo   @invalid                          ; Data offset must be >= header size
        ;
        ; Validate data size is not zero
        ldd   mub.HDR_DATA_SIZE,x
        beq   @invalid                          ; Data size cannot be zero
        ;
        clra                                    ; Valid file
        rts
        ;
@invalid
        lda   #mub.ERR_INVALID_FILE
        rts

;-------------------------------------------------------------------------------
; mub.parse.header - Parse MUB header and setup player
;-------------------------------------------------------------------------------
mub.parse.header
        ldx   mub.data
        stx   mub.header                        ; Store header address
        ;
        ; Parse music data pointer
        ldd   mub.HDR_DATA_OFFSET,x
        leay  d,x                               ; Y = header + data offset
        sty   mub.music.data
        ldd   mub.HDR_DATA_SIZE,x
        std   mub.music.size
        ;
        ; Parse tag data pointer (if present)
        ldd   mub.HDR_TAG_OFFSET,x
        beq   @no_tag
        leay  d,x                               ; Y = header + tag offset
        sty   mub.tag.data
        ldd   mub.HDR_TAG_SIZE,x
        std   mub.tag.size
        bra   @check_pcm
@no_tag clr   mub.tag.data
        clr   mub.tag.data+1
        ;
@check_pcm
        ; Parse PCM data pointer (if present)
        ldd   mub.HDR_PCM_OFFSET,x
        beq   @no_pcm
        leay  d,x                               ; Y = header + PCM offset
        sty   mub.pcm.data
        ldd   mub.HDR_PCM_SIZE,x
        std   mub.pcm.size
        bra   @setup_timing
@no_pcm clr   mub.pcm.data
        clr   mub.pcm.data+1
        ;
@setup_timing
        ; Get Timer B value from music data (first byte)
        ldy   mub.music.data
        lda   ,y                                ; First byte is Timer B value
        sta   mub.timer.b
        ;
        ; Setup channel data pointers
        jsr   mub.setup.channel.pointers
        ;
        ; Setup default tempo and timing
        lda   #mub.DEFAULT_TEMPO
        sta   mub.tempo
        jsr   mub.calc.tempo.divider
        ;
        rts

;-------------------------------------------------------------------------------
; mub.setup.channel.pointers - Setup channel data pointers from MUB
;-------------------------------------------------------------------------------
mub.setup.channel.pointers
        ; Music data format after Timer B:
        ; - 11 channel pointers (2 bytes each) = 22 bytes
        ; - Channel data follows
        ;
        ldy   mub.music.data
        leay  1,y                               ; Skip Timer B byte
        ;
        ; Setup channel pointers for all 11 channels
        ldx   #mub.channels
        ldb   #mub.MAX_CHANNELS
        ;
@loop   ; Get channel data offset
        ldd   ,y++                              ; Read 16-bit offset
        beq   @inactive                         ; 0 = inactive channel
        ;
        ; Calculate actual address
        leay  d,y                               ; Y = music.data + 1 + offset
        leay  -2,y                              ; Adjust for the increment
        ;
        ; Store in channel work area
        sty   mub.ch.wadr,x                     ; Current data pointer
        sty   mub.ch.tadr,x                     ; Top data pointer
        ;
        ; Mark channel as active
        lda   #mub.CH_ACTIVE
        sta   mub.ch.length+3,x                 ; Store in high byte of length
        ;
        bra   @next
        ;
@inactive
        ; Clear channel data
        clr   mub.ch.length+3,x                 ; Clear status flags
        ;
@next   leax  mub.CHANNEL_SIZE_EXT,x            ; Next channel
        decb
        bne   @loop
        ;
        rts

;-------------------------------------------------------------------------------
; mub.calc.tempo.divider - Calculate tempo divider for frame timing
;-------------------------------------------------------------------------------
mub.calc.tempo.divider
        ; Use Timer B value from MUB for timing
        ; Timer B controls the playback speed
        lda   mub.timer.b
        beq   @default                          ; Use default if 0
        ;
        ; Convert Timer B to frame divider
        ; Timer B = 256 - (desired_frequency / base_frequency * 256)
        ; For simplicity, use Timer B directly as frame divider
        tfr   a,b
        clra
        std   mub.tick.divider
        rts
        ;
@default
        ; Default timing (60 Hz)
        ldd   #1
        std   mub.tick.divider
        rts
        ;
;*******************************************************************************
; Channel Management
;*******************************************************************************

;-------------------------------------------------------------------------------
; mub.init.channels - Initialize all channels
;-------------------------------------------------------------------------------
mub.init.channels
        ; Clear all channel data - optimized for 6809
        ldx   #mub.channels
        ldd   #0
        ldb   #mub.MAX_CHANNELS * mub.CHANNEL_SIZE_EXT / 2
        ;
@clear  std   ,x++                              ; Use post-increment for efficiency
        decb                                    ; DECB is faster than LEAy -1,y
        bne   @clear
        ;
        ; Initialize channel numbers
        ldx   #mub.channels
        ldb   #0                                ; Channel number
        lda   #mub.MAX_CHANNELS
        ;
@loop   ; Set channel number
        stb   mub.ch.chnum+3,x                  ; Store in low byte of chnum
        ;
        ; Set default volume (full volume) - optimized
        stb   mub.ch.volume+3,x                 ; Reuse B register value for volume
        ;
        ; Initialize extended features
        pshs  a,b                               ; Save counters
        jsr   mub.init.channel.extended         ; Initialize extended features
        puls  a,b                               ; Restore counters
        ;
        ; Next channel - optimized addressing
        leax  mub.CHANNEL_SIZE_EXT,x
        incb
        deca
        bne   @loop
        ;
        rts

;-------------------------------------------------------------------------------
; mub.process.channels - Process all active channels
;-------------------------------------------------------------------------------
mub.process.channels
        ; Optimized channel processing loop
        ldx   #mub.channels
        ldb   #0                                ; Channel number
        lda   #mub.MAX_CHANNELS
        ;
@loop   ; Check if channel is active - optimized
        tst   mub.ch.length+3,x                 ; Test status flags directly
        bpl   @next                             ; Skip if not active (bit 7 clear)
        ;
        ; Process this channel - avoid stack usage
        pshs  a,b,x                             ; Only push when necessary
        jsr   mub.process.channel
        jsr   mub.process.lfo                   ; Process LFO for this channel
        ; Note: Soft envelope is processed within mub.apply.volume when needed
        puls  a,b,x
        ;
@next   ; Next channel - optimized increment
        leax  mub.CHANNEL_SIZE_EXT,x           ; Next channel data
        incb                                    ; Next channel number
        deca
        bne   @loop
        ;
        rts

;-------------------------------------------------------------------------------
; mub.process.channel - Process single channel
;-------------------------------------------------------------------------------
; input REG : [B] channel number
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.process.channel
        ; Check if channel has data to process - optimized
        ldu   mub.ch.wadr,x                     ; Get current data pointer directly in U
        beq   @inactive                         ; No data pointer = inactive
        ;
        ; Decrement length counter - optimized 16-bit decrement
        ldd   mub.ch.length,x
        beq   @read_command                     ; Time to read new command
        subd  #1                                ; Decrement 16-bit counter
        std   mub.ch.length,x
        rts                                     ; Still playing current note - early return
        ;
@read_command
        ; Read next command byte
        lda   ,u+                               ; Read command byte
        stu   mub.ch.wadr,x                     ; Update data pointer
        ;
        ; Process command based on value
        cmpa  #$F0
        bhs   @mml_command                      ; $F0-$FF = MML commands
        cmpa  #$80
        bhs   @note_or_rest                     ; $80-$EF = notes and rests
        ;
        ; $00-$7F = Length/timing data, continue processing
        bra   @read_command
        ;
@mml_command
        ; Process MML command ($F0-$FF) - use authentic MUCOM88 system
        jsr   mub.process.mucom88.commands
        bra   @read_command                     ; Continue processing
        ;
@note_or_rest
        cmpa  #$FF
        beq   @end_track                        ; $FF = end of track
        ;
        ; Note or rest command
        jsr   mub.process.note.command
        ;
@end_track
        ; End of track - deactivate channel - optimized bit manipulation
        lda   mub.ch.length+3,x                 ; Get status flags
        anda  #^mub.CH_ACTIVE                   ; Clear active flag
        ora   #mub.CH_END                       ; Set end flag
        sta   mub.ch.length+3,x
        ;
@inactive
        rts

;-------------------------------------------------------------------------------
; mub.process.mml.command - Process MML commands ($00-$7F)
;-------------------------------------------------------------------------------
; input REG : [A] command byte
; input REG : [B] channel number
; input REG : [X] channel data pointer
; input REG : [U] data stream pointer
;-------------------------------------------------------------------------------
mub.process.mml.command
        ; Ultra-optimized MML command dispatch - minimal instructions
        cmpa  #$05                              ; Check if command is in range
        bhi   @unknown                          ; Unknown command
        ;
        ; Direct jump using address table offset - no intermediate register
        deca                                    ; Convert to 0-based index (1-5 -> 0-4)
        lsla                                    ; A = A * 2 (2 bytes per address)
        ldx   #@addr_table                      ; Load table address
        jmp   [a,x]                             ; Direct jump using table offset
        ;
@addr_table
        fdb   @voice                            ; Command 1
        fdb   @volume                           ; Command 2  
        fdb   @octave                           ; Command 3
        fdb   @length                           ; Command 4
        fdb   @tempo                            ; Command 5
        ;
@unknown
        ; Unknown command - skip parameter if present
        rts
        ;
@voice  ; Voice change command
        lda   ,u+                               ; Read voice number
        stu   mub.ch.wadr,x                     ; Update pointer
        sta   mub.ch.vnum+3,x                   ; Store voice number
        jsr   mub.load.voice                    ; Load voice data and send to YM2608
        rts
        ;
@volume ; Volume command  
        lda   ,u+                               ; Read volume value
        stu   mub.ch.wadr,x                     ; Update pointer
        sta   mub.ch.volume+3,x                 ; Store volume
        ; Apply volume to channel
        jsr   mub.apply.volume
        rts
        ;
@octave ; Octave command
        lda   ,u+                               ; Read octave value
        stu   mub.ch.wadr,x                     ; Update pointer
        cmpa  #8                                ; Check range (0-7)
        bhs   @octave_clamp                     ; Clamp if too high
        sta   mub.ch.octave,x                   ; Store octave
        rts
@octave_clamp
        lda   #7                                ; Clamp to maximum octave
        sta   mub.ch.octave,x                   ; Store clamped octave
        rts
        ;
@length ; Note length command
        lda   ,u+                               ; Read length value
        stu   mub.ch.wadr,x                     ; Update pointer
        tsta                                    ; Check if zero
        beq   @length_default                   ; Use default if zero
        sta   mub.ch.note_length,x              ; Store note length
        rts
@length_default
        lda   #48                               ; Default quarter note
        sta   mub.ch.note_length,x              ; Store default length
        rts
        ;
@tempo  ; Tempo change (global)
        lda   ,u+                               ; Read tempo value
        stu   mub.ch.wadr,x                     ; Update pointer
        sta   mub.tempo
        jsr   mub.calc.tempo.divider
        rts
        ;
@cmd    fcb   0                                ; Command storage

;-------------------------------------------------------------------------------
; mub.process.mucom88.commands - Process authentic MUCOM88 MML commands
;-------------------------------------------------------------------------------
; input REG : [A] command byte ($F0-$FF)
; input REG : [B] channel number
; input REG : [X] channel data pointer
; input REG : [U] data stream pointer
;-------------------------------------------------------------------------------
mub.process.mucom88.commands
        ; MUCOM88 compatible MML command dispatch
        cmpa  #mub.MML_EXTENDED                 ; Check for extended commands
        beq   @extended
        ;
        ; Standard MML commands ($F0-$FE)
        suba  #mub.MML_VOICE                    ; Convert to 0-based (F0->0)
        cmpa  #15                               ; Check range (0-14)
        bhi   @unknown                          ; Invalid command
        lsla                                    ; A = A * 2 (2 bytes per address)
        ldy   #@mml_table                       ; Load table address
        jmp   [a,y]                             ; Direct jump using table offset
        ;
@mml_table
        fdb   @voice                            ; F0 - Voice change '@'
        fdb   @volume                           ; F1 - Volume set 'v'
        fdb   @detune                           ; F2 - Detune 'D'
        fdb   @gate_time                        ; F3 - Gate time 'q'
        fdb   @lfo                              ; F4 - LFO set
        fdb   @repeat_start                     ; F5 - Repeat start '['
        fdb   @repeat_end                       ; F6 - Repeat end ']'
        fdb   @mdset_or_noise                   ; F7 - MDSET (FM) / Noise/Mix 'P' (SSG)
        fdb   @stereo_or_noisew                 ; F8 - Stereo/Pan (FM) / Noise params (SSG)
        fdb   @flag_set                         ; F9 - Flag set
        fdb   @w_reg_or_envelope                ; FA - Write register 'y' (FM) / Envelope 'E' (SSG)
        fdb   @volume_up                        ; FB - Volume up ')'
        fdb   @hard_lfo                         ; FC - Hardware LFO
        fdb   @tie                              ; FD - Tie '&'
        fdb   @repeat_skip                      ; FE - Repeat skip '/'
        ;
@extended
        ; Extended commands (FF xx)
        lda   ,u+                               ; Read sub-command
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.process.extended.commands     ; Process extended commands
        rts
        ;
@unknown
        ; Unknown command
        rts
        ;
@voice  ; F0 - Voice change '@'
        lda   ,u+                               ; Read voice number
        stu   mub.ch.wadr,x                     ; Update pointer
        sta   mub.ch.vnum+3,x                   ; Store voice number
        jsr   mub.load.voice                    ; Load voice data and send to YM2608
        rts
        ;
@volume ; F1 - Volume set 'v'
        lda   ,u+                               ; Read volume value
        stu   mub.ch.wadr,x                     ; Update pointer
        sta   mub.ch.volume+3,x                 ; Store volume
        jsr   mub.apply.volume                  ; Apply to channel
        rts
        ;
@detune ; F2 - Detune 'D'
        ldd   ,u++                              ; Read detune value (16-bit)
        stu   mub.ch.wadr,x                     ; Update pointer
        std   mub.ch.detune,x                   ; Store detune
        rts
        ;
@gate_time ; F3 - Gate time 'q'
        lda   ,u+                               ; Read gate time
        stu   mub.ch.wadr,x                     ; Update pointer
        cmpa  #mub.MAX_GATE_TIME                ; Check range
        bls   @gate_ok
        lda   #mub.MAX_GATE_TIME                ; Clamp to maximum
@gate_ok
        sta   mub.ch.gate_time,x                ; Store gate time
        rts
        ;
@lfo    ; F4 - LFO set
        lda   ,u+                               ; Read LFO sub-command
        stu   mub.ch.wadr,x                     ; Update pointer
        tsta                                    ; Check sub-command
        beq   @lfo_off                          ; 0 = LFO off
        deca                                    ; Convert to 0-based
        jsr   mub.lfo.set                       ; Process LFO command
        rts
        ;
@lfo_off
        jsr   mub.lfo.off                       ; Turn off LFO
        rts
        ;
@repeat_start ; F5 - Repeat start '['
        lda   ,u+                               ; Read repeat count
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.repeat.start
        rts
        ;
@repeat_end ; F6 - Repeat end ']'
        jsr   mub.repeat.end
        rts
        ;
@mdset_or_noise ; F7 - MDSET (FM) or Noise/Mix 'P' (SSG)
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        cmpb  #6                                ; Check if FM channel (0-5)
        blo   @mdset                            ; FM channel = MDSET
        ;
        ; SSG channel = NOISE
@noise  lda   ,u+                               ; Read noise parameter
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.ssg.set.noise                 ; Set SSG noise/mix mode
        rts
        ;
@mdset  ; F7 - MDSET (SE Mode detune)
        jsr   mub.set.se.mode                   ; Enable SE mode
        ; Read 4 detune values for 4 operators
        ldd   ,u++                              ; Read OP1, OP2 detune
        std   mub.detdat                        ; Store OP1, OP2
        ldd   ,u++                              ; Read OP3, OP4 detune  
        std   mub.detdat+2                      ; Store OP3, OP4
        stu   mub.ch.wadr,x                     ; Update pointer
        rts
        ;
@stereo_or_noisew ; F8 - Stereo/Pan (FM) or Noise params (SSG)
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        cmpb  #6                                ; Check if SSG channel (6-8)
        blo   @stereo                           ; FM channel = STEREO
        ;
        ; SSG channel = NOISEW
@noisew lda   ,u+                               ; Read noise parameter
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.ssg.set.noise.params          ; Set noise parameters
        rts
        ;
@stereo ; F8 - STEREO (FM channels)
        lda   ,u+                               ; Read stereo parameter
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.set.stereo                    ; Set stereo mode
        rts
        ;
@flag_set ; F9 - Flag set
        lda   ,u+                               ; Read flag value
        stu   mub.ch.wadr,x                     ; Update pointer
        sta   mub.flgadr                        ; Store in flag address (MUCOM88 compatible)
        rts
        ;
@w_reg_or_envelope ; FA - Write register 'y' (FM) or Envelope 'E' (SSG)
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        cmpb  #6                                ; Check if SSG channel (6-8)
        blo   @w_reg                            ; FM channel = W_REG
        ;
        ; SSG channel = ENVPST
@envelope
        jsr   mub.ssg.set.envelope              ; Set SSG envelope
        ; Envelope parameters are read by the function
        rts
        ;
@w_reg  ; FA - W_REG (FM channels) - direct YM2608 register write
        ldb   ,u+                               ; Read register number
        lda   ,u+                               ; Read register value
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   ym2608.write                      ; Write directly to YM2608
        rts
        ;
@volume_up ; FB - Volume up ')'
        lda   ,u+                               ; Read volume delta
        stu   mub.ch.wadr,x                     ; Update pointer
        adda  mub.ch.volume+3,x                 ; Add to current volume
        cmpa  #15                               ; Check overflow
        bls   @vol_ok                           ; Within range
        lda   #15                               ; Clamp to max
@vol_ok sta   mub.ch.volume+3,x                 ; Store new volume
        jsr   mub.apply.volume                  ; Apply to channel
        rts
        ;
@hard_lfo ; FC - Hardware LFO
        lda   ,u+                               ; Read frequency control
        pshs  a                                 ; Save frequency control
        lda   ,u+                               ; Read PMS (Pitch Modulation Sensitivity)
        pshs  a                                 ; Save PMS
        lda   ,u+                               ; Read AMS (Amplitude Modulation Sensitivity)
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.set.hardware.lfo              ; Set hardware LFO (A=AMS, stack=PMS,FREQ)
        leas  2,s                               ; Clean stack
        rts
        ;
@tie    ; FD - Tie '&'
        ; MUCOM88 TIE logic: RES bit 6 = disable KEYOFF = enable TIE
        lda   mub.ch.flags1,x                   ; Get main flags (IX+31)
        anda  #%10111111                        ; Clear bit 6 (KEYOFF FLAG)
        sta   mub.ch.flags1,x                   ; Store back - TIE now active
        rts
        ;
@repeat_skip ; FE - Repeat skip '/'
        ; MUCOM88 RSKIP: Conditional repeat skip
        ; Skips ahead if we're in the last iteration of a repeat
        ldd   ,u++                              ; Read skip offset (2 bytes)
        stu   mub.ch.wadr,x                     ; Update pointer
        ;
        ; Check if we're in a repeat and if it's the last iteration
        ldy   mub.ch.repeat_stack,x             ; Get current stack pointer
        beq   @no_skip                          ; No active repeat, don't skip
        ;
        ; Get repeat info from stack (without popping)
        leay  -mub.REPEAT_STACK_ENTRY_SIZE,y    ; Point to current entry
        lda   ,y                                ; Get repeat count
        deca                                    ; Check if count = 1 (last iteration)
        bne   @no_skip                          ; Not last iteration, don't skip
        ;
        ; Last iteration: apply skip offset
        ldu   mub.ch.wadr,x                     ; Get current position
        leau  d,u                               ; Add skip offset
        stu   mub.ch.wadr,x                     ; Update pointer
        ;
@no_skip
        rts

;-------------------------------------------------------------------------------
; mub.process.note.command - Process note/rest commands ($80-$FE)
;-------------------------------------------------------------------------------
; input REG : [A] note/rest command byte
; input REG : [B] channel number
; input REG : [X] channel data pointer
; input REG : [U] data stream pointer
;-------------------------------------------------------------------------------
mub.process.note.command
        cmpa  #$80
        beq   @rest                             ; $80 = rest
        ;
        ; $81-$FE = notes (C, C#, D, D#, E, F, F#, G, G#, A, A#, B)
        suba  #$81                              ; Convert to note number (0-125)
        sta   @note
        ;
        ; Read note length
        lda   ,u+                               ; Read length byte
        stu   mub.ch.wadr,x                     ; Update pointer
        tfr   a,b
        clra
        std   mub.ch.length,x                   ; Set length counter
        ;
        ; Calculate MIDI note number including octave
        lda   @note                             ; Get note number (0-125)
        ldb   #12                               ; 12 notes per octave
        pshs  d                                 ; Save note and divisor
        ;
        ; Extract octave from note (note / 12)
        lda   @note                             ; Get note again
        ; Simple division: A = A / B, B = A % B
        clr   ,-s                               ; Clear quotient on stack
@div_loop
        suba  #12                               ; Subtract 12
        bcs   @div_done                         ; If carry, we're done
        inc   ,s                                ; Increment quotient
        bra   @div_loop
@div_done
        adda  #12                               ; Restore remainder
        sta   @note                             ; Store note within octave (0-11)
        puls  b                                 ; Get calculated octave
        ;
        ; Add channel's octave setting
        addb  mub.ch.octave,x                   ; Add channel octave
        cmpb  #8                                ; Check maximum octave
        blo   @octave_ok
        ldb   #7                                ; Clamp to max octave
@octave_ok
        ;
        ; Calculate final MIDI note: octave * 12 + note
        pshs  b                                 ; Save octave
        lda   #12
        mul                                     ; D = octave * 12
        addb  @note                             ; Add note within octave
        stb   @final_note                       ; Store final note
        puls  b                                 ; Restore octave
        puls  d                                 ; Clean stack
        ;
        ; Send note to YM2608 based on channel type
        lda   mub.ch.chnum+3,x                  ; Get channel number
        cmpa  #6
        blo   @fm_channel
        cmpa  #9
        blo   @ssg_channel
        cmpa  #10
        beq   @rhythm_channel
        ;
        ; ADPCM channel (10)
        lda   @final_note                       ; Use calculated note
        jsr   mub.play.adpcm.note
        bra   @set_flags
        ;
@rhythm_channel
        ; Rhythm channel (9) 
        lda   @final_note                       ; Use calculated note
        jsr   mub.play.rhythm.note
        bra   @set_flags
        ;
@ssg_channel
        ; SSG channels (6-8)
        lda   @final_note                       ; Use calculated note
        ldb   mub.ch.chnum+3,x
        subb  #6                                ; Convert to SSG channel 0-2
        jsr   ym2608.ssg.note.on
        bra   @set_flags
        ;
@fm_channel
        ; FM channel (0-5)
        lda   @final_note                       ; Use calculated note
        ldb   mub.ch.chnum+3,x
        jsr   ym2608.note.on
        ;
@set_flags
        ; Set note on flag
        lda   mub.ch.length+3,x                 ; Get status flags
        ora   #mub.CH_NOTE_ON                   ; Set note on flag
        sta   mub.ch.length+3,x
        rts
        ;
@rest   ; Rest command
        lda   ,u+                               ; Read rest length
        stu   mub.ch.wadr,x                     ; Update pointer
        tfr   a,b
        clra
        std   mub.ch.length,x                   ; Set length counter
        ;
        ; Turn off current note
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        jsr   ym2608.note.off
        ;
        ; Clear note on flag
        lda   mub.ch.length+3,x                 ; Get status flags
        anda  #^mub.CH_NOTE_ON                  ; Clear note on flag
        sta   mub.ch.length+3,x
        rts
        ;
@note       fcb   0                            ; Note storage
@final_note fcb   0                            ; Final calculated note

;-------------------------------------------------------------------------------
; mub.apply.volume - Apply volume to channel
;-------------------------------------------------------------------------------
; input REG : [B] channel number
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.apply.volume
        pshs  a,b,d                             ; Save registers
        ;
        ; Process soft envelope if active
        jsr   mub.soft.envelope                 ; Process envelope, result in A
        pshs  a                                 ; Save envelope-modified volume
        ;
        ; Get base volume and combine with envelope
        ldb   mub.ch.volume,x                   ; Get base volume (using corrected offset)
        andb  #$0F                              ; Mask to 4-bit volume
        ;
        ; If envelope was active, A contains the modified volume
        ; If not active, A contains the original volume
        puls  a                                 ; Restore envelope result
        ;
        ; Apply volume to YM2608 based on channel type
        ldb   mub.ch.chnum,x                    ; Get channel number (using corrected offset)
        cmpb  #6                                ; Check if SSG channel (6-8)
        bhs   @apply_ssg_volume                 ; SSG channel
        ;
        cmpb  #3                                ; Check if FM channel (0-2)
        blo   @apply_fm_volume                  ; FM channel
        ;
        ; ADPCM/Rhythm channels (3-5 in our mapping)
        ; Use legacy function for now
        lda   mub.ch.volume+3,x                 ; Get channel volume (legacy offset)
        ldb   mub.ch.chnum+3,x                  ; Get channel number (legacy offset)
        jsr   ym2608.set.volume
        bra   @volume_done
        ;
@apply_fm_volume
        ; Apply FM volume using FMVDAT table
        cmpa  #20                               ; Check range
        blo   @fm_in_range
        lda   #19                               ; Clamp to maximum
        ;
@fm_in_range
        leay  mub.fmvdat,pcr                    ; Get FM volume table
        lda   a,y                               ; Get volume value from table
        ;
        ; Apply to FM channel TL registers
        ; Use legacy function for now
        lda   mub.ch.volume+3,x                 ; Get channel volume (legacy offset)
        ldb   mub.ch.chnum+3,x                  ; Get channel number (legacy offset)
        jsr   ym2608.set.volume
        bra   @volume_done
        ;
@apply_ssg_volume
        ; Apply SSG volume (0-15 range)
        cmpa  #15                               ; Check range
        bls   @ssg_in_range
        lda   #15                               ; Clamp to maximum
        ;
@ssg_in_range
        ; Calculate SSG volume register (A/B/C = $08,$09,$0A)
        tfr   a,b                               ; Volume value in B
        lda   mub.ch.chnum,x                    ; Get channel number
        suba  #6                                ; Convert to 0-2 range
        adda  #$08                              ; Add base register ($08)
        ldx   #0                                ; Port 0 for SSG
        jsr   ym2608.write                      ; Write to YM2608
        ;
@volume_done
        puls  a,b,d,pc                          ; Restore and return
        ;
;*******************************************************************************
; PCM/ADPCM Channel Handling
;*******************************************************************************

;-------------------------------------------------------------------------------
; mub.play.adpcm.note - Play ADPCM sample
;-------------------------------------------------------------------------------
; input REG : [A] sample number
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.play.adpcm.note
        ; Store sample number
        sta   mub.ch.vnum+3,x                   ; Store sample in voice field
        ;
        ; Check if PCM data is available
        ldd   mub.pcm.data
        beq   @no_pcm                           ; No PCM data embedded
        ;
        ; Calculate sample offset in PCM data
        ; Each sample entry is 8 bytes (start addr, end addr, delta-N, flags)
        ldb   mub.ch.vnum+3,x                   ; Get sample number
        beq   @no_pcm                           ; Sample 0 = no sample
        decb                                    ; Convert to 0-based
        lda   #8                                ; 8 bytes per sample entry
        mul                                     ; D = sample offset
        ;
        ; Get sample data from PCM area
        ldy   mub.pcm.data
        leay  d,y                               ; Y = PCM data + sample offset
        ;
        ; Load sample parameters
        ldd   ,y++                              ; Start address
        std   @start_addr
        ldd   ,y++                              ; End address  
        std   @end_addr
        ldd   ,y++                              ; Delta-N (frequency)
        std   @delta_n
        ldd   ,y++                              ; Flags/Level
        std   @flags_level
        ;
        ; Send to YM2608 ADPCM - pass parameters via registers
        ldx   #@start_addr                      ; X points to parameter block
        jsr   ym2608.adpcm.play
        ;
@no_pcm rts
        ;
; Temporary storage for ADPCM parameters
@start_addr fdb 0
@end_addr   fdb 0  
@delta_n    fdb 0
@flags_level fdb 0

;-------------------------------------------------------------------------------
; mub.play.rhythm.note - Play rhythm sound
;-------------------------------------------------------------------------------
; input REG : [A] rhythm instrument number
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.play.rhythm.note
        ; Store rhythm number
        sta   mub.ch.vnum+3,x                   ; Store rhythm in voice field
        ;
        ; Send rhythm command to YM2608
        ldb   mub.ch.volume+3,x                 ; Get volume
        jsr   ym2608.rhythm.play
        ;
        rts
        ;
;*******************************************************************************
; End of Music Handling
;*******************************************************************************

;-------------------------------------------------------------------------------
; mub.check.end - Check if music has ended
;-------------------------------------------------------------------------------
mub.check.end
        ; Check if any channels are still active
        ldx   #mub.channels
        lda   #mub.MAX_CHANNELS
        ;
@loop   ldb   mub.ch.status,x
        andb  #mub.CH_ACTIVE
        bne   @still_playing                    ; At least one channel active
        ;
        leax  mub.CHANNEL_SIZE_EXT,x
        deca
        bne   @loop
        ;
        ; No channels active - music ended
        ldx   mub.callback
        beq   @check_loop
        jmp   ,x                                ; Call user callback
        ;
@check_loop
        lda   mub.loop
        beq   @stop_music
        ;
        ; Restart music
        jsr   mub.restart
        rts
        ;
@stop_music
        jsr   mub.stop
        ;
@still_playing
        rts

;-------------------------------------------------------------------------------
; mub.restart - Restart music from beginning
;-------------------------------------------------------------------------------
mub.restart
        ; Reinitialize channels with original data
        jsr   mub.setup.channel.pointers
        jsr   mub.init.channels
        ;
        ; Reset timing
        lda   #1
        sta   mub.frame.wait
        clr   mub.tick.counter
        clr   mub.tick.counter+1
        ;
        rts

;-------------------------------------------------------------------------------
; mub.get.status - Get player status
;-------------------------------------------------------------------------------
; output REG: [A] current status
;-------------------------------------------------------------------------------
mub.get.status
        lda   mub.status
        rts

;-------------------------------------------------------------------------------
; mub.set.tempo - Set playback tempo
;-------------------------------------------------------------------------------
; input REG : [A] new tempo value
;-------------------------------------------------------------------------------
mub.set.tempo
        sta   mub.tempo
        jsr   mub.calc.tempo.divider
        rts

;-------------------------------------------------------------------------------
; mub.fade.out - Start fade out
;-------------------------------------------------------------------------------
; input REG : [A] fade speed (frames per step)
;-------------------------------------------------------------------------------
mub.fade.out
        sta   mub.fade.speed
        lda   mub.total.volume
        sta   mub.fade.counter
        rts

;-------------------------------------------------------------------------------
; mub.process.fade - Process fade out
;-------------------------------------------------------------------------------
mub.process.fade
        lda   mub.fade.counter
        beq   @rts                              ; No fade in progress
        ;
        dec   mub.fade.speed
        bne   @rts                              ; Not time to fade yet
        ;
        ; Reset fade speed counter
        lda   mub.tempo
        lsra                                    ; Divide by 2 for fade speed
        sta   mub.fade.speed
        ;
        ; Decrease volume
        dec   mub.fade.counter
        bne   @apply_fade
        ;
        ; Fade complete - stop music
        jsr   mub.stop
        rts
        ;
@apply_fade
        ; Apply new volume to all channels
        lda   mub.fade.counter
        sta   mub.total.volume
        jsr   mub.apply.fade.to.all             ; Apply fade to all active channels
        ;
@rts    rts
        
;===============================================================================
; REPEAT SYSTEM FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.repeat.start - Start a repeat section
;-------------------------------------------------------------------------------
; input REG : [A] repeat count
; input REG : [B] channel number
; input REG : [X] channel data pointer
; input REG : [U] current data pointer
;-------------------------------------------------------------------------------
mub.repeat.start
        pshs  d,y                               ; Save registers
        ;
        ; Calculate repeat stack address for this channel
        lda   mub.ch.chnum+3,x                  ; Get channel number
        ldb   #mub.REPEAT_STACK_SIZE * mub.REPEAT_STACK_ENTRY_SIZE
        mul                                     ; A = channel * stack_size
        ldy   #mub.repeat.stacks                ; Base address
        leay  a,y                               ; Y = channel stack base
        ;
        ; Get current stack pointer
        ldd   mub.ch.repeat_stack,x             ; Current stack pointer
        cmpd  #mub.REPEAT_STACK_SIZE * mub.REPEAT_STACK_ENTRY_SIZE
        bhs   @stack_overflow                   ; Stack full
        ;
        ; Push repeat info onto stack
        lda   ,s                                ; Get repeat count from stack
        sta   d,y                               ; Store repeat count
        stu   d,y                               ; Store current address (2 bytes)
        ;
        ; Update stack pointer
        addd  #mub.REPEAT_STACK_ENTRY_SIZE      ; Move to next entry
        std   mub.ch.repeat_stack,x             ; Update stack pointer
        ;
@stack_overflow
        puls  d,y,pc                            ; Restore and return

;-------------------------------------------------------------------------------
; mub.repeat.end - End a repeat section
;-------------------------------------------------------------------------------
; input REG : [B] channel number
; input REG : [X] channel data pointer
; input REG : [U] current data pointer
; output REG: [U] updated data pointer (may jump back)
;-------------------------------------------------------------------------------
mub.repeat.end
        pshs  d,y                               ; Save registers
        ;
        ; Calculate repeat stack address for this channel
        lda   mub.ch.chnum+3,x                  ; Get channel number
        ldb   #mub.REPEAT_STACK_SIZE * mub.REPEAT_STACK_ENTRY_SIZE
        mul                                     ; A = channel * stack_size
        ldy   #mub.repeat.stacks                ; Base address
        leay  a,y                               ; Y = channel stack base
        ;
        ; Get current stack pointer
        ldd   mub.ch.repeat_stack,x             ; Current stack pointer
        beq   @stack_underflow                  ; Stack empty
        ;
        ; Move to previous entry
        subd  #mub.REPEAT_STACK_ENTRY_SIZE      ; Move back
        std   mub.ch.repeat_stack,x             ; Update stack pointer
        ;
        ; Get repeat info from stack
        lda   d,y                               ; Get repeat count
        deca                                    ; Decrement count
        beq   @repeat_done                      ; Count reached 0
        ;
        ; Store decremented count back
        sta   d,y                               ; Update count
        ;
        ; Jump back to repeat start
        ldu   d,y                               ; Load repeat start address
        bra   @end
        ;
@repeat_done
        ; Repeat finished, continue normally
        bra   @end
        ;
@stack_underflow
        ; No matching repeat start - ignore
        ;
@end    puls  d,y,pc                            ; Restore and return

;-------------------------------------------------------------------------------
; mub.init.channel.extended - Initialize extended channel features
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.init.channel.extended
        ; Initialize repeat stack
        ldd   #0
        std   mub.ch.repeat_stack,x             ; Clear stack pointer
        std   mub.ch.repeat_count,x             ; Clear repeat count
        ;
        ; Initialize gate time
        lda   #mub.DEFAULT_GATE_TIME
        sta   mub.ch.gate_time,x                ; Set default gate time
        ;
        ; Initialize MUCOM88 flags (bit 6 SET = KEYOFF enabled by default)
        lda   #%01000000                        ; Set KEYOFF flag (normal state)
        sta   mub.ch.flags1,x                   ; Store in main flags (IX+31)
        ;
        ; Initialize octave and note length
        lda   #4                                ; Default octave 4 (MUCOM88 standard)
        sta   mub.ch.octave,x                   ; Set default octave
        lda   #48                               ; Default note length (48 ticks = quarter note)
        sta   mub.ch.note_length,x              ; Set default note length
        ;
        ; Initialize LFO
        clr   mub.ch.lfo_delay,x
        clr   mub.ch.lfo_speed,x
        clr   mub.ch.lfo_depth,x
        clr   mub.ch.lfo_counter,x
        ;
        rts
        
;===============================================================================
; VOICE LOADING FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.load.voice - Load voice data and send to YM2608
;-------------------------------------------------------------------------------
; input REG : [A] voice number
; input REG : [B] channel number
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------

mub.load.voice
        pshs  d,y,u                             ; Save registers
        ;
        ; Check if this is an FM channel (0-5)
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        cmpb  #6                                ; Check if FM channel
        bhs   @not_fm                           ; Not FM, skip voice loading
        ;
        ; Calculate voice data address in MUB
        ; Voice data starts after header + music data
        ldy   mub.voice.data.addr               ; Base voice data address
        beq   @not_fm                           ; No voice data available, same as not FM
        ;
        ; Each voice is 25 bytes (FM algorithm + 4 operators * 6 params each)
        ldb   #25                               ; Voice size
        mul                                     ; D = voice_number * voice_size
        leay  d,y                               ; Y = voice data address
        ;
        ; Load voice data to YM2608
        ; Voice format: [ALG][OP1_TL][OP1_AR][OP1_DR][OP1_SL][OP1_RR][OP1_ML]...[OP4_ML]
        lda   ,y+                               ; Algorithm + Feedback
        anda  #$07                              ; Mask algorithm (0-7)
        sta   mub.ch.alg+3,x                    ; Store algorithm
        ;
        ; Send algorithm to YM2608
        ldb   #$B0                              ; Algorithm register base
        addb  mub.ch.chnum+3,x                  ; Add channel offset
        jsr   ym2608.write                      ; Write algorithm
        ;
        ; Load 4 operators (24 parameters total)
        ldb   #4                                ; 4 operators
        ldu   #@op_regs                         ; Register offset table
        ;
@op_loop
        pshs  b                                 ; Save operator counter
        ;
        ; Load 6 parameters per operator
        ldb   #6                                ; 6 parameters per operator
@param_loop
        lda   ,y+                               ; Read parameter
        pshs  a,b                               ; Save parameter and counter
        ;
        ; Calculate register address
        lda   ,u+                               ; Get base register offset
        adda  mub.ch.chnum+3,x                  ; Add channel offset
        tfr   a,b                               ; Register in B
        puls  a                                 ; Restore parameter
        jsr   ym2608.write                      ; Write to YM2608
        ;
        puls  b                                 ; Restore counter
        decb
        bne   @param_loop
        ;
        puls  b                                 ; Restore operator counter
        decb
        bne   @op_loop
        ;
@not_fm
        puls  d,y,u,pc                          ; Restore and return
        ;
; YM2608 FM operator register offsets (TL, AR, DR, SL, RR, ML)
@op_regs
        fcb   $40,$50,$60,$70,$80,$30           ; Operator 1
        fcb   $44,$54,$64,$74,$84,$34           ; Operator 2  
        fcb   $48,$58,$68,$78,$88,$38           ; Operator 3
        fcb   $4C,$5C,$6C,$7C,$8C,$3C           ; Operator 4

;-------------------------------------------------------------------------------
; mub.get.voice.data.address - Get voice data address from MUB
;-------------------------------------------------------------------------------
; output REG: [Y] voice data address (0 if no voice data)
;-------------------------------------------------------------------------------
mub.get.voice.data.address
        ldy   mub.data.addr                     ; Get MUB data address
        beq   @no_data                          ; No MUB loaded
        ;
        ; Voice data comes after music data
        ; Skip to end of music data using data size
        ldd   mub.data.size                     ; Get music data size
        leay  d,y                               ; Y = end of music data
        ;
        ; Voice data starts here (if present)
        ; Check if we have enough space for voice data
        ldd   mub.file.size                     ; Get total file size
        subd  mub.data.size                     ; Subtract music data size
        subd  #mub.HEADER_SIZE                  ; Subtract header size
        cmpd  #25                               ; Need at least 25 bytes for one voice
        blo   @no_data                          ; Not enough data
        ;
        ; Y points to voice data, return it
        rts
        ;
@no_data
        ldy   #0                                ; No voice data available
        rts
        
;===============================================================================
; LFO SYSTEM FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.lfo.set - Configure LFO parameters
;-------------------------------------------------------------------------------
; input REG : [A] LFO type (0=off, 1=vibrato, 2=tremolo, 3=both)
; input REG : [X] channel data pointer
; input REG : [U] data stream pointer
;-------------------------------------------------------------------------------
mub.lfo.set
        pshs  d,y                               ; Save registers
        ;
        ; MUCOM88 SETDEL: Set LFO delay
        lda   ,u+                               ; Read LFO delay
        sta   mub.ch.lfo_delay,x                ; Set delay (IX+19)
        sta   mub.ch.lfo_work1,x                ; Set work1 (IX+20)
        ;
        ; MUCOM88 SETCO: Set LFO counter
        lda   ,u+                               ; Read LFO speed (counter)
        sta   mub.ch.lfo_counter,x              ; Set counter (IX+21)
        sta   mub.ch.lfo_work2,x                ; Set work2 (IX+22)
        ;
        ; MUCOM88 SETVCT: Set LFO increment (2 bytes)
        ldd   ,u++                              ; Read LFO increment (16-bit)
        std   mub.ch.lfo_increment,x            ; Set increment (IX+23,24)
        std   mub.ch.lfo_work34,x               ; Set work3,4 (IX+25,26)
        ;
        ; MUCOM88 SETPEK: Set LFO peak level
        lda   ,u+                               ; Read LFO depth (peak level)
        sta   mub.ch.lfo_peak,x                 ; Set peak level (IX+27)
        lsra                                    ; Shift right (SRL A)
        sta   mub.ch.lfo_work5,x                ; Set work5 (IX+28)
        ;
        stu   mub.ch.wadr,x                     ; Update data pointer
        ;
        ; MUCOM88 LFORST: Reset LFO delay and continue flag
        jsr   mub.lfo.reset
        ;
        ; MUCOM88 LFORST2: Reset peak level and increment work
        jsr   mub.lfo.reset2
        ;
        ; Set LFO active flag (bit 7 of IX+31)
        ldb   mub.ch.flags1,x                   ; Get main flags (IX+31)
        orb   #%10000000                        ; Set LFO flag (bit 7)
        stb   mub.ch.flags1,x                   ; Store back
        ;
        puls  d,y,pc                            ; Restore and return

;-------------------------------------------------------------------------------
; mub.lfo.off - Turn off LFO
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.lfo.off
        ; Clear LFO flag in MUCOM88 flags
        ldb   mub.ch.flags1,x                   ; Get main flags (IX+31)
        andb  #%01111111                        ; Clear LFO flag (bit 7)
        stb   mub.ch.flags1,x                   ; Store back
        ;
        ; Clear LFO parameters
        clr   mub.ch.lfo_delay,x
        clr   mub.ch.lfo_work1,x
        clr   mub.ch.lfo_counter,x
        clr   mub.ch.lfo_work2,x
        ldd   #0
        std   mub.ch.lfo_increment,x
        std   mub.ch.lfo_work34,x
        clr   mub.ch.lfo_peak,x
        clr   mub.ch.lfo_work5,x
        ;
        rts

;-------------------------------------------------------------------------------
; mub.lfo.reset - Reset LFO delay and continue flag (MUCOM88 LFORST)
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.lfo.reset
        ; Reset LFO delay work from delay value
        lda   mub.ch.lfo_delay,x                ; Get delay (IX+19)
        sta   mub.ch.lfo_work1,x                ; Store in work1 (IX+20)
        ;
        ; Reset LFO continue flag (bit 5 of IX+31)
        lda   mub.ch.flags1,x                   ; Get main flags
        anda  #%11011111                        ; Clear continue flag (bit 5)
        sta   mub.ch.flags1,x                   ; Store back
        ;
        rts

;-------------------------------------------------------------------------------
; mub.lfo.reset2 - Reset peak level and increment work (MUCOM88 LFORST2)
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.lfo.reset2
        ; Reset peak level work
        lda   mub.ch.lfo_peak,x                 ; Get peak level (IX+27)
        lsra                                    ; Shift right (SRL A)
        sta   mub.ch.lfo_work5,x                ; Store in work5 (IX+28)
        ;
        ; Reset increment work from increment value
        lda   mub.ch.lfo_increment,x            ; Get increment low (IX+23)
        sta   mub.ch.lfo_work34,x               ; Store in work3 (IX+25)
        lda   mub.ch.lfo_increment+1,x          ; Get increment high (IX+24)
        sta   mub.ch.lfo_work34+1,x             ; Store in work4 (IX+26)
        ;
        rts

;-------------------------------------------------------------------------------
; mub.process.lfo - Process LFO for a channel (called per frame)
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.process.lfo
        pshs  a,b,d,y                           ; Save registers
        ;
        ; Check if LFO is active (bit 7 of IX+31)
        ldb   mub.ch.flags1,x                   ; Get main flags (IX+31)
        bitb  #%10000000                        ; Test LFO flag (bit 7)
        bne   >
        puls  a,b,d,y,pc                        ; LFO not active, return
!
        ; MUCOM88 PLLFO processing
        ;
        ; Check delay counter (IX+20)
        ldb   mub.ch.lfo_work1,x                ; Get delay work (IX+20)
        beq   @process_lfo                      ; No delay, process LFO
        decb                                    ; Decrement delay
        stb   mub.ch.lfo_work1,x                ; Store back
        puls  a,b,d,y,pc                        ; Still in delay, return
        ;
@process_lfo
        ; Check peak level counter (IX+28) - PLLFO logic
        lda   mub.ch.lfo_work5,x                ; Get peak level counter
        tsta                                    ; Check if zero
        bne   @pllfo1                           ; Not zero, continue
        ;
        ; Peak level counter is zero - reset (PLLFO logic)
        ldd   #0                                ; HL = 0 in original
        lda   mub.ch.lfo_work34+1,x             ; Get work4 (IX+26) - high byte
        ldb   mub.ch.lfo_work34,x               ; Get work3 (IX+25) - low byte
        ;
        ; Reset peak level counter
        lda   mub.ch.lfo_peak,x                 ; Get peak level (IX+27)
        lsra                                    ; Shift right
        sta   mub.ch.lfo_work5,x                ; Store in counter (IX+28)
        ;
@pllfo1
        ; Decrement peak level counter (PLLFO1)
        dec   mub.ch.lfo_work5,x                ; P.L.C.-1 (IX+28)
        ;
        ; Get LFO increment work values
        lda   mub.ch.lfo_work34,x               ; Get work3 (IX+25) - low
        ldb   mub.ch.lfo_work34+1,x             ; Get work4 (IX+26) - high
        tfr   d,y                               ; Store in Y for calculation
        ;
        ; Add LFO increment to work values
        ldd   mub.ch.lfo_increment,x            ; Get increment (IX+23,24)
        leay  d,y                               ; Add increment to work
        tfr   y,d                               ; Get result
        std   mub.ch.lfo_work34,x               ; Store back in work (IX+25,26)
        ;
        ; Calculate LFO output value (simplified PLS2)
        tfr   b,a                               ; Use high byte as LFO value
        ;
        ; Apply to frequency (PLLFO2 equivalent)
        ; Check if this is channel 3 in SE mode
        ldb   mub.ch.chnum,x                    ; Get channel number
        cmpb  #2                                ; Channel 3 (0-based = 2)
        bne   @normal_lfo
        ;
        ; Check SE mode flag
        ldb   mub.se.mode.flag                  ; Get SE mode flag
        cmpb  #$78                              ; SE mode active?
        bne   @normal_lfo
        ;
        ; SE mode LFO - apply to all 4 operators (LFOP4 equivalent)
        std   mub.newfnm                        ; Store new F-Number work
        jsr   mub.apply.se.lfo.to.operators     ; Apply LFO to all 4 operators
        bra   @lfo_done
        ;
@normal_lfo
        ; Normal LFO - apply to F-Number registers (PLLFO2)
        ; Store F-Number data in channel
        sta   mub.ch.fnum2,x                    ; Store F-Number 2 (IX+30)
        stb   mub.ch.fnum1,x                    ; Store F-Number 1 (IX+29)
        ;
        ; Calculate YM2608 register addresses
        pshs  x                                 ; Save channel pointer
        ldb   #$A4                              ; Base F-Number high register
        addb  mub.ch.chnum,x                    ; Add channel offset
        lda   mub.ch.fnum2,x                    ; Get F-Number high value
        ; Select port based on channel: 0-2 use port 0, 3-5 use port 1
        pshs  a                                 ; Save F-Number value
        lda   mub.ch.chnum,x                    ; Get channel number
        cmpa  #3                                ; Channel 3 or higher?
        blo   @port0_high                       ; Use port 0 for channels 0-2
        ldx   #1                                ; Port 1 for channels 3-5
        bra   @write_high
@port0_high
        ldx   #0                                ; Port 0 for channels 0-2
@write_high
        puls  a                                 ; Restore F-Number value
        jsr   ym2608.write                      ; Write F-Number high
        ;
        puls  x                                 ; Restore channel pointer
        pshs  x                                 ; Save again
        ldb   #$A0                              ; F-Number low register base
        addb  mub.ch.chnum,x                    ; Add channel offset
        lda   mub.ch.fnum1,x                    ; Get F-Number low
        ; Select port based on channel: 0-2 use port 0, 3-5 use port 1
        pshs  a                                 ; Save F-Number value
        lda   mub.ch.chnum,x                    ; Get channel number
        cmpa  #3                                ; Channel 3 or higher?
        blo   @port0_low                        ; Use port 0 for channels 0-2
        ldx   #1                                ; Port 1 for channels 3-5
        bra   @write_low
@port0_low
        ldx   #0                                ; Port 0 for channels 0-2
@write_low
        puls  a                                 ; Restore F-Number value
        jsr   ym2608.write                      ; Write F-Number low
        puls  x                                 ; Restore channel pointer
        ;
@lfo_done
        ; Set LFO continue flag
        lda   mub.ch.flags1,x                   ; Get main flags
        ora   #%00100000                        ; Set continue flag (bit 5)
        sta   mub.ch.flags1,x                   ; Store back
        ;
        ; Store computed LFO value for external use
        tfr   b,a                               ; Get LFO value
        sta   @lfo_value                        ; Store for other functions
        puls  a,b,d,y,pc                        ; Restore and return
        ;
@lfo_value fcb 0                               ; Current LFO value
        
;===============================================================================
; STEREO CONTROL FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.set.stereo - Set stereo/pan control
;-------------------------------------------------------------------------------
; input REG : [A] stereo parameter
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.set.stereo
        pshs  d,y                               ; Save registers
        ;
        ; Check channel type for stereo handling
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        ;
        ; Check if Drum mode
        tst   mub.drmf1
        bne   @drum_stereo
        ;
        ; Check if PCM mode  
        tst   mub.pcmflg
        bne   @pcm_stereo
        ;
        ; FM stereo mode
@fm_stereo
        cmpb  #6                                ; Check if FM channel (0-5)
        bhs   @exit                             ; Not FM channel
        ;
        ; FM stereo: A contains L/R bits
        ; Format: bit 7-6 = L/R for this channel
        lsra                                    ; Shift to bits 5-4
        lsra
        sta   @stereo_temp                      ; Store temporarily
        ;
        ; Calculate YM2608 pan register (B4-B6)
        ldb   #$B4                              ; Pan register base
        addb  mub.ch.chnum+3,x                  ; Add channel offset
        lda   @stereo_temp                      ; Get stereo value
        jsr   ym2608.write                      ; Write to YM2608
        bra   @exit
        ;
@pcm_stereo
        ; PCM stereo: store in PCMLR variable
        sta   mub.pcmlr                         ; Store PCM L/R control
        bra   @exit
        ;
@drum_stereo
        ; Drum stereo: control individual drum instruments
        anda  #$0F                              ; Mask to 4 bits (4 drum instruments)
        ; Each bit controls L/R for different drum instruments
        ; Bit 0 = Bass Drum, Bit 1 = Snare, Bit 2 = Cymbal, Bit 3 = Hi-Hat
        sta   @drum_lr_temp                     ; Store drum L/R settings
        ;
        ; Apply to YM2608 rhythm L/R register ($18)
        pshs  x                                 ; Save channel pointer
        lda   #$18                              ; Rhythm L/R register
        ldb   @drum_lr_temp                     ; Get L/R settings
        ldx   #1                                ; Port 1 for rhythm
        jsr   ym2608.write                      ; Write to YM2608
        puls  x                                 ; Restore channel pointer
        ;
@exit   puls  d,y,pc                            ; Restore and return
        ;
@stereo_temp   fcb 0                           ; Temporary stereo value
@drum_lr_temp  fcb 0                           ; Temporary drum L/R settings
        
;===============================================================================
; ADVANCED CHANNEL FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.set.channel.mode - Set channel mode (FM/SSG/PCM/Drum)
;-------------------------------------------------------------------------------
; input REG : [A] mode (0=FM, 1=SSG, 2=PCM, 3=Drum)
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.set.channel.mode
        pshs  d                                 ; Save registers
        ;
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        ;
        ; Set appropriate mode flags
        tsta                                    ; Check mode
        beq   @fm_mode                          ; 0 = FM mode
        deca
        beq   @ssg_mode                         ; 1 = SSG mode
        deca
        beq   @pcm_mode                         ; 2 = PCM mode
        ;
        ; 3 = Drum mode
@drum_mode
        lda   #1
        sta   mub.drmf1                         ; Set drum flag
        clr   mub.pcmflg                        ; Clear PCM flag
        clr   mub.ssgf1                         ; Clear SSG flag
        bra   @exit
        ;
@pcm_mode
        lda   #1
        sta   mub.pcmflg                        ; Set PCM flag
        clr   mub.drmf1                         ; Clear drum flag
        clr   mub.ssgf1                         ; Clear SSG flag
        bra   @exit
        ;
@ssg_mode
        lda   #1
        sta   mub.ssgf1                         ; Set SSG flag
        clr   mub.drmf1                         ; Clear drum flag
        clr   mub.pcmflg                        ; Clear PCM flag
        bra   @exit
        ;
@fm_mode
        clr   mub.drmf1                         ; Clear all mode flags
        clr   mub.pcmflg
        clr   mub.ssgf1
        ;
@exit   puls  d,pc                              ; Restore and return

;===============================================================================
; SE MODE (SOUND EFFECT) FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.set.se.mode - Enable SE mode (Sound Effect with per-operator detune)
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.set.se.mode
        ; SE mode is activated by setting special flag
        ; This enables per-operator detune on FM channel 3
        lda   mub.ch.chnum+3,x                  ; Get channel number
        cmpa  #2                                ; Check if channel 3 (0-based = 2)
        bne   @exit                             ; SE mode only on channel 3
        ;
        ; Enable SE mode flag (equivalent to PLSET1+1 = 78H in original)
        lda   #$78                              ; SE mode flag value
        sta   mub.se.mode.flag                  ; Set SE mode flag
        ;
@exit   rts

;-------------------------------------------------------------------------------
; mub.apply.se.detune - Apply SE mode detune to operators
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
; input REG : [D] base F-Number
;-------------------------------------------------------------------------------
mub.apply.se.detune
        pshs  d,y,u                             ; Save registers
        ;
        ; Check if SE mode is active
        lda   mub.se.mode.flag
        cmpa  #$78                              ; Check SE mode flag
        bne   @normal_mode                      ; Not SE mode
        ;
        ; SE mode: apply individual detune to each operator
        ldy   #mub.detdat                       ; Point to detune data
        ldu   #@op_regs                         ; Point to operator register table
        lda   #4                                ; 4 operators
        ;
@op_loop
        pshs  a                                 ; Save operator counter
        ;
        ; Get detune value for this operator
        ldb   ,y+                               ; Get detune value in B
        sex                                     ; Sign extend B to A (D = signed detune)
        addd  ,s++                              ; Add to base F-Number (pop base F-Number from stack)
        std   temp_fnum                        ; Store result safely
        ;
        ; Calculate F-Number register for this operator (A4+op, A0+op)
        ldb   ,u+                               ; Get operator offset
        addb  #$A4                              ; F-Number high register base
        lda   temp_fnum                        ; Get high byte of F-Number
        jsr   ym2608.write                      ; Write F-Number high
        ;
        ldb   -1,u                              ; Get operator offset again
        addb  #$A0                              ; F-Number low register base
        lda   temp_fnum+1                      ; Get low byte of F-Number
        jsr   ym2608.write                      ; Write F-Number low
        puls  a                                 ; Restore operator counter
        deca
        bne   @op_loop                          ; Continue for all operators
        bra   @exit
        ;
@normal_mode
        ; Normal mode: use standard F-Number setting
        ; This is handled by standard note processing
        ;
@exit   puls  d,y,u,pc                          ; Restore and return
        ;
; Operator register offsets for SE mode
@op_regs
        fcb   0,4,8,$0C                         ; OP1, OP2, OP3, OP4 offsets

;-------------------------------------------------------------------------------
; mub.apply.se.lfo.to.operators - Apply SE mode LFO to all 4 operators
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
; input REG : [D] LFO-modified F-Number in mub.newfnm
;-------------------------------------------------------------------------------
mub.apply.se.lfo.to.operators
        pshs  d,y,u                             ; Save registers
        ;
        ; Check if we're really in SE mode on channel 3
        lda   mub.ch.chnum,x                    ; Get channel number
        cmpa  #2                                ; Channel 3 (0-based = 2)
        bne   @not_se_mode                      ; Not channel 3
        ;
        lda   mub.se.mode.flag                  ; Get SE mode flag
        cmpa  #$78                              ; SE mode active?
        bne   @not_se_mode                      ; Not SE mode
        ;
        ; Apply LFO-modified F-Number to all 4 operators
        ldd   mub.newfnm                        ; Get LFO-modified F-Number
        ldy   #mub.detdat                       ; Point to detune data
        ldu   #@se_op_regs                      ; Point to operator register table
        lda   #4                                ; 4 operators
        ;
@op_loop
        pshs  a                                 ; Save operator counter
        ;
        ; Get detune value for this operator and apply LFO
        ldb   ,y+                               ; Get detune value in B
        sex                                     ; Sign extend B to A (D = signed detune)
        addd  mub.newfnm                        ; Add LFO-modified F-Number
        std   temp_fnum                        ; Store result safely
        ;
        ; Write F-Number high register for this operator
        ldb   ,u                                ; Get operator F-Number high register offset
        addb  #$A4                              ; F-Number high register base
        pshs  x                                 ; Save channel pointer
        lda   temp_fnum                        ; Get high byte of F-Number
        ; SE mode is always on channel 3, so always use port 1
        ldx   #1                                ; Port 1 for channel 3
        jsr   ym2608.write                      ; Write F-Number high
        ;
        ; Write F-Number low register for this operator
        ldb   ,u+                               ; Get operator F-Number low register offset
        addb  #$A0                              ; F-Number low register base
        lda   temp_fnum+1                      ; Get low byte of F-Number
        jsr   ym2608.write                      ; Write F-Number low
        ;
        puls  x                                 ; Restore channel pointer
        puls  a                                 ; Restore operator counter
        deca
        bne   @op_loop                          ; Continue for all operators
        ;
@not_se_mode
        puls  d,y,u,pc                          ; Restore and return
        ;
; SE mode operator register offsets (for F-Number registers)
@se_op_regs
        fcb   0,4,8,$0C                         ; OP1, OP2, OP3, OP4 offsets

temp_fnum
        fdb   0                                 ; Temporary F-Number storage
        
;===============================================================================
; SSG NOISE/ENVELOPE FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.ssg.set.noise - Set SSG noise/mix control
;-------------------------------------------------------------------------------
; input REG : [A] noise parameter
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.ssg.set.noise
        pshs  d,y                               ; Save registers
        ;
        sta   @noise_param                      ; Store noise parameter
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        subb  #6                                ; Convert to SSG channel (0-2)
        cmpb  #3                                ; Check valid SSG channel
        bhs   @exit                             ; Invalid channel
        ;
        ; Calculate noise control bits
        ; Original: mix register $07 controls tone/noise per channel
        lda   mub.pregbf+5                      ; Get current mix register value
        sta   @mix_temp                         ; Save current value
        ;
        ; Clear bits for this channel
        lda   #%01111011                        ; Mask pattern
        pshs  b                                 ; Save channel number
        clra                                    ; Clear A for 16-bit
        tfr   d,y                               ; Y = channel number (16-bit)
        puls  b                                 ; Restore channel number
        tstb                                    ; Test channel number
        beq   @apply_mask                       ; Channel 0, use as-is
@shift_mask
        lsla                                    ; Rotate mask left
        leay  -1,y                              ; Decrement counter
        bne   @shift_mask                       ; Continue shifting
        ;
@apply_mask
        anda  @mix_temp                         ; Clear old bits
        sta   @mix_temp                         ; Store masked value
        ;
        ; Apply new noise setting
        lda   @noise_param                      ; Get noise parameter
        pshs  b                                 ; Save channel number
        clra                                    ; Clear A for 16-bit
        tfr   d,y                               ; Y = channel number (16-bit)
        puls  b                                 ; Restore channel number
        tstb                                    ; Test channel number
        beq   @apply_noise                      ; Channel 0, use as-is
@shift_noise
        lsla                                    ; Rotate noise bits left
        leay  -1,y                              ; Decrement counter
        bne   @shift_noise                      ; Continue shifting
        ;
@apply_noise
        ora   @mix_temp                         ; Combine with mix register
        ;
        ; Write to YM2608 mix register
        tfr   a,b                               ; Value in B
        lda   #$07                              ; Mix register
        ldx   #0                                ; Port 0 for SSG
        jsr   ym2608.write                      ; Write to YM2608
        ;
        ; Update register buffer
        stb   mub.pregbf+5                      ; Store in buffer
        ;
@exit   puls  d,y,pc                            ; Restore and return
        ;
@noise_param fcb 0                             ; Noise parameter storage
@mix_temp    fcb 0                             ; Mix register temp storage

;-------------------------------------------------------------------------------
; mub.ssg.set.noise.params - Set SSG noise generator parameters
;-------------------------------------------------------------------------------
; input REG : [A] noise parameter (frequency)
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.ssg.set.noise.params
        pshs  d                                 ; Save registers
        ;
        ; NOISEW sets the noise generator frequency (register $06)
        pshs  a                                 ; Save noise parameter
        lda   #$06                              ; Noise frequency register
        puls  b                                 ; Noise parameter in B
        ldx   #0                                ; Port 0 for SSG
        jsr   ym2608.write                      ; Write to YM2608
        ;
        ; Update register buffer (PREGBF+4 in original)
        stb   mub.pregbf+4                      ; Store in buffer
        ;
        puls  d,pc                              ; Restore and return
        ;
; SE Mode flag storage
mub.se.mode.flag fcb 0                         ; SE mode flag ($78 when active)
        
;===============================================================================
; MUCOM88 ORIGINAL DATA TABLES
;===============================================================================
        ;
; FM Volume Data Table (20 bytes) - FMVDAT
mub.fmvdat
        fcb   $36,$33,$30,$2D,$2A,$28,$25,$22   ; Volume 0-7
        fcb   $20,$1D,$1A,$18,$15,$12,$10,$0D   ; Volume 8-15
        fcb   $0A,$08,$05,$02                   ; Volume 16-19
        ;
; Carry Data Table (8 bytes) - CRYDAT  
mub.crydat
        fcb   $08,$08,$08,$08,$0C,$0E,$0E,$0F   ; Algorithm carry data
        ;
; PMS/AMS/LR Data Table (7 bytes) - PALDAT
mub.paldat
        fcb   $C0,$C0,$C0,$00,$C0,$C0,$C0       ; PMS/AMS/LR default values
        ;
; Drum Volume Data Table (6 bytes) - DRMVOL
mub.drmvol
        fcb   $C0,$C0,$C0,$C0,$C0,$C0           ; Bass, Snare, Cymbal, Hi-hat, Tom, Rim
        ;
; F-Number Table (24 bytes) - FNUMB
mub.fnumb
        fdb   $026A,$028F,$02B6,$02DF,$030B,$0339   ; C, C#, D, D#, E, F
        fdb   $036A,$039E,$03D5,$0410,$044E,$048F   ; F#, G, G#, A, A#, B
        ;
; SSG F-Number Table (24 bytes) - SNUMB
mub.snumb
        fdb   $0E80E,$120E,$480D,$890C,$0D50B,$2B0B  ; SSG C-F
        fdb   $8A0A,$0F309,$6409,$0DD08,$5E08,$0E607 ; SSG F#-B
        ;
; SSG Envelope Data (16 envelopes * 6 bytes = 96 bytes) - SSGDAT
mub.ssgdat
        fcb   255,255,255,255,0,255             ; E0
        fcb   255,255,255,200,0,10             ; E1
        fcb   255,255,255,200,1,10             ; E2
        fcb   255,255,255,190,0,10             ; E3
        fcb   255,255,255,190,1,10             ; E4
        fcb   255,255,255,170,0,10             ; E5
        fcb   40,70,14,190,0,15                ; E6
        fcb   120,30,255,255,0,10              ; E7
        fcb   255,255,255,225,8,15             ; E8
        fcb   255,255,255,1,255,255            ; E9
        fcb   255,255,255,200,8,255            ; EA
        fcb   255,255,255,220,20,8             ; EB
        fcb   255,255,255,255,0,10             ; EC
        fcb   255,255,255,255,0,10             ; ED
        fcb   120,80,255,255,0,255             ; EE
        fcb   255,255,255,220,0,255            ; EF
        ;
; Additional MUCOM88 work variables
mub.notsb2               fcb   0                ; Not sub 2
mub.ready                fcb   1                ; Key on enable/disable (1=enabled)
mub.p_out                fcb   0                ; Port out
mub.m_vectr              fcb   0                ; Mode vector (32H or AAH)
mub.port13               fdb   0                ; Port 13 (44H or A8H)
mub.fdco                 fcb   0,0              ; FD counter (fade level, fade counter)
mub.keybuf               fcb   0                ; Key buffer
mub.fmport               fcb   0                ; FM port (0 or 4)
mub.fnum                 fdb   0                ; Current F-Number
mub.type1                fcb   $32,$44,$46      ; Type 1 data
mub.type2                fcb   $AA,$A8,$AC      ; Type 2 data
mub.rhythm               fcb   0                ; Rhythm flag
mub.newfnm               fdb   0                ; New F-Number work
mub.op_sel               fcb   $A6,$AC,$AD,$AE  ; Operator select (OP 4,3,1,2)
mub.chnum                fcb   0                ; Current channel number
mub.c2num                fcb   0                ; Channel 2 number
mub.tb_top               fdb   0                ; Table top
mub.timer_b              fcb   100              ; Timer B value
mub.totalv               fcb   0                ; Total volume (global fade)
mub.musicnum             fcb   0                ; Current music number
mub.t_flag               fcb   0                ; Time display flag
mub.wkleng               equ   38               ; Work area length (channel size)
        ;
; ADPCM Work Area
mub.pcmnmb               ; PCM number table (12 entries * 2 bytes)
        fdb   $49BA+200,$4E1C+200,$52C1+200,$57AD+200
        fdb   $5CE4+200,$626A+200,$6844+200,$6E77+200
        fdb   $7509+200,$7BFE+120,$835E+200,$8B2D+200
mub.sttadr               fdb   0                ; Start address
mub.endadr               fdb   0                ; End address  
mub.delt_n               fdb   0                ; Delta-N
mub.pcmnum               fcb   0                ; PCM number
        
;===============================================================================
; HARDWARE LFO FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.set.hardware.lfo - Set YM2608 hardware LFO
;-------------------------------------------------------------------------------
; input REG : [A] AMS (Amplitude Modulation Sensitivity)
; input STACK: [PMS] (Pitch Modulation Sensitivity) 
; input STACK: [FREQ] (Frequency control)
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.set.hardware.lfo
        pshs  d,y                               ; Save registers
        ;
        sta   @ams_value                        ; Store AMS
        lda   3,s                               ; Get PMS from stack
        sta   @pms_value                        ; Store PMS
        lda   4,s                               ; Get FREQ from stack
        ;
        ; Set LFO frequency control (Register $22)
        ora   #%00001000                        ; Enable LFO (bit 3)
        pshs  a                                 ; Save value
        lda   #$22                              ; LFO control register
        puls  b                                 ; Value in B
        ldx   #0                                ; Port 0 for LFO
        jsr   ym2608.write                      ; Write to YM2608
        ;
        ; Set PMS/AMS for the channel
        ldb   mub.ch.chnum+3,x                  ; Get channel number
        cmpb  #6                                ; Check if FM channel
        bhs   @exit                             ; Not FM channel
        ;
        ; Calculate PMS/AMS register (B4-B6 for channels 0-2, 1AC-1AE for channels 3-5)
        cmpb  #3                                ; Check which port
        blo   @port0                            ; Channels 0-2 use port 0
        ;
        ; Port 1 (channels 3-5)
        lda   #$B4                              ; Base register
        suba  #3                                ; Adjust for channels 3-5
        adda  mub.ch.chnum+3,x                  ; Add channel offset
        bra   @write_pms_ams
        ;
@port0  ; Port 0 (channels 0-2)
        lda   #$B4                              ; Base register  
        adda  mub.ch.chnum+3,x                  ; Add channel offset
        ;
@write_pms_ams
        tfr   a,b                               ; Register in B
        ;
        ; Combine PMS and AMS (PMS in bits 6-4, AMS in bits 1-0)
        lda   @pms_value                        ; Get PMS
        anda  #%00000111                        ; Mask to 3 bits
        lsla                                    ; Shift to bits 6-4
        lsla
        lsla
        lsla
        sta   @temp_value                       ; Store shifted PMS
        ;
        lda   @ams_value                        ; Get AMS
        anda  #%00000011                        ; Mask to 2 bits (bits 1-0)
        ora   @temp_value                       ; Combine with PMS
        ;
        jsr   ym2608.write                      ; Write PMS/AMS to YM2608
        ;
@exit   puls  d,y,pc                            ; Restore and return
        ;
@ams_value   fcb 0                             ; AMS storage
@pms_value   fcb 0                             ; PMS storage  
@temp_value  fcb 0                             ; Temporary value
        
;===============================================================================
; SSG ENVELOPE FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.ssg.set.envelope - Set SSG hardware envelope
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
; input REG : [U] data stream pointer (pointing to 6 envelope parameters)
;-------------------------------------------------------------------------------
mub.ssg.set.envelope
        pshs  d,y,u                             ; Save registers
        ;
        ; SSG envelope uses 6 parameters from data stream
        ; Based on original MUCOM88 ENVPST implementation
        ;
        ; Copy 6 envelope parameters to channel structure (offset +12 in original)
        leay  mub.ch.lfo_delay,x                ; Use LFO area for envelope storage
        lda   #6                                ; 6 parameters
        ;
@copy_loop
        ldb   ,u+                               ; Read parameter
        stb   ,y+                               ; Store in channel structure
        deca
        bne   @copy_loop                        ; Continue for all parameters
        ;
        ; Update data pointer
        stu   mub.ch.wadr,x                     ; Store updated pointer
        ;
        ; Set envelope active flag (original: OR 10010000B with volume)
        lda   mub.ch.volume+3,x                 ; Get current volume
        ora   #%10010000                        ; Set envelope enable flags
        sta   mub.ch.volume+3,x                 ; Store back
        ;
        ; Configure YM2608 envelope registers
        ; Register $0B = Envelope period low
        ; Register $0C = Envelope period high  
        ; Register $0D = Envelope shape
        ;
        ; Set envelope period (from parameters 0,1)
        ldb   mub.ch.lfo_delay,x                ; Get period low
        pshs  x                                 ; Save channel pointer
        lda   #$0B                              ; Envelope period low register
        ldx   #0                                ; Port 0 for SSG
        jsr   ym2608.write                      ; Write to YM2608
        ;
        puls  x                                 ; Restore channel pointer
        ldb   mub.ch.lfo_delay+1,x              ; Get period high
        pshs  x                                 ; Save channel pointer
        lda   #$0C                              ; Envelope period high register
        ldx   #0                                ; Port 0 for SSG
        jsr   ym2608.write                      ; Write to YM2608
        ;
        ; Set envelope shape (from parameter 2)
        puls  x                                 ; Restore channel pointer
        ldb   mub.ch.lfo_delay+2,x              ; Get envelope shape
        lda   #$0D                              ; Envelope shape register
        ldx   #0                                ; Port 0 for SSG
        jsr   ym2608.write                      ; Write to YM2608
        ;
        puls  d,y,u,pc                          ; Restore and return
        
;===============================================================================
; EXTENDED COMMANDS (FF xx) FUNCTIONS
;===============================================================================

;-------------------------------------------------------------------------------
; mub.process.extended.commands - Process extended commands (FF xx)
;-------------------------------------------------------------------------------
; input REG : [A] sub-command (F0-F5)
; input REG : [X] channel data pointer
; input REG : [U] data stream pointer
;-------------------------------------------------------------------------------
mub.process.extended.commands
        pshs  d                                 ; Save registers
        ;
        ; Dispatch extended commands
        suba  #$F0                              ; Convert to 0-based (F0->0)
        cmpa  #7                                ; Check range (0-6)
        bhs   @unknown                          ; Invalid command
        lsla                                    ; A = A * 2 (2 bytes per address)
        ldy   #@ext_table                       ; Load table address
        jmp   [a,y]                             ; Direct jump using table offset
        ;
@ext_table
        fdb   @pcm_volume_mode                  ; FFF0 - PCM volume mode
        fdb   @hard_envelope                    ; FFF1 - Hard envelope 's'
        fdb   @envelope_period                  ; FFF2 - Hard envelope period
        fdb   @reverb                           ; FFF3 - Reverb
        fdb   @reverb_mode                      ; FFF4 - Reverb mode
        fdb   @reverb_switch                    ; FFF5 - Reverb switch
        fdb   @soft_envelope                    ; FFF6 - Soft envelope
        ;
@unknown
        puls  d,pc                              ; Unknown command
        ;
@pcm_volume_mode ; FFF0 - PCM volume mode
        lda   ,u+                               ; Read PCM volume mode
        stu   mub.ch.wadr,x                     ; Update pointer
        sta   mub.pvmode                        ; Store PCM volume mode
        puls  d,pc                              ; Return
        ;
@hard_envelope ; FFF1 - Hard envelope 's'
        lda   ,u+                               ; Read envelope parameter
        stu   mub.ch.wadr,x                     ; Update pointer
        ; Hard envelope implementation deliberately incomplete
        ; This feature was removed in MUCOM88 Ver1.7 due to technical issues
        ; See HARD_ENVELOPE_ANALYSIS.md for details
        puls  d,pc                              ; Return
        ;
@envelope_period ; FFF2 - Hard envelope period
        lda   ,u+                               ; Read envelope period
        stu   mub.ch.wadr,x                     ; Update pointer
        ; Envelope period implementation deliberately incomplete
        ; This feature was removed in MUCOM88 Ver1.7 due to technical issues
        ; See HARD_ENVELOPE_ANALYSIS.md for details
        puls  d,pc                              ; Return
        ;
@reverb ; FFF3 - Reverb
        lda   ,u+                               ; Read reverb parameter
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.set.reverb                    ; Set reverb
        puls  d,pc                              ; Return
        ;
@reverb_mode ; FFF4 - Reverb mode
        lda   ,u+                               ; Read reverb mode
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.set.reverb.mode               ; Set reverb mode
        puls  d,pc                              ; Return
        ;
@reverb_switch ; FFF5 - Reverb switch
        lda   ,u+                               ; Read reverb switch
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.set.reverb.switch             ; Set reverb switch
        puls  d,pc                              ; Return
        ;
@soft_envelope ; FFF6 - Soft envelope
        lda   ,u+                               ; Read envelope number
        stu   mub.ch.wadr,x                     ; Update pointer
        jsr   mub.init.soft.envelope            ; Initialize soft envelope
        puls  d,pc           

;-------------------------------------------------------------------------------
; mub.set.reverb - Set reverb parameters
;-------------------------------------------------------------------------------
; input REG : [A] reverb parameter
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.set.reverb
        ; Store reverb parameter in channel (original: IX+17)
        sta   mub.ch.lfo_delay+3,x              ; Use unused LFO area
        ;
        ; Set reverb flag (bit 5 of IX+33 in original)
        lda   mub.ch.flags2,x                   ; Get extended flags (IX+33)
        ora   #%00100000                        ; Set reverb flag (bit 5)
        sta   mub.ch.flags2,x                   ; Store back
        ;
        rts

;-------------------------------------------------------------------------------
; mub.set.reverb.mode - Set reverb mode
;-------------------------------------------------------------------------------
; input REG : [A] reverb mode (0=off, 1=on)
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.set.reverb.mode
        tsta                                    ; Check mode
        bne   @enable_mode                      ; Non-zero = enable
        ;
        ; Disable reverb mode (bit 4 of IX+33)
        lda   mub.ch.flags2,x                   ; Get extended flags (IX+33)
        anda  #%11101111                        ; Clear reverb mode flag (bit 4)
        sta   mub.ch.flags2,x                   ; Store back
        rts
        ;
@enable_mode
        ; Enable reverb mode
        lda   mub.ch.flags2,x                   ; Get extended flags (IX+33)
        ora   #%00010000                        ; Set reverb mode flag (bit 4)
        sta   mub.ch.flags2,x                   ; Store back
        rts

;-------------------------------------------------------------------------------
; mub.set.reverb.switch - Set reverb switch
;-------------------------------------------------------------------------------
; input REG : [A] reverb switch (0=off, 1=on)
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.set.reverb.switch
        tsta                                    ; Check switch
        bne   @enable_reverb                    ; Non-zero = enable
        ;
        ; Disable reverb (bit 5 of IX+33)
        lda   mub.ch.flags2,x                   ; Get extended flags (IX+33)
        anda  #%11011111                        ; Clear reverb flag (bit 5)
        sta   mub.ch.flags2,x                   ; Store back
        jsr   mub.apply.volume                  ; Update volume (original calls STVOL)
        rts
        ;
@enable_reverb
        ; Enable reverb
        lda   mub.ch.flags2,x                   ; Get extended flags (IX+33)
        ora   #%00100000                        ; Set reverb flag (bit 5)
        sta   mub.ch.flags2,x                   ; Store back
        rts
        
;===============================================================================
; SOFT ENVELOPE SYSTEM (MUCOM88 SOFENV)
;===============================================================================

;-------------------------------------------------------------------------------
; mub.soft.envelope - Process software envelope for a channel
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
; output REG : [A] calculated volume level
; Processes Attack, Decay, Sustain, Release states
; Based on MUCOM88 SOFENV function
;-------------------------------------------------------------------------------
mub.soft.envelope
        pshs  b,d,y                             ; Save registers
        ;
        ; Check if soft envelope is active (bit 7 of IX+6)
        ldb   mub.ch.volume,x                   ; Get volume data
        bitb  #%10000000                        ; Test soft envelope flag
        beq   @no_envelope                      ; Not active
        ;
        ; Process envelope states based on flags in volume register
        ; bit 4 = attack flag, bit 5 = decay flag, bit 6 = sustain flag
        ;
        bitb  #%00010000                        ; Check attack flag (bit 4)
        bne   @attack_state                     ; In attack state
        ;
        bitb  #%00100000                        ; Check decay flag (bit 5)  
        bne   @decay_state                      ; In decay state
        ;
        bitb  #%01000000                        ; Check sustain flag (bit 6)
        bne   @sustain_state                    ; In sustain state
        ;
        ; Default: Release state
        bra   @release_state
        ;
@no_envelope
        ; No envelope active - return current volume
        lda   mub.ch.volume,x                   ; Get volume
        anda  #%00001111                        ; Mask to volume only
        puls  b,d,y,pc                          ; Return
        ;
@attack_state
        ; ATTACK: Increase envelope counter until 0xFF
        lda   mub.ch.work11,x                   ; Get envelope counter
        ldb   mub.ch.soft_env,x                 ; Get attack rate (IX+13)
        pshs  cc                                ; Save carry
        pshs  b                                 ; Save B on stack
        adda  ,s+                               ; Add attack rate
        puls  cc                                ; Restore carry
        bcc   @attack_continue                  ; No overflow
        lda   #$FF                              ; Clamp to maximum
        ;
@attack_continue
        cmpa  #$FF                              ; Check if reached maximum
        sta   mub.ch.work11,x                   ; Store envelope counter
        bne   @calc_volume                      ; Not at max, continue
        ;
        ; Transition to DECAY state
        lda   mub.ch.volume,x                   ; Get volume flags
        eora  #%00110000                        ; Toggle attack/decay flags
        sta   mub.ch.volume,x                   ; Store back - TO STATE 2 (DECAY)
        bra   @calc_volume
        ;
@decay_state
        ; DECAY: Decrease envelope counter to sustain level
        lda   mub.ch.work11,x                   ; Get envelope counter
        ldb   mub.ch.soft_env+1,x               ; Get decay rate (IX+14)
        ldy   #0                                ; Clear Y for sustain level
        ldy   mub.ch.soft_env+2,x               ; Get sustain level (IX+15)
        ;
        pshs  b                                 ; Save B on stack
        suba  ,s+                               ; A = A - B (subtract decay rate)
        bcs   @decay_clamp                      ; Underflow
        cmpa  mub.ch.soft_env+2,x               ; Compare with sustain level
        bhs   @decay_continue                   ; Still above sustain
        ;
@decay_clamp
        lda   mub.ch.soft_env+2,x               ; Clamp to sustain level
        ;
@decay_continue
        cmpa  mub.ch.soft_env+2,x               ; Check if reached sustain
        sta   mub.ch.work11,x                   ; Store envelope counter
        bne   @calc_volume                      ; Not at sustain, continue
        ;
        ; Transition to SUSTAIN state
        lda   mub.ch.volume,x                   ; Get volume flags
        eora  #%01100000                        ; Toggle decay/sustain flags
        sta   mub.ch.volume,x                   ; Store back - TO STATE 3 (SUSTAIN)
        bra   @calc_volume
        ;
@sustain_state
        ; SUSTAIN: Slowly decrease from sustain level
        lda   mub.ch.work11,x                   ; Get envelope counter
        ldb   mub.ch.soft_env+3,x               ; Get sustain rate (IX+16)
        pshs  b                                 ; Save B on stack
        suba  ,s+                               ; A = A - B (subtract sustain rate)
        bcc   @sustain_continue                 ; No underflow
        clra                                    ; Clamp to zero
        ;
@sustain_continue
        tsta                                    ; Check if zero
        sta   mub.ch.work11,x                   ; Store envelope counter
        bne   @calc_volume                      ; Not zero, continue
        ;
        ; End of envelope
        lda   mub.ch.volume,x                   ; Get volume flags
        anda  #%10001111                        ; Clear envelope state flags
        sta   mub.ch.volume,x                   ; Store back - END OF ENVELOPE
        bra   @calc_volume
        ;
@release_state
        ; RELEASE: Decrease envelope counter to zero
        lda   mub.ch.work11,x                   ; Get envelope counter
        ldb   mub.ch.soft_env+4,x               ; Get release rate (IX+17)
        pshs  b                                 ; Save B on stack
        suba  ,s+                               ; A = A - B (subtract release rate)
        bcc   @release_continue                 ; No underflow
        clra                                    ; Clamp to zero
        ;
@release_continue
        sta   mub.ch.work11,x                   ; Store envelope counter
        ; Fall through to volume calculation
        ;
@calc_volume
        ; Calculate final volume: envelope_level * volume / 16
        ; Based on MUCOM88 SOFEV7 function
        pshs  x                                 ; Save channel pointer
        ;
        lda   mub.ch.work11,x                   ; Get envelope level (E register in original)
        ldb   #0                                ; D = 0
        tfr   d,y                               ; Y = envelope level (16-bit)
        ;
        ldd   #0                                ; HL = 0 in original
        ldb   mub.ch.volume,x                   ; Get volume
        andb  #%00001111                        ; Mask to volume only
        incb                                    ; +1 (original INC A)
        ;
        ; Multiply: HL += DE * B times
@mult_loop
        leay  d,y                               ; HL += DE
        decb                                    ; DJNZ equivalent
        bne   @mult_loop
        ;
        tfr   y,d                               ; Get result
        tfr   b,a                               ; A = H (high byte)
        ;
        puls  x                                 ; Restore channel pointer
        ;
        ; Check additional envelope flags (reverb processing)
        ldb   mub.ch.flags1,x                   ; Get main flags (IX+31)
        bitb  #%01000000                        ; Check bit 6 (KEYOFF FLAG)
        bne   @envelope_done                    ; Key off - return as is
        ;
        ldb   mub.ch.flags2,x                   ; Get extended flags (IX+33)
        bitb  #%00100000                        ; Check bit 5 (REVERB FLAG)
        beq   @envelope_done                    ; No reverb - return as is
        ;
        ; Apply reverb processing (original adds IX+17 and shifts right)
        adda  mub.ch.reverb_param,x             ; Add reverb parameter
        lsra                                    ; Shift right (SRL A)
        ;
@envelope_done
        puls  b,d,y,pc                          ; Return with volume in A

;-------------------------------------------------------------------------------
; mub.init.soft.envelope - Initialize soft envelope for a channel
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
; input REG : [A] envelope number (0-15)
;-------------------------------------------------------------------------------
mub.init.soft.envelope
        pshs  b,d,y                             ; Save registers
        ;
        ; Calculate envelope data address: SSGDAT + (envelope_num * 6)
        ldb   #6                                ; 6 bytes per envelope
        mul                                     ; D = envelope_num * 6
        leay  mub.ssgdat,pcr                    ; Base address
        leay  d,y                               ; Y = envelope data address
        ;
        ; Copy 5 envelope parameters to channel (IX+13-17)
        lda   ,y+                               ; Attack rate
        sta   mub.ch.soft_env,x
        lda   ,y+                               ; Decay rate
        sta   mub.ch.soft_env+1,x
        lda   ,y+                               ; Sustain level
        sta   mub.ch.soft_env+2,x
        lda   ,y+                               ; Sustain rate
        sta   mub.ch.soft_env+3,x
        lda   ,y+                               ; Release rate
        sta   mub.ch.soft_env+4,x
        ;
        ; Initialize envelope counter
        clr   mub.ch.work11,x                   ; Clear envelope counter (IX+11)
        ;
        ; Set soft envelope active and start in ATTACK state
        lda   mub.ch.volume,x                   ; Get current volume
        ora   #%10010000                        ; Set envelope flag + attack flag
        anda  #%10011111                        ; Clear decay/sustain flags
        sta   mub.ch.volume,x                   ; Store back
        ;
        puls  b,d,y,pc                          ; Return

;-------------------------------------------------------------------------------
; mub.stop.soft.envelope - Stop soft envelope for a channel
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.stop.soft.envelope
        lda   mub.ch.volume,x                   ; Get current volume
        anda  #%01101111                        ; Clear soft envelope flag (bit 7)
        sta   mub.ch.volume,x                   ; Store back
        rts
        
;===============================================================================
; SYSTÈME DE CONTRÔLE MUCOM88 (MSTART/MSTOP/AKYOFF/SSGOFF)
;===============================================================================

;-------------------------------------------------------------------------------
; mub.mstart - Start music with complete system initialization
;-------------------------------------------------------------------------------
; input REG : [A] music number
; Based on MUCOM88 MSTART function
;-------------------------------------------------------------------------------
mub.mstart
        pshs  a,b,d,x,y                         ; Save registers
        ;
        ; Store music number
        sta   mub.musicnum                       ; Store current music number
        ;
        ; All key off and sound off
        jsr   mub.all.key.off                   ; AKYOFF equivalent
        jsr   mub.ssg.all.off                   ; SSGOFF equivalent
        ;
        ; Initialize work areas
        jsr   mub.work.init                     ; WORKINIT equivalent
        ;
        ; Hardware check and setup (simplified for 6809)
        jsr   mub.hardware.check                ; CHK equivalent
        ;
        ; Enable system (timer setup)
        jsr   mub.system.enable                 ; ENBL equivalent
        ;
        ; Set to normal mode
        jsr   mub.to.normal.mode                ; TO_NML equivalent
        ;
        puls  a,b,d,x,y,pc                      ; Restore and return

;-------------------------------------------------------------------------------
; mub.mstop - Stop music with complete system shutdown
;-------------------------------------------------------------------------------
; Based on MUCOM88 MSTOP function
;-------------------------------------------------------------------------------
mub.mstop
        pshs  a,b,d,x,y                         ; Save registers
        ;
        ; All key off and sound off
        jsr   mub.all.key.off                   ; AKYOFF equivalent
        jsr   mub.ssg.all.off                   ; SSGOFF equivalent
        ;
        ; Disable timer (hardware specific)
        lda   #$27                              ; Timer control register
        ldb   #$00                              ; Disable all timers
        ldx   #0                                ; Port 0
        jsr   ym2608.write                      ; Disable YM2608 timer
        ;
        puls  a,b,d,x,y,pc                      ; Restore and return

;-------------------------------------------------------------------------------
; mub.all.key.off - Turn off all FM keys (MUCOM88 AKYOFF)
;-------------------------------------------------------------------------------
mub.all.key.off
        pshs  a,b,d                             ; Save registers
        ;
        ; Turn off all FM channels (0-6)
        ldb   #0                                ; Start with channel 0
        lda   #7                                ; 7 channels (0-6)
        ;
@loop   pshs  a,b                               ; Save counters
        pshs  b                                 ; Save channel number
        lda   #$28                              ; Key on/off register
        puls  b                                 ; Channel in B (value)
        ldx   #0                                ; Port 0 for key control
        jsr   ym2608.write                      ; Send key off
        puls  a,b                               ; Restore counters
        ;
        incb                                    ; Next channel
        deca
        bne   @loop                             ; Continue for all channels
        ;
        puls  a,b,d,pc                          ; Restore and return

;-------------------------------------------------------------------------------
; mub.ssg.all.off - Turn off all SSG channels (MUCOM88 SSGOFF)
;-------------------------------------------------------------------------------
mub.ssg.all.off
        pshs  a,b,d                             ; Save registers
        ;
        ; Turn off SSG channels A, B, C (registers $08, $09, $0A)
        ldb   #$08                              ; Start with volume A
        lda   #3                                ; 3 SSG channels
        ;
@loop   pshs  a,b                               ; Save counters
        tfr   b,a                               ; Register in A
        ldb   #0                                ; Volume = 0
        ldx   #0                                ; Port 0 for SSG
        jsr   ym2608.write                      ; Send volume off
        puls  a,b                               ; Restore counters
        ;
        incb                                    ; Next register
        deca
        bne   @loop                             ; Continue for all SSG channels
        ;
        puls  a,b,d,pc                          ; Restore and return

;-------------------------------------------------------------------------------
; mub.work.init - Initialize all work areas (MUCOM88 WORKINIT)
;-------------------------------------------------------------------------------
mub.work.init
        pshs  a,b,d,x,y                         ; Save registers
        ;
        ; Clear control variables
        clr   mub.c2num                         ; Clear channel 2 number
        clr   mub.chnum                         ; Clear current channel
        clr   mub.pvmode                        ; Clear PCM volume mode
        ;
        ; Initialize all FM channels
        ldx   #mub.channels                     ; Point to channel data
        lda   #mub.MAX_CHANNELS                 ; Number of channels
        ;
@init_loop
        pshs  a                                 ; Save counter
        jsr   mub.fm.init                       ; Initialize this channel
        leax  mub.CHANNEL_SIZE_EXT,x            ; Next channel
        puls  a                                 ; Restore counter
        deca
        bne   @init_loop                        ; Continue for all channels
        ;
        puls  a,b,d,x,y,pc                      ; Restore and return

;-------------------------------------------------------------------------------
; mub.fm.init - Initialize single channel (MUCOM88 FMINIT)
;-------------------------------------------------------------------------------
; input REG : [X] channel data pointer
;-------------------------------------------------------------------------------
mub.fm.init
        pshs  a,b,d,y                           ; Save registers
        ;
        ; Clear entire channel data area
        ldy   #mub.CHANNEL_SIZE_EXT             ; Size to clear
        ldd   #0                                ; Clear value
        ;
@clear  std   ,x++                              ; Clear 2 bytes and advance
        leay  -2,y                              ; Decrement counter
        bne   @clear                            ; Continue until done
        ;
        ; Reset X to start of channel
        leax  -mub.CHANNEL_SIZE_EXT,x           ; Back to start
        ;
        ; Set default values
        lda   #1                                ; Default length counter
        sta   mub.ch.length,x                   ; Set length
        clr   mub.ch.volume,x                   ; Clear volume
        ;
        puls  a,b,d,y,pc                        ; Restore and return

;-------------------------------------------------------------------------------
; mub.hardware.check - Hardware check and setup (MUCOM88 CHK)
;-------------------------------------------------------------------------------
mub.hardware.check
        pshs  a,b,d,x,y                         ; Save registers
        ;
        ; Clear status
        clr   mub.notsb2                        ; Clear not sub 2
        ;
        ; Setup hardware type (simplified for 6809)
        ; Copy type data to work variables
        ldy   #mub.type1                        ; Source
        ldx   #mub.m_vectr                      ; Destination
        lda   #3                                ; 3 bytes
        ;
@copy   ldb   ,y+                               ; Get byte
        stb   ,x+                               ; Store byte
        deca
        bne   @copy                             ; Continue
        ;
        puls  a,b,d,x,y,pc                      ; Restore and return

;-------------------------------------------------------------------------------
; mub.system.enable - Enable system timer (MUCOM88 ENBL)
;-------------------------------------------------------------------------------
mub.system.enable
        pshs  a,b,d                             ; Save registers
        ;
        ; Set Timer B value
        ldb   mub.timer_b                       ; Get timer value
        lda   #$26                              ; Timer B register
        ldx   #0                                ; Port 0 for timer
        jsr   ym2608.write                      ; Set timer value
        ;
        ; Enable timer (simplified)
        lda   #$27                              ; Timer control register
        ldb   #$3A                              ; Timer on value
        jsr   ym2608.write                      ; Enable timer
        ;
        puls  a,b,d,pc                          ; Restore and return

;-------------------------------------------------------------------------------
; mub.to.normal.mode - Set to normal mode (MUCOM88 TO_NML)
;-------------------------------------------------------------------------------
mub.to.normal.mode
        ; Set system to normal operating mode
        ; (Implementation depends on target system)
        rts

;===============================================================================
; SYSTÈME DE FADEOUT ET VOLUME GLOBAL (FDOUT/TOTALV)
;===============================================================================

;-------------------------------------------------------------------------------
; mub.fadeout - Process automatic fadeout (MUCOM88 FDOUT)
;-------------------------------------------------------------------------------
mub.fadeout
        pshs  a,b,d,x                           ; Save registers
        ;
        ; Check fade counter
        lda   mub.fdco+1                        ; Get fade counter
        deca                                    ; Decrement
        sta   mub.fdco+1                        ; Store back
        bne   @fade_done                        ; Not time yet
        ;
        ; Reset fade counter
        lda   #16                               ; Reset value
        sta   mub.fdco+1                        ; Store counter
        ;
        ; Check fade level
        lda   mub.fdco                          ; Get fade level
        tsta                                    ; Check if zero
        beq   @fade_done                        ; Fade complete
        ;
        ; Decrease fade level
        deca                                    ; Decrease fade
        sta   mub.fdco                          ; Store back
        ;
        ; Calculate total volume
        adda  #$F0                              ; Add offset (original logic)
        sta   mub.totalv                        ; Set global volume
        ;
        ; Apply fade to all active channels
        jsr   mub.apply.fade.to.all             ; Apply to all channels
        ;
@fade_done
        puls  a,b,d,x,pc                        ; Restore and return

;-------------------------------------------------------------------------------
; mub.apply.fade.to.all - Apply fade to all channels
;-------------------------------------------------------------------------------
mub.apply.fade.to.all
        pshs  a,b,x                             ; Save registers
        ;
        ; Process all channels
        ldx   #mub.channels                     ; Start of channels
        lda   #mub.MAX_CHANNELS                 ; Number of channels
        ;
@loop   pshs  a                                 ; Save counter
        ;
        ; Check if channel is active
        ldb   mub.ch.length+3,x                 ; Get status
        bitb  #mub.CH_ACTIVE                    ; Test active bit
        beq   @next                             ; Skip if inactive
        ;
        ; Apply current volume with fade
        jsr   mub.apply.volume                  ; Apply volume (includes fade)
        ;
@next   leax  mub.CHANNEL_SIZE_EXT,x            ; Next channel
        puls  a                                 ; Restore counter
        deca
        bne   @loop                             ; Continue for all channels
        ;
        puls  a,b,x,pc                          ; Restore and return

;-------------------------------------------------------------------------------
; mub.start.fadeout - Start fadeout process
;-------------------------------------------------------------------------------
; input REG : [A] fade speed (0=stop, 1-255=fade levels)
;-------------------------------------------------------------------------------
mub.start.fadeout
        sta   mub.fdco                          ; Set fade level
        lda   #16                               ; Default counter
        sta   mub.fdco+1                        ; Set fade counter
        rts

;-------------------------------------------------------------------------------
; mub.stop.fadeout - Stop fadeout and restore full volume
;-------------------------------------------------------------------------------
mub.stop.fadeout
        clr   mub.fdco                          ; Clear fade level
        clr   mub.fdco+1                        ; Clear fade counter
        clr   mub.totalv                        ; Reset total volume
        rts

 ENDSECTION
