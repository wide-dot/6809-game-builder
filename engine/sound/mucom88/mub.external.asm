;*******************************************************************************
; MUCOM88 MUB Player External Definitions
; ------------------------------------------------------------------------------
; External symbol definitions for the MUB player
; Include this file when you need to reference MUB player functions
; from other modules without including the full implementation
;*******************************************************************************

; MUB Player Core Functions
mub.play       EXTERNAL                        ; Initialize and start MUB playback
mub.obj.play   EXTERNAL                        ; Object-based MUB player initialization  
mub.frame.play EXTERNAL                        ; Process one frame of MUB playback
mub.stop       EXTERNAL                        ; Stop MUB playback
mub.pause      EXTERNAL                        ; Pause MUB playback
mub.resume     EXTERNAL                        ; Resume MUB playback
mub.get.status EXTERNAL                        ; Get player status
mub.set.tempo  EXTERNAL                        ; Set playback tempo
mub.fade.out   EXTERNAL                        ; Start fade out

; YM2608 Interface Functions
ym2608.init       EXTERNAL                     ; Initialize YM2608 to silent state
ym2608.write      EXTERNAL                     ; Write to YM2608 register
ym2608.silence    EXTERNAL                     ; Silence all channels
ym2608.note.on    EXTERNAL                     ; Turn on note for FM channel
ym2608.note.off   EXTERNAL                     ; Turn off note for FM channel
ym2608.set.volume EXTERNAL                     ; Set volume for channel
ym2608.load.voice EXTERNAL                     ; Load FM voice data
ym2608.ssg.note.on EXTERNAL                    ; Play note on SSG channel
ym2608.calc.fnum  EXTERNAL                     ; Calculate F-Number from note
ym2608.adpcm.play EXTERNAL                     ; Play ADPCM sample
ym2608.rhythm.play EXTERNAL                    ; Play rhythm instrument

; Hardware Interface (system-specific - must be provided by system layer)
ym2608.PORT_0_ADDR EXTERNAL                    ; YM2608 Port 0 Address Register
ym2608.PORT_0_DATA EXTERNAL                    ; YM2608 Port 0 Data Register
ym2608.PORT_1_ADDR EXTERNAL                    ; YM2608 Port 1 Address Register
ym2608.PORT_1_DATA EXTERNAL                    ; YM2608 Port 1 Data Register

; System Interface (must be provided by system layer)
irq.on         EXTERNAL                        ; Enable interrupts
irq.off        EXTERNAL                        ; Disable interrupts

; Extended MUB Player Functions (new features)
mub.repeat.start       EXTERNAL                ; Start repeat section
mub.repeat.end         EXTERNAL                ; End repeat section  
mub.load.voice         EXTERNAL                ; Load FM voice from MUB
mub.lfo.set            EXTERNAL                ; Configure LFO parameters
mub.lfo.off            EXTERNAL                ; Turn off LFO
mub.process.lfo        EXTERNAL                ; Process LFO per frame
mub.apply.se.lfo.to.operators EXTERNAL         ; Apply SE mode LFO to operators
