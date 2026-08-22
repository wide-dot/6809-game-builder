#!/usr/bin/env python3
"""Table de consultation du script camera warship : arcade vs v2.

Pour chaque entree du script arcade (maincpu 0x1000:6F8A, entrees de 3
octets [vy, vx, trames] — vitesse = v/16 px/trame, cf. SHL AL,4 du tick a
0xc4eb/0xc4ff) : les valeurs brutes, la vitesse interpretee, la conversion
v2 (sx = vx*6, sy = vy*12 en 8.8, trames copiees), les cumuls de temps et
de position, et le CONTROLE de l'entree correspondante du fichier committe
src/stages/03/warship/camera-script.asm ('=' si identique a la conversion
recalculee — 0 divergence au 20/08/2026).

Les cumuls partent du SPAWN du pilote (wave $0100 = ts arcade $2000).
L'autoscroll checkpoint ($0080 arcade / $0030 v2, 256 trames) fait avant
lui +128 px arcade / +48 px v2 en x, NON inclus.

    usage : tools/warship_script_table.py [sortie.txt]
"""
import re, sys, os

ROM = os.path.expanduser(
    '~/Documents/Claude/Projects/re.arcade.r-type/out/rom/maincpu.bin')
INNER = 0x16F8A
GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

rom = open(ROM, 'rb').read()
def s8(b): return b - 256 if b >= 128 else b
segs, off = [], INNER
while rom[off + 2] != 0x80:
    segs.append((s8(rom[off]), s8(rom[off + 1]), rom[off + 2]))  # (vy, vx, fr)
    off += 3

def num(v):
    v = v.strip()
    neg = v.startswith('-')
    if neg: v = v[1:]
    n = int(v[1:], 16) if v.startswith('$') else int(v)
    return -n if neg else n

committed = []
for line in open(os.path.join(GAME, 'src/stages/03/warship/camera-script.asm')):
    s = line.split(';')[0].strip()
    m = re.match(r'(fdb|fcb)\s+(.+)', s) if s else None
    if not m: continue
    for v in m.group(2).split(','):
        committed.append((m.group(1), num(v)))
entries, i = [], 0
while i + 3 <= len(committed):
    (k1, sx), (k2, sy), (k3, fr) = committed[i:i + 3]
    if (k1, k2, k3) != ('fdb', 'fdb', 'fcb'): break
    entries.append((sx, sy, fr)); i += 3

lines = [__doc__, ""]
h = (f"{'#':>3} | {'vy':>4} {'vx':>4} {'fr':>3} | {'arc px/f x':>10} {'y':>7} |"
     f" {'sx v2':>6} {'sy v2':>6} | {'t fin':>5} {'s@55':>6} | {'x arc':>7} {'y arc':>7} |"
     f" {'x v2':>7} {'y v2':>7} | chk")
lines += [h, '-' * len(h)]
t = 0; xa = ya = 0.0; xv = yv = 0; mism = 0
for i, (vy, vx, fr) in enumerate(segs):
    esx, esy = vx * 6, vy * 12
    ok = '='
    if i < len(entries):
        csx, csy, cfr = entries[i]
        if csx != esx or csy != esy or cfr != fr:
            ok = f"DIFF committe=({csx},{csy},{cfr})"; mism += 1
    else:
        ok = 'ABSENT'; mism += 1
    t += fr; xa += vx * fr / 16.0; ya += vy * fr / 16.0
    xv += esx * fr; yv += esy * fr
    lines.append(f"{i:>3} | {vy:>4} {vx:>4} {fr:>3} | {vx/16.0:>10.4f} {vy/16.0:>7.4f} |"
                 f" {esx:>6} {esy:>6} | {t:>5} {t/55:>6.1f} | {xa:>7.1f} {ya:>7.1f} |"
                 f" {xv/256:>7.1f} {yv/256:>7.1f} | {ok}")
lines += ['-' * len(h),
          f"{len(segs)} entrees arcade ; committees {len(entries)}"
          f" (dont terminateur) ; divergences : {mism}",
          f"total : {t} trames = {t/55:.1f}s arcade / {t/50:.1f}s v2"]
out = sys.argv[1] if len(sys.argv) > 1 else 'warship-script-table.txt'
open(out, 'w').write('\n'.join(lines))
print(f"{out}: {len(segs)} entrees, {mism} divergences")
