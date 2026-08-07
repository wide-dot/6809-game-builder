#!/usr/bin/env python3
"""Convertir un plan de niveau arcade en `in.png`, l'entrée de leanscroll.

Le portage travaille sur une image unique par stage, `src/stages/NN/map/in.png`,
que leanscroll découpe ensuite en tuiles et en carte. Cette image est le plan
AVANT du niveau arcade, réduit au format TO8 et ramené sur la palette 16
couleurs du jeu.

Réduction : 3/8 en X, 3/4 en Y, au plus proche voisin — 3072x240 devient
1152x180. Mesuré : rejoué sur le stage 5, ce sous-échantillonnage reproduit
`in.png` du dépôt au pixel près (100 % des 207 360 pixels), une fois la
correspondance de couleurs appliquée.

Palette : les stages partagent les index 1 à 4, 6, 8 à 14. Restent quatre
emplacements libres — 5, 7, 15, 16 — que chaque stage attribue à ses propres
teintes. L'attribution est faite ici par coût : à chaque tour, l'emplacement va
à la couleur source dont le rattachement au reste de la palette coûte le plus
cher (nombre de pixels x distance RGB), puis les distances sont recalculées.
Les couleurs retenues gardent leur valeur arcade telle quelle — c'est déjà le
cas des emplacements libres des autres stages, et png2pal quantifie au moment
du build.

    usage : tools/arcade_to_in.py <NN> <plan_arcade.png> [options]

    --ref NN        stage dont on reprend la palette de base (défaut 05)
    --free a,b,..   emplacements attribuables (défaut 5,7,15,16)
    --out chemin    sortie (défaut src/stages/<NN>/map/in.png)
    --dry-run       n'écrit rien, affiche seulement la correspondance

Entrée type : re.arcade.r-type/out/tiles/level<N>_f.png
"""
import argparse
import os
import sys
from collections import Counter

from PIL import Image

SCALE_X = 3 / 8
SCALE_Y = 3 / 4
FREE_DEFAULT = [5, 7, 15, 16]


def downscale(src, width, height):
    """Plus proche voisin, phase 0 — celle qui reproduit les stages existants."""
    w, h = src.size
    out = Image.new('RGB', (width, height))
    sp, op = src.load(), out.load()
    for y in range(height):
        ay = y * h // height
        for x in range(width):
            op[x, y] = sp[x * w // width, ay]
    return out


def dist(a, b):
    return sum((u - v) ** 2 for u, v in zip(a, b))


def assign(colors, palette, free):
    """Attribue les emplacements libres, puis rend la correspondance complète.

    `colors` : Counter {rgb: nb_pixels}. `palette` : liste de 256 rgb.
    Les emplacements libres partent non attribués ; ils sont pris un par un par
    la couleur au coût résiduel le plus élevé.
    """
    fixed = [i for i in range(1, 17) if i not in free]
    chosen = {}

    def nearest(c, slots):
        return min(slots, key=lambda i: dist(c, palette[i]))

    slots = list(fixed)
    for slot in free:
        candidates = [c for c in colors if c not in chosen.values()]
        if not candidates:
            break
        worst = max(candidates, key=lambda c: colors[c] * dist(c, palette[nearest(c, slots)]))
        if dist(worst, palette[nearest(worst, slots)]) == 0:
            break  # déjà exactement représentée : l'emplacement ne sert à rien
        palette[slot] = worst
        chosen[slot] = worst
        slots.append(slot)

    return {c: nearest(c, slots) for c in colors}, chosen


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('stage')
    ap.add_argument('plane')
    ap.add_argument('--ref', default='05')
    ap.add_argument('--free', default=','.join(map(str, FREE_DEFAULT)))
    ap.add_argument('--out', default=None)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('-h', '--help', action='store_true')
    args = ap.parse_args()
    if args.help:
        print(__doc__)
        return 0

    free = [int(v) for v in args.free.split(',') if v]
    out_path = args.out or f'src/stages/{args.stage}/map/in.png'

    src = Image.open(args.plane).convert('RGB')
    w, h = src.size
    width, height = round(w * SCALE_X), round(h * SCALE_Y)
    small = downscale(src, width, height)

    ref = Image.open(f'src/stages/{args.ref}/map/in.png')
    palette = ref.getpalette()
    palette = [tuple(palette[i * 3:i * 3 + 3]) for i in range(256)]

    colors = Counter(small.get_flattened_data())
    mapping, chosen = assign(colors, palette, free)

    print(f'{args.plane}  {w}x{h}  ->  {out_path}  {width}x{height}')
    print(f'palette de base : stage {args.ref} ; emplacements attribuables {free}')
    print()
    print(f'{"couleur arcade":18} {"pixels":>8} {"%":>6}  idx  {"couleur TO8":18} ecart')
    total = width * height
    for c, n in colors.most_common():
        i = mapping[c]
        tag = '  <= emplacement pris' if i in chosen and chosen[i] == c else ''
        print(f'  {str(c):16} {n:8} {100 * n / total:5.2f}%  {i:3}  {str(palette[i]):18} '
              f'{dist(c, palette[i]) ** 0.5:5.0f}{tag}')

    if args.dry_run:
        return 0

    out = Image.new('P', (width, height))
    flat = []
    for rgb in palette:
        flat += list(rgb)
    out.putpalette(flat)
    op, sp = out.load(), small.load()
    for y in range(height):
        for x in range(width):
            op[x, y] = mapping[sp[x, y]]
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out.save(out_path)
    print(f'\necrit {out_path}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
