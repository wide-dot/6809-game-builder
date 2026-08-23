#!/usr/bin/env python3
"""Profile le banc pscroll : ou partent les cycles ?

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/profile_pscroll.py \
        dist/to8.fd [camera_cible] [trames]

Attribue les cycles par ROUTINE, pas par PC : les frontieres viennent du
.lwmap du build, donc elles suivent le code au lieu d'etre recopiees a la
main. Le BLAST, lui, s'execute dans le buffer monte en fenetre cartouche —
il apparait donc comme du temps passe en $0000-$3FFF, et c'est ce qui le
distingue de tout le reste.

Le profileur compte des cycles EMULES : la charge de la machine hote ne le
fausse pas.
"""
import os, re, sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
from mcp import Toje

image = os.path.abspath(sys.argv[1])
target_cam = int(sys.argv[2]) if len(sys.argv) > 2 else 900
frames = int(sys.argv[3]) if len(sys.argv) > 3 else 200
LWMAP = os.path.join(os.path.dirname(image) or ".",
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")
BASE = 0x6100
WIT = 0x9C00


def symbols():
    s = {}
    for line in open(LWMAP):
        m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
        if m:
            s[m.group(1)] = int(m.group(2), 16) + BASE
    return s


sym = symbols()


def rng(name):
    return sym[name]





# Les bornes, dans l'ordre du binaire. Le dernier champ est le libelle.
ORDER = [
    ("pscroll.buildSkeleton",     "squelette (init seul)"),
    ("pscroll.setCameraX",        "setCameraX"),
    ("pscroll.computeStretch",    "computeStretch"),
    ("pscroll.init",              "init"),
    ("pscroll.move",              "move (camera, coutures, feed)"),
    ("pscroll.feedBand",          "feedBand (adressage)"),
    ("pscroll.engraveColumn",     "engraveColumn (dispatch rangee)"),
    ("pscroll.do",                "do (decomposition x)"),
    ("pscroll.runBuffer",         "runBuffer (patch + entree)"),
    ("pscroll.row.tbl",           "table des routines"),
    ("pscroll.row.00",            "ROUTINES DE GRAVURE (cablees)"),
    ("pscroll.row.data",          "donnees de rangee"),
    ("pscroll.col.tbl",           "tables de colonne"),
]

t = Toje()
t.boot_floppy(image)


def wit():
    b = t.read(f"{WIT:04X}", 4)
    return {"frames": b[0], "cam": (b[1] << 8) | b[2]}


for _ in range(60):
    t.call("run_frames", {"n": 100})
    w = wit()
    if w["cam"] >= target_cam:
        break
print("profil a partir de :", wit(), flush=True)

before = wit()
t.call("profile_reset")
t.call("profile_start")
t.call("run_frames", {"n": frames})
t.call("profile_stop")
after = wit()

top = t.call("profile_top", {"n": 1000, "by": "cycles"})
rows = top.get("rows", [])
total = top.get("total_cycles", 0)

bounds = [(sym[n], lbl) for n, lbl in ORDER if n in sym]
bounds.sort()
acc = {lbl: 0 for _, lbl in bounds}
acc["LE BLAST (buffer, fenetre cartouche)"] = 0
acc["main / engine / irq / joypad"] = 0
acc["moniteur"] = 0
listed = 0
for r in rows:
    pc = int(r["pc"], 16)
    c = r["cycles"]
    listed += c
    if pc < 0x4000:
        acc["LE BLAST (buffer, fenetre cartouche)"] += c
    elif pc >= 0xE000:
        acc["moniteur"] += c
    elif pc < bounds[0][0]:
        acc["main / engine / irq / joypad"] += c
    else:
        lbl = bounds[0][1]
        for a, l in bounds:
            if pc >= a:
                lbl = l
            else:
                break
        acc[lbl] += c

rendered = (after["frames"] - before["frames"]) & 0xFF
print(f"camera {before['cam']} -> {after['cam']}, {frames} trames machine, "
      f"{rendered} rendus = {50.0*rendered/frames:.2f} img/s")
print(f"cycles {total}, dont {listed} dans les {len(rows)} PC les plus chauds "
      f"({100.0*listed/total:.1f} %)\n")
print(f"{'poste':40s} {'cycles':>10s} {'%':>7s} {'cy/trame':>10s}")
for lbl, c in sorted(acc.items(), key=lambda kv: -kv[1]):
    if not c:
        continue
    print(f"{lbl:40s} {c:10d} {100.0*c/total:6.2f}% "
          f"{c/rendered if rendered else 0:10.0f}")
t.close()
