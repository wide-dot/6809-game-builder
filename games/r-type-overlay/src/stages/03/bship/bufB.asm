; Buffer de code mscroll du battleship, plan 1 (RAMB, zone $A000-$BFFF).
; Le flux de chunks genere par <mscroll output="start"> : BUFFER_LINES=181
; lignes (viewport r-type 180 + la ligne du jmp de sortie), toutes porteuses
; du contenu de la vue (0, 0) de la carte. Tourne monte en espace cartouche :
; la cible du jmp de bouclage est l'adresse de chargement, $0000 dans sa page.

mscroll.buffer.b
        INCLUDEBIN "gen/stages/03/bship/battleship.start.1.bin"
        jmp   >mscroll.buffer.b            ; extended force : DP est sur la
                                           ; page engine pendant le blast
