#!/usr/bin/env python3
"""Simule le cout en cycles d'une mise a jour du buffer pscroll, par granularite.

LE LAYOUT DE DESTINATION (c'est lui qui commande)
-------------------------------------------------
BM16 : px X -> plan (X>>1)&1  (0 = $C000, 1 = $A000), octet X>>2, quartet X&1.
Donc un OCTET porte 2 px ADJACENTS (4b et 4b+1 pour le plan 0), et l'ecran
alterne de plan tous les 2 px.

Le buffer mscroll est du CODE : chunk = ldd #imm / ldx #imm / pshs d,x, soit
4 octets de donnees pour UN plan = 16 px d'ecran (dont 8 px lui appartiennent).
L'unite d'ecriture naturelle est donc l'OPERANDE de 2 octets, qui couvre une
travee de 8 px d'ecran (4 px de son plan).

  chunk (par plan) : [ldd #AABB][ldx #CCDD]
                      \_octets 0,1_/\_2,3_/
                       travee 8 px   travee 8 px

PAS DE READ-MODIFY-WRITE : le bitfield donne le contenu COMPLET de l'octet,
on le reecrit toujours en entier. Le quartet n'est donc jamais une unite.

COUTS 6809 (cycles, page directe non utilisee ici)
  lda #imm 2 | ldd #imm 3 | lda n,y 5 | ldd n,y 6
  sta n,u  5 | std n,u  6 | leau n,u 5 | ldu #imm 3
"""
from collections import Counter

W_BYTES, ROWS, LINES_PER_ROW = 48, 30, 6
CELLS = W_BYTES * 8
CY = dict(lda_imm=2, ldd_imm=3, lda_tab=5, ldd_tab=6,
          sta=5, std=6, leau=5, ldu=3)


def units_touched(x0, npx):
    """Operandes (plan, chunk, index) touches par une travee de npx px a x0."""
    out = set()
    for x in range(x0, x0 + npx):
        plane = (x >> 1) & 1
        byte = x >> 2
        out.add((plane, byte >> 2, (byte & 3) >> 1))   # (plan, chunk, operande)
    return out


def bytes_touched(x0, npx):
    out = set()
    for x in range(x0, x0 + npx):
        out.add(((x >> 1) & 1, x >> 2))
    return out


# --- combien d'unites une gomme de 3 px touche-t-elle, selon son alignement ---
print("=== une gomme (3 px) : ce qu'elle touche dans le buffer ===")
d_op, d_by = Counter(), Counter()
for c in range(CELLS):
    d_op[len(units_touched(3 * c, 3))] += 1
    d_by[len(bytes_touched(3 * c, 3))] += 1
print(f"  operandes (2 o) touches : {dict(sorted(d_op.items()))}  sur {CELLS} colonnes")
print(f"  octets touches          : {dict(sorted(d_by.items()))}")
print("  -> resultat NET : quel que soit son alignement, une gomme touche")
print("     TOUJOURS exactement 2 octets, un par plan, dans 2 operandes.")
print("     L'entrelacement des plans tous les 2 px l'interdit d'aller plus")
print("     loin : 3 px, c'est 2 px d'un plan et 1 px de l'autre.\n")

# --- le cout d'une mise a jour, par granularite -------------------------------
GRAINS = [("gomme, 3 px", 3), ("2 gommes, 6 px", 6), ("travee, 8 px", 8),
          ("periode du motif, 12 px", 12), ("chunk entier, 16 px", 16)]


