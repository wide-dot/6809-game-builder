#!/usr/bin/env python3
"""L'epave de la salle du Bydo core, en bande de tuiles pour <tilepatch>.

A la mort du noyau, la borne nettoie sa salle (bydo_clear_chamber_tilemap,
0x40:EAA9) : dix blocs 8x6 du plan de fond, deux colonnes de 64 px sur toute
la hauteur, a droite de l'ecran camera arretee — ce qui reste du noyau est une
epave. Chez nous c'est `tilemap.stamp` sur la carte du stage 8 (voir
docs/lang/en/tilemaps.md) : les colonnes 56 a 59, lignes 0 a 14.

LA SOURCE est la capture arcade de cette zone, `src/stages/08/wreck/arcade.png`
(128x240) : MAME, stage 8, vaisseau epingle en (512, 228), recomposee de deux
trames ou la camera a deja repris (16602 : x 160, 16694 : x 91 ; moitie gauche
de la seconde, droite de la premiere, la ou le vaisseau ne passe pas — la
bande commune est identique au pixel). Les explosions couvrent la salle tant
que la camera est arretee.

LA CONVERSION est celle de la carte (arcade_to_in.py) : 3/8 en X, 3/4 en Y au
plus proche voisin, couleurs ramenees sur la palette du stage 8 en CIE Lab, le
noir en index 0 (rien a peindre : le champ est efface au noir).

LES COUTURES. Le defilement lit un plan PAIR et un plan IMPAIR (tuiles
decalees d'un pixel) : une tuile impaire porte un pixel de sa voisine. Une
epave decoupee seule perd ce pixel a ses bords — un trait noir d'un pixel qui
suit l'epave des que la camera defile (vu sur la video du 16/10/2026). La
bande porte donc ses deux voisines de carte (colonnes 55 et 60, prises dans
map/in.png) : le patch couvre les colonnes 55 a 59, la colonne 60 n'est la
que pour la couture de droite — et d'elle seule sa premiere colonne de pixels,
la seule qu'une tuile impaire lise (le plan impair lit x + 1) ; le reste est
laisse vide pour que ses tuiles ne coutent rien.

Sortie : src/stages/08/wreck/in.png (72x180 : colonne 55, l'epave, colonne
60), que <leanscroll> decoupe.
Rejeu : python3 tools/gen_bydo_wreck.py ; --check dit si la sortie est a jour.
"""
import importlib.util
import os
import sys

from PIL import Image

SRC = 'src/stages/08/wreck/arcade.png'
OUT = 'src/stages/08/wreck/in.png'
PAL = 'src/stages/08/palette/pal.png'
MAP = 'src/stages/08/map/in.png'
COL = 56                                   # the wreck's first map column (12 px)
HERE = os.path.dirname(os.path.abspath(__file__))


def lab_helper():
    sys.path.insert(0, HERE)
    spec = importlib.util.spec_from_file_location('a2i', os.path.join(HERE, 'arcade_to_in.py'))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m.dist_lab


def render():
    dist = lab_helper()
    src = Image.open(SRC).convert('RGB')
    p = Image.open(PAL).getpalette()
    pal = [tuple(p[3 * i:3 * i + 3]) for i in range(17)]
    w, h = src.width * 3 // 8, src.height * 3 // 4
    out = Image.new('P', (w, h), 0)
    out.putpalette(p[:17 * 3] + [0] * (768 - 17 * 3))
    cache = {}
    for y in range(h):
        for x in range(w):
            c = src.getpixel((x * 8 // 3, y * 4 // 3))
            if c == (0, 0, 0):
                continue
            if c not in cache:
                cache[c] = min(range(1, 17), key=lambda i: dist(c, pal[i]))
            out.putpixel((x, y), cache[c])
    # its two map neighbours, for the odd plane's seams
    m = Image.open(MAP)
    strip = Image.new('P', (12 + w + 12, h), 0)
    strip.putpalette(out.getpalette())
    strip.paste(m.crop((12 * (COL - 1), 0, 12 * COL, h)), (0, 0))
    strip.paste(out, (12, 0))
    # the odd plane reads x + 1 (leanscroll's shift): of column 60 only its
    # first pixel column ever reaches a patched tile — the rest stays blank,
    # so its tiles cost almost nothing
    strip.paste(m.crop((12 * COL + w, 0, 12 * COL + w + 1, h)), (12 + w, 0))
    return strip


def main():
    im = render()
    if '--check' in sys.argv:
        ok = os.path.exists(OUT) and Image.open(OUT).tobytes() == im.tobytes()
        print('%s : %s' % (OUT, 'a jour' if ok else 'PERIME — relancer tools/gen_bydo_wreck.py'))
        return 0 if ok else 1
    im.save(OUT)
    print('%s ecrit (%dx%d)' % (OUT, im.width, im.height))
    return 0


if __name__ == '__main__':
    sys.exit(main())
