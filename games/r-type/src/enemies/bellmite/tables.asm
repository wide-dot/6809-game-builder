; GENERE par tools/gen_bellmite.py depuis la ROM arcade — ne pas editer.
; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.

; 1000:5F5C bellmite_difficulty_phase_period, par difficulte
bellmite.Period
        fdb   $0033,$0020,$0018,$0010
bellmite.NSAT   equ 37

; 1000:5F6C les decalages d'orbite des satellites, {x, y}
bellmite.SatOffsets
        fdb   -62,-50     ; satellite 1
        fdb   -92,22      ; satellite 2
        fdb   48,38       ; satellite 3
        fdb   64,-28      ; satellite 4
        fdb   -92,-18     ; satellite 5
        fdb   -40,40      ; satellite 6
        fdb   60,4        ; satellite 7
        fdb   6,-64       ; satellite 8
        fdb   -34,-54     ; satellite 9
        fdb   -66,34      ; satellite 10
        fdb   4,52        ; satellite 11
        fdb   48,-16      ; satellite 12
        fdb   -78,-30     ; satellite 13
        fdb   -16,46      ; satellite 14
        fdb   24,36       ; satellite 15
        fdb   16,-44      ; satellite 16
        fdb   -50,-36     ; satellite 17
        fdb   -72,16      ; satellite 18
        fdb   42,22       ; satellite 19
        fdb   48,-16      ; satellite 20
        fdb   -84,-2      ; satellite 21
        fdb   -50,20      ; satellite 22
        fdb   34,0        ; satellite 23
        fdb   24,-22      ; satellite 24
        fdb   -64,-16     ; satellite 25
        fdb   -58,2       ; satellite 26
        fdb   18,16       ; satellite 27
        fdb   0,-30       ; satellite 28
        fdb   -40,-16     ; satellite 29
        fdb   -24,24      ; satellite 30
        fdb   0,28        ; satellite 31
        fdb   8,-6        ; satellite 32
        fdb   -10,-50     ; satellite 33
        fdb   -32,4       ; satellite 34
        fdb   -24,-34     ; satellite 35
        fdb   -10,8       ; satellite 36
        fdb   -16,-12     ; satellite 37

; 1000:6002 les 32 cibles du noyau, {x, y}
bellmite.Targets
        fdb   $0188,$0138  ;  0
        fdb   $01F8,$0140  ;  1
        fdb   $01F8,$00D8  ;  2
        fdb   $0288,$0128  ;  3
        fdb   $0268,$00E0  ;  4
        fdb   $0188,$0138  ;  5
        fdb   $01A8,$0108  ;  6
        fdb   $01B8,$00E0  ;  7
        fdb   $01C8,$0128  ;  8
        fdb   $01F8,$0140  ;  9
        fdb   $01F8,$00D8  ; 10
        fdb   $0220,$0120  ; 11
        fdb   $0210,$00F0  ; 12
        fdb   $0258,$0130  ; 13
        fdb   $0250,$0108  ; 14
        fdb   $0288,$0128  ; 15
        fdb   $0268,$00E0  ; 16
        fdb   $0188,$0138  ; 17
        fdb   $01F8,$0140  ; 18
        fdb   $0268,$00E0  ; 19
        fdb   $0188,$0138  ; 20
        fdb   $01A8,$0108  ; 21
        fdb   $01B8,$00E0  ; 22
        fdb   $01C8,$0128  ; 23
        fdb   $01F8,$0140  ; 24
        fdb   $01F8,$00D8  ; 25
        fdb   $0220,$0120  ; 26
        fdb   $0210,$00F0  ; 27
        fdb   $0258,$0130  ; 28
        fdb   $0250,$0108  ; 29
        fdb   $0288,$0128  ; 30
        fdb   $0268,$00E0  ; 31

