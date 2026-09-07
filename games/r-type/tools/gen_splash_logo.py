#!/usr/bin/env python3
"""L'ecran « WIDE DOT presents » : le logo pose sur la grille BM16, 160x200,
palette indexee telle que png2bin (bm16) et png2pal l'attendent.

    python3 tools/gen_splash_logo.py [apercu.png]

SOURCE : src/common/flow/splash/source/wide-dot-logo.jpg (1206x274). Mesures
faites dedans : capitales de y 48 a 231, logo de x 94 a 1119 ; l'anneau du O
occupe x 805-992, y 51-229, en cellules de 46.75 x 25.4 px (4 colonnes,
7 lignes), c'est un pixel LARGE (1.84:1). Sur TO8 une cellule devient
7 pixels x 6 lignes (1.94:1 a l'ecran) ; echelle x = 7/46.75, echelle y =
echelle x * 5/3 pour compenser le pixel large. Les lettres sont
reechantillonnees puis seuillees (pas d'anticrenelage, decision auteur),
l'anneau est REDESSINE en blocs entiers, jamais reechantillonne.

COULEURS : celles du title (Pal_title), aux MEMES INDEX que Pal_title, pour
que les deux ecrans partagent leurs entrees de palette. Les valeurs RGB du
PNG sont celles du profil 'to' de png2pal : elles retombent exactement sur
les niveaux TO8 voulus. Lettres en chrome R-Type par bandes (blanc,
periwinkle clair, teal, teal moyen), anneau teal / teal sombre. Pas de « presents ».

CONVENTION D'INDEX : l'index 0 du PNG est la transparence pour toute la
chaine (png2pal part de l'index 1, png2bin decale les pixels d'un cran) ;
index 1 = entree 0 = noir = la bordure. PNG a 8 bits par pixel (bits=8),
un PNG 4 bits donnerait des rayures par png2bin.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'src', 'common', 'flow', 'splash', 'source', 'wide-dot-logo.jpg')
OUT = os.path.join(HERE, '..', 'src', 'common', 'flow', 'splash', 'images', '00.png')

W, H = 160, 200
CELL_W, CELL_H = 7, 6
SX = CELL_W / 46.75
SY = SX * 5 / 3
LOGO = (94, 48, 1119, 231)                 # bbox des capitales dans la source
RING = (805, 51, 992, 229)                 # l'anneau
RING_COLS, RING_ROWS = 4, 7
LOGO_X, LOGO_Y = 3, 68                     # placement (pixels, lignes)
THRESHOLD = 0.45                           # couverture d'encre minimale d'un pixel plein

# les niveaux TO8 -> RGB du profil png2pal 'to' (identite au passage dans l'outil)
TO = [0, 97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255]


def lvl(r, g, b):
    return (TO[r], TO[g], TO[b])


# entree Pal_title -> (index PNG = entree + 1, couleur)
BLACK = 1            # entree 0   $0000
TEAL = 2             # entree 1   $a00a  le corps du logo R-Type
TEAL_DARK = 9        # entree 8   $2002
TEAL_MID = 10        # entree 9   $4004
PERI = 11            # entree 10  $330e
PERI_L = 12          # entree 11  $770f
WHITE = 13           # entree 12  $ff0e
COLORS = {BLACK: lvl(0, 0, 0), TEAL: lvl(0, 10, 10), TEAL_DARK: lvl(0, 2, 2), TEAL_MID: lvl(0, 4, 4),
          PERI: lvl(3, 3, 14), PERI_L: lvl(7, 7, 15), WHITE: lvl(15, 15, 14)}
BANDS = [(0.25, WHITE), (0.5, PERI_L), (0.8, TEAL), (1.0, TEAL_MID)]   # de haut en bas
RING_LIGHT, RING_DARK = TEAL, TEAL_DARK

src = Image.open(SRC).convert('L')
sp = src.load()


def ring_cells():
    """classe de chaque cellule de l'anneau, lue au centre : d sombre, l clair, . vide"""
    cw = (RING[2] - RING[0]) / RING_COLS
    ch = (RING[3] - RING[1]) / RING_ROWS
    cells = []
    for r in range(RING_ROWS):
        row = ''
        for c in range(RING_COLS):
            g = sp[int(RING[0] + cw * (c + .5)), int(RING[1] + ch * (r + .5))]
            row += 'd' if g < 120 else ('l' if g < 200 else '.')
        cells.append(row)
    return cells


im = Image.new('P', (W, H), BLACK)
pal = [(255, 0, 255)] + [COLORS.get(i, (0, 0, 0)) for i in range(1, 17)]
pal += [(0, 0, 0)] * (256 - len(pal))
im.putpalette([c for col in pal for c in col])
d = ImageDraw.Draw(im)

# --- les lettres : bande reechantillonnee, anneau exclu, seuil, bandes de couleur
lw = int(round((LOGO[2] - LOGO[0]) * SX))
lh = int(round((LOGO[3] - LOGO[1]) * SY))
band = src.crop(LOGO).resize((lw, lh), Image.LANCZOS)
bp = band.load()
ring_x0 = int(round((RING[0] - LOGO[0]) * SX))
ring_x1 = ring_x0 + RING_COLS * CELL_W
for y in range(lh):
    color = BANDS[-1][1]
    for frac, c in BANDS:
        if y / lh < frac:
            color = c
            break
    for x in range(lw):
        if ring_x0 - 1 <= x < ring_x1 + 1:
            continue
        t = (255 - bp[x, y]) / (255 - 64)
        if t >= THRESHOLD:
            im.putpixel((LOGO_X + x, LOGO_Y + y), color)

# --- l'anneau : blocs entiers
cells = ring_cells()
ry0 = LOGO_Y + int(round((RING[1] - LOGO[1]) * SY))
for r, row in enumerate(cells):
    for c, cls in enumerate(row):
        if cls == '.':
            continue
        x, y = LOGO_X + ring_x0 + c * CELL_W, ry0 + r * CELL_H
        d.rectangle((x, y, x + CELL_W - 1, y + CELL_H - 1), fill=RING_LIGHT if cls == 'l' else RING_DARK)

# (pas de « presents » : decision auteur, la place est reservee a une barre de chargement)

im.save(OUT, bits=8)
print('ecrit', os.path.normpath(OUT), im.size, 'lettres %dx%d, anneau %s' % (lw, lh, cells))

if len(sys.argv) > 1:                       # apercu aux proportions de l'ecran, gamma TEA5114
    GAMMA = [0, 100, 127, 147, 163, 179, 191, 203, 215, 223, 231, 239, 243, 247, 251, 255]
    LEVELS = {BLACK: (0, 0, 0), TEAL: (0, 10, 10), TEAL_DARK: (0, 2, 2), TEAL_MID: (0, 4, 4),
              PERI: (3, 3, 14), PERI_L: (7, 7, 15), WHITE: (15, 15, 14)}
    view = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W):
            view.putpixel((x, y), tuple(GAMMA[v] for v in LEVELS[im.getpixel((x, y))]))
    view.resize((640, 480), Image.NEAREST).save(sys.argv[1])
    print('apercu', sys.argv[1])
