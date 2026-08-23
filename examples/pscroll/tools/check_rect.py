#!/usr/bin/env python3
"""Prouve pscroll.clearRect : la surface balayee, et rien d'autre.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/check_rect.py dist/to8.fd

On pose la mire (640 gommes, un champ dense et connu), on photographie, on
declenche un balayage, on rephotographie. La difference doit etre EXACTEMENT
l'intersection de la surface balayee et de la mire — ni plus (on mangerait des
gommes voisines), ni moins (on en laisserait dans le couloir).

Chaque cas est joue sur une mire fraiche : un balayage ne doit pas dependre de
ce que le precedent a laisse.
"""
import os, re, sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/games/r-type/tools")
from mcp import Toje
from gen_pellet_tables import BALL, BG, CELL_W, CELL_H, VP_Y
from PIL import Image

image = os.path.abspath(sys.argv[1])
LWMAP = os.path.join(os.path.dirname(image),
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")
ORG_X, ORG_Y, PX_W, PX_H = 32, 112, 4, 2

sym = {}
for line in open(LWMAP):
    m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
    if m:
        sym[m.group(1)] = int(m.group(2), 16) + 0x6100

MOTIF = []
for _l in open(os.path.join(os.path.dirname(image),
                            "../src/assets/game-modes/to8/main/smiley.asm")):
    _l = _l.strip()
    if _l.startswith("fcb"):
        MOTIF.append([int(v.strip().lstrip("$"), 16) for v in _l[3:].split(",")])

t = Toje()


def wr(name, *b):
    t.call("write_memory", {"addr": "%04X" % sym[name],
                            "bytes": ["%02X" % v for v in b]})


def rd(name, n=1):
    return t.read("%04X" % sym[name], n)


def pixels():
    p = t.call("screenshot")["path"]
    q = Image.open(p).convert("RGB").load()
    return {(x, y) for y in range(VP_Y, VP_Y + 180) for x in range(160)
            if sum(q[ORG_X + PX_W * x + 1, ORG_Y + PX_H * y]) > 60}


def mire(c, r):
    """la mire porte-t-elle une gomme a cette cellule de motif ?"""
    if not (0 <= c < 32 and 0 <= r < 30):
        return False
    return (MOTIF[r][c >> 3] >> (7 - (c & 7))) & 1


t.boot_floppy(image)
wr("smiley.loop", 0)
wr("cytron.enable", 0)
for _ in range(300):                      # la mire se pose
    if rd("smiley.row")[0] >= 30:
        break
    t.call("run_frames", {"n": 10})
wr("smiley.pause", 255)                   # elle reste
cam = (rd("pscroll.camera.x", 2)[0] << 8) | rd("pscroll.camera.x", 2)[1]
COL0 = (rd("smiley.col0", 2)[0] << 8) | rd("smiley.col0", 2)[1]
print("camera %d, mire aux cellules %d..%d" % (cam, COL0, COL0 + 31))

CAS = [
    ("horizontal, 4x4 balaye de 6 cellules", COL0 + 4, 10, COL0 + 10, 10, 4, 4),
    ("horizontal court (sous le seuil)",     COL0 + 20, 4, COL0 + 21, 4, 4, 4),
    ("vertical, 4x4 balaye de 5 rangees",    COL0 + 14, 2, COL0 + 14, 7, 4, 4),
    ("bande du beam : 2 rangees, 12 cases",  COL0 + 2, 20, COL0 + 10, 20, 4, 2),
    ("debordant a gauche de la carte",       -3, 25, COL0 + 2, 25, 4, 2),
]

ko = 0
for nom, c0, r0, c1, r1, w, h in CAS:
    avant = pixels()
    wr("pscroll.rect.c0", (c0 >> 8) & 0xFF, c0 & 0xFF)
    wr("pscroll.rect.r0", r0)
    wr("pscroll.rect.c1", (c1 >> 8) & 0xFF, c1 & 0xFF)
    wr("pscroll.rect.r1", r1)
    wr("pscroll.rect.w", w)
    wr("pscroll.rect.h", h)
    wr("bench.rect", 1)
    for _ in range(20):
        t.call("run_frames", {"n": 4})
        if rd("bench.rect")[0] == 0:
            break
    t.call("run_frames", {"n": 12})
    for v in ("pscroll.rect.a", "pscroll.rect.b", "pscroll.rect.n"):
        b2 = rd(v, 2)
        print("      %-18s = %d" % (v, (b2[0] << 8) | b2[1]))
    print("      row=%d done=%d edge16=%d"
          % (rd("pscroll.rect.row")[0], rd("pscroll.rect.done")[0],
             rd("pscroll.edge16")[0]))
    apres = pixels()
    partis = avant - apres
    # le modele : la surface balayee, intersectee avec la mire
    attendus = set()
    for r in range(min(r0, r1), max(r0, r1) + h):
        for c in range(min(c0, c1), max(c0, c1) + w):
            if not (0 <= c < 384 and 0 <= r < 30):
                continue
            if not mire(c - COL0, r):
                continue
            for l in range(CELL_H):
                for d in range(CELL_W):
                    if BALL[l][d] != BG:
                        attendus.add((3 * c - cam + d, VP_Y + CELL_H * r + l))
    attendus = {p for p in attendus if 0 <= p[0] < 160}
    if partis == attendus:
        print("  %-40s OK  (%d px effaces)" % (nom, len(partis)))
    else:
        ko += 1
        print("  %-40s %d px en trop, %d oublies"
              % (nom, len(partis - attendus), len(attendus - partis)))
        if partis - attendus:
            print("      en trop :", sorted(partis - attendus)[:6])
        if attendus - partis:
            print("      oublies :", sorted(attendus - partis)[:6])
    # remettre la mire pour le cas suivant
    wr("smiley.row", 0)
    wr("smiley.pause", 255)
    for _ in range(300):
        if rd("smiley.row")[0] >= 30:
            break
        t.call("run_frames", {"n": 10})

print("\nBILAN :", "TOUT CONFORME" if not ko else "%d cas faux" % ko)
t.close()
sys.exit(1 if ko else 0)