def cost(npx, mode, nlines, nphases, source="table", aligned=False):
    """cycles pour rafraichir npx px sur nlines lignes, les 2 plans, nphases.

    aligned=True : la travee tombe sur une frontiere de chunk (le cas du feed
    de scroll, ou la colonne entrante EST un chunk). Sinon on prend le pire
    alignement, qui est le cas d'une gomme quelconque dans le champ."""
    worst = 0
    for x0 in ([0] if aligned else range(0, 48, 1)):
        if mode == "octet":
            u = bytes_touched(x0, npx)
            ld = CY["lda_tab"] if source == "table" else CY["lda_imm"]
            st = CY["sta"]
        else:
            u = units_touched(x0, npx)
            ld = CY["ldd_tab"] if source == "table" else CY["ldd_imm"]
            st = CY["std"]
        per_plane = Counter(p for p, *_ in u)
        # une passe par (plan, phase) : U pose une fois, puis leau par ligne
        c = 0
        for p in (0, 1):
            n = per_plane.get(p, 0)
            if not n:
                continue
            c += CY["ldu"] + nlines * (n * (ld + st) + CY["leau"])
        worst = max(worst, c * nphases)
    return worst


print("=== cout d'UNE mise a jour (6 lignes = une rangee de cellules) ===")
print("valeurs = pire alignement ; source des donnees = table precalculee\n")
print(f"{'granularite':26s} {'octet/octet':>12s} {'operande 2 o':>13s}   1 px = x2")
for name, npx in GRAINS:
    b = cost(npx, "octet", LINES_PER_ROW, 1)
    w = cost(npx, "operande", LINES_PER_ROW, 1)
    print(f"{name:26s} {b:9d} cy {w:10d} cy   {w*2:6d} cy")

print("\n=== evenements de jeu reels (1 px : les DEUX phases) ===")


def event(name, cells, npx_each, note=""):
    """cells = nb de zones distinctes a rafraichir, npx_each = largeur de zone"""
    per = cost(npx_each, "operande", LINES_PER_ROW, 2)
    print(f"  {name:44s} {cells * per:7d} cy   {note}")


event("1 gomme mangee (tir simple)", 1, 3)
event("amas 2x2 du Force pod (6 px, 2 rangees)", 2, 6, "2 rangees de 6 lignes")
event("Force pod : 4 amas 2x2, champ VIERGE", 8, 6, "le pic, une seule fois")
event("Force pod stationnaire (0 a 4 transitions)", 1, 6, "garde pellet.test")
event("tir dans un tunnel deja creuse", 0, 3, "aucune ecriture")

print("\n=== gravure d'une colonne entiere (feed de scroll, chunk ALIGNE) ===")
print(f"{'grappe':24s} {'lignes':>7s} {'table 2px':>10s} {'table 1px':>10s} "
      f"{'deroule 1px':>12s}")
for nl, lbl in ((180, "grande salle"), (96, "rideaux d'entree"), (24, "rideau isole")):
    t1 = cost(16, "operande", nl, 1, source="table", aligned=True)
    d1 = cost(16, "operande", nl, 1, source="code", aligned=True)
    print(f"{lbl:24s} {nl:7d} {t1:8d} cy {t1*2:8d} cy {d1*2:10d} cy")

print("\n=== amorti par trame, dans la grande salle ===")
COL = cost(16, "operande", 180, 2, source="table", aligned=True)
for vit in (1.0, 1.6, 2.0):
    trames = 16 / vit
    print(f"  a {vit:.1f} px/trame : une colonne tous les {trames:4.1f} trames "
          f"-> {COL/trames:6.0f} cy/trame amortis ({100*COL/trames/54000:.1f} % du blast)")
print(f"\n  traversee complete de la salle (12 colonnes) : {12*COL} cy au total")
print(f"  le NIVEAU entier : 15 colonnes non vides -> {15*COL} cy,")
print(f"  soit ce que la passe actuelle brule en {15*COL/691537:.1f} trame(s).")

print("\n=== taille du code si l'on deroule (question des routines cablees) ===")
# par ligne et par plan : ldd #imm (3 o) + std n,u (2 o) x2 operandes + leau (3 o)
oct_ligne = 2 * (3 + 2) + 3
print(f"  deroulement PLEIN d'une colonne : {oct_ligne} o/ligne/plan"
      f" x 180 x 2 plans = {oct_ligne*180*2} o par motif et par phase")
