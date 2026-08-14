;*******************************************************************************
; brood — SQUELETTE (chantier 3) : le cast du stage 2 n'a pas de source v1,
; il sera cree depuis la reference arcade. Ce squelette donne a l'objet son
; unite, son id et ses lignes de wave : il spawne par l'index du stage,
; compte son passage dans les temoins du banc, et se supprime aussitot —
; une implementation vide ne bloque jamais le pool d'objets.
;
; A implementer (bestiaire re-rtype) : organisme fixe qui crache des
; parasites Zoid sur le R-craft — le zoid (enfant, jamais dans la wave)
; viendra AVEC cette implementation, pas avant. Alias v1 : baldur (la wave
; v1 ecrivait ObjID_baldur ; le catalog et routines.yaml disent brood).
; Routine arcade : 1000:7d68 (re-rtype data/routines.yaml, id 36) ;
; sprites : entites `brood` et `zoid` du catalog re.arcade.r-type.
;
;*******************************************************************************
;*******************************************************************************

brood.Object
        jmp   stage2.cast.stub          ; implementation vide : compter, rendre le slot
