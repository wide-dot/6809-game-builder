; Garde d'inclusion : un membre de PAGESET porte plusieurs blocs qui
; incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
; fois — c'est vrai independamment du pageset.
 IFNDEF SCALE_CONST
SCALE_CONST equ 1

scale.XN1PX equ -$0060 ; x:-0.375
scale.XP1PX equ $0060  ; x:+0.375
scale.YN1PX equ -$00C0 ; y:-0.75
scale.YP1PX equ $00C0  ; y:+0.75

 ENDC