; 1000:5F64 les vitesses d'attaque, une table par difficulte
bellmite.AttackVels
        fdb   bellmite.AttackVel0,bellmite.AttackVel1,bellmite.AttackVel2,bellmite.AttackVel3

; 1000:8FD0 vitesses d'attaque (difficulte 0), {vx, vy} en 8.8,
; indexees par le code de direction (pas de 4 : N, NNE ... NNW)
bellmite.AttackVel0
        fdb   0,544       ; $00 N
        fdb   208,512     ; $04 NNE
        fdb   400,400     ; $08 NE
        fdb   544,240     ; $0C ENE
        fdb   608,0       ; $10 E
        fdb   544,-240    ; $14 ESE
        fdb   400,-400    ; $18 SE
        fdb   208,-512    ; $1C SSE
        fdb   0,-544      ; $20 S
        fdb   -208,-512   ; $24 SSW
        fdb   -400,-400   ; $28 SW
        fdb   -544,-240   ; $2C WSW
        fdb   -608,0      ; $30 W
        fdb   -544,240    ; $34 WNW
        fdb   -400,400    ; $38 NW
        fdb   -208,512    ; $3C NNW

; 1000:9050 vitesses d'attaque (difficulte 1), {vx, vy} en 8.8,
; indexees par le code de direction (pas de 4 : N, NNE ... NNW)
bellmite.AttackVel1
        fdb   0,656       ; $00 N
        fdb   256,624     ; $04 NNE
        fdb   496,496     ; $08 NE
        fdb   672,288     ; $0C ENE
        fdb   768,0       ; $10 E
        fdb   672,-288    ; $14 ESE
        fdb   496,-496    ; $18 SE
        fdb   256,-624    ; $1C SSE
        fdb   0,-656      ; $20 S
        fdb   -256,-624   ; $24 SSW
        fdb   -496,-496   ; $28 SW
        fdb   -672,-288   ; $2C WSW
        fdb   -768,0      ; $30 W
        fdb   -672,288    ; $34 WNW
        fdb   -496,496    ; $38 NW
        fdb   -256,624    ; $3C NNW

; 1000:9090 vitesses d'attaque (difficulte 2), {vx, vy} en 8.8,
; indexees par le code de direction (pas de 4 : N, NNE ... NNW)
bellmite.AttackVel2
        fdb   0,736       ; $00 N
        fdb   304,704     ; $04 NNE
        fdb   560,560     ; $08 NE
        fdb   768,320     ; $0C ENE
        fdb   848,0       ; $10 E
        fdb   768,-320    ; $14 ESE
        fdb   560,-560    ; $18 SE
        fdb   304,-704    ; $1C SSE
        fdb   0,-736      ; $20 S
        fdb   -304,-704   ; $24 SSW
        fdb   -560,-560   ; $28 SW
        fdb   -768,-320   ; $2C WSW
        fdb   -848,0      ; $30 W
        fdb   -768,320    ; $34 WNW
        fdb   -560,560    ; $38 NW
        fdb   -304,704    ; $3C NNW

; 1000:90D0 vitesses d'attaque (difficulte 3), {vx, vy} en 8.8,
; indexees par le code de direction (pas de 4 : N, NNE ... NNW)
bellmite.AttackVel3
        fdb   0,800       ; $00 N
        fdb   320,752     ; $04 NNE
        fdb   592,608     ; $08 NE
        fdb   832,352     ; $0C ENE
        fdb   912,0       ; $10 E
        fdb   832,-352    ; $14 ESE
        fdb   592,-608    ; $18 SE
        fdb   320,-752    ; $1C SSE
        fdb   0,-800      ; $20 S
        fdb   -320,-752   ; $24 SSW
        fdb   -592,-608   ; $28 SW
        fdb   -832,-352   ; $2C WSW
        fdb   -912,0      ; $30 W
        fdb   -832,352    ; $34 WNW
        fdb   -592,608    ; $38 NW
        fdb   -320,752    ; $3C NNW
