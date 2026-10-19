* ---------------------------------------------------------------------------
* IrqObjSmps
* ----------
* An IRQ user routine (DP $E7) : the Smps object's music frame (SmpsObj's
* routine 4), its page mounted. The driver's variables (Smps.*) are here,
* resident, shared by the game and the driver.
*
* trashes : a, x
* ---------------------------------------------------------------------------
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
SFXToPlay2                     rmb   1                ; V2-DEVIATION (06/10/2026) : s2's second SFX queue slot (PlaySound2, PlaySoundStereo)
 ENDSTRUCT

; V2-DEVIATION : the instance an equate on the fill (`org` does not rewind a
; section : migration/org-does-not-rewind-a-section.md), its members spelled
; out from the struct's offsets.
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
Smps.SFXToPlay2               equ   Smps+SmpsVar.SFXToPlay2
        ;org   SmpsStructStart ; V2-DEVIATION: see above
        fill  0,sizeof{SmpsVar}
