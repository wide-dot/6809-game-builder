;*******************************************************************************
; YM2608 (OPNA) Constants
; ------------------------------------------------------------------------------
; Constants for YM2608 sound chip interface
; Used by MUB player for FM synthesis and SSG
;*******************************************************************************

engine.sound.ym2608.const.asm equ 1

; YM2608 Register Map
; -------------------
; Port 0 Registers (FM Part 1)
ym2608.REG_LFO               equ $22             ; LFO Control
ym2608.REG_TIMER_A_MSB       equ $24             ; Timer A MSB
ym2608.REG_TIMER_A_LSB       equ $25             ; Timer A LSB
ym2608.REG_TIMER_B           equ $26             ; Timer B
ym2608.REG_TIMER_CTRL        equ $27             ; Timer Control
ym2608.REG_KEY_ON            equ $28             ; Key On/Off

; FM Channel 1-3 Registers (Port 0)
ym2608.REG_DT_MUL_OP1        equ $30             ; Detune/Multiple Operator 1
ym2608.REG_DT_MUL_OP2        equ $34             ; Detune/Multiple Operator 2
ym2608.REG_DT_MUL_OP3        equ $38             ; Detune/Multiple Operator 3
ym2608.REG_DT_MUL_OP4        equ $3C             ; Detune/Multiple Operator 4

ym2608.REG_TL_OP1            equ $40             ; Total Level Operator 1
ym2608.REG_TL_OP2            equ $44             ; Total Level Operator 2
ym2608.REG_TL_OP3            equ $48             ; Total Level Operator 3
ym2608.REG_TL_OP4            equ $4C             ; Total Level Operator 4

ym2608.REG_KS_AR_OP1         equ $50             ; Key Scale/Attack Rate Operator 1
ym2608.REG_KS_AR_OP2         equ $54             ; Key Scale/Attack Rate Operator 2
ym2608.REG_KS_AR_OP3         equ $58             ; Key Scale/Attack Rate Operator 3
ym2608.REG_KS_AR_OP4         equ $5C             ; Key Scale/Attack Rate Operator 4

ym2608.REG_AM_DR_OP1         equ $60             ; AM/Decay Rate Operator 1
ym2608.REG_AM_DR_OP2         equ $64             ; AM/Decay Rate Operator 2
ym2608.REG_AM_DR_OP3         equ $68             ; AM/Decay Rate Operator 3
ym2608.REG_AM_DR_OP4         equ $6C             ; AM/Decay Rate Operator 4

ym2608.REG_SR_OP1            equ $70             ; Sustain Rate Operator 1
ym2608.REG_SR_OP2            equ $74             ; Sustain Rate Operator 2
ym2608.REG_SR_OP3            equ $78             ; Sustain Rate Operator 3
ym2608.REG_SR_OP4            equ $7C             ; Sustain Rate Operator 4

ym2608.REG_SL_RR_OP1         equ $80             ; Sustain Level/Release Rate Operator 1
ym2608.REG_SL_RR_OP2         equ $84             ; Sustain Level/Release Rate Operator 2
ym2608.REG_SL_RR_OP3         equ $88             ; Sustain Level/Release Rate Operator 3
ym2608.REG_SL_RR_OP4         equ $8C             ; Sustain Level/Release Rate Operator 4

ym2608.REG_FNUM_L            equ $A0             ; F-Number Low
ym2608.REG_FNUM_H            equ $A4             ; F-Number High/Block

ym2608.REG_FB_ALGO           equ $B0             ; Feedback/Algorithm
ym2608.REG_LR_AMS_PMS        equ $B4             ; LR/AMS/PMS

; Port 1 Registers (FM Part 2 - Channels 4-6)
; Same structure as Port 0 but for channels 4-6

; SSG Registers (Port 0)
ym2608.REG_SSG_FREQ_A_L      equ $00             ; SSG Channel A Frequency Low
ym2608.REG_SSG_FREQ_A_H      equ $01             ; SSG Channel A Frequency High
ym2608.REG_SSG_FREQ_B_L      equ $02             ; SSG Channel B Frequency Low
ym2608.REG_SSG_FREQ_B_H      equ $03             ; SSG Channel B Frequency High
ym2608.REG_SSG_FREQ_C_L      equ $04             ; SSG Channel C Frequency Low
ym2608.REG_SSG_FREQ_C_H      equ $05             ; SSG Channel C Frequency High
ym2608.REG_SSG_NOISE         equ $06             ; SSG Noise Frequency
ym2608.REG_SSG_MIXER         equ $07             ; SSG Mixer
ym2608.REG_SSG_VOL_A         equ $08             ; SSG Channel A Volume
ym2608.REG_SSG_VOL_B         equ $09             ; SSG Channel B Volume
ym2608.REG_SSG_VOL_C         equ $0A             ; SSG Channel C Volume
ym2608.REG_SSG_ENV_L         equ $0B             ; SSG Envelope Frequency Low
ym2608.REG_SSG_ENV_H         equ $0C             ; SSG Envelope Frequency High
ym2608.REG_SSG_ENV_SHAPE     equ $0D             ; SSG Envelope Shape

