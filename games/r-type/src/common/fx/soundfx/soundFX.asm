
; V2-DEVIATION: meme fichier, chemin v2 — le pilote est importe dans
; engine/sound/ (ligne de manifest du 04/08).
        INCLUDE "engine/sound/soundFX.asm"

; Sound data lookup table
soundFX.soundTable
            fdb     soundFX.FireSound.data
            fdb     soundFX.ExplosionSound.data
            fdb     soundFX.BonusSound.data
            fdb     soundFX.PodAttachSound.data
            fdb     soundFX.FireBlastSound.data
            fdb     soundFX.PlayerHitSound.data
            fdb     soundFX.sms37PodEject.data
            fdb     soundFX.sms39ExtraLife.data
            fdb     soundFX.sms43CounterairLaser.data
            fdb     soundFX.sms44PodSimpleFire.data
            fdb     soundFX.sms45ExplosionSmall.data
            fdb     soundFX.sms47ExplosionTurret.data
            fdb     soundFX.HitSound.data

; Sound data format:
; ------------------
;
; header
; ------
; Byte 0: Length of data (in commands)
; Byte 1: Channel number (0-8)
;
; commands (3 bytes each)
; -----------------------
; Byte 0: Register
; Byte 1: Data
; Byte 2: Delay (in 50Hz ticks)
;
; special command
; ---------------
; Byte 0: $FF, Bytes 1-2: Custom instrument data address

soundFX.FireSound.data
        ; header
        fcb     25          ; Number of commands
        fcb     5           ; Channel number (5)
            
        fcb     $30,$F0,0 ; vol:2
        fcb     $20,$19,0
        fcb     $10,$01,1

        fcb     $20,$17,0
        fcb     $10,$81,1

        fcb     $20,$17,0
        fcb     $10,$20,1

        fcb     $20,$15,0
        fcb     $10,$E5,1

        fcb     $20,$1D,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$B0,1

        fcb     $20,$1B,0
        fcb     $10,$57,1

        fcb     $20,$1B,0
        fcb     $10,$43,1

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $20,$19,0
        fcb     $10,$20,1

        fcb     $20,$17,0
        fcb     $10,$E5,1

        fcb     $20,$15,0
        fcb     $10,$20

soundFX.ExplosionSound.data
        ; Header
        fcb     39                    ; Number of commands
        fcb     5                     ; Channel number (5)

        fcb     $30,$20,0 ; vol:4
        fcb     $20,$19,0
        fcb     $10,$10,1

        fcb     $20,$19,0
        fcb     $10,$6B,1

        fcb     $20,$19,0
        fcb     $10,$CA,1

        fcb     $20,$1F,0
        fcb     $10,$6B,1

        fcb     $20,$1F,0
        fcb     $10,$FC,1

        fcb     $20,$1D,0
        fcb     $10,$6B,1

        fcb     $20,$1D,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$57,1

        fcb     $20,$1D,0
        fcb     $10,$10,1

        fcb     $20,$1F,0
        fcb     $10,$31,1

        fcb     $20,$1F,0
        fcb     $10,$98,1

        fcb     $20,$1F,0
        fcb     $10,$CA,1

        fcb     $20,$1F,0
        fcb     $10,$31,1

        fcb     $20,$1D,0
        fcb     $10,$6B,1

        fcb     $20,$1D,0
        fcb     $10,$10,1

        fcb     $20,$1B,0
        fcb     $10,$98,1

        fcb     $20,$1D,0
        fcb     $10,$31,1

        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1F,0
        fcb     $10,$CA

