* Les masques de cast : quel stage charge quels lots de la bibliothèque
* d'ennemis (un bit par lot, l'ordre est celui de la table game.cast.lots
* de l'engine). Source de vérité : la matrice arcade,
* docs/lang/fr/analyse-lots-ennemis-2026-08.md.
*
* Le stage entrant passe SON masque à game.stage.switch (registre U) ;
* l'engine converge lot par lot. Un stage sans cast commun passe 0.

 IFNDEF CAST_CONST
CAST_CONST equ 1

cast.lot.bink      equ %00000001   ; A : stages 1, 3, 4, 6, 7
cast.lot.patapata  equ %00000010   ; B : stages 1, 3, 4, 7
cast.lot.cancer    equ %00000100   ; C : stages 1, 4, 5, 7
cast.lot.bugpstaff equ %00001000   ; D : stages 1, 4, 7
cast.lot.scant     equ %00010000   ; E (scant + son tir) : stages 1, 7
cast.lot.mid       equ %00100000   ; F (squelette) : stages 5, 7

cast.stage1 equ cast.lot.bink|cast.lot.patapata|cast.lot.cancer|cast.lot.bugpstaff|cast.lot.scant
cast.stage2 equ 0
cast.stage3 equ cast.lot.bink|cast.lot.patapata
cast.stage4 equ cast.lot.bink|cast.lot.patapata|cast.lot.cancer|cast.lot.bugpstaff
cast.stage5 equ cast.lot.cancer|cast.lot.mid
cast.stage6 equ cast.lot.bink
cast.stage7 equ cast.lot.bink|cast.lot.patapata|cast.lot.cancer|cast.lot.bugpstaff|cast.lot.scant|cast.lot.mid
cast.stage8 equ 0
cast.title  equ 0

 ENDC
