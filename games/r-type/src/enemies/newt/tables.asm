; GENERE par tools/gen_newt.py depuis la ROM arcade — ne pas editer.
; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.

; 1000:329E la vitesse par phase, 8.8 : {vx, vy}
newt.Vel
        fdb   $FF00,$0000  ; phase 0
        fdb   $0100,$0000  ; phase 1
        fdb   $0000,$00E0  ; phase 2
        fdb   $0000,$FF20  ; phase 3

; 1000:32AE le point sonde par phase : {dx, dy}
newt.Probe
        fdb   -32,0  ; phase 0
        fdb   32,0  ; phase 1
        fdb   0,32  ; phase 2
        fdb   0,-32  ; phase 3

; 1000:93DC les departs, par bits 0-3 du jeton : {x ecran, y}
newt.Start
        fdb   712,376  ; 0
        fdb   712,336  ; 1
        fdb   712,296  ; 2
        fdb   712,264  ; 3
        fdb   712,232  ; 4
        fdb   712,216  ; 5
        fdb   712,176  ; 6
        fdb   712,152  ; 7
        fdb   712,152  ; 8
        fdb   712,152  ; 9
        fdb   712,152  ; A
        fdb   712,152  ; B
        fdb   712,152  ; C
        fdb   712,152  ; D
        fdb   712,152  ; E
        fdb   712,152  ; F
