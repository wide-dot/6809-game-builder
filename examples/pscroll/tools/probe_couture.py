#!/usr/bin/env python3
"""LE DECALAGE D'UNE LIGNE AUX COUTURES — repro, non resolu au 23/08/2026.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/probe_couture.py

Le plan de gommes s'affiche UNE LIGNE TROP BAS sur les derniers pixels de
camera avant certaines coutures, puis se remet exactement au pas de couture.
Ce que la sonde etablit :

  - stable et reproductible (cinq mesures identiques au repos), donc ni une
    capture en vol ni un artefact de double-buffer ;
  - c'est bien un decalage d'UNE ligne vers le bas de TOUT le plan (verifie en
    image : les rangees larges du motif tombent une ligne plus bas), pas une
    dechirure ni un decalage horizontal ;
  - il tient sur camera mod 160 dans [153..159] et disparait au pas de couture
    (stretch++ / origin--) ;
  - il ne touche PAS toutes les coutures : celle de 640 est saine, celles de
    800 et 960 non — c'est ce qui interdit de conclure a un simple +8 manquant
    dans le seuil de couture (move compare camera.x a seam.tbl, alors que
    l'index de bande derive de camera.x + 8 : la theorie predit 152..159 a
    TOUTES les coutures, ce que la mesure dementit) ;
  - stretch, origin et seam.tbl sont mutuellement coherents a l'instant du
    defaut : startline = ROW_BIAS - bande/10 et origin = ROW_BIAS - 1 - stretch
    concordent sur les bandes visibles. La contradiction est donc ailleurs.

ATTENTION, piege : poker pscroll.origin pour tester ne prouve rien et ABIME le
ruban — runBuffer y pose un jmp de sortie qu'il restaure a la ligne d'origine ;
changer origin entre deux trames laisse un jmp orphelin dans le buffer.

C'est le defaut a fermer avant de migrer pscroll dans games/r-type."""
import os, re, sys
sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/games/r-type/tools")
from mcp import Toje
from gen_pellet_tables import BALL, BG, CELL_H, VP_Y
from PIL import Image

BASE = "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/examples/pscroll"
sym = {}
for l in open(BASE + "/gen/assets/game-modes/to8/main/build/main.lwmap"):
    m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', l.strip())
    if m:
        sym[m.group(1)] = int(m.group(2), 16) + 0x6100
t = Toje()
t.boot_floppy(BASE + "/dist/to8.fd")
wr = lambda n, *b: t.call("write_memory", {"addr": "%04X" % sym[n],
                                           "bytes": ["%02X" % v for v in b]})
rb = lambda n: t.read("%04X" % sym[n], 1)[0]
def w16(n):
    b = t.read("%04X" % sym[n], 2); return (b[0] << 8) | b[1]
S = 48
def diff():
    cam = w16("pscroll.camera.x")
    c = bytearray()
    for off in range(0, S * 30, 240):
        c += bytes(t.read("%04X" % (sym["field.map"] + off), min(240, S * 30 - off)))
    bit = lambda cc, rr: (c[rr * S + (cc >> 3)] >> (7 - (cc & 7))) & 1
    q = Image.open(t.call("screenshot")["path"]).convert("RGB").load()
    vu = {(x, y) for y in range(VP_Y, VP_Y + 180) for x in range(12, 148)
          if sum(q[32 + 4 * x + 1, 112 + 2 * y]) > 60}
    att = set()
    for X in range(12, 148):
        cc, d = divmod(cam + X, 3)
        for r in range(30):
            if 0 <= cc < 384 and bit(cc, r):
                for l in range(CELL_H):
                    if BALL[l][d] != BG:
                        att.add((X, VP_Y + CELL_H * r + l))
    # est-ce le decalage d'UNE ligne vers le bas ?
    shift = len({(x, y + 1) for (x, y) in att} & vu)
    return cam, att - vu, vu - att, shift

wr("smiley.loop", 0); wr("smiley.row", 60); wr("cytron.enable", 0)
t.call("run_frames", {"n": 30})

for cible in (636, 796, 956):
    wr("pscroll.camera.speedx", 3, 0); wr("ctrlspeedx", 3, 0)
    for _ in range(400):
        t.call("run_frames", {"n": 2})
        if w16("pscroll.camera.x") >= cible - 6:
            break
    wr("pscroll.camera.speedx", 0, 0); wr("ctrlspeedx", 0, 0)
    for _ in range(6):
        t.call("run_frames", {"n": 1})
    print("--- fenetre autour de %d (camera %% 160 = %d)" % (cible, cible % 160))
    vus = set()
    for _ in range(90):
        cam, mq, tr, sh = diff()
        if cam not in vus:
            vus.add(cam)
            etat = "OK" if not (mq or tr) else (
                "DECALE D'UNE LIGNE" if sh > 0.8 * len(mq) else "AUTRE (%d/%d)" % (sh, len(mq)))
            print("   camera %4d (mod160=%3d) stretch=%d origin=%d edge16=%2d "
                  "window=%2d : %s"
                  % (cam, cam % 160, rb("pscroll.stretch"), rb("pscroll.origin"),
                     rb("pscroll.edge16"), rb("pscroll.window"), etat))
        if cam >= cible + 4:
            break
        wr("pscroll.camera.speedx", 0, 0x30); wr("ctrlspeedx", 0, 0x30)
        t.call("run_frames", {"n": 1})
        wr("pscroll.camera.speedx", 0, 0); wr("ctrlspeedx", 0, 0)
        for _ in range(3):
            t.call("run_frames", {"n": 1})
t.close()
