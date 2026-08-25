#!/usr/bin/env python3
"""Le smiley du banc : une mire de 32 x 30 cellules, en gommes.

    python3 tools/gen_smiley.py

Pourquoi une mire et pas un dessin : une cellule de gomme fait 3 px sur 6
lignes, et le pixel BM16 est deux fois plus large que haut — une cellule est
donc a peu pres CARREE a l'ecran, et un disque trace sur la grille de
cellules doit apparaitre rond. S'il apparait ovale, la geometrie est fausse.
Les yeux et la bouche sont des CREUX : ils verifient qu'une cellule vide
reste vide au milieu de voisines pleines, ce qu'un aplat ne dirait pas.

Sortie : src/assets/game-modes/to8/main/smiley.asm — 30 rangees de 4 octets,
bit 7 = la cellule la plus a gauche, comme le champ de gommes lui-meme.
"""
import os

W, H = 32, 30
CX, CY = (W - 1) / 2.0, (H - 1) / 2.0
R = 14.6


def dedans(c, r):
    """le disque, en unites ECRAN : une cellule vaut 3 px sur 6 lignes, et
    un px BM16 vaut deux unites de large — donc 6 x 6, une cellule carree."""
    dx = (c - CX)
    dy = (r - CY)
    return dx * dx + dy * dy <= R * R


def oeil(c, r, ox, oy):
    return abs(c - ox) <= 1 and abs(r - oy) <= 1


def bouche(c, r):
    # un arc : la moitie basse d'un anneau, epais d'une cellule
    dx = (c - CX)
    dy = (r - (CY - 1.5))
    if dy <= 1.5:
        return False
    d = (dx * dx / 1.0 + dy * dy) ** 0.5
    return 7.4 <= d <= 8.8


def cellule(c, r):
    if not dedans(c, r):
        return False
    if oeil(c, r, CX - 5, CY - 4) or oeil(c, r, CX + 5, CY - 4):
        return False
    if bouche(c, r):
        return False
    return True


lignes = []
for r in range(H):
    bits = [cellule(c, r) for c in range(W)]
    octets = []
    for k in range(0, W, 8):
        v = 0
        for i, b in enumerate(bits[k:k + 8]):
            if b:
                v |= 1 << (7 - i)
        octets.append(v)
    lignes.append(octets)
    print("".join("#" if b else "." for b in bits))

out = os.path.join(os.path.dirname(__file__),
                   "../src/assets/game-modes/to8/main/smiley.asm")
L = [";" + "*" * 78,
     "; Le smiley du banc — GENERE par tools/gen_smiley.py, ne pas editer.",
     ";",
     "; 32 cellules x 30 rangees, bit 7 = la cellule la plus a gauche. Le banc",
     "; le dessine une rangee par trame en appelant pscroll.setCell, puis",
     "; l'efface de la meme facon : c'est la mire des deux chemins de mutation.",
     ";" + "*" * 78,
     "bench.smiley.W equ %d" % W,
     "bench.smiley.H equ %d" % H,
     "bench.smiley"]
for octets in lignes:
    L.append("        fcb   " + ",".join("$%02X" % v for v in octets))
open(out, "w").write("\n".join(L) + "\n")
print("\necrit", os.path.normpath(out), "—", sum(
    bin(v).count("1") for o in lignes for v in o), "gommes")
