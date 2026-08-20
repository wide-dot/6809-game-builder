#!/usr/bin/env python3
"""Trace le chemin camera de la couche battleship sur la carte mscroll.

Reference = integrale v2 du script arcade (memes conversions que le pilote :
autoscroll checkpoint $0030 pendant 256 trames, puis sx=vx*6 / sy=vy*12 par
trame). Deux sorties :
  warship-path-deplie.png : Y sans wrap — au-dessus du trait, la camera est
      au-dessus du haut de carte (le wrap 384 montre du ciel)
  warship-path.png        : espace carte (Y wrappe 384)
Trait = coin haut-gauche du viewport 160x180 (rectangle vert = t0), couleur
bleu->jaune->rouge avec le temps, points blancs toutes les 20 s v2.

    usage : tools/warship_path.py  (depuis games/r-type-overlay)
"""
import os
from PIL import Image, ImageDraw

ROM = os.path.expanduser(
    '~/Documents/Claude/Projects/re.arcade.r-type/out/rom/maincpu.bin')
INNER = 0x16F8A; MAP_W, MAP_H = 640, 384
GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

rom = open(ROM, 'rb').read()
def s8(b): return b - 256 if b >= 128 else b
segs, off = [], INNER
while rom[off + 2] != 0x80:
    segs.append((s8(rom[off + 1]) * 6, s8(rom[off]) * 12, rom[off + 2]))
    off += 3
pts = []; x = y = t = 0
for _ in range(256):
    x += 0x30; t += 1; pts.append((t, x / 256.0, y / 256.0))
for sx, sy, fr in segs:
    for _ in range(fr):
        x += sx; y += sy; t += 1; pts.append((t, x / 256.0, y / 256.0))

def col(tt):
    f = tt / pts[-1][0]
    if f < 0.5:
        a = f * 2; return (int(60 + 195 * a), int(120 + 135 * a), int(255 * (1 - a)))
    a = (f - 0.5) * 2; return (255, int(255 * (1 - a)), 0)

src = Image.open(os.path.join(GAME, 'src/stages/03/map/battleship.png')).convert('RGB')
Z = 2

def render(unwrapped):
    PAD = 80 if unwrapped else 0
    H = ((200 + PAD) if unwrapped else MAP_H) * Z
    img = Image.new('RGB', (MAP_W * Z, H), (10, 10, 30))
    m = Image.eval(src.resize((MAP_W * Z, MAP_H * Z), Image.NEAREST),
                   lambda v: v * 2 // 3)
    img.paste(m.crop((0, 0, MAP_W * Z, (200 if unwrapped else MAP_H) * Z)),
              (0, PAD * Z))
    d = ImageDraw.Draw(img)
    if unwrapped:
        d.line([(0, PAD * Z), (MAP_W * Z, PAD * Z)], fill=(60, 60, 90))
    def P(px, py):
        if not unwrapped: py %= MAP_H
        return (px * Z, (py + PAD) * Z)
    d.rectangle([P(0, 0), P(160, 180)], outline=(80, 255, 80), width=2)
    prev = None
    for (tt, px, py) in pts[::4]:
        p = P(px, py)
        if prev and abs(p[1] - prev[1]) < MAP_H * Z / 2:
            d.line([prev, p], fill=col(tt), width=3)
        prev = p
    for (tt, px, py) in pts:
        if tt % 1000 == 0:
            p = P(px, py)
            d.ellipse((p[0]-5, p[1]-5, p[0]+5, p[1]+5), fill=(255,255,255), outline=0)
            d.text((p[0]+7, p[1]-14), f"{tt//50}s", fill=(255, 255, 255))
    sp = P(pts[255][1], pts[255][2])
    d.ellipse((sp[0]-7, sp[1]-7, sp[0]+7, sp[1]+7), outline=(80, 255, 80), width=3)
    d.text((sp[0]+9, sp[1]+2), "spawn pilote", fill=(80, 255, 80))
    return img

render(True).save('warship-path-deplie.png')
render(False).save('warship-path.png')
print("-> warship-path-deplie.png, warship-path.png,", len(pts), "trames")