soundFX.BonusSound.data
        ; Header
        fcb     43                    ; Number of commands
        fcb     5                     ; Channel number (5)

        fcb     $30,$20,0 ; vol:3
        fcb     $10,$98,0
        fcb     $20,$17,2

        fcb     $20,$17,0
        fcb     $10,$CA,2

        fcb     $20,$19,0
        fcb     $10,$01,2

        fcb     $20,$19,0
        fcb     $10,$10,1

        fcb     $20,$19,0
        fcb     $10,$31,2

        fcb     $20,$19,0
        fcb     $10,$57,2

        fcb     $20,$19,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$98,2

        fcb     $20,$19,0
        fcb     $10,$CA,2

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$10,2

        fcb     $20,$1B,0
        fcb     $10,$31,2

        fcb     $20,$1B,0
        fcb     $10,$57,1

        fcb     $20,$1B,0
        fcb     $10,$81,2

        fcb     $20,$1B,0
        fcb     $10,$98,2

        fcb     $20,$1D,0
        fcb     $10,$01,1

        fcb     $20,$1D,0
        fcb     $10,$31,2

        fcb     $20,$1D,0
        fcb     $10,$98,2

        fcb     $20,$1F,0
        fcb     $10,$01,1

        fcb     $20,$1F,0
        fcb     $10,$31,2

        fcb     $20,$1F,0
        fcb     $10,$98

soundFX.PodAttachSound.data
        ; Header
        fcb     43                    ; Number of commands
        fcb     5                     ; Channel number (5)

        fcb     $30,$B0,0 ; vol:2
        fcb     $10,$01,0
        fcb     $20,$1F,2

        fcb     $20,$1D,0
        fcb     $10,$E5,2

        fcb     $20,$1D,0
        fcb     $10,$B0,1

        fcb     $20,$1D,0
        fcb     $10,$81,2

        fcb     $20,$1D,0
        fcb     $10,$57,1

        fcb     $20,$1D,0
        fcb     $10,$43,2

        fcb     $20,$1D,0
        fcb     $10,$20,2

        fcb     $20,$1D,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$E5,2

        fcb     $20,$1B,0
        fcb     $10,$B0,1

        fcb     $20,$1B,0
        fcb     $10,$81,2

        fcb     $20,$1B,0
        fcb     $10,$57,2

        fcb     $20,$1B,0
        fcb     $10,$43,1

        fcb     $20,$1B,0
        fcb     $10,$20,2

        fcb     $20,$1B,0
        fcb     $10,$01,1

        fcb     $20,$1B,0
        fcb     $10,$43,2

        fcb     $20,$1B,0
        fcb     $10,$81,2

        fcb     $20,$1D,0
        fcb     $10,$01,1

        fcb     $20,$1D,0
        fcb     $10,$43,2

        fcb     $20,$1D,0
        fcb     $10,$81,1

        fcb     $20,$1F,0
        fcb     $10,$01

soundFX.FireBlastSound.data
        ; Header
        fcb     38                    ; Number of commands
        fcb     5                     ; Channel number (5)

        fcb     $10,$81,0
        fcb     $30,$E0,0 ; vol:2
        fcb     $20,$15,1

        fcb     $20,$17,0
        fcb     $10,$20,1

        fcb     $20,$17,0
        fcb     $10,$B0,1

        fcb     $20,$17,0
        fcb     $10,$6B,1

        fcb     $20,$15,0
        fcb     $10,$E5,1

        fcb     $20,$15,0
        fcb     $10,$81,1

        fcb     $20,$1B,1

        fcb     $20,$1B,0
        fcb     $10,$43,1

        fcb     $20,$1B,0
        fcb     $10,$20,1

        fcb     $20,$19,0
        fcb     $10,$E5,1

        fcb     $20,$19,0
        fcb     $10,$81,1

        fcb     $20,$19,0
        fcb     $10,$6B,1

        fcb     $20,$19,0
        fcb     $10,$20,1

        fcb     $20,$17,0
        fcb     $10,$E5,1

        fcb     $20,$17,0
        fcb     $10,$81,1

        fcb     $20,$17,0
        fcb     $10,$43,1

        fcb     $20,$17,0
        fcb     $10,$01,1

        fcb     $20,$15,0
        fcb     $10,$B0,1

        fcb     $20,$15,0
        fcb     $10,$81

