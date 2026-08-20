; Buffer de code mscroll du battleship, plan 0 (RAMA, zone $C000-$DFFF).
; Le flux de chunks genere par <mscroll output="start"> : BUFFER_LINES=181
; lignes (viewport r-type 180 + la ligne du jmp de sortie), toutes porteuses
; du contenu de la vue (0, 0) de la carte. Tourne monte en espace cartouche :
; la cible du jmp de bouclage est l'adresse de chargement, $0000 dans sa page.

mscroll.buffer.a
        INCLUDEBIN "gen/stages/03/bship/battleship.start.0.bin"
        jmp   >mscroll.buffer.a            ; extended force : DP est sur la
                                           ; page engine pendant le blast
