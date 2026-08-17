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

    --pal-next      convertit contre la NOUVELLE palette (campagne 08/2026) :
                    base = les 12 communs de pal-next.png, emplacements
                    attribuables = les cases propres au stage (13, 14, 16 PNG,
                    plus 15 si l'olive n'y est pas gelée). L'olive 617A00 est
                    PRÉ-CHARGÉE en 15 PNG (matériel 14) quand un lot d'ennemis
                    du stage la porte — le gel se mesure dans cast.const.asm et
                    les images des lots, jamais dans une liste écrite. Écrit
                    AUSSI la palette dédiée src/stages/<NN>/palette/pal.png,
                    depuis la même affectation : les deux ne peuvent pas
                    diverger. --ref et --free sont ignorés dans ce mode.

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


PAL_NEXT = 'src/stages/01/palette/pal-next.png'
OLIVE = (0x61, 0x7A, 0x00)
MAGENTA = (0xCC, 0x00, 0xFF)


def _usage_mod():
    """Le releve palette_usage, importe comme module — une seule source pour
    « quels lots ce stage charge » et « quelles images porte un lot »."""
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        'palette_usage', os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                      'palette_usage.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def olive_gelee(stage):
    """L'olive est-elle gravee en materiel 14 sur ce stage ? Vrai si un LOT
    charge par le stage a une image qui emploie l'index materiel 14. Mesure —
    cast.const.asm + scenes du config + PNG des lots — parce que la liste
    « 1, 3, 4, 5, 7 » n'est vraie que tant que le cast la rend vraie."""
    import xml.etree.ElementTree as ET
    pu = _usage_mod()
    lots = pu.lots_du_stage('stage%d' % int(stage), '.')
    if not lots:
        return False
    root = ET.parse('to8.config.xml').getroot()
    scenes = {sc.get('name'): [l.get('name') for l in sc.iter('load')]
              for sc in root.iter('scene')}
    unites = {u for lot in lots for u in scenes.get('scenes.lot.%s' % lot, [])}
    for f in root.iter('file'):
        if f.get('name') not in unites:
            continue
        for g in f.iter('gfxcomp'):
            for png in pu.expanse(g, '.'):
                if Image.open(png).histogram()[15]:      # PNG 15 = materiel 14
                    return True
    return False


def palette_pal_next(stage):
    """(palette 256 rgb, emplacements attribuables) du mode --pal-next.
    PNG 1..12 = les 12 communs de pal-next ; 13..16 = les cases du stage,
    attribuables — sauf 15 (materiel 14), pre-chargee olive si gelee."""
    p = Image.open(PAL_NEXT).getpalette()
    communs = [tuple(p[i * 3:i * 3 + 3]) for i in range(1, 13)]
    palette = [MAGENTA] + communs + [(0, 0, 0)] * 243
    free = [13, 14, 15, 16]
    if olive_gelee(stage):
        palette[15] = OLIVE
        free = [13, 14, 16]
    return palette, free


def ecrire_pal(stage, palette, chosen):
    """La palette dediee du stage, depuis la MEME affectation que l'in.png.
    Les cases propres restees sans teinte sortent en noir — visible dans le
    fichier, et le noir est la valeur la moins intrusive si un pixel egare
    les touche."""
    out = os.path.join('src/stages/%s/palette' % stage, 'pal.png')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im = Image.new('P', (1, 1))
    flat = []
    for i in range(256):
        flat += list(palette[i] if i <= 16 else (0, 0, 0))
    im.putpalette(flat)
    im.save(out)
    return out


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('stage')
    ap.add_argument('plane')
    ap.add_argument('--ref', default='05')
    ap.add_argument('--free', default=','.join(map(str, FREE_DEFAULT)))
    ap.add_argument('--out', default=None)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--pal-next', action='store_true')
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

    if args.pal_next:
        palette, free = palette_pal_next(args.stage)
        gel = 15 not in free
        print('mode pal-next : communs de %s ; cases attribuables (PNG) %s%s'
              % (PAL_NEXT, free,
                 ' ; olive GELEE en 15 (materiel 14), mesuree sur les lots'
                 if gel else ''))
    else:
        ref = Image.open(f'src/stages/{args.ref}/map/in.png')
        palette = ref.getpalette()
        palette = [tuple(palette[i * 3:i * 3 + 3]) for i in range(256)]

    colors = Counter(small.get_flattened_data())
    mapping, chosen = assign(colors, palette, free)

    print(f'{args.plane}  {w}x{h}  ->  {out_path}  {width}x{height}')
    if not args.pal_next:
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
    if args.pal_next:
        pal_path = ecrire_pal(args.stage, palette, chosen)
        print(f'ecrit {pal_path} (la meme affectation : accord garanti)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
