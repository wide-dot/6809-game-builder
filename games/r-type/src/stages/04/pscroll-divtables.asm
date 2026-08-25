; ****************************************************************************
; pscroll — les tables de division de grow, GENEREES
;
; tools/gen_pscroll_divtables.py — ne pas editer a la main.
;
; Deux divisions par une constante sur une plage bornee : une table plate et
; un `ldb b,x` remplacent les boucles de soustractions successives. La
; premiere rend n/3 sur 0..175 (la largeur du ruban plus le reste de
; son origine), la seconde n/6 sur 0..191 (une ligne dans le champ).
; ****************************************************************************

; La taille est EXPORTEE : pscroll.sweep borne son index avant de lire, les
; armes qui l'appellent ne garantissent pas toutes leur plage.
pscroll.div3.SIZE equ 176
pscroll.div6.SIZE equ 192

pscroll.div3.tbl
        fcb   0,0,0,1,1,1,2,2,2,3,3,3,4,4,4,5
        fcb   5,5,6,6,6,7,7,7,8,8,8,9,9,9,10,10
        fcb   10,11,11,11,12,12,12,13,13,13,14,14,14,15,15,15
        fcb   16,16,16,17,17,17,18,18,18,19,19,19,20,20,20,21
        fcb   21,21,22,22,22,23,23,23,24,24,24,25,25,25,26,26
        fcb   26,27,27,27,28,28,28,29,29,29,30,30,30,31,31,31
        fcb   32,32,32,33,33,33,34,34,34,35,35,35,36,36,36,37
        fcb   37,37,38,38,38,39,39,39,40,40,40,41,41,41,42,42
        fcb   42,43,43,43,44,44,44,45,45,45,46,46,46,47,47,47
        fcb   48,48,48,49,49,49,50,50,50,51,51,51,52,52,52,53
        fcb   53,53,54,54,54,55,55,55,56,56,56,57,57,57,58,58

pscroll.div6.tbl
        fcb   0,0,0,0,0,0,1,1,1,1,1,1,2,2,2,2
        fcb   2,2,3,3,3,3,3,3,4,4,4,4,4,4,5,5
        fcb   5,5,5,5,6,6,6,6,6,6,7,7,7,7,7,7
        fcb   8,8,8,8,8,8,9,9,9,9,9,9,10,10,10,10
        fcb   10,10,11,11,11,11,11,11,12,12,12,12,12,12,13,13
        fcb   13,13,13,13,14,14,14,14,14,14,15,15,15,15,15,15
        fcb   16,16,16,16,16,16,17,17,17,17,17,17,18,18,18,18
        fcb   18,18,19,19,19,19,19,19,20,20,20,20,20,20,21,21
        fcb   21,21,21,21,22,22,22,22,22,22,23,23,23,23,23,23
        fcb   24,24,24,24,24,24,25,25,25,25,25,25,26,26,26,26
        fcb   26,26,27,27,27,27,27,27,28,28,28,28,28,28,29,29
        fcb   29,29,29,29,30,30,30,30,30,30,31,31,31,31,31,31
