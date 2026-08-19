;*******************************************************************************
; mid — SQUELETTE (lot F de la bibliothèque) : pas de source v1, il sera
; créé depuis la référence arcade. Ce squelette donne à l'objet son unité,
; son id et ses lignes de wave dans les stages 5 et 7 : il spawne par
; l'index du stage, compte son passage dans les témoins du banc, et se
; supprime aussitôt — une implémentation vide ne bloque jamais le pool.
;
; Routine arcade : 0x5cea (re-rtype data/routines.yaml, index 19), citée
; 14 fois par la wave du stage 5 et 2 fois par celle du stage 7 — le seul
; ennemi multi-stages sans implémentation, d'où sa place dans la
; bibliothèque dès maintenant (analyse-lots-ennemis-2026-08.md).
;*******************************************************************************

mid.Object
        jmp   lib.mid.stub              ; implementation vide : compter, rendre le slot
