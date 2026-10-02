; Tourelles de PROUE — GENERE par tools/gen_warship_frontmulti.py
; depuis le dump arcade. Six variantes : cinq jeux de poses (c et e
; partagent le 3e) et six tables de tir.

; roue front-turret-a (table 7B4E) : les poses du jeu partage
fturret.wheel.front_turret_a
        fdb   set_front_turret_0,set_front_turret_1,set_front_turret_2,set_front_turret_3
        fdb   set_front_turret_4,set_front_turret_5,set_front_turret_5,set_front_turret_5
        fdb   set_front_turret_4,set_front_turret_4,set_front_turret_3,set_front_turret_2
        fdb   set_front_turret_1,set_front_turret_0,set_front_turret_6,set_front_turret_6

; tir variante 0 (table 7C30) : fdb vx,vy puis fcb pose,alt
; de la boule ($FF = direction sans tir, la porte d arc)
fturret.fire.0
        fdb   0,-384
        fcb   0,1 ; dir 0 (record 7CF0)
        fdb   72,-288
        fcb   2,3 ; dir 1 (record 7CF6)
        fdb   96,-192
        fcb   4,5 ; dir 2 (record 7CFC)
        fdb   144,-144
        fcb   6,7 ; dir 3 (record 7D02)
        fdb   192,0
        fcb   8,9 ; dir 4 (record 7D08)
        fdb   144,144
        fcb   10,11 ; dir 5 (record 7D0E)
        fdb   0,0
        fcb   $FF,$FF ; dir 6 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 7 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 8 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 9 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 10 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 11 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 12 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 13 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 14 : pas de tir
        fdb   -72,-288
        fcb   20,21 ; dir 15 (record 7D2C)

; roue front-turret-b (table 7B6E) : les poses du jeu partage
fturret.wheel.front_turret_b
        fdb   set_front_turret_3,set_front_turret_2,set_front_turret_2,set_front_turret_3
        fdb   set_front_turret_4,set_front_turret_5,set_front_turret_7,set_front_turret_7
        fdb   set_front_turret_7,set_front_turret_5,set_front_turret_4,set_front_turret_4
        fdb   set_front_turret_4,set_front_turret_4,set_front_turret_3,set_front_turret_3

; tir variante 1 (table 7C50) : fdb vx,vy puis fcb pose,alt
; de la boule ($FF = direction sans tir, la porte d arc)
fturret.fire.1
        fdb   0,0
        fcb   $FF,$FF ; dir 0 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 1 : pas de tir
        fdb   96,-192
        fcb   4,5 ; dir 2 (record 7CFC)
        fdb   144,-144
        fcb   6,7 ; dir 3 (record 7D02)
        fdb   192,0
        fcb   8,9 ; dir 4 (record 7D08)
        fdb   144,144
        fcb   10,11 ; dir 5 (record 7D0E)
        fdb   96,192
        fcb   12,13 ; dir 6 (record 7D14)
        fdb   0,0
        fcb   $FF,$FF ; dir 7 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 8 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 9 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 10 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 11 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 12 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 13 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 14 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 15 : pas de tir

; roue front-turret-c (table 7B8E) : les poses du jeu partage
fturret.wheel.front_turret_c
        fdb   set_front_turret_4,set_front_turret_3,set_front_turret_3,set_front_turret_3
        fdb   set_front_turret_4,set_front_turret_5,set_front_turret_7,set_front_turret_8
        fdb   set_front_turret_9,set_front_turret_10,set_front_turret_10,set_front_turret_9
        fdb   set_front_turret_8,set_front_turret_7,set_front_turret_5,set_front_turret_4

; tir variante 2 (table 7C70) : fdb vx,vy puis fcb pose,alt
; de la boule ($FF = direction sans tir, la porte d arc)
fturret.fire.2
        fdb   0,0
        fcb   $FF,$FF ; dir 0 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 1 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 2 : pas de tir
        fdb   144,-144
        fcb   6,7 ; dir 3 (record 7D02)
        fdb   192,0
        fcb   8,9 ; dir 4 (record 7D08)
        fdb   144,144
        fcb   10,11 ; dir 5 (record 7D0E)
        fdb   96,192
        fcb   12,13 ; dir 6 (record 7D14)
        fdb   72,288
        fcb   14,15 ; dir 7 (record 7D1A)
        fdb   0,384
        fcb   16,17 ; dir 8 (record 7D20)
        fdb   -72,288
        fcb   18,19 ; dir 9 (record 7D26)
        fdb   0,0
        fcb   $FF,$FF ; dir 10 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 11 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 12 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 13 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 14 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 15 : pas de tir

