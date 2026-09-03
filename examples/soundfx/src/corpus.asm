; GENERE par tools/gen_corpus.py — ne pas editer a la main.
; Le corpus Master System de games/r-type, un bloc par son, au format du
; pilote soundFX (en-tete nb commandes + voie, commandes registre/donnee/delai).

corpus.count equ 54

        INCLUDE "src/corpus/18-fire.asm"
        INCLUDE "src/corpus/33-fire-blast.asm"
        INCLUDE "src/corpus/34.asm"
        INCLUDE "src/corpus/35-missile-launch.asm"
        INCLUDE "src/corpus/36-player-hit.asm"
        INCLUDE "src/corpus/37-pod-eject.asm"
        INCLUDE "src/corpus/38-pod-attach.asm"
        INCLUDE "src/corpus/39-extra-life.asm"
        INCLUDE "src/corpus/40-bonus.asm"
        INCLUDE "src/corpus/41-rebound-laser.asm"
        INCLUDE "src/corpus/42-ground-laser.asm"
        INCLUDE "src/corpus/43-counterair-laser.asm"
        INCLUDE "src/corpus/44-pod-simple-fire.asm"
        INCLUDE "src/corpus/45-explosion-small.asm"
        INCLUDE "src/corpus/46-explosion-0.asm"
        INCLUDE "src/corpus/47-explosion-turret.asm"
        INCLUDE "src/corpus/48-explosion-big.asm"
        INCLUDE "src/corpus/49-explosion-wick.asm"
        INCLUDE "src/corpus/50-enemy-hit.asm"
        INCLUDE "src/corpus/51-boss-hit.asm"
        INCLUDE "src/corpus/52.asm"
        INCLUDE "src/corpus/53.asm"
        INCLUDE "src/corpus/54.asm"
        INCLUDE "src/corpus/55.asm"
        INCLUDE "src/corpus/56.asm"
        INCLUDE "src/corpus/57.asm"
        INCLUDE "src/corpus/58.asm"
        INCLUDE "src/corpus/59.asm"
        INCLUDE "src/corpus/60.asm"
        INCLUDE "src/corpus/61.asm"
        INCLUDE "src/corpus/62.asm"
        INCLUDE "src/corpus/63.asm"
        INCLUDE "src/corpus/64.asm"
        INCLUDE "src/corpus/65.asm"
        INCLUDE "src/corpus/66.asm"
        INCLUDE "src/corpus/67.asm"
        INCLUDE "src/corpus/68.asm"
        INCLUDE "src/corpus/69.asm"
        INCLUDE "src/corpus/70.asm"
        INCLUDE "src/corpus/71.asm"
        INCLUDE "src/corpus/72.asm"
        INCLUDE "src/corpus/73.asm"
        INCLUDE "src/corpus/74.asm"
        INCLUDE "src/corpus/75.asm"
        INCLUDE "src/corpus/76-countdown10.asm"
        INCLUDE "src/corpus/87-countdown09.asm"
        INCLUDE "src/corpus/88-countdown08.asm"
        INCLUDE "src/corpus/89-countdown07.asm"
        INCLUDE "src/corpus/90-countdown06.asm"
        INCLUDE "src/corpus/91-countdown05.asm"
        INCLUDE "src/corpus/92-countdown04.asm"
        INCLUDE "src/corpus/93-countdown03.asm"
        INCLUDE "src/corpus/94-countdown02.asm"
        INCLUDE "src/corpus/95-countdown01.asm"

; adresse du bloc de chaque son
corpus.table
        fdb   soundFX.sms18Fire.data
        fdb   soundFX.sms33FireBlast.data
        fdb   soundFX.sms34.data
        fdb   soundFX.sms35MissileLaunch.data
        fdb   soundFX.sms36PlayerHit.data
        fdb   soundFX.sms37PodEject.data
        fdb   soundFX.sms38PodAttach.data
        fdb   soundFX.sms39ExtraLife.data
        fdb   soundFX.sms40Bonus.data
        fdb   soundFX.sms41ReboundLaser.data
        fdb   soundFX.sms42GroundLaser.data
        fdb   soundFX.sms43CounterairLaser.data
        fdb   soundFX.sms44PodSimpleFire.data
        fdb   soundFX.sms45ExplosionSmall.data
        fdb   soundFX.sms46Explosion0.data
        fdb   soundFX.sms47ExplosionTurret.data
        fdb   soundFX.sms48ExplosionBig.data
        fdb   soundFX.sms49ExplosionWick.data
        fdb   soundFX.sms50EnemyHit.data
        fdb   soundFX.sms51BossHit.data
        fdb   soundFX.sms52.data
        fdb   soundFX.sms53.data
        fdb   soundFX.sms54.data
        fdb   soundFX.sms55.data
        fdb   soundFX.sms56.data
        fdb   soundFX.sms57.data
        fdb   soundFX.sms58.data
        fdb   soundFX.sms59.data
        fdb   soundFX.sms60.data
        fdb   soundFX.sms61.data
        fdb   soundFX.sms62.data
        fdb   soundFX.sms63.data
        fdb   soundFX.sms64.data
        fdb   soundFX.sms65.data
        fdb   soundFX.sms66.data
        fdb   soundFX.sms67.data
        fdb   soundFX.sms68.data
        fdb   soundFX.sms69.data
        fdb   soundFX.sms70.data
        fdb   soundFX.sms71.data
        fdb   soundFX.sms72.data
        fdb   soundFX.sms73.data
        fdb   soundFX.sms74.data
        fdb   soundFX.sms75.data
        fdb   soundFX.sms76Countdown10.data
        fdb   soundFX.sms87Countdown09.data
        fdb   soundFX.sms88Countdown08.data
        fdb   soundFX.sms89Countdown07.data
        fdb   soundFX.sms90Countdown06.data
        fdb   soundFX.sms91Countdown05.data
        fdb   soundFX.sms92Countdown04.data
        fdb   soundFX.sms93Countdown03.data
        fdb   soundFX.sms94Countdown02.data
        fdb   soundFX.sms95Countdown01.data

