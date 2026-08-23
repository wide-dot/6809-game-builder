#!/usr/bin/env python3
"""Capture la mire du banc a un instant precis de son cycle.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/shot_smiley.py dist/to8.fd <rangee>

<rangee> est la valeur de smiley.row a atteindre : 30 = la mire vient d'etre
entierement dessinee, 60 = elle vient d'etre entierement effacee. Le script
attend cette valeur, capture, et dit ou il a ecrit l'image.
"""
import os, re, shutil, sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
from mcp import Toje

image = os.path.abspath(sys.argv[1])
cible = int(sys.argv[2]) if len(sys.argv) > 2 else 30
dest = sys.argv[3] if len(sys.argv) > 3 else "/tmp/claude-501/smiley.png"
LWMAP = os.path.join(os.path.dirname(image),
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")

sym = {}
for line in open(LWMAP):
    m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
    if m:
        sym[m.group(1)] = int(m.group(2), 16) + 0x6100

t = Toje()
t.boot_floppy(image)
adr = "%04X" % sym["smiley.row"]
vu = -1
for i in range(300):
    r = t.read(adr, 1)[0]
    if r != vu:
        print("trame ~%4d : smiley.row = %d" % (i * 10, r), flush=True)
        vu = r
    if r >= cible:
        break
    t.call("run_frames", {"n": 10})
else:
    print("!! smiley.row n'a pas atteint", cible)
p = t.call("screenshot")["path"]
shutil.copy(p, dest)
print("capture ->", dest, " (smiley.row =", t.read(adr, 1)[0], ")")
t.close()