soundFX.PlayerHitSound.data
        ; Header
        fcb     66                    ; Number of commands
        fcb     5                     ; Channel number (5)

        fcb     $30,$F0,0 ; vol:1
        fcb     $20,$15,0
        fcb     $10,$20,2

        fcb     $20,$15,0
        fcb     $10,$81,1

        fcb     $20,$15,0
        fcb     $10,$E5,1

        fcb     $20,$15,0
        fcb     $10,$81,1

        fcb     $20,$15,0
        fcb     $10,$20,1

        fcb     $20,$15,0
        fcb     $10,$57,1

        fcb     $20,$15,0
        fcb     $10,$B0,1

        fcb     $20,$17,0
        fcb     $10,$20,1

        fcb     $20,$15,0
        fcb     $10,$B0,1

        fcb     $20,$15,0
        fcb     $10,$57,1

        fcb     $20,$15,0
        fcb     $10,$20,1

        fcb     $20,$13,0
        fcb     $10,$E5,1

        fcb     $30,$E1,0
        fcb     $20,$15,0
        fcb     $10,$01,1

        fcb     $20,$13,0
        fcb     $10,$E5,1

        fcb     $20,$13,0
        fcb     $10,$B0,1

        fcb     $20,$13,0
        fcb     $10,$81,2

        fcb     $20,$13,0
        fcb     $10,$57,1

        fcb     $20,$13,0
        fcb     $10,$43,1

        fcb     $20,$13,0
        fcb     $10,$20,2

        fcb     $20,$13,0
        fcb     $10,$01,1

        fcb     $20,$11,0
        fcb     $10,$E5,1

        fcb     $20,$11,0
        fcb     $10,$B0,1

        fcb     $20,$11,0
        fcb     $10,$81,2

        fcb     $20,$11,0
        fcb     $10,$57,1

        fcb     $20,$11,0
        fcb     $10,$43,1

        fcb     $20,$11,0
        fcb     $10,$20,2

        fcb     $20,$11,0
        fcb     $10,$01,1

        fcb     $20,$13,0
        fcb     $10,$E5,1

        fcb     $20,$13,0
        fcb     $10,$B0,1

        fcb     $20,$13,0
        fcb     $10,$81,2

        fcb     $20,$13,0
        fcb     $10,$57,1

        fcb     $20,$13,0
        fcb     $10,$43

; ---------------------------------------------------------------------------
; Les sept sons retenus a l'ecoute (03/09/2026) : blocs GENERES par
; tools/sms_sfx_to_soundfx.py depuis le corpus Master System, inclus tels
; quels — ne pas les editer ici, regenerer (`--tout --sortie ...`).
;
; AUCUN NE REECRIT L'INSTRUMENT PERSONNALISE du YM2413, et c'est le critere
; qui a fait le tri : la musique s'en sert, un bruitage qui le redefinit joue
; sous elle. Les cinq sons du corpus qui le demandaient sont abandonnes, sauf
; le coup encaisse, force au piano (hit-piano.asm, genere avec --instrument 3).
; Le detail des abandons et des emprunts est dans soundFX.const.asm.
; ---------------------------------------------------------------------------
        INCLUDE "reference/sms/sfx/soundfx/37-pod-eject.asm"
        INCLUDE "reference/sms/sfx/soundfx/39-extra-life.asm"
        INCLUDE "reference/sms/sfx/soundfx/43-counterair-laser.asm"
        INCLUDE "reference/sms/sfx/soundfx/44-pod-simple-fire.asm"
        INCLUDE "reference/sms/sfx/soundfx/45-explosion-small.asm"
        INCLUDE "reference/sms/sfx/soundfx/47-explosion-turret.asm"
        INCLUDE "src/common/fx/soundfx/hit-piano.asm"