; roue front-turret-d (table 7BAE) : les poses du jeu partage
fturret.wheel.front_turret_d
        fdb   set_front_turret_4,set_front_turret_3,set_front_turret_3,set_front_turret_3
        fdb   set_front_turret_4,set_front_turret_5,set_front_turret_7,set_front_turret_8
        fdb   set_front_turret_8,set_front_turret_8,set_front_turret_7,set_front_turret_5
        fdb   set_front_turret_4,set_front_turret_4,set_front_turret_5,set_front_turret_5

; tir variante 3 (table 7C90) : fdb vx,vy puis fcb pose,alt
; de la boule ($FF = direction sans tir, la porte d arc)
fturret.fire.3
        fdb   0,0
        fcb   $FF,$FF ; dir 0 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 1 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 2 : pas de tir
        fdb   144,-144
        fcb   6,7 ; dir 3 (record 7D02)
        fdb   192,0
        fcb   8,9 ; dir 4 (record 7D08)
        fdb   144,144
        fcb   10,11 ; dir 5 (record 7D0E)
        fdb   96,192
        fcb   12,13 ; dir 6 (record 7D14)
        fdb   72,288
        fcb   14,15 ; dir 7 (record 7D1A)
        fdb   0,0
        fcb   $FF,$FF ; dir 8 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 9 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 10 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 11 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 12 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 13 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 14 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 15 : pas de tir

; tir variante 4 (table 7CB0) : fdb vx,vy puis fcb pose,alt
; de la boule ($FF = direction sans tir, la porte d arc)
fturret.fire.4
        fdb   0,0
        fcb   $FF,$FF ; dir 0 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 1 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 2 : pas de tir
        fdb   144,-144
        fcb   6,7 ; dir 3 (record 7D02)
        fdb   192,0
        fcb   8,9 ; dir 4 (record 7D08)
        fdb   144,144
        fcb   10,11 ; dir 5 (record 7D0E)
        fdb   96,192
        fcb   12,13 ; dir 6 (record 7D14)
        fdb   72,288
        fcb   14,15 ; dir 7 (record 7D1A)
        fdb   0,384
        fcb   16,17 ; dir 8 (record 7D20)
        fdb   -72,288
        fcb   18,19 ; dir 9 (record 7D26)
        fdb   0,0
        fcb   $FF,$FF ; dir 10 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 11 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 12 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 13 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 14 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 15 : pas de tir

; roue front-turret-e (table 7BCE) : les poses du jeu partage
fturret.wheel.front_turret_e
        fdb   set_front_turret_4,set_front_turret_4,set_front_turret_4,set_front_turret_4
        fdb   set_front_turret_4,set_front_turret_5,set_front_turret_7,set_front_turret_8
        fdb   set_front_turret_9,set_front_turret_10,set_front_turret_10,set_front_turret_10
        fdb   set_front_turret_9,set_front_turret_8,set_front_turret_7,set_front_turret_5

; tir variante 5 (table 7CD0) : fdb vx,vy puis fcb pose,alt
; de la boule ($FF = direction sans tir, la porte d arc)
fturret.fire.5
        fdb   0,0
        fcb   $FF,$FF ; dir 0 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 1 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 2 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 3 : pas de tir
        fdb   192,0
        fcb   8,9 ; dir 4 (record 7D08)
        fdb   144,144
        fcb   10,11 ; dir 5 (record 7D0E)
        fdb   96,192
        fcb   12,13 ; dir 6 (record 7D14)
        fdb   72,288
        fcb   14,15 ; dir 7 (record 7D1A)
        fdb   0,384
        fcb   16,17 ; dir 8 (record 7D20)
        fdb   -72,288
        fcb   18,19 ; dir 9 (record 7D26)
        fdb   0,0
        fcb   $FF,$FF ; dir 10 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 11 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 12 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 13 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 14 : pas de tir
        fdb   0,0
        fcb   $FF,$FF ; dir 15 : pas de tir

; 11 poses partagees : set_front_turret_0..10
fturret.Wheels
        fdb   fturret.wheel.front_turret_a
        fdb   fturret.wheel.front_turret_b
        fdb   fturret.wheel.front_turret_c
        fdb   fturret.wheel.front_turret_d
        fdb   fturret.wheel.front_turret_c
        fdb   fturret.wheel.front_turret_e
fturret.Fires
        fdb   fturret.fire.0
        fdb   fturret.fire.1
        fdb   fturret.fire.2
        fdb   fturret.fire.3
        fdb   fturret.fire.4
        fdb   fturret.fire.5

; la boite (1000:7E46), rayons et excentrage v2
fturret.BOX equ $0408 ; rx,ry
fturret.CTR equ $0000 ; cx,cy (signes)
