* ---------------------------------------------------------------------------
* IrqObjSmps
* ----------
* IRQ Subroutine to run smps driver as an object
*
* input REG : [none]
* reset REG : [a,x]
*
* feature request - whith the new builder architecture, it will be possible
* to make a direct call without the need of an address table
* it should also be possible to store and execute objects in ROM instead
* of RAM
*
* ---------------------------------------------------------------------------
        ;setdp $E7 ; V2-DEVIATION: setdp neutralized (not permitted in lwasm
                  ; obj target) ; the one direct operand below is an explicit <, still assembled direct
                  ; (migration/setdp-obj-target.md)
IrqObjSmps
        lda   Obj_Index_Page+ObjID_Smps
        sta   <$E6                                    ; mount Smps page in RAM

        lda   #4                                      ; Smps MusicFrame routine id
        ldx   Obj_Index_Address+2*ObjID_Smps          ; load page and addr of sound routine
        jmp   ,x                                      ; Call Smps sound driver and return

SmpsVar STRUCT
SFXPriorityVal                 rmb   1        
TempoTimeout                   rmb   1        
CurrentTempo                   rmb   1                ; Stores current tempo value here
StopMusic                      rmb   1                ; Set to 7Fh to pause music, set to 80h to unpause. Otherwise 00h
FadeOutCounter                 rmb   1        
FadeOutDelay                   rmb   1        
QueueToPlay                    rmb   1                ; if NOT set to 80h, means new index was requested by 68K
SFXToPlay                      rmb   1                ; When Genesis wants to play "normal" sound, it writes it here
VoiceTblPtr                    rmb   2                ; address of the voices
SFXVoiceTblPtr                 rmb   2                ; address of the SFX voices
FadeInFlag                     rmb   1        
FadeInDelay                    rmb   1        
FadeInCounter                  rmb   1        
1upPlaying                     rmb   1        
TempoMod                       rmb   1        
TempoTurbo                     rmb   1                ; Stores the tempo if speed shoes are acquired (or 7Bh is played anywho)
SpeedUpFlag                    rmb   1        
DACEnabled                     rmb   1                
60HzData                       rmb   1                ; 1: play 60hz track at 50hz, 0: do not skip frames
 ENDSTRUCT

; V2-DEVIATION: in the lwasm obj target `org` does not rewind a section : the
; instance reserved its bytes, then the fill was appended after them, and
; every later byte of the game mode moved away from its symbol. The instance
; is an equate on the fill instead, its members spelled out from the struct's
; field offsets (migration/org-does-not-rewind-a-section.md).
SmpsStructStart
Smps          equ   SmpsStructStart
Smps.SFXPriorityVal           equ   Smps+SmpsVar.SFXPriorityVal
Smps.TempoTimeout             equ   Smps+SmpsVar.TempoTimeout
Smps.CurrentTempo             equ   Smps+SmpsVar.CurrentTempo
Smps.StopMusic                equ   Smps+SmpsVar.StopMusic
Smps.FadeOutCounter           equ   Smps+SmpsVar.FadeOutCounter
Smps.FadeOutDelay             equ   Smps+SmpsVar.FadeOutDelay
Smps.QueueToPlay              equ   Smps+SmpsVar.QueueToPlay
Smps.SFXToPlay                equ   Smps+SmpsVar.SFXToPlay
Smps.VoiceTblPtr              equ   Smps+SmpsVar.VoiceTblPtr
Smps.SFXVoiceTblPtr           equ   Smps+SmpsVar.SFXVoiceTblPtr
Smps.FadeInFlag               equ   Smps+SmpsVar.FadeInFlag
Smps.FadeInDelay              equ   Smps+SmpsVar.FadeInDelay
Smps.FadeInCounter            equ   Smps+SmpsVar.FadeInCounter
Smps.1upPlaying               equ   Smps+SmpsVar.1upPlaying
Smps.TempoMod                 equ   Smps+SmpsVar.TempoMod
Smps.TempoTurbo               equ   Smps+SmpsVar.TempoTurbo
Smps.SpeedUpFlag              equ   Smps+SmpsVar.SpeedUpFlag
Smps.DACEnabled               equ   Smps+SmpsVar.DACEnabled
Smps.60HzData                 equ   Smps+SmpsVar.60HzData
        ;org   SmpsStructStart ; V2-DEVIATION: see above
        fill  0,sizeof{SmpsVar}

        ;setdp dp/256 ; V2-DEVIATION: setdp neutralized (see above)