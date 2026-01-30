;*******************************************************************************
; MUCOM88 MUB Player Macros
; ------------------------------------------------------------------------------
; Convenient macros for using the MUB player in games
; Following the engine's macro naming convention with underscore prefix
;*******************************************************************************

engine.sound.mub.macro.asm equ 1

;-------------------------------------------------------------------------------
; _mub.obj.play - Play MUB music with object management
;-------------------------------------------------------------------------------
; param 1: Memory page of MUB data
; param 2: MUB data address
; param 3: Loop flag (mub.LOOP or mub.NO_LOOP)
; param 4: Callback routine address (or mub.NO_CALLBACK)
;
; Usage: _mub.obj.play #5, #music_data, #mub.LOOP, #music_end_callback
;-------------------------------------------------------------------------------
_mub.obj.play MACRO
        _ram.cart.set \1                       ; Set memory page (uses register A)
        ldx   \2                               ; MUB data address
        ldb   \3                               ; Loop flag
        ldy   \4                               ; Callback routine
        jsr   mub.obj.play
 ENDM

;-------------------------------------------------------------------------------
; _mub.play - Simple MUB music playback
;-------------------------------------------------------------------------------
; param 1: Memory page of MUB data  
; param 2: MUB data address
; param 3: Loop flag (mub.LOOP or mub.NO_LOOP)
; param 4: Callback routine address (or mub.NO_CALLBACK)
;
; Usage: _mub.play #5, #music_data, #mub.LOOP, #mub.NO_CALLBACK
;-------------------------------------------------------------------------------
_mub.play MACRO
        lda   \1                               ; Memory page
        ldx   \2                               ; MUB data address
        ldb   \3                               ; Loop flag
        ldy   \4                               ; Callback routine
        jsr   mub.play
 ENDM

;-------------------------------------------------------------------------------
; _mub.frame.play - Process one frame of MUB playback
;-------------------------------------------------------------------------------
; Should be called every frame (1/60s NTSC or 1/50s PAL)
; No parameters required
;
; Usage: _mub.frame.play
;-------------------------------------------------------------------------------
_mub.frame.play MACRO
        jsr   mub.frame.play
 ENDM

;-------------------------------------------------------------------------------
; _mub.stop - Stop MUB playback
;-------------------------------------------------------------------------------
; No parameters required
;
; Usage: _mub.stop
;-------------------------------------------------------------------------------
_mub.stop MACRO
        jsr   mub.stop
 ENDM

;-------------------------------------------------------------------------------
; _mub.pause - Pause MUB playback
;-------------------------------------------------------------------------------
; No parameters required
;
; Usage: _mub.pause
;-------------------------------------------------------------------------------
_mub.pause MACRO
        jsr   mub.pause
 ENDM

;-------------------------------------------------------------------------------
; _mub.resume - Resume MUB playback
;-------------------------------------------------------------------------------
; No parameters required
;
; Usage: _mub.resume
;-------------------------------------------------------------------------------
_mub.resume MACRO
        jsr   mub.resume
 ENDM

;-------------------------------------------------------------------------------
; _ym2608.init - Initialize YM2608 sound chip
;-------------------------------------------------------------------------------
; No parameters required
;
; Usage: _ym2608.init
;-------------------------------------------------------------------------------
_ym2608.init MACRO
        jsr   ym2608.init
 ENDM

;-------------------------------------------------------------------------------
; _ym2608.write - Write to YM2608 register
;-------------------------------------------------------------------------------
; param 1: Register number
; param 2: Data value
; param 3: Port number (0 or 1)
;
; Usage: _ym2608.write #$22, #$08, #0
;-------------------------------------------------------------------------------
_ym2608.write MACRO
        lda   \1                               ; Register number
        ldb   \2                               ; Data value
        ldx   \3                               ; Port number
        jsr   ym2608.write
 ENDM