; identifiant Master System (index du test sonore)
corpus.id
        fcb   18
        fcb   33
        fcb   34
        fcb   35
        fcb   36
        fcb   37
        fcb   38
        fcb   39
        fcb   40
        fcb   41
        fcb   42
        fcb   43
        fcb   44
        fcb   45
        fcb   46
        fcb   47
        fcb   48
        fcb   49
        fcb   50
        fcb   51
        fcb   52
        fcb   53
        fcb   54
        fcb   55
        fcb   56
        fcb   57
        fcb   58
        fcb   59
        fcb   60
        fcb   61
        fcb   62
        fcb   63
        fcb   64
        fcb   65
        fcb   66
        fcb   67
        fcb   68
        fcb   69
        fcb   70
        fcb   71
        fcb   72
        fcb   73
        fcb   74
        fcb   75
        fcb   76
        fcb   87
        fcb   88
        fcb   89
        fcb   90
        fcb   91
        fcb   92
        fcb   93
        fcb   94
        fcb   95

; duree en trames (somme des delais, plafonnee a 255)
corpus.duration
        fcb   12
        fcb   19
        fcb   55
        fcb   54
        fcb   38
        fcb   16
        fcb   34
        fcb   57
        fcb   36
        fcb   40
        fcb   34
        fcb   47
        fcb   9
        fcb   8
        fcb   19
        fcb   24
        fcb   48
        fcb   21
        fcb   9
        fcb   7
        fcb   25
        fcb   8
        fcb   20
        fcb   66
        fcb   21
        fcb   63
        fcb   21
        fcb   19
        fcb   32
        fcb   66
        fcb   64
        fcb   5
        fcb   25
        fcb   9
        fcb   10
        fcb   31
        fcb   18
        fcb   10
        fcb   22
        fcb   9
        fcb   31
        fcb   96
        fcb   67
        fcb   67
        fcb   67
        fcb   67
        fcb   67
        fcb   67
        fcb   67
        fcb   67
        fcb   67
        fcb   67
        fcb   67
        fcb   67

; bit 0 : joue sur l instrument personnalise ; bit 1 : un des sons du jeu
corpus.flags
        fcb   2
        fcb   2
        fcb   1
        fcb   3
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   2
        fcb   3
        fcb   3
        fcb   3
        fcb   3
        fcb   0
        fcb   0
        fcb   0
        fcb   1
        fcb   0
        fcb   1
        fcb   0
        fcb   1
        fcb   1
        fcb   1
        fcb   0
        fcb   1
        fcb   1
        fcb   0
        fcb   1
        fcb   0
        fcb   1
        fcb   0
        fcb   1
        fcb   0
        fcb   1
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0
        fcb   0

; nom affiche (dernier caractere avec le bit 7)
corpus.name
        fdb   corpus.name.18
        fdb   corpus.name.33
        fdb   corpus.name.34
        fdb   corpus.name.35
        fdb   corpus.name.36
        fdb   corpus.name.37
        fdb   corpus.name.38
        fdb   corpus.name.39
        fdb   corpus.name.40
        fdb   corpus.name.41
        fdb   corpus.name.42
        fdb   corpus.name.43
        fdb   corpus.name.44
        fdb   corpus.name.45
        fdb   corpus.name.46
        fdb   corpus.name.47
        fdb   corpus.name.48
        fdb   corpus.name.49
        fdb   corpus.name.50
        fdb   corpus.name.51
        fdb   corpus.name.52
        fdb   corpus.name.53
        fdb   corpus.name.54
        fdb   corpus.name.55
        fdb   corpus.name.56
        fdb   corpus.name.57
        fdb   corpus.name.58
        fdb   corpus.name.59
        fdb   corpus.name.60
        fdb   corpus.name.61
        fdb   corpus.name.62
        fdb   corpus.name.63
        fdb   corpus.name.64
        fdb   corpus.name.65
        fdb   corpus.name.66
        fdb   corpus.name.67
        fdb   corpus.name.68
        fdb   corpus.name.69
        fdb   corpus.name.70
        fdb   corpus.name.71
        fdb   corpus.name.72
        fdb   corpus.name.73
        fdb   corpus.name.74
        fdb   corpus.name.75
        fdb   corpus.name.76
        fdb   corpus.name.87
        fdb   corpus.name.88
        fdb   corpus.name.89
        fdb   corpus.name.90
        fdb   corpus.name.91
        fdb   corpus.name.92
        fdb   corpus.name.93
        fdb   corpus.name.94
        fdb   corpus.name.95

