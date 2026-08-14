#!/usr/bin/env python3
"""Enregistre une vidéo (GIF animé) d'une image disquette sous toje.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/record.py dist/to8.fd sortie.gif \
        [--skip N] [--frames N] [--every K] [--press-start] [--scale S]

Composition pure des outils MCP existants : les trames avancent en TURBO
(run_frames fast=true — mêmes instructions, mêmes cycles), et une trame sur
`every` est rendue à la demande par `screenshot` (re-rastérisée depuis la
VRAM courante, donc juste même en turbo). Le GIF rejoue en temps réel :
chaque vignette dure every*20 ms. Le TO8 affiche 16 couleurs — le GIF est
sans perte.

  --skip N        avance de N trames en turbo avant d'enregistrer (défaut 0)
  --frames N      durée de l'enregistrement en trames machine (défaut 1500)
  --every K       une vignette toutes les K trames (défaut 5 -> 10 img/s)
  --press-start   appuie sur la touche du menu/title avant d'enregistrer
  --press-until ADDR=VV
                  appuie sur la touche par rafales jusqu'à ce que l'octet
                  hexa ADDR vaille VV (l'idiome des lanes : entrer dans le
                  jeu en guettant un témoin, ex. 8767=01 pour r-type)
  --scale S       réduction entière de la vignette (défaut 2 -> 352x312)
"""
import argparse, os, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp import Toje
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
a = p.parse_args()

t = Toje()
t.boot_floppy(a.image)
if a.press_start:
    t.press()
    t.call("run_frames", {"n": 25, "timeout_ms": 30000, "fast": True})
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

ms = a.every * 20                            # rejoue en temps réel (50 Hz)
shots[0].save(a.out, save_all=True, append_images=shots[1:],
              duration=ms, loop=0, optimize=True)
size = os.path.getsize(a.out)
print(f"{a.out}: {len(shots)} vignettes, {a.frames*20/1000:.1f}s de machine, {size/1024:.0f} Ko")