;-------------------------------------------------------------------------------
; _ym2608.note.on - Turn on note for FM channel
;-------------------------------------------------------------------------------
; param 1: Note number (0-127)
; param 2: Channel number (0-5)
;
; Usage: _ym2608.note.on #60, #0  ; Middle C on channel 0
;-------------------------------------------------------------------------------
_ym2608.note.on MACRO
        lda   \1                               ; Note number
        ldb   \2                               ; Channel number
        jsr   ym2608.note.on
 ENDM

;-------------------------------------------------------------------------------
; _ym2608.note.off - Turn off note for FM channel
;-------------------------------------------------------------------------------
; param 1: Channel number (0-5)
;
; Usage: _ym2608.note.off #0  ; Turn off channel 0
;-------------------------------------------------------------------------------
_ym2608.note.off MACRO
        ldb   \1                               ; Channel number
        jsr   ym2608.note.off
 ENDM

;-------------------------------------------------------------------------------
; _ym2608.set.volume - Set volume for channel
;-------------------------------------------------------------------------------
; param 1: Volume (0-127)
; param 2: Channel number
;
; Usage: _ym2608.set.volume #100, #0  ; Set channel 0 volume to 100
;-------------------------------------------------------------------------------
_ym2608.set.volume MACRO
        lda   \1                               ; Volume
        ldb   \2                               ; Channel number
        jsr   ym2608.set.volume
 ENDM

;-------------------------------------------------------------------------------
; _ym2608.silence - Silence all channels
;-------------------------------------------------------------------------------
; No parameters required
;
; Usage: _ym2608.silence
;-------------------------------------------------------------------------------
_ym2608.silence MACRO
        jsr   ym2608.silence
 ENDM

;-------------------------------------------------------------------------------
; Conditional compilation macros for different sound chip configurations
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; _mub.init.check - Check if MUB player is available
;-------------------------------------------------------------------------------
; Sets condition codes based on availability
;
; Usage: 
;   _mub.init.check
;   bne   no_mub_support
;-------------------------------------------------------------------------------
_mub.init.check MACRO
 IFDEF engine.sound.mub.asm
        lda   #1                               ; MUB support available
 ELSE
        lda   #0                               ; No MUB support
 ENDC
        tsta                                   ; Set condition codes
 ENDM

;-------------------------------------------------------------------------------
; _mub.play.safe - Safe MUB playback with error checking
;-------------------------------------------------------------------------------
; param 1: Memory page of MUB data
; param 2: MUB data address  
; param 3: Loop flag
; param 4: Callback routine address
; param 5: Error handler address (optional)
;
; Usage: _mub.play.safe #5, #music_data, #mub.LOOP, #mub.NO_CALLBACK, #error_handler
;-------------------------------------------------------------------------------
_mub.play.safe MACRO
 IFDEF engine.sound.mub.asm
        _mub.init.check
        beq   @no_mub_support\@
        _mub.play \1, \2, \3, \4
        bra   @done\@
@no_mub_support\@
 IFNE \5-0                                     ; If error handler provided
        jsr   \5
 ENDC
@done\@
 ELSE
 IFNE \5-0                                     ; If error handler provided
        jsr   \5
 ENDC
 ENDC
 ENDM

;-------------------------------------------------------------------------------
; Utility macros for common operations
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; _mub.play.bgm - Play background music
;-------------------------------------------------------------------------------
; Simplified macro for typical BGM usage
; param 1: Music data address
;
; Usage: _mub.play.bgm #level1_music
;-------------------------------------------------------------------------------
_mub.play.bgm MACRO
        _mub.play #5, \1, #mub.LOOP, #mub.NO_CALLBACK
 ENDM

;-------------------------------------------------------------------------------
; _mub.play.jingle - Play short jingle (no loop)
;-------------------------------------------------------------------------------
; Simplified macro for jingles and sound effects
; param 1: Music data address
; param 2: Callback routine (called when finished)
;
; Usage: _mub.play.jingle #victory_jingle, #jingle_finished
;-------------------------------------------------------------------------------
_mub.play.jingle MACRO
        _mub.play #5, \1, #mub.NO_LOOP, \2
 ENDM

;-------------------------------------------------------------------------------
; _mub.get.status - Get player status
;-------------------------------------------------------------------------------
; No parameters required
; Returns status in A register
;
; Usage: _mub.get.status
;-------------------------------------------------------------------------------
_mub.get.status MACRO
        jsr   mub.get.status
 ENDM

