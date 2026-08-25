#!/usr/bin/env python3
"""Enregistre une vidéo (GIF animé) d'une image disquette sous toje.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/record.py dist/to8.fd sortie.gif \
        [--skip N] [--frames N] [--every K] [--press-start] [--scale S]

Composition pure des outils MCP existants : les trames avancent en TURBO
(run_frames fast=true — mêmes instructions, mêmes cycles), et une trame sur
`every` est rendue à la demande par `screenshot` (re-rastérisée depuis la
VRAM courante, donc juste même en turbo). Le GIF garde la VITESSE DE
CAPTURE (25 img/s quel que soit `every`) : le film est accéléré d'un
facteur every/2. Le TO8 affiche 16 couleurs — le GIF est sans perte.

  --skip N        avance de N trames en turbo avant d'enregistrer (défaut 0)
  --frames N      durée de l'enregistrement en trames machine (défaut 1500)
  --every K       une vignette toutes les K trames (défaut 5 -> 10 img/s)
  --press-start   appuie sur la touche du menu/title avant d'enregistrer
  --press-until ADDR=VV
                  appuie sur la touche par rafales jusqu'à ce que l'octet
                  hexa ADDR vaille VV (l'idiome des lanes : entrer dans le
                  jeu en guettant un témoin, ex. 8767=01 pour r-type)
  --scale S       réduction entière de la vignette (défaut 2 -> 352x312)
  --stage N       entre directement dans le stage N par le cheat du title
                  (tct.pstage), invincible arme. Demande --gamedir : les
                  adresses sont lues dans dist/occupancy-fd.html et les
                  .lwmap du jeu, jamais codées en dur.
  --gamedir DIR   la racine du jeu (ex. games/r-type), pour --stage
"""
import argparse, os, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp import Toje, bench_block
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument("image")
p.add_argument("out")
p.add_argument("--skip", type=int, default=0)
p.add_argument("--frames", type=int, default=1500)
p.add_argument("--every", type=int, default=5)
p.add_argument("--press-start", action="store_true")
p.add_argument("--press-until", metavar="ADDR=VV")
p.add_argument("--scale", type=int, default=2)
p.add_argument("--stage", type=int)
p.add_argument("--gamedir", default=".")
a = p.parse_args()

def _sym(mapfile, name, base=0):
    import re
    for l in open(os.path.join(a.gamedir, mapfile)):
        m = re.match(r"Symbol: %s \(.*\) = ([0-9A-Fa-f]+)" % re.escape(name), l)
        if m:
            return base + int(m.group(1), 16)
    raise SystemExit("symbole %s absent de %s" % (name, mapfile))


def _unit(name):
    import re
    occ = open(os.path.join(a.gamedir, "dist/occupancy-fd.html")).read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    if not m:
        raise SystemExit("unite %s absente de l occupancy" % name)
    return int(m.group(1)), int(m.group(2))


def enter_stage(t, n):
    """Poser le cheat du title puis relancer — l'idiome des sondes.

    Le poke de $E7E6 se fait au POINT SUR (gfxlock.bufferSwap.wait, un PC de
    RAM fixe) : ecrire le registre de page pendant que PC est dans la fenetre
    cartouche retire le code sous les pieds du processeur.
    """
    _, engine = _unit("common.engine")
    safe = _sym("gen/common/build/engine.lwmap", "gfxlock.bufferSwap.wait", engine)
    page, addr = _unit("title.cheat")
    addr += _sym("gen/title/build/cheat.lwmap", "tct.pstage") - 0
    for _ in range(40):
        r = t.call("run_until_pc", {"pc": "%04X" % safe, "max_instructions": 400000})
        if isinstance(r, dict) and r.get("reached"):
            break
        t.call("run_frames", {"n": 60})
    else:
        raise SystemExit("point sur jamais atteint")
    t.call("write_memory", {"addr": "0xE7E6", "bytes": ["%02X" % (0x60 + page)]})
    t.call("write_memory", {"addr": hex(addr), "bytes": ["%02X" % n, "01"]})
    ok = t.read(hex(addr), 2) == [n, 1]
    t.call("write_memory", {"addr": "0xE7E6", "bytes": ["78"]})
    if not ok:
        raise SystemExit("le cheat n a pas pris")
    t.press()
    for _ in range(12):
        t.call("run_frames", {"n": 500, "timeout_ms": 600000, "fast": True})
        b = t.read("%04X" % bench_block(a.image), 2)
        if b[0] == 0xCA and b[1] == n:
            return
    raise SystemExit("stage %d jamais seme" % n)


t = Toje()
t.boot_floppy(a.image)
if a.press_start:
    t.press()
    t.call("run_frames", {"n": 25, "timeout_ms": 30000, "fast": True})
if a.stage:
    t.call("run_frames", {"n": 3000, "timeout_ms": 600000, "fast": True})
    enter_stage(t, a.stage)
if a.press_until:
    addr, val = a.press_until.split("=")
    val = int(val, 16)
    for _ in range(200):
        t.press()
        t.call("run_frames", {"n": 100, "timeout_ms": 30000, "fast": True})
        if t.read(addr, 1)[0] == val:
            break
    else:
        raise SystemExit(f"--press-until {a.press_until} jamais atteint")
if a.skip:
    done = 0
    while done < a.skip:                     # run_frames plafonne n à 100000
        step = min(a.skip - done, 50000)
        t.call("run_frames", {"n": step, "timeout_ms": 600000, "fast": True})
        done += step

shots = []
with tempfile.TemporaryDirectory() as tmp:
    png = os.path.join(tmp, "frame.png")
    for i in range(0, a.frames, a.every):
        t.call("run_frames", {"n": a.every, "timeout_ms": 60000, "fast": True})
        t.call("screenshot", {"path": png})
        img = Image.open(png).convert("RGB")
        if a.scale > 1:
            img = img.resize((img.width // a.scale, img.height // a.scale), Image.NEAREST)
        # 16 couleurs machine : la quantification est exacte, le GIF sans perte
        shots.append(img.quantize(colors=64))
        if i and i % 500 == 0:
            print(f"  {i}/{a.frames} trames", flush=True)
t.close()

# Pas de recalage temps réel (décision auteur) : le GIF garde la vitesse de
# capture — une vignette = un pas de lecture à 25 img/s, quel que soit
# `every`. Le film est donc accéléré d'un facteur every*20/40.
ms = 40
shots[0].save(a.out, save_all=True, append_images=shots[1:],
              duration=ms, loop=0, optimize=True)
size = os.path.getsize(a.out)
print(f"{a.out}: {len(shots)} vignettes, {a.frames*20/1000:.1f}s de machine "
      f"en {len(shots)*ms/1000:.1f}s de film (x{a.every*20/ms:.1f}), {size/1024:.0f} Ko")
