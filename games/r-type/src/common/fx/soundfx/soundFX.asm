
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
            fdb     soundFX.sms35MissileLaunch.data
            fdb     soundFX.sms37PodEject.data
            fdb     soundFX.sms39ExtraLife.data
            fdb     soundFX.sms41ReboundLaser.data
            fdb     soundFX.sms42GroundLaser.data
            fdb     soundFX.sms43CounterairLaser.data
            fdb     soundFX.sms44PodSimpleFire.data
            fdb     soundFX.sms45ExplosionSmall.data
            fdb     soundFX.sms47ExplosionTurret.data
            fdb     soundFX.sms48ExplosionBig.data
            fdb     soundFX.sms49ExplosionWick.data
            fdb     soundFX.sms50EnemyHit.data
            fdb     soundFX.sms51BossHit.data

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
; Les treize sons confirmes a l'oreille (03/09/2026) : blocs GENERES par
; tools/sms_sfx_to_soundfx.py depuis le corpus Master System, inclus tels
; quels — ne pas les editer ici, regenerer (`--tout --sortie ...`).
; Cinq d'entre eux (35, 48, 49, 50, 51) jouent sur l'instrument personnalise
; du YM2413 et commencent par le redefinir (registres $00-$07) : c'est le
; geste 6 de l'outil. Le lecteur de musique partage cet instrument — la
; Master System faisait exactement de meme, son pilote le reecrivait avant
; chaque bruitage.
; ---------------------------------------------------------------------------
        INCLUDE "reference/sms/sfx/soundfx/35-missile-launch.asm"
        INCLUDE "reference/sms/sfx/soundfx/37-pod-eject.asm"
        INCLUDE "reference/sms/sfx/soundfx/39-extra-life.asm"
        INCLUDE "reference/sms/sfx/soundfx/41-rebound-laser.asm"
        INCLUDE "reference/sms/sfx/soundfx/42-ground-laser.asm"
        INCLUDE "reference/sms/sfx/soundfx/43-counterair-laser.asm"
        INCLUDE "reference/sms/sfx/soundfx/44-pod-simple-fire.asm"
        INCLUDE "reference/sms/sfx/soundfx/45-explosion-small.asm"
        INCLUDE "reference/sms/sfx/soundfx/47-explosion-turret.asm"
        INCLUDE "reference/sms/sfx/soundfx/48-explosion-big.asm"
        INCLUDE "reference/sms/sfx/soundfx/49-explosion-wick.asm"
        INCLUDE "reference/sms/sfx/soundfx/50-enemy-hit.asm"
        INCLUDE "reference/sms/sfx/soundfx/51-boss-hit.asm"
