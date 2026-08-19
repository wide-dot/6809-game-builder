; Garde d'inclusion : un membre de PAGESET porte plusieurs blocs qui
; incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
; fois — c'est vrai independamment du pageset.
 IFNDEF RTYPE_OBJECT_CONST
RTYPE_OBJECT_CONST equ 1

; rtype object constant override
; ------------------------------
fireCounter         equ x_acl             ; 2 bytes - var 26
fireVelocityPreset  equ y_acl             ; 1 byte  - var 28 - 8bit index (thomson) instead of 16bit address (arcade) (0 means no fire, 1-7 is a preset)
fireThreshold       equ y_acl+1           ; 1 byte  - var 2a - 8bit value (thomson) instead of 16bit value (arcade)
fireDisplayDelay    equ routine_secondary ; 1 byte  - var 20 - 8bit value (thomson) instead of 16bit value (arcade)
fireReset           equ routine_tertiary  ; 2 bytes - var 2c

; La hauteur du champ de jeu, constante du game mode v1 (main.asm:91). Le force
; pod la lit pour se borner ; d'autres objets suivront. Gardee : les mains v1
; encore presents dans l'arbre la definissent aussi.
 IFNDEF viewport_height
viewport_height     equ 180
 ENDC

 ENDC
