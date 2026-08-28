; Reacteurs et capsules — GENERE par tools/gen_warship_reactors.py
; depuis le dump arcade.

; LE SCRIPT D'ORIENTATION des quatre reacteurs de ventre (1000:7e56).
; Une entree : fdb seuil (trames depuis la naissance du MAITRE), fcb
; orientation (0..5), fcb flamme (0 ou 1). Fin : seuil = -1.
; Les quatre reacteurs lisent ce meme script — c'est ce qui les
; synchronise alors qu'ils naissent a des instants differents.
breactor.script
        fdb   0
        fcb   2,0 ; #0 etat 0004
        fdb   1744
        fcb   3,0 ; #1 etat 0006
        fdb   1804
        fcb   2,0 ; #2 etat 0004
        fdb   1864
        fcb   2,1 ; #3 etat 8004
        fdb   2064
        fcb   2,1 ; #4 etat 8004
        fdb   2116
        fcb   3,0 ; #5 etat 0006
        fdb   2168
        fcb   0,0 ; #6 etat 0000
        fdb   2256
        fcb   0,1 ; #7 etat 8000
        fdb   2408
        fcb   0,1 ; #8 etat 8000
        fdb   2488
        fcb   5,0 ; #9 etat 000A
        fdb   2944
        fcb   4,0 ; #10 etat 0008
        fdb   3044
        fcb   4,1 ; #11 etat 8008
        fdb   3144
        fcb   4,1 ; #12 etat 8008
        fdb   3362
        fcb   5,0 ; #13 etat 000A
        fdb   3584
        fcb   0,0 ; #14 etat 0000
        fdb   3684
        fcb   0,1 ; #15 etat 8000
        fdb   -1

; Les six directions (1000:7e9a) vers cinq jeux d'images.
breactor.Sets
        fdb   set_bottom_reactor_bottom_0 ; 0
        fdb   set_bottom_reactor_bottom_0 ; 1
        fdb   set_bottom_reactor_bottom_right_full_0 ; 2
        fdb   set_bottom_reactor_bottom_right_0 ; 3
        fdb   set_bottom_reactor_bottom_left_full_0 ; 4
        fdb   set_bottom_reactor_bottom_left_0 ; 5

; corps du reacteur arriere (1000:7A3C) arcade x[-40..32] y[-15..15]
rreactor.BODYBOX equ $0E0B
rreactor.BODYCTR equ $FE00
; ses flammes geantes (1000:7A44) arcade x[-32..64] y[-16..16]
rreactor.FLAMEBOX equ $120C
rreactor.FLAMECTR equ $0600
; reacteur de ventre (1000:7ECA) arcade x[-8..8] y[-8..8]
breactor.BOX equ $0306
breactor.CTR equ $0000
; capsule de survie (1000:7B46) arcade x[-68..68] y[-14..14]
capsule.BOX equ $1A0A
capsule.CTR equ $0000
; petite capsule et triangle (1000:7A8C) arcade x[-16..16] y[-14..16]
detach.BOX equ $060B
detach.CTR equ $00FF
