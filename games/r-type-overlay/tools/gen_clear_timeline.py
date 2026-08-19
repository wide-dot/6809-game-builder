#!/usr/bin/env python3
"""Genere la timeline d'effacement d'un stage — les changements de fenetre.

    python3 tools/gen_clear_timeline.py [01 02 ...]     # defaut : 01

Le blast d'effacement (clearblast.asm) est pilote par deux operandes : la
borne BASSE (operande du LDS) et la borne HAUTE (offset de saut dans le
deroule). Ce script les precalcule depuis in.png, a la maille de la rangee
de tuiles (12 px), et n'emet que les CHANGEMENTS — le tick de stage-main
applique une entree quand la camera franchit son seuil.

La regle : une rangee n'est zappable a une position camera que si TOUTES
les cellules de la fenetre visible (12-13 colonnes) y sont pleinement
peintes — apres la regle overlay (blocs de ciel 3x6 transparents, cf.
sky_transparent.py), appliquee ici en memoire pour lire les in.png traites
ou non. Seules les rangees CONSECUTIVES depuis le haut (t) et depuis le
bas (b) se zappent : la fenetre reste contigue, c'est ce que deux
operandes savent dire. Le blast ne presume rien : meme la rangee du bas
(que sky_transparent.py maintient peinte) est DEDUITE de la carte ici —
elle donne b >= 1 partout, ce n'est pas une regle codee en dur.
L'analyse est ERODEE d'un pixel de camera de chaque cote : le plan impair
est l'art decale d'un pixel, une transition ne doit jamais s'appliquer un
pixel trop tot.

Fenetre emise : lignes ecran [11+12t .. 190-12b], poussees arrondies
AU-DESSUS (le depassement, 8 octets au plus, sort par la borne haute,
couverte par la rangee zappee ou le masque).

Sortie : src/stages/<st>/clear-timeline.asm, inclus par l'unite du stage.
"""
import sys

from PIL import Image

TILE, ROWS = 12, 15
NPUSH = 800                            # le deroule du blast (tout le champ, 11-190)

def load(stage):
    im = Image.open(f"src/stages/{stage}/map/in.png").convert("P")
    px = im.load()
    W, H = im.size
    sky = set()
    for cx in range(0, W, 3):
        for cy in range(0, H - 12, 6):
            if all(px[cx + i, cy + j] == 1 for j in range(6) for i in range(3)):
                sky.add((cx, cy))
    def opaque(x, y):
        return px[x, y] != 0 and (x // 3 * 3, y // 6 * 6) not in sky
    return opaque, W, H

for stage in (sys.argv[1:] or ["01"]):
    opaque, W, H = load(stage)
    COLS = W // TILE
    smax = W - 144

    # rangee pleinement couverte, par cellule
    full = [[all(opaque(c * TILE + i, r * TILE + j)
                 for j in range(TILE) for i in range(TILE))
             for r in range(ROWS)] for c in range(COLS)]

    def tb(cam):
        """(rangees zappees en haut, en bas) a cette position camera"""
        c0 = cam // TILE
        nc = 12 if cam % TILE == 0 else 13
        cols = range(c0, min(c0 + nc, COLS))
        def row_ok(r):
            return all(full[c][r] for c in cols)
        t = 0
        while t < ROWS - 1 and row_ok(t):
            t += 1
        b = 0
        while b < ROWS - t - 1 and row_ok(ROWS - 1 - b):
            b += 1
        return t, b

    # l'erosion d'un pixel de chaque cote (plan impair = art decale de 1 px)
    raw = [tb(cam) for cam in range(smax + 1)]
    def eroded(cam):
        lo, hi = max(0, cam - 1), min(smax, cam + 1)
        return (min(raw[c][0] for c in (lo, cam, hi)),
                min(raw[c][1] for c in (lo, cam, hi)))

    entries = []
    prev = None
    for cam in range(smax + 1):
        cur = eroded(cam)
        if cur != prev:
            t, b = cur
            top_line = 11 + 12 * t
            bot_line = 190 - 12 * b
            nbytes = (bot_line - top_line + 1) * 40
            count = -(-nbytes // 9)                    # arrondi au-dessus
            assert count <= NPUSH, (stage, cam, cur)
            lds = 0xA000 + (bot_line + 1) * 40
            assert lds - 9 * count >= 0xA000 + 10 * 40, (stage, cam, cur)
            skip = 2 * (NPUSH - count)
            entries.append((cam, lds, skip, t, b, top_line, bot_line))
            prev = cur
    out = f"src/stages/{stage}/clear-timeline.asm"
    with open(out, "w") as f:
        f.write(f"""; GENERE par tools/gen_clear_timeline.py — NE PAS EDITER.
; La timeline d'effacement du stage {stage} : seulement les CHANGEMENTS de
; fenetre, precalcules pour clearblast.asm. Une entree = [camera(2),
; operande LDS plan couleur(2), offset de saut(2)] ; sentinelle $FFFF.
; t/b = rangees de tuiles zappees en haut/bas de la fenetre.
clear.timeline
""")
        for cam, lds, skip, t, b, tl, bl in entries:
            f.write(f"        fdb   {cam},${lds:04X},{skip}"
                    f"   ; t={t} b={b} lignes {tl}-{bl}\n")
        f.write("        fdb   $FFFF                ; fin — la camera n'y va jamais\n")
    rows_saved = sum(1 for c in range(smax+1) if eroded(c)[0] or eroded(c)[1] > 1)
    print(f"stage {stage}: {len(entries)} changements -> {out} "
          f"({6*len(entries)+2} octets) ; haut ou bas etendu sur "
          f"{100*rows_saved/(smax+1):.0f} % des positions")
