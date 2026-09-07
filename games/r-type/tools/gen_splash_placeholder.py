#!/usr/bin/env python3
"""Le placeholder de l'ecran « WIDE DOT presents » : 160x200, palette indexee,
tel que png2bin (bm16) et png2pal l'attendent. A remplacer par l'image reelle
au meme chemin, meme format.

CONVENTION D'INDEX : l'index 0 du PNG est la transparence pour toute la chaine
(png2pal part de l'index 1, png2bin decale les pixels d'un cran). Un ecran
plein n'utilise donc que les index 1 a 16 : index 1 = noir = entree 0 de la
palette TO8 = la bordure.

    python3 tools/gen_splash_placeholder.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..',
                   'src', 'common', 'flow', 'splash', 'images', '00.png')
W, H = 160, 200
pal = [(255, 0, 255), (0, 0, 0), (255, 255, 255), (170, 170, 170), (0, 170, 170)] + [(0, 0, 0)] * 11
im = Image.new('P', (W, H), 1)                    # fond : index 1 = noir
im.putpalette([c for rgb in pal for c in rgb])
d = ImageDraw.Draw(im)
big = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 26)
small = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 12)


def center(text, font, y, ink):
    x0, y0, x1, y1 = d.textbbox((0, 0), text, font=font)
    d.text(((W - (x1 - x0)) // 2 - x0, y), text, font=font, fill=ink)


d.rectangle((20, 70, 139, 71), fill=4)
center('WIDE', big, 78, 2)
center('DOT', big, 104, 2)
d.rectangle((20, 136, 139, 137), fill=4)
center('presents', small, 146, 3)
im.save(out, bits=8)                              # 8 bits/pixel : png2bin decale la
                                                   # transparence octet par octet, un PNG
                                                   # 4 bits donnerait 0x11 -> 0x10, des rayures
print('ecrit', os.path.normpath(out), im.size, 'mode', im.mode)
