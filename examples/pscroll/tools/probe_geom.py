#!/usr/bin/env python3
"""Lit ce que pscroll.geom a calcule, pour une cellule donnee.

    TOJE_MCP=... python3 tools/probe_geom.py dist/to8.fd <col> <row> [<col> <row> ...]

Pose la cellule par le pilote du banc, puis relit sc.chunk / sc.seam /
sc.chunkoff / sc.dst et les compare a ce que la formule dit. Sert a trancher
entre « la table est fausse » et « le code qui la lit est faux ».
"""
import os, re, sys
from PIL import Image

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
from mcp import Toje

image = os.path.abspath(sys.argv[1])
cibles = [(int(sys.argv[i]), int(sys.argv[i + 1]))
          for i in range(2, len(sys.argv), 2)]
LWMAP = os.path.join(os.path.dirname(image),
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")
sym = {}
for line in open(LWMAP):
    m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
    if m:
        sym[m.group(1)] = int(m.group(2), 16) + 0x6100

ROWS, CELL_H, LINE_SIZE, CPL, CSZ = 30, 6, 80, 10, 8
ROW_BIAS = 9

t = Toje()
t.boot_floppy(image)


def wr(name, *b):
    t.call("write_memory", {"addr": "%04X" % sym[name],
                            "bytes": ["%02X" % v for v in b]})


def rd(name, n=1):
    return t.read("%04X" % sym[name], n)


wr("smiley.loop", 0)
wr("smiley.row", 60)                  # pas de mire : ecran vide
t.call("run_frames", {"n": 40})
cam = (rd("pscroll.camera.x", 2)[0] << 8) | rd("pscroll.camera.x", 2)[1]
print("camera =", cam)

def pixels():
    p = t.call("screenshot")["path"]
    im = Image.open(p).convert("RGB")
    q = im.load()
    return {(x, y) for y in range(200) for x in range(160)
            if sum(q[32 + 4 * x + 1, 112 + 2 * y]) > 60}


for col, row in cibles:
    avant = pixels()
    px = 3 * col
    wr("cytron.col", col >> 8, col & 0xFF)
    wr("cytron.row", row)
    wr("cytron.px", px >> 8, px & 0xFF)
    wr("cytron.erase", 0)
    wr("cytron.enable", 1)
    for _ in range(30):
        t.call("run_frames", {"n": 2})
        if rd("cytron.enable")[0] == 0:
            break
    t.call("run_frames", {"n": 12})    # que les deux tampons soient repeints
    neuf = sorted(pixels() - avant)
    print("  pixels allumes par la mutation :", neuf)
    print("  attendus (3 px x 6 lignes en %d..%d) : x %d..%d, y %d..%d"
          % (row, row, px - cam, px - cam + 2, 11 + 6 * row, 11 + 6 * row + 5))
    chunk = rd("pscroll.sc.chunk")[0]
    seam = rd("pscroll.sc.seam")[0]
    co = rd("pscroll.sc.chunkoff", 2)
    dst = rd("pscroll.sc.dst", 2)
    co = (co[0] << 8) | co[1]
    dst = (dst[0] << 8) | dst[1]
    # ce que la formule dit, pour la PHASE traitee en dernier (la 1)
    att = []
    for phase in (0, 1):
        n0 = px - phase
        c = n0 >> 4
        s = c // CPL
        cof = (CPL - 1 - c % CPL) * CSZ
        line = ROW_BIAS - s + CELL_H * (ROWS - 1 - row) + CELL_H - 1
        att.append((c, s, cof, line * LINE_SIZE + cof + 1))
    pg = rd("pscroll.wr.page0", 2)
    b0 = rd("pscroll.wr.base0", 2)
    b1 = rd("pscroll.wr.base1", 2)
    bp = rd("pscroll.buf.page", 4)
    ph = rd("pscroll.sc.phase")[0]
    print("cellule %3d rangee %2d (px %3d) : chunk=%d seam=%d chunkoff=%d "
          "dst=%d" % (col, row, px, chunk, seam, co, dst))
    print("      phase finale=%d  pages posees=%02X/%02X  (buffers %s)"
          % (ph, pg[0], pg[1], "/".join("%02X" % v for v in bp)))
    print("      bases=%04X/%04X" % ((b0[0] << 8) | b0[1], (b1[0] << 8) | b1[1]))
    for phase, a in enumerate(att):
        print("      phase %d attendu : chunk=%d seam=%d chunkoff=%d dst=%d %s"
              % (phase, a[0], a[1], a[2], a[3],
                 "<-- correspond" if (chunk, seam, co, dst) == a else ""))
t.close()
