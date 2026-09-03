* Garde d'inclusion : un membre de pageset porte plusieurs units qui
* incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
* fois — c'est vrai independamment du pageset.
 IFNDEF COLLISION_MACROS
COLLISION_MACROS equ 1

; usage:
;
; in the main code :
; AABB_List_friend fdb   0,0
; AABB_List_ennemy fdb   0,0
; AABB_List_player fdb   0,0
; AABB_List_bonus  fdb   0,0
; 
; in the object code :
; AABB_0 equ ext_variables ; 9 bytes
;
; _Collision_AddAABB AABB_0,AABB_list_friend
; _Collision_RemoveAABB AABB_0,AABB_list_friend
; _Collision_CleanLinksAABB AABB_0
; _Collision_Do AABB_list_friend,AABB_list_ennemy
;
; WARNING !
; - When a box change from a list to another, you MUST use CleanLinksAABB after removing and before adding
; - Never use a single box in two or more lists
; --------------------------------------

_Collision_AddAABB MACRO
        pshs  u,x,y
        leax  \1,u
        ldy   #\2
        jsr   Collision_AddAABB
        puls  u,x,y
 ENDM

_Collision_AddAABB_x MACRO
        pshs  u,x,y
        leax  \1,x
        ldy   #\2
        jsr   Collision_AddAABB
        puls  u,x,y
 ENDM

; --------------------------------------

_Collision_RemoveAABB MACRO
        pshs  d,u,x,y
        ldx   #\2
        stx   Collision_Remove_1
        stx   Collision_Remove_3
        leax  2,x
        stx   Collision_Remove_2
        leax  \1,u
        jsr   Collision_RemoveAABB
        puls  d,u,x,y
 ENDM

; Le pendant en X de _Collision_RemoveAABB : la boite n'est pas toujours dans
; un OST pointe par U. Collision_AddAABB lie de la MEMOIRE QUELCONQUE et
; Collision_Do ne touche que la structure, jamais l'objet derriere — un manager
; peut donc posseder ses boites dans sa propre table (manager de tirs,
; 29/08/2026). _Collision_AddAABB_x existait deja ; il lui manquait son retrait.
_Collision_RemoveAABB_x MACRO
        pshs  d,u,x,y
        ldx   #\2
        stx   Collision_Remove_1
        stx   Collision_Remove_3
        leax  2,x
        stx   Collision_Remove_2
        puls  d,u,x,y
        pshs  d,u,y
        leax  \1,x
        jsr   Collision_RemoveAABB
        puls  d,u,y
 ENDM

; --------------------------------------

_Collision_CleanLinksAABB MACRO
        ldd   #0
        std   \1+AABB.prev,u
        std   \1+AABB.next,u
 ENDM

; --------------------------------------

_Collision_Do MACRO
        ldd   \1
        std   Collision_Do_1
        ldd   \2
        std   Collision_Do_2
        jsr   Collision_Do
 ENDM

; --------------------------------------
; V2-DEVIATION 2026-09-03 : la projection ecran d'un centre de boite.
;
; Collision_Do compare les centres SUR UN OCTET, modulo 256 : deux centres
; distants de 250 px ont un ecart de 6 et se touchent. Un objet arme hors
; champ (a x - camera = -20, ou 236) est donc vu de l'autre cote de l'ecran.
; La regle : un centre hors de [0,255] est CALE au bord dont il est le plus
; proche — un objet parti a gauche reste a gauche, loin de tout ce qui est a
; l'ecran ; les adjacences vraies (un ennemi a -3 contre un tir a 2) restent
; des contacts. Le noyau ne change pas, il ne peut rien y faire.
; Cf. docs/lang/en/migration/aabb-screen-projection.md.
;
; Entree : D = le decalage ecran SIGNE du centre (x - camera, ou y).
; Sortie : \1+AABB.cx,u (ou .cy) = D cale dans [0,255]. X, Y, U intacts.
; Le cas courant (0..255) coute tsta + beq + stb : dix cycles, dix octets
; par site — le signe de A passe dans la retenue, pas dans une branche.

_AABB.setCx MACRO
        tsta                           ; l'octet haut : 0 = entre 0 et 255
        beq   @ok
        asla                           ; C = le signe de A
        ldb   #255                     ; au-dela de 255 : cale a droite...
        adcb  #0                       ; ...ou negatif : 255 + 1 = 0, a gauche
@ok     stb   \1+AABB.cx,u
 ENDM

_AABB.setCy MACRO
        tsta
        beq   @ok
        asla
        ldb   #255                     ; au-dela de 255 : cale en bas...
        adcb  #0                       ; ...ou negatif : cale en haut
@ok     stb   \1+AABB.cy,u
 ENDM

 ENDC
