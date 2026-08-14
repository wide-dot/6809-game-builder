;*******************************************************************************
; outslay — SQUELETTE (chantier 3) : le cast du stage 2 n'a pas de source v1,
; il sera cree depuis la reference arcade. Ce squelette donne a l'objet son
; unite, son id et ses lignes de wave : il spawne par l'index du stage,
; compte son passage dans les temoins du banc, et se supprime aussitot —
; une implementation vide ne bloque jamais le pool d'objets.
;
; A implementer (bestiaire re-rtype) : serpent symbiotique, corps
; invulnerable, boucle a travers la zone sur un chemin fixe. Present ici en
; ennemi REGULIER (un spawn) ; sa forme boss accompagne gomander.
; Routine arcade : 1000:915b (re-rtype data/routines.yaml, id 29) ;
; sprites : entite `outslay` du catalog re.arcade.r-type.
;
;*******************************************************************************
;*******************************************************************************

outslay.Object
        jmp   stage2.cast.stub          ; implementation vide : compter, rendre le slot
