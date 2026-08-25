#!/usr/bin/env python3
"""Regarde cytron ramper : on l'amene dans le champ de vision et on le suit.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/shot_cytron.py dist/to8.fd [trames]

Saute la mire, amene la camera devant la position de depart de cytron, le
laisse jouer son script arcade, puis capture — et relit sa position, sa pose et
la cellule qu'il vient de semer, pour que le rendu se juge sur des chiffres et
pas seulement a l'oeil.
"""
import os, re, shutil, sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
from mcp import Toje

image = os.path.abspath(sys.argv[1])
trames = int(sys.argv[2]) if len(sys.argv) > 2 else 400
dest = sys.argv[3] if len(sys.argv) > 3 else "/tmp/claude-501/cytron.png"
LWMAP = os.path.join(os.path.dirname(image),
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")
sym = {}
for line in open(LWMAP):
    m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
    if m:
        sym[m.group(1)] = int(m.group(2), 16) + 0x6100

t = Toje()


def wr(name, *b):
    t.call("write_memory", {"addr": "%04X" % sym[name],
                            "bytes": ["%02X" % v for v in b]})


def rd(name, n=1):
    return t.read("%04X" % sym[name], n)


def w16(name):
    b = rd(name, 2)
    return (b[0] << 8) | b[1]


t.boot_floppy(image)
wr("smiley.loop", 0)                   # pas de mire : on veut le champ nu
wr("smiley.row", 60)
wr("cytron.enable", 0)
t.call("run_frames", {"n": 30})

# la camera devant le point de depart : cytron entre a la cellule START_X
depart = 200 * 3                       # cellules -> px de carte
cible = max(0, depart - 60)
wr("ctrlspeedx", 1, 0)
wr("pscroll.camera.speedx", 1, 0)
for _ in range(900):
    if w16("pscroll.camera.x") >= cible:
        break
    t.call("run_frames", {"n": 10})
wr("pscroll.camera.speedx", 0, 0)
wr("ctrlspeedx", 0, 0)
print("camera figee a", w16("pscroll.camera.x"),
      "-> cellules", w16("pscroll.camera.x") // 3, "..",
      w16("pscroll.camera.x") // 3 + 53)

wr("cytron.enable", 255)
t.call("run_frames", {"n": trames})
print("cytron : x=%.2f cellules  y=%.2f  pose=%d  derniere cellule sondee=(%d,%d)"
      % (w16("cytron.x") / 256.0, w16("cytron.y") / 256.0,
         rd("cytron.img")[0], w16("cytron.col"), rd("cytron.row")[0]))
print("mutations comptees :", t.read("9D06", 1)[0])
shutil.copy(t.call("screenshot")["path"], dest)
print("capture ->", dest)
t.close()
