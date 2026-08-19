#!/usr/bin/env python3
"""L'effacement doit-il suivre la tilemap ? — le simulateur qui a tranche.

    python3 tools/clear_profile_sim.py [01 02 ...]      # defaut : les 8 stages

L'idee de depart (auteur, 19/08) : la ou la tilemap repeint tout, l'effacement
fait double emploi — un profil par stage, indexe par la position de scroll,
desactiverait des blocs de PSHS. Ce script simule l'idee sur les cartes
reelles, A LA LIGNE (pas a la rangee de tuiles : la granularite se deduit des
donnees), en rejouant la camera au pixel avec la parite plan pair/impair.

CE QUE LA SIMULATION A ETABLI (19/08, les 8 stages) :

1. Les lignes zappables ne sortent QU'EN RANGEES ENTIERES de 12 alignees :
   l'intersection des profils d'opacite sur 13 colonnes tue toute ligne
   partielle (le relief varie trop d'une colonne a l'autre).

2. Le profil DYNAMIQUE (par position de scroll) rapporte peu : 300-900
   cy/trame en moyenne selon le stage, et ZERO dans les salles de boss
   (ouvertes), la ou les trames sont deja les plus cheres. Face au cout
   (table par stage, blast segmente, dispatch runtime), NON RETENU.

3. Les gains qui comptent sont STATIQUES et en BORD de fenetre :
     stage 5 : 18 lignes toujours pleines en HAUT + 18 en bas   (~3 000 cy)
     stage 8 : 18 en bas + une bande fixe lignes 6-17           (~2 200 cy)
     stages 1,2,3,4,6,7 : seulement la rangee du bas, deja hors du blast.
   La bonne mecanique est donc la FENETRE D'EFFACEMENT PAR STAGE, figee a
   l'assemblage (generaliser ROWTOP/ROWEND de clearblast.asm — zero cout
   runtime), pas un profil dynamique.

La regle overlay (blocs 3x6 de ciel -> transparents, rangee du bas exclue,
cf. sky_transparent.py) est appliquee en memoire : le script lit les in.png
tels que commites, traites ou non.
"""
import sys

from PIL import Image

TILE, ROWS = 12, 15
CY_LINE = 40 * 2 * 1.556              # 124,5 cy la ligne (deux plans, blast)
FR_PX = 16 / 3                        # trames machine par pixel de camera
BOSS_DWELL = 4600                     # trames a scroll_max (mesure toje, stage 1)

def load(stage):
    im = Image.open(f"src/stages/{stage}/map/in.png").convert("P")
    px = im.load()
    W, H = im.size
    sky = set()
    for cx in range(0, W, 3):
        for cy in range(0, H - 12, 6):        # rangee du bas exclue (contrat)
            if all(px[cx + i, cy + j] == 1 for j in range(6) for i in range(3)):
                sky.add((cx, cy))
    def opaque(x, y):
        return px[x, y] != 0 and (x // 3 * 3, y // 6 * 6) not in sky
    return opaque, W, H

for stage in (sys.argv[1:] or [f"{n:02d}" for n in range(1, 9)]):
    opaque, W, H = load(stage)
    COLS = W // TILE
    # masque 12 bits par cellule : la ligne j de la cellule est pleinement opaque
    lm = [[0] * ROWS for _ in range(COLS)]
    for c in range(COLS):
        for r in range(ROWS):
            m = 0
            for j in range(TILE):
                if all(opaque(c * TILE + i, r * TILE + j) for i in range(TILE)):
                    m |= 1 << j
            lm[c][r] = m
    smax = W - 144

    # --- le profil dynamique : lignes zappables par position camera ----------
    tot = w = 0.0
    boss_n = zero = 0
    for cam in range(0, smax + 1, 2):
        c0 = cam // TILE
        nc = 12 if cam % TILE == 0 else 13
        n = 0
        for r in range(ROWS):
            acc = 0xFFF
            for c in range(c0, min(c0 + nc, COLS)):
                acc &= lm[c][r]
                if not acc:
                    break
            y0 = r * TILE
            n += sum(1 for j in range(TILE)
                     if acc >> j & 1 and 11 <= y0 + j + 11 <= 178)
        d = FR_PX * 2 + (BOSS_DWELL if cam >= smax - 1 else 0)
        tot += n * d
        w += d
        if cam >= smax - 1:
            boss_n = n
        if n == 0:
            zero += 1

    # --- la fenetre statique : lignes toujours pleines, sur toute la carte ---
    always = {y for y in range(H)
              if all(opaque(x, y) for x in range(W))}
    top = 0
    while top in always:
        top += 1
    bot = H - 1
    while bot in always:
        bot -= 1
    mid = sorted(y for y in always if top <= y <= bot)

    print(f"stage {stage}: dynamique {tot/w:5.1f} lignes/trame "
          f"({tot/w*CY_LINE:5.0f} cy, boss {boss_n*CY_LINE:5.0f}, "
          f"zero {100*zero/(smax//2+1):3.0f} %) | statique : "
          f"haut {top} lignes, bas {H-1-bot} lignes"
          + (f", bande fixe {mid[0]}-{mid[-1]}" if mid else "")
          + f" -> fenetre [{11+top}..{10+bot+1}] ecran, "
            f"{(top + (H-12-1-bot))*CY_LINE:+5.0f} cy/trame gratuits")