;-------------------------------------------------------------------------------
; _mub.set.tempo - Set playback tempo
;-------------------------------------------------------------------------------
; param 1: New tempo value
;
; Usage: _mub.set.tempo #140
;-------------------------------------------------------------------------------
_mub.set.tempo MACRO
        lda   \1
        jsr   mub.set.tempo
 ENDM

;-------------------------------------------------------------------------------
; _mub.fade.out - Start fade out
;-------------------------------------------------------------------------------
; param 1: Fade speed (frames per step)
;
; Usage: _mub.fade.out #16
;-------------------------------------------------------------------------------
_mub.fade.out MACRO
        lda   \1
        jsr   mub.fade.out
 ENDM

;-------------------------------------------------------------------------------
; SSG-specific macros
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; _ym2608.ssg.note.on - Play note on SSG channel
;-------------------------------------------------------------------------------
; param 1: Note number
; param 2: SSG channel (0-2)
;
; Usage: _ym2608.ssg.note.on #60, #0
;-------------------------------------------------------------------------------
_ym2608.ssg.note.on MACRO
        lda   \1                               ; Note number
        ldb   \2                               ; SSG channel
        jsr   ym2608.ssg.note.on
 ENDM

;-------------------------------------------------------------------------------
; _ym2608.load.voice - Load FM voice
;-------------------------------------------------------------------------------
; param 1: Voice number
; param 2: Channel number
;
; Usage: _ym2608.load.voice #1, #0
;-------------------------------------------------------------------------------
_ym2608.load.voice MACRO
        lda   \1                               ; Voice number
        ldb   \2                               ; Channel number
        jsr   ym2608.load.voice
 ENDM

;===============================================================================
; EXTENDED MUB PLAYER MACROS (New Features)
;===============================================================================

;-------------------------------------------------------------------------------
; _mub.repeat.start - Start repeat section
;-------------------------------------------------------------------------------
; param 1: Repeat count
;
; Usage: _mub.repeat.start #3
;-------------------------------------------------------------------------------
_mub.repeat.start MACRO
        lda   \1                               ; Repeat count
        jsr   mub.repeat.start
 ENDM

;-------------------------------------------------------------------------------
; _mub.repeat.end - End repeat section
;-------------------------------------------------------------------------------
; Usage: _mub.repeat.end
;-------------------------------------------------------------------------------
_mub.repeat.end MACRO
        jsr   mub.repeat.end
 ENDM

;-------------------------------------------------------------------------------
; _mub.lfo.set - Configure LFO
;-------------------------------------------------------------------------------
; param 1: LFO type (0=off, 1=vibrato, 2=tremolo, 3=both)
; param 2: Delay
; param 3: Speed  
; param 4: Depth
;
; Usage: _mub.lfo.set #1, #10, #5, #20
;-------------------------------------------------------------------------------
_mub.lfo.set MACRO
        lda   \1                               ; LFO type
        ldb   \2                               ; Delay
        stb   @lfo_delay
        ldb   \3                               ; Speed
        stb   @lfo_speed
        ldb   \4                               ; Depth
        stb   @lfo_depth
        jsr   mub.lfo.set
        bra   @lfo_skip
@lfo_delay fcb 0
@lfo_speed fcb 0
@lfo_depth fcb 0
@lfo_skip
 ENDM

;-------------------------------------------------------------------------------
; _mub.lfo.off - Turn off LFO
;-------------------------------------------------------------------------------
; Usage: _mub.lfo.off
;-------------------------------------------------------------------------------
_mub.lfo.off MACRO
        jsr   mub.lfo.off
 ENDM

;-------------------------------------------------------------------------------
; _mub.load.voice - Load voice from MUB
;-------------------------------------------------------------------------------
; param 1: Voice number
;
; Usage: _mub.load.voice #5
;-------------------------------------------------------------------------------
_mub.load.voice MACRO
        lda   \1                               ; Voice number
        jsr   mub.load.voice
 ENDM
