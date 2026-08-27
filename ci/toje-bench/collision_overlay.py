#!/usr/bin/env python3
"""Superpose les plans de collision d'un stage sur une capture d'écran TO8.

    cd games/r-type
    python3 ../../ci/toje-bench/collision_overlay.py dist/to8.fd overlay.png \
        --stage 3 --until-camera 430 [--cheat-invincible] [--fire]

Sert à répondre à UNE question : « ce que le jeu teste tombe-t-il sur ce que
le joueur voit ? » — un décalage entre la carte de collision et le décor
dessiné est invisible en lecture de code et saute aux yeux ici.

La projection n'est pas une reconstitution approchée : elle rejoue
l'ARITHMÉTIQUE EXACTE de `terrainCollision.loadMap`, avec les variables lues
en RAM **au moment même de la capture** (caméra, scroll_tile_pos, offset24,
et les bases du plan attaché). C'est ce qui rend le verdict opposable : si le
vert (foreground) tombe pile sur le sol dessiné, la projection est calibrée,
et alors tout écart du rouge (background) est un vrai défaut d'alignement.

Trouvé avec, le 26/08/2026 : la silhouette du battleship du stage 3 dérivait
du vaisseau dessiné — 64 px à son arrivée, 252 px plus loin — parce que le
plan background était indexé sur la caméra principale alors que le vaisseau
est dessiné par une couche mscroll qui a la sienne.

Prérequis : le stage doit avoir une unité de collision (`terrain/terrain.asm`)
et ses .bin lisibles depuis le dépôt.
"""
import argparse
import glob
import json
import os
import platform
import re
import subprocess
import sys

from mcp import Toje, bench_block

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow requis : python3 -m pip install pillow")

# --- géométrie du lookup, identique à engine/objects/collision/ -------------
CELL_W, CELL_H = 3, 6           # une cellule de collision, en pixels TO8
BLOCK_W = 24                    # un octet de carte couvre 24 px (8 cellules)
VIEW_TOP = 11                   # haut du champ de jeu (yOffset equ *-22)
ROWS = 30                       # 30 lignes de 6 px = 180 px de champ

# --- géométrie de la fenêtre toje ------------------------------------------
# 704 x 624 = bordures + 320x200 doublés en x, doublés en y.
BORDER_X, BORDER_Y, SCALE_X, SCALE_Y = 32, 112, 4, 2