corpus.name.18 fcc "FIR"
        fcb   $C5
corpus.name.33 fcc "FIRE BLAS"
        fcb   $D4
corpus.name.34 fcc "SMS 3"
        fcb   $B4
corpus.name.35 fcc "MISSILE LAUNC"
        fcb   $C8
corpus.name.36 fcc "PLAYER HI"
        fcb   $D4
corpus.name.37 fcc "POD EJEC"
        fcb   $D4
corpus.name.38 fcc "POD ATTAC"
        fcb   $C8
corpus.name.39 fcc "EXTRA LIF"
        fcb   $C5
corpus.name.40 fcc "BONU"
        fcb   $D3
corpus.name.41 fcc "REBOUND LASE"
        fcb   $D2
corpus.name.42 fcc "GROUND LASE"
        fcb   $D2
corpus.name.43 fcc "COUNTERAIR LASE"
        fcb   $D2
corpus.name.44 fcc "POD SIMPLE FIR"
        fcb   $C5
corpus.name.45 fcc "EXPLOSION SMAL"
        fcb   $CC
corpus.name.46 fcc "EXPLOSION "
        fcb   $B0
corpus.name.47 fcc "EXPLOSION TURRE"
        fcb   $D4
corpus.name.48 fcc "EXPLOSION BI"
        fcb   $C7
corpus.name.49 fcc "EXPLOSION WIC"
        fcb   $CB
corpus.name.50 fcc "ENEMY HI"
        fcb   $D4
corpus.name.51 fcc "BOSS HI"
        fcb   $D4
corpus.name.52 fcc "SMS 5"
        fcb   $B2
corpus.name.53 fcc "SMS 5"
        fcb   $B3
corpus.name.54 fcc "SMS 5"
        fcb   $B4
corpus.name.55 fcc "SMS 5"
        fcb   $B5
corpus.name.56 fcc "SMS 5"
        fcb   $B6
corpus.name.57 fcc "SMS 5"
        fcb   $B7
corpus.name.58 fcc "SMS 5"
        fcb   $B8
corpus.name.59 fcc "SMS 5"
        fcb   $B9
corpus.name.60 fcc "SMS 6"
        fcb   $B0
corpus.name.61 fcc "SMS 6"
        fcb   $B1
corpus.name.62 fcc "SMS 6"
        fcb   $B2
corpus.name.63 fcc "SMS 6"
        fcb   $B3
corpus.name.64 fcc "SMS 6"
        fcb   $B4
corpus.name.65 fcc "SMS 6"
        fcb   $B5
corpus.name.66 fcc "SMS 6"
        fcb   $B6
corpus.name.67 fcc "SMS 6"
        fcb   $B7
corpus.name.68 fcc "SMS 6"
        fcb   $B8
corpus.name.69 fcc "SMS 6"
        fcb   $B9
corpus.name.70 fcc "SMS 7"
        fcb   $B0
corpus.name.71 fcc "SMS 7"
        fcb   $B1
corpus.name.72 fcc "SMS 7"
        fcb   $B2
corpus.name.73 fcc "SMS 7"
        fcb   $B3
corpus.name.74 fcc "SMS 7"
        fcb   $B4
corpus.name.75 fcc "SMS 7"
        fcb   $B5
corpus.name.76 fcc "COUNTDOWN1"
        fcb   $B0
corpus.name.87 fcc "COUNTDOWN0"
        fcb   $B9
corpus.name.88 fcc "COUNTDOWN0"
        fcb   $B8
corpus.name.89 fcc "COUNTDOWN0"
        fcb   $B7
corpus.name.90 fcc "COUNTDOWN0"
        fcb   $B6
corpus.name.91 fcc "COUNTDOWN0"
        fcb   $B5
corpus.name.92 fcc "COUNTDOWN0"
        fcb   $B4
corpus.name.93 fcc "COUNTDOWN0"
        fcb   $B3
corpus.name.94 fcc "COUNTDOWN0"
        fcb   $B2
corpus.name.95 fcc "COUNTDOWN0"
        fcb   $B1