print(f"  -> 11 motifs x 2 phases = {oct_ligne*180*2*11*2} o = "
      f"{oct_ligne*180*2*11*2/16384:.1f} pages : REDHIBITOIRE")
print(f"  deroulement d'UNE RANGEE (6 lignes) + boucle sur 30 rangees :"
      f" {oct_ligne*6*2} o, partage par tous les motifs : NEGLIGEABLE")


# =============================================================================
# LES COMBINAISONS VERTICALES (proposition auteur, 22/08)
# -----------------------------------------------------------------------------
# Plutot que d'ecrire au pas de 3 px, on MAXIMISE la maj a la bande de 16 px,
# soit 8 px par plan. La vue d'un plan sur cette bande est un peigne : 2 px,
# saut de 2 px, 2 px... = 4 octets. La carte etant connue au build, on enumere
# les combinaisons verticales de ce peigne et on genere une routine cablee par
# combinaison. Point cle : la combinaison ne mentionne PAS le plan — le meme
# peigne se retrouve dans les deux, ce qui partage les routines.
# =============================================================================
def _cell(dat, c, r):
    if c < 0 or c >= CELLS:
        return 0
    return (dat[r * W_BYTES + (c >> 3)] >> (7 - (c & 7))) & 1


def combinaisons(path="src/stages/04/terrain/level4_ball.bin"):
    dat = open(path, "rb").read()

    def rowcombo(x0, r):
        out = []
        for j in range(4):                      # 4 paires, une tous les 4 px
            x = x0 + 4 * j
            out.append((x % 3, _cell(dat, x // 3, r), _cell(dat, (x + 1) // 3, r)))
        return tuple(out)

    inst = {}
    for c in range(1152 // 16):
        for p in (0, 1):                        # plan 0 : x0=16c ; plan 1 : +2
            for r in range(ROWS):
                inst.setdefault(rowcombo(16 * c + 2 * p, r), []).append((c, p, r))
    vide = lambda k: not any(a or b for _, a, b in k)
    p0 = {k for k, v in inst.items() if any(p == 0 for _, p, _ in v)}
    p1 = {k for k, v in inst.items() if any(p == 1 for _, p, _ in v)}
    nv = [k for k in inst if not vide(k)]

    oct_l = 2 * (3 + 2) + 3                     # ldd#/std,u  ldd#/std3,u  leau
    cy_l = (3 + 5) + (3 + 6) + 5
    print("\n=== combinaisons verticales : une rangee (6 lignes) x 4 o d'un plan ===")
    print(f"  instances dans le niveau : {len(inst) and sum(len(v) for v in inst.values())}")
    print(f"  COMBINAISONS DISTINCTES  : {len(inst)}  ({len(nv)} non vides)")
    print(f"  vues par le plan 0 : {len(p0)} | par le plan 1 : {len(p1)} | "
          f"COMMUNES : {len(p0 & p1)}")
    print(f"  routines si les plans sont separes : {len(p0) + len(p1)}")
    print(f"  routines si elles sont PARTAGEES   : {len(inst)}   "
          f"-> {len(p0) + len(p1) - len(inst)} de moins "
          f"({100 * (len(p0) + len(p1) - len(inst)) // (len(p0) + len(p1))} %)")
    print(f"\n  code : {oct_l * 6} o par routine x {len(inst)} x 2 phases = "
          f"{oct_l * 6 * len(inst) * 2} o ({oct_l * 6 * len(inst) * 2 / 1024:.1f} Ko)")
    print(f"  cout : {cy_l * 6} cy par appel (un plan, 6 lignes)")
    print(f"         {cy_l * 6 * 4} cy pour une rangee complete (2 plans, 2 phases)")
    print(f"         {cy_l * 6 * ROWS * 4} cy pour une COLONNE entiere "
          f"(contre 20892 en table : -25 %)")


if __name__ == "__main__":
    import os
    if os.path.exists("src/stages/04/terrain/level4_ball.bin"):
        combinaisons()
    else:
        print("\n(lancer depuis games/r-type/ pour l'analyse des combinaisons)")
