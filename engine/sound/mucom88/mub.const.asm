;*******************************************************************************
; MUCOM88 MUB Player Constants
; ------------------------------------------------------------------------------
; Constants for MUB (MUCOM88 Binary) format player
; Based on MUCOM88 original by Yuzo Koshiro
; 6809 port by [Author]
;*******************************************************************************

engine.sound.mub.const.asm equ 1

; MUB File Format Constants
; -------------------------
mub.MAGIC                    equ $4D554238       ; Magic number for MUB files ("MUB8")
mub.HEADER_SIZE              equ 32              ; Size of MUB header
mub.MAX_CHANNELS             equ 11              ; Maximum number of channels (FM: 6, SSG: 3, RHYTHM: 1, ADPCM: 1)

; MUB Header Offsets
; ------------------
mub.HDR_MAGIC                equ 0               ; Magic number "MUB8" (4 bytes)
mub.HDR_DATA_OFFSET          equ 4               ; Offset to music data (4 bytes)
mub.HDR_DATA_SIZE            equ 8               ; Size of music data (4 bytes)
mub.HDR_TAG_OFFSET           equ 12              ; Offset to tag data (4 bytes)
mub.HDR_TAG_SIZE             equ 16              ; Size of tag data (4 bytes)
mub.HDR_PCM_OFFSET           equ 20              ; Offset to PCM data (4 bytes)
mub.HDR_PCM_SIZE             equ 24              ; Size of PCM data (4 bytes)
mub.HDR_JUMP_COUNT           equ 28              ; Jump count (2 bytes)
mub.HDR_JUMP_LINE            equ 30              ; Jump line (2 bytes)

; Player Status Constants
; -----------------------
mub.STATUS_STOP              equ 0               ; Player stopped
mub.STATUS_PLAY              equ 1               ; Player playing
mub.STATUS_PAUSE             equ 2               ; Player paused

; Loop Constants
; --------------
mub.NO_LOOP                  equ 0               ; No loop
mub.LOOP                     equ 1               ; Enable loop
mub.NO_CALLBACK              equ 0               ; No callback routine

; Channel Types
; -------------
mub.CH_FM1                   equ 0               ; FM Channel 1
mub.CH_FM2                   equ 1               ; FM Channel 2
mub.CH_FM3                   equ 2               ; FM Channel 3
mub.CH_FM4                   equ 3               ; FM Channel 4
mub.CH_FM5                   equ 4               ; FM Channel 5
mub.CH_FM6                   equ 5               ; FM Channel 6
mub.CH_SSG1                  equ 6               ; SSG Channel 1
mub.CH_SSG2                  equ 7               ; SSG Channel 2
mub.CH_SSG3                  equ 8               ; SSG Channel 3
mub.CH_RHYTHM                equ 9               ; Rhythm Channel
mub.CH_ADPCM                 equ 10              ; ADPCM Channel

; MML Command Constants (based on MUCOM88 original)
; ---------------------
; F0-FF range commands (extended commands)
mub.MML_VOICE                equ $F0             ; Voice change '@'
mub.MML_VOLUME               equ $F1             ; Volume set 'v'
mub.MML_DETUNE               equ $F2             ; Detune 'D'
mub.MML_GATE_TIME            equ $F3             ; Gate time 'q'
mub.MML_LFO                  equ $F4             ; LFO set
mub.MML_REPEAT_START         equ $F5             ; Repeat start '['
mub.MML_REPEAT_END           equ $F6             ; Repeat end ']'
mub.MML_NOISE                equ $F7             ; Noise/Mix 'P' (SSG)
mub.MML_STEREO               equ $F8             ; Stereo/Pan
mub.MML_FLAG_SET             equ $F9             ; Flag set
mub.MML_ENVELOPE             equ $FA             ; Envelope 'E' (SSG)
mub.MML_VOLUME_UP            equ $FB             ; Volume up ')'
mub.MML_HARD_LFO             equ $FC             ; Hardware LFO
mub.MML_TIE                  equ $FD             ; Tie '&'
mub.MML_REPEAT_SKIP          equ $FE             ; Repeat skip '/'
mub.MML_EXTENDED             equ $FF             ; Extended commands

