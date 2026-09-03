; Garde d'inclusion : un membre de PAGESET porte plusieurs blocs qui
; incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
; fois — c'est vrai independamment du pageset.
 IFNDEF EXPLOSION_CONST
EXPLOSION_CONST equ 1


explosion.subtype.smallx3 equ 0
explosion.subtype.smallx2 equ 2
explosion.subtype.fwk     equ 4
explosion.subtype.mid     equ 6
explosion.subtype.big     equ 8
explosion.subtype.big.blue equ 10
explosion.subtype.big.brown equ 12
explosion.subtype.smallx3.erase equ 14

; LE SON D'UNE EXPLOSION (03/09/2026). La borne ne le tire pas du sprite mais
; de l'ennemi qui meurt : cinq paliers et deux cascades (doc/arcade-sound-
; reference.md, familles $50-$54). Il voyage dans les bits 4-6 du subtype,
; a cote de l'animation (bits 0-3) — a AJOUTER a un explosion.subtype.* sur
; le site qui cree l'explosion. Sans palier, le son est celui d'avant :
; l'explosion moyenne ($51), qui etait joue pour toutes.
explosion.sfx.medium   equ $00  ; borne $51 — bink, cytron, p-staff, slither, cancer, geld
explosion.sfx.small    equ $10  ; borne $50 — pata-pata, bug, tirs, bonus
explosion.sfx.turret   equ $20  ; borne $52 — shell, blaster, brood, zoid, nerfs, pieces du warship
explosion.sfx.big      equ $30  ; borne $53 — tabrok, gouger, scant, capsule
explosion.sfx.wick     equ $40  ; borne $54
explosion.sfx.cascade  equ $50  ; boss : $51/$52/$53 au sort, une chance sur quatre de silence
explosion.sfx.cascade2 equ $60  ; compiler : $52/$53 au sort
explosion.sfx.none     equ $70  ; muet

 ENDC
