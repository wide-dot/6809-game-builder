#!/usr/bin/env python3
"""Les deux tables de division de pscroll.grow — GENEREES.

    python3 tools/gen_pscroll_divtables.py        (depuis games/r-type)

pscroll.grow convertit un point (pixel de carte, ligne ecran) en cellule de
gomme. Les deux conversions sont des divisions par une constante, et elles
etaient faites par soustractions successives : la division par 3 tournait
jusqu'a 380 fois par appel (elle divisait la coordonnee de CARTE, qui croit
avec le niveau), pour 42,7 % du temps machine releve a la camera 665 le
24/08/2026.

Une division par une constante sur une plage bornee, c'est une table. Les
deux plages le sont :
  - la colonne : pscroll.grow soustrait d'abord l'origine du ruban et refuse
    tout ce qui n'y tient pas, donc l'operande vaut 0..161, plus le reste de
    l'origine (0..2) ;
  - la rangee : une ligne ecran moins le haut du champ, donc 0..188.

Les valeurs tiennent sur un octet (54 et 31 au plus) : deux tables plates,
un `ldb b,x` chacune. Voir la reference maison DIV3u/DIV6u
(src/common/weapons/forcepods/obj_reboundlaser.asm) — une reciproque par
`mul`, ~60 cycles ; ici la plage est assez petite pour faire mieux encore.
"""
import os

OUT = "src/stages/04/pscroll-divtables.asm"
CELL_W, CELL_H = 3, 6
COL_SPAN = 176          # 0..161 d'offset + 0..2 de reste, arrondi
ROW_SPAN = 192          # 0..188 de ligne dans le champ, arrondi


def bloc(nom, n, div, commentaire):
    L = [f"{nom}"]
    for base in range(0, n, 16):
        vals = ",".join(str(i // div) for i in range(base, min(base + 16, n)))
        L.append(f"        fcb   {vals}")
    return L


L = [
    "; ****************************************************************************",
    "; pscroll — les tables de division de grow, GENEREES",
    ";",
    "; tools/gen_pscroll_divtables.py — ne pas editer a la main.",
    ";",
    "; Deux divisions par une constante sur une plage bornee : une table plate et",
    "; un `ldb b,x` remplacent les boucles de soustractions successives. La",
    f"; premiere rend n/{CELL_W} sur 0..{COL_SPAN - 1} (la largeur du ruban plus le reste de",
    f"; son origine), la seconde n/{CELL_H} sur 0..{ROW_SPAN - 1} (une ligne dans le champ).",
    "; ****************************************************************************",
    "",
]
L += bloc("pscroll.div3.tbl", COL_SPAN, CELL_W, None)
L.append("")
L += bloc("pscroll.div6.tbl", ROW_SPAN, CELL_H, None)
L.append("")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w").write("\n".join(L))
print(f"ecrit {OUT} : div3 sur {COL_SPAN} octets, div6 sur {ROW_SPAN}")