; Note/Rest commands
mub.CMD_REST                 equ $80             ; Rest command
mub.CMD_NOTE_BASE            equ $81             ; Base for note commands (C)
mub.CMD_END                  equ $FF             ; End of track

; Extended command sub-codes (after $FF)
mub.EXT_PCM_VOLUME_MODE      equ $F0             ; PCM volume mode
mub.EXT_HARD_ENVELOPE        equ $F1             ; Hard envelope 's'
mub.EXT_REVERB               equ $F3             ; Reverb

; Legacy constants (for compatibility)
mub.CMD_NOTE_ON              equ $80             ; Note on command
mub.CMD_NOTE_OFF             equ $90             ; Note off command
mub.CMD_TEMPO                equ $B0             ; Tempo change
mub.CMD_VOLUME               equ $C0             ; Volume change
mub.CMD_INSTRUMENT           equ $D0             ; Instrument change
mub.CMD_PAN                  equ $E0             ; Pan change
mub.CMD_LOOP_START           equ $F0             ; Loop start
mub.CMD_LOOP_END             equ $F1             ; Loop end
mub.CMD_JUMP                 equ $F2             ; Jump command

; Timing Constants
; ----------------
mub.DEFAULT_TEMPO            equ 120             ; Default tempo (BPM)
mub.TICKS_PER_BEAT           equ 48              ; Ticks per beat
mub.FRAMES_PER_SECOND        equ 60              ; Frames per second (NTSC)

; Error Codes
; -----------
mub.ERR_NONE                 equ 0               ; No error
mub.ERR_INVALID_FILE         equ 1               ; Invalid MUB file
mub.ERR_OUT_OF_MEMORY        equ 2               ; Out of memory
mub.ERR_INVALID_CHANNEL      equ 3               ; Invalid channel
mub.ERR_PLAYBACK_ERROR       equ 4               ; Playback error

; Buffer Sizes
; ------------
mub.BUFFER_SIZE              equ 512             ; Size of decode buffer per channel
mub.VOICE_BUFFER_SIZE        equ 256             ; Size of voice data buffer

; Repeat System Constants
; -----------------------
mub.REPEAT_STACK_SIZE        equ 8               ; Max nested repeat levels per channel
mub.REPEAT_STACK_ENTRY_SIZE  equ 4               ; Bytes per repeat entry (address + count)
mub.MAX_REPEAT_COUNT         equ 255             ; Maximum repeat count

; Gate Time Constants
; -------------------
mub.DEFAULT_GATE_TIME        equ 8               ; Default gate time (8/8 = full length)
mub.MAX_GATE_TIME            equ 8               ; Maximum gate time

; LFO Constants
; -------------
mub.LFO_OFF                  equ 0               ; LFO disabled
mub.LFO_VIBRATO              equ 1               ; Vibrato (pitch modulation)
mub.LFO_TREMOLO              equ 2               ; Tremolo (volume modulation)
mub.LFO_BOTH                 equ 3               ; Both vibrato and tremolo

; Channel data field aliases for compatibility
mub.ch.gate_time             equ mub.ch.lfo_delay ; Gate time storage (reuse LFO area)
mub.ch.status                equ mub.ch.length+3  ; Channel status (high byte of length)
mub.ch.lfo_speed             equ mub.ch.lfo_delay+1 ; LFO speed storage
mub.ch.lfo_depth             equ mub.ch.lfo_delay+2 ; LFO depth storage

; Variable aliases for compatibility
mub.data.addr                equ mub.data         ; Data address alias
mub.data.size                equ mub.music.size   ; Data size alias
mub.file.size                equ mub.music.size   ; File size alias (simplified)