def engine_symbols(config="to8.config.xml", gensource="gen/common/engine.asm"):
    """Adresse absolue des variables du lookup, DÉRIVÉE du build courant.

    Les coder en dur serait un piège : les offsets d'une unité bougent à chaque
    repack de l'arène. On réassemble donc l'unité résidente avec les `<define>`
    du config et on lit son dump de symboles ; l'adresse de base vient du
    config lui-même (`common.engine` est à page/adresse fixes, il n'apparaît
    pas dans gen/layout.asm).
    """
    xml = open(config).read()
    m = re.search(r'<file name="common\.engine"[^>]*address="\$?([0-9A-Fa-f]+)"', xml)
    if not m:
        sys.exit("adresse de common.engine introuvable dans %s" % config)
    base = int(m.group(1), 16)

    defines = []
    for sym, val in re.findall(r'<define symbol="([^"]+)"(?:\s+value="([^"]*)")?\s*/>', xml):
        defines += ["-D", "%s=%s" % (sym, val) if val else "%s=1" % sym]

    osdir = {"Darwin": "macos", "Linux": "linux"}.get(platform.system(), "windows")
    lwasm = glob.glob(os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..", "..", "toolbox", "third-party", "bin", osdir + "*", "lwasm"))
    if not lwasm:
        sys.exit("lwasm introuvable sous toolbox/third-party/bin/")
    sym = "/tmp/collision_overlay.sym"
    r = subprocess.run([lwasm[0], "-9", "--obj", "-I", ".", "-o", "/dev/null",
                        "--symbol-dump=" + sym] + defines + [gensource],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit("lwasm a echoue :\n" + r.stderr[:800])
    want = ("scroll_tile_pos", "scroll_tile_pos_offset24",
            "terrainCollision.bgLayer", "terrainCollision.bgLayer.x",
            "terrainCollision.bgLayer.y")
    out = {}
    for line in open(sym):
        p = line.split()
        if len(p) == 3 and p[0] in want and p[1] == "EQU":
            out[p[0]] = base + int(p[2].lstrip("$"), 16)
    missing = set(want) - set(out)
    if missing:
        sys.exit("symboles absents du dump : %s" % ", ".join(sorted(missing)))
    return out


def cheat(t, stage, invincible=True):
    """Séquence du title : h,b,g,d puis N×haut = stage N ; +bas = invincible."""
    def jp(d=None, a=False):
        t.call("press_joystick", {"joystick": 0, "hold_frames": 6,
                                  **({"direction": d} if d else {}),
                                  **({"button_a": True} if a else {})})
    t.call("run_frames", {"n": 600, "fast": False, "timeout_ms": 60000})
    if invincible:
        for d in ("up", "down", "left", "right", "down"):
            jp(d)
    for d in ("up", "down", "left", "right"):
        jp(d)
    for _ in range(stage):
        jp("up")
    jp(a=True)


def read_word(t, addr):
    b = t.read(addr, 2)
    return (b[0] << 8) | b[1]


def snapshot(image, stage, until_camera, out_png, sym, fire=False):
    """Amène le jeu au point voulu, puis fige capture + variables du lookup."""
    t = Toje()
    t.boot_floppy(image)
    t.call("set_pointer_device", {"device": "none"})
    bench = bench_block(image)
    cheat(t, stage)

    for _ in range(60):
        t.call("run_frames", {"n": 200, "fast": True, "timeout_ms": 60000})
        if t.read("%04X" % bench, 5)[1] == stage:
            break
    else:
        t.close()
        sys.exit("stage %d jamais atteint" % stage)

    cam = 0
    for _ in range(60):
        t.call("run_frames", {"n": 300, "fast": True, "timeout_ms": 60000})
        b = t.read("%04X" % bench, 7)
        cam = (b[3] << 8) | b[4]
        if cam >= until_camera:
            break
    t.call("run_frames", {"n": 30, "fast": False, "timeout_ms": 20000})

    if fire:
        t.call("press_joystick", {"joystick": 0, "hold_frames": 8,
                                  "button_a": True})
        t.call("run_frames", {"n": 10, "fast": False, "timeout_ms": 20000})

    # L'INSTANTANÉ : capture et variables lues machine arrêtée, donc cohérents.
    t.call("screenshot", {"path": out_png})
    st = {
        "stage": stage,
        "camx": read_word(t, "9FE6"),                    # glb_camera_x_pos
        "scroll_tile_pos": t.read("%04X" % sym["scroll_tile_pos"], 1)[0],
        "offset24": t.read("%04X" % sym["scroll_tile_pos_offset24"], 1)[0],
        "bgLayer": t.read("%04X" % sym["terrainCollision.bgLayer"], 1)[0],
        "bgLayer_x": read_word(t, "%04X" % sym["terrainCollision.bgLayer.x"]),
        "bgLayer_y": read_word(t, "%04X" % sym["terrainCollision.bgLayer.y"]),
        "camera": cam,
    }
    t.close()
    return st


def s16(v):
    return v - 65536 if v > 32767 else v


class Plane:
    """Un plan de collision et la façon dont loadMap l'indexe."""

    def __init__(self, path, width_bytes):
        self.raw = open(path, "rb").read()
        self.w = width_bytes
        self.rows = len(self.raw) // width_bytes

    def cell(self, col, row):
        """col est un index de CELLULE (3 px), pas d'octet."""
        if not (0 <= col < self.w * 8 and 0 <= row < self.rows):
            return False
        return (self.raw[row * self.w + (col >> 3)] >> (7 - (col & 7))) & 1

    def solid_scroll(self, st, sx, sy):
        """Chemin standard : indexé sur le scroll principal."""
        if not (VIEW_TOP <= sy < VIEW_TOP + ROWS * CELL_H):
            return False
        b = sx + st["offset24"]
        if b < 8:
            return False
        blk, cell = (b - 8) // BLOCK_W, ((b - 8) % BLOCK_W) // CELL_W
        col = (blk + st["scroll_tile_pos"]) * 8 + cell
        return self.cell(col, (sy - VIEW_TOP) // CELL_H)

    def solid_layer(self, st, sx, sy):
        """Chemin attaché : indexé dans le repère de la couche (bgAttached)."""
        lx = sx + s16(st["bgLayer_x"])
        ly = (sy - VIEW_TOP) + s16(st["bgLayer_y"])
        if not (0 <= lx < self.w * BLOCK_W) or not (0 <= ly < self.rows * CELL_H):
            return False
        return self.cell(lx // CELL_W, ly // CELL_H)


def compose(st, shot_png, out_png, fc, bc):
    shot = Image.open(shot_png).convert("RGBA")
    ov = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    attached = bool(st["bgLayer"])
    for sy in range(VIEW_TOP, VIEW_TOP + ROWS * CELL_H):
        py = BORDER_Y + sy * SCALE_Y
        for sx in range(160):
            px = BORDER_X + sx * SCALE_X
            box = [px, py, px + SCALE_X - 1, py + SCALE_Y - 1]
            if bc and (bc.solid_layer(st, sx, sy) if attached
                       else bc.solid_scroll(st, sx, sy)):
                d.rectangle(box, fill=(255, 40, 40, 110))
            if fc and fc.solid_scroll(st, sx, sy):
                d.rectangle(box, fill=(40, 255, 80, 110))
    out = Image.alpha_composite(shot, ov)
    d2 = ImageDraw.Draw(out)
    d2.text((36, 8), "VERT = foreground (calibration : doit tomber sur le decor)",
            fill=(80, 255, 120))
    d2.text((36, 24), "ROUGE = background%s" %
            (" — ATTACHE a une couche" if attached else ""), fill=(255, 80, 80))
    d2.text((36, 40), "stage %d  camx=%d  tile_pos=%d  off24=%d%s" % (
        st["stage"], st["camx"], st["scroll_tile_pos"], st["offset24"],
        ("  base=(%d,%d)" % (s16(st["bgLayer_x"]), s16(st["bgLayer_y"])))
        if attached else ""), fill=(255, 255, 255))
    out.convert("RGB").save(out_png)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("out", help="PNG composé")
    ap.add_argument("--stage", type=int, required=True)
    ap.add_argument("--until-camera", type=int, default=200,
                    help="avancer jusqu'a cette camera avant de figer")
    ap.add_argument("--fire", action="store_true", help="tirer avant la capture")
    ap.add_argument("--terrain-dir", default=None,
                    help="defaut : src/stages/<NN>/terrain")
    args = ap.parse_args()

    tdir = args.terrain_dir or "src/stages/%02d/terrain" % args.stage
    tasm = os.path.join(tdir, "terrain.asm")
    if not os.path.exists(tasm):
        sys.exit("pas d'unite de collision : %s" % tasm)
    width = None
    for line in open(tasm):
        if "lvlMapWidth" in line and "equ" in line:
            width = int(line.split("equ")[1].split(";")[0].strip())
    if not width:
        sys.exit("lvlMapWidth introuvable dans %s" % tasm)

    def plane(suffix):
        p = os.path.join(tdir, "level%d_%s.bin" % (args.stage, suffix))
        return Plane(p, width) if os.path.exists(p) else None

    fc, bc = plane("fc"), plane("bc")
    sym = engine_symbols()
    shot = os.path.splitext(args.out)[0] + "_shot.png"
    st = snapshot(args.image, args.stage, args.until_camera, shot, sym, args.fire)
    print(json.dumps(st), flush=True)
    compose(st, shot, args.out, fc, bc)
    print("compose -> %s" % args.out)


if __name__ == "__main__":
    main()
