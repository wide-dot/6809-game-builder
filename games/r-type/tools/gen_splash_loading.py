#!/usr/bin/env python3
"""L'ecran du boot : l'image LOADING du jeu, seule sur le noir, a la place
exacte ou le title la montre avant un stage (pixel 64, ligne 90) — le meme
ecran de chargement partout, avec la meme barre orange (decision auteur,
08/09/2026 ; le logo WIDE DOT est retire).

    python3 tools/gen_splash_loading.py [apercu.png]

SOURCE : src/common/flow/loading/images/00.png (34x26, l'image de l'objet
ObjID_loading du title, qui porte aussi la piste grise de la barre). Sa
palette est reprise telle quelle : png2pal en fait Pal_splash comme il fait
Pal_loading, aux memes entrees — l'orange de la barre reste l'entree 12.

CONVENTION D'INDEX : l'index 0 du PNG est la transparence pour toute la
chaine (png2pal part de l'index 1, png2bin decale les pixels d'un cran) ;
index 1 = entree 0 = noir = le fond et la bordure. PNG a 8 bits par pixel.
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'src', 'common', 'flow', 'loading', 'images', '00.png')
OUT = os.path.join(HERE, '..', 'src', 'common', 'flow', 'splash', 'images', '00.png')

W, H = 160, 200
X0, Y0 = 64, 90            # ou le title pose ObjID_loading (mesure sous toje)
BLACK = 1                  # index 1 = entree 0 = noir

src = Image.open(SRC)
assert src.mode == 'P', src.mode
sp = src.load()
im = Image.new('P', (W, H), BLACK)
im.putpalette(src.getpalette())
dst = im.load()
for y in range(src.height):
    for x in range(src.width):
        v = sp[x, y]
        dst[X0 + x, Y0 + y] = BLACK if v == 0 else v
im.save(OUT, bits=8)
print("%s : %dx%d, LOADING en (%d,%d)" % (os.path.relpath(OUT), W, H, X0, Y0))

if len(sys.argv) > 1:
    im.convert('RGB').resize((640, 400), Image.NEAREST).save(sys.argv[1])
