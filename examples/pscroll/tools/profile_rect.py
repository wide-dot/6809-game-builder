#!/usr/bin/env python3
"""Ce que coute un effacement en masse, sur une mire DETERMINISTE.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/profile_rect.py dist/to8.fd

Une cellule deja vide ne coute que son rejet : mesurer un effacement sur un
champ dont on ne connait pas le remplissage ne veut rien dire. Deux campagnes
du 23/08 ont donne 148 puis 621 cycles par cellule pour le MEME cas, l'ecart
venant du champ et non du code.

Ce script rend donc la mire verifiable : avant chaque cas il compte les pixels
allumes et les GOMMES REELLEMENT PRESENTES dans le rectangle vise, et il refuse
de conclure si le compte bouge d'un cas a l'autre.
"""
import os, re, sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/games/r-type/tools")
from mcp import Toje
from gen_pellet_tables import VP_Y
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


def wr(n, *b):
    t.call("write_memory", {"addr": "%04X" % sym[n],
                            "bytes": ["%02X" % v for v in b]})


def rd(n, k=1):
    return t.read("%04X" % sym[n], k)


def w16(n):
    b = rd(n, 2)
    return (b[0] << 8) | b[1]


def allumes():
    p = t.call("screenshot")["path"]
    q = Image.open(p).convert("RGB").load()
    return sum(1 for y in range(VP_Y, VP_Y + 180) for x in range(160)
               if sum(q[ORG_X + PX_W * x + 1, ORG_Y + PX_H * y]) > 60)


def mire(c, r):
    if not (0 <= c < 32 and 0 <= r < 30):
        return False
    return (MOTIF[r][c >> 3] >> (7 - (c & 7))) & 1


def poser_mire(reboot=False):
    """redessine la mire et n'en sort que quand elle est COMPLETE.

    Avec reboot : on repart d'une machine neuve. Redessiner par-dessus un champ
    deja entame ne restaure pas tout — mesure du 23/08, 240 pixels manquants
    apres un premier effacement — et un profilage sur un champ inconnu ne veut
    rien dire."""
    if reboot:
        t.boot_floppy(image)
        wr("smiley.loop", 0)
        wr("cytron.enable", 0)
    wr("smiley.row", 0)
    wr("smiley.pause", 255)
    for _ in range(400):
        if rd("smiley.row")[0] >= 30:
            break
        t.call("run_frames", {"n": 10})
    t.call("run_frames", {"n": 24})        # les deux tampons repeints
    return allumes()


t.boot_floppy(image)
wr("smiley.loop", 0)
wr("cytron.enable", 0)
reference = poser_mire()
COL0 = w16("smiley.col0")
print("mire de reference : %d pixels allumes, cellules %d..%d"
      % (reference, COL0, COL0 + 31))

CAS = [
    ("bloc 4x4 seul",           COL0 + 6, 10, COL0 + 6, 10, 4, 4),
    ("4x4 balaye de 6 (union)", COL0 + 4, 10, COL0 + 10, 10, 4, 4),
    ("bande beam 2x12",         COL0 + 2, 20, COL0 + 10, 20, 4, 2),
    ("bande large 2x24",        COL0 + 2, 24, COL0 + 22, 24, 4, 2),
]

LO, HI = sym["pscroll.clearRect"], sym["pscroll.tbl.bit"]
MUT = sym["pscroll.setCell"]

for nom, c0, r0, c1, r1, w, h in CAS:
    n = poser_mire(reboot=True)
    if n != reference:
        print("!! mire NON deterministe : %d pixels au lieu de %d" % (n, reference))
    # les gommes reellement presentes dans le rectangle vise
    gommes = sum(1 for r in range(min(r0, r1), max(r0, r1) + h)
                 for c in range(min(c0, c1), max(c0, c1) + w)
                 if mire(c - COL0, r))
    cases = (max(r0, r1) + h - min(r0, r1)) * (max(c0, c1) + w - min(c0, c1))
    wr("pscroll.rect.c0", (c0 >> 8) & 255, c0 & 255)
    wr("pscroll.rect.r0", r0)
    wr("pscroll.rect.c1", (c1 >> 8) & 255, c1 & 255)
    wr("pscroll.rect.r1", r1)
    wr("pscroll.rect.w", w)
    wr("pscroll.rect.h", h)
    t.call("profile_reset")
    t.call("profile_start")
    wr("bench.rect", 1)
    for _ in range(30):
        t.call("run_frames", {"n": 2})
        if rd("bench.rect")[0] == 0:
            break
    t.call("profile_stop")
    top = t.call("profile_top", {"n": 1000, "by": "cycles"})
    rect = sum(r["cycles"] for r in top.get("rows", []) if LO <= int(r["pc"], 16) < HI)
    mut = sum(r["cycles"] for r in top.get("rows", []) if MUT <= int(r["pc"], 16) < LO)
    print("%-24s %3d cases dont %3d gommes | clearRect %5d + mutation %5d = "
          "%5d cy, soit %4d cy/case et %4d cy/gomme"
          % (nom, cases, gommes, rect, mut, rect + mut,
             (rect + mut) // cases, (rect + mut) // max(gommes, 1)))
t.close()
