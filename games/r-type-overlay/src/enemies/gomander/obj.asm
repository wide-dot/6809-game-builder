;*******************************************************************************
; gomander — SQUELETTE (chantier 3) : le cast du stage 2 n'a pas de source v1,
; il sera cree depuis la reference arcade. Ce squelette donne a l'objet son
; unite, son id et ses lignes de wave : il spawne par l'index du stage,
; compte son passage dans les temoins du banc, et se supprime aussitot —
; une implementation vide ne bloque jamais le pool d'objets.
;
; A implementer (bestiaire re-rtype) : le BOSS du stage 2 — masse de chair
; a un oeil, orbe bleu intermittent comme point faible, protege par
; l'Outslay qui entre et sort de ses tubes pour regenerer.
; Routine arcade : 1000:a22e (re-rtype data/routines.yaml, id 28) ;
; sprites : entite `gomander` du catalog re.arcade.r-type.
;
;*******************************************************************************
;*******************************************************************************

gomander.Object
        jmp   stage2.cast.stub          ; implementation vide : compter, rendre le slot