; ADPCM Registers (Port 1)
ym2608.REG_ADPCM_CTRL        equ $10             ; ADPCM Control
ym2608.REG_ADPCM_L_R         equ $11             ; ADPCM L/R
ym2608.REG_ADPCM_START_L     equ $12             ; ADPCM Start Address Low
ym2608.REG_ADPCM_START_H     equ $13             ; ADPCM Start Address High
ym2608.REG_ADPCM_END_L       equ $14             ; ADPCM End Address Low
ym2608.REG_ADPCM_END_H       equ $15             ; ADPCM End Address High
ym2608.REG_ADPCM_DELTA_L     equ $19             ; ADPCM Delta-N Low
ym2608.REG_ADPCM_DELTA_H     equ $1A             ; ADPCM Delta-N High
ym2608.REG_ADPCM_LEVEL       equ $1B             ; ADPCM Level

; Rhythm Registers (Port 1)
ym2608.REG_RHYTHM_CTRL       equ $10             ; Rhythm Control
ym2608.REG_RHYTHM_BD         equ $18             ; Bass Drum
ym2608.REG_RHYTHM_SD         equ $19             ; Snare Drum
ym2608.REG_RHYTHM_TOP        equ $1A             ; Top Cymbal
ym2608.REG_RHYTHM_HH         equ $1B             ; Hi-Hat
ym2608.REG_RHYTHM_TOM        equ $1C             ; Tom
ym2608.REG_RHYTHM_RIM        equ $1D             ; Rim Shot

; Key On/Off Channel Values
ym2608.KEY_CH1               equ $00             ; Channel 1
ym2608.KEY_CH2               equ $01             ; Channel 2
ym2608.KEY_CH3               equ $02             ; Channel 3
ym2608.KEY_CH4               equ $04             ; Channel 4
ym2608.KEY_CH5               equ $05             ; Channel 5
ym2608.KEY_CH6               equ $06             ; Channel 6

; Key On/Off Operator Masks
ym2608.KEY_OP1               equ %00010000       ; Operator 1
ym2608.KEY_OP2               equ %00100000       ; Operator 2
ym2608.KEY_OP3               equ %01000000       ; Operator 3
ym2608.KEY_OP4               equ %10000000       ; Operator 4
ym2608.KEY_ALL_OP            equ %11110000       ; All Operators

; SSG Envelope Shapes
ym2608.SSG_ENV_HOLD_LOW      equ $00             ; Hold at low level
ym2608.SSG_ENV_ATTACK        equ $04             ; Attack only
ym2608.SSG_ENV_ALT_ATTACK    equ $08             ; Alternate attack
ym2608.SSG_ENV_HOLD_HIGH     equ $0A             ; Hold at high level
ym2608.SSG_ENV_DECAY         equ $0C             ; Decay only
ym2608.SSG_ENV_ALT_DECAY     equ $0E             ; Alternate decay

; ADPCM Control Bits
ym2608.ADPCM_RESET           equ %00000001       ; ADPCM Reset
ym2608.ADPCM_RECORD          equ %00000010       ; ADPCM Record
ym2608.ADPCM_PLAY            equ %10000000       ; ADPCM Play

; Rhythm Control Bits
ym2608.RHYTHM_BD             equ %00000001       ; Bass Drum
ym2608.RHYTHM_SD             equ %00000010       ; Snare Drum
ym2608.RHYTHM_TOP            equ %00000100       ; Top Cymbal
ym2608.RHYTHM_HH             equ %00001000       ; Hi-Hat
ym2608.RHYTHM_TOM            equ %00010000       ; Tom
ym2608.RHYTHM_RIM            equ %00100000       ; Rim Shot

; Additional Rhythm Constants
ym2608.REG_RHYTHM_VOL        equ $19             ; Rhythm volume register
ym2608.RHYTHM_ON             equ $80             ; Rhythm on bit

; Port Addresses (to be defined by system-specific implementation)
; ym2608.PORT_0_ADDR          EXTERNAL            ; Port 0 Address Register
; ym2608.PORT_0_DATA          EXTERNAL            ; Port 0 Data Register
; ym2608.PORT_1_ADDR          EXTERNAL            ; Port 1 Address Register
; ym2608.PORT_1_DATA          EXTERNAL            ; Port 1 Data Register
