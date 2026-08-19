;*******************************************************************************
; gouger — SQUELETTE (chantier 3) : le cast du stage 2 n'a pas de source v1,
; il sera cree depuis la reference arcade. Ce squelette donne a l'objet son
; unite, son id et ses lignes de wave : il spawne par l'index du stage,
; compte son passage dans les temoins du banc, et se supprime aussitot —
; une implementation vide ne bloque jamais le pool d'objets.
;
; A implementer (bestiaire re-rtype) : cache dans le plafond ou le sol,
; jaillit en diagonale a la detection de l'intrus. L'ennemi DOMINANT de la
; wave du stage 2 : 29 de ses 34 spawns de cast.
; Routine arcade : 1000:6f89 (re-rtype data/routines.yaml, id 13) ;
; sprites : entite `gouger` du catalog re.arcade.r-type (4 directions x
; 8 trames, meta-sprites indirects $1307E-$130DE, palette $27).
;
;*******************************************************************************
;*******************************************************************************

gouger.Object
        jmp   stage2.cast.stub          ; implementation vide : compter, rendre le slot
