;*******************************************************************************
; wick — SQUELETTE (chantier 3) : le cast du stage 2 n'a pas de source v1,
; il sera cree depuis la reference arcade. Ce squelette donne a l'objet son
; unite, son id et ses lignes de wave : il spawne par l'index du stage,
; compte son passage dans les temoins du banc, et se supprime aussitot —
; une implementation vide ne bloque jamais le pool d'objets.
;
; A implementer (bestiaire re-rtype) : unite volante qui arrive de l'avant
; vers le milieu du stage. Un seul spawn dans la wave.
; Routine arcade : 1000:875d (re-rtype data/routines.yaml, id 15) ;
; sprites : entite `wick` du catalog re.arcade.r-type.
;
;*******************************************************************************
;*******************************************************************************

wick.Object
        jmp   stage2.cast.stub          ; implementation vide : compter, rendre le slot
