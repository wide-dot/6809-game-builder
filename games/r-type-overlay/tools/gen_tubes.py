#!/usr/bin/env python3
"""Construire la bande d'animation des quatre ouvertures du gomander.

Le boss du stage 2 n'anime pas que son oeil. tick_gomander_orb_pellet_run
(0x40:A638) repeint aussi quatre tentacules — les ouvertures d'ou sortent les
pellets — chacune sur DEUX images alternees toutes les quatre trames. C'est le
moteur tile_pool du catalogue arcade.

## Le placement, sans nouvelle correlation

Les recipes portent une position ECRAN par ouverture (spawn_x, spawn_y en
1000:4d82). Les positions ABSOLUES ne se transposent pas — notre carte est une
fenetre de la carte arcade — mais les ECARTS, eux, se transposent : il suffit
d'un point de reference, et l'oeil en est un, mesure par correlation
(cf. gen_engulf.py, ancre (1047, 84) de map/in.png).

    v2 = ancre_oeil + (arcade - arcade_oeil) * (0.375, -0.75)

Verifie a l'ecran : les quatre rectangles tombent sur les quatre tentacules.

## Un rectangle unique de 4x4, et pourquoi il ne touche pas l'oeil

Les quatre ouvertures n'ont pas la meme taille (7x8, 9x8, 7x8 et 10x8 cellules
arcade). Un seul <tilepatch> impose pourtant une taille de frame unique, la
bande etant lue par plages : on prend donc 4x4 tuiles pour tout le monde, ce
qui laisse une marge autour de l'art.

Cette marge n'est PAS neutre : elle recopie des cellules que l'animation ne
possede pas. Les rectangles sont donc cales en S'ECARTANT de l'oeil (colonnes
87-88, lignes 7-8), et aucun des quatre ne l'atteint. Les cellules de marge
recoivent le decor de la carte lui-meme, donc les reecrire ne se voit pas.

    tube 0 : rectangle (83, 6)   art a l'offset (27, 0)
    tube 1 : rectangle (82, 11)  art a l'offset (21, 0)
    tube 2 : rectangle (89, 6)   art a l'offset ( 0, 0)
    tube 3 : rectangle (89, 11)  art a l'offset ( 9, 0)

Sortie : src/stages/02/tubes/in.png, huit images de 48x48 cote a cote —
tube0.a, tube0.b, tube1.a, tube1.b, ... — d'ou les `first` 0, 2, 4 et 6.
"""
import os
import subprocess
import sys
import glob

from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCADE = os.path.expanduser('~/Documents/Claude/Projects/re.arcade.r-type')

TUILE = 12
COLS = ROWS = 4                       # le rectangle commun, en cellules

# L'ancre de l'oeil, mesuree par correlation (gen_engulf.py).
EYE_ARCADE = (0x1EC, 0x10C)
EYE_V2 = (1047, 84)

# (spawn_x, spawn_y) arcade et dimensions en cellules, lues dans
# gomander_orb_pellet_recipes (1000:4d82).
TUBES = [(0x1ac, 0x11c, 7, 8),
         (0x17c, 0x0cc, 9, 8),
         (0x224, 0x11c, 7, 8),
         (0x23c, 0x0cc, 10, 8)]


def place(ax, ay, cells_x, cells_y):
    """Rectangle 4x4 et offset de l'art dedans, en pixels v2."""
    vx = EYE_V2[0] + (ax - EYE_ARCADE[0]) * 0.375
    vy = EYE_V2[1] + (ay - EYE_ARCADE[1]) * -0.75
    w = cells_x * 8 * 0.375
    c0, c1 = int(vx // TUILE), int((vx + w - 1) // TUILE)
    r0 = int(vy // TUILE)
    # se caler a COLS colonnes en S'ECARTANT de l'oeil, colonnes 87-88
    base = c1 - (COLS - 1) if c0 < 87 else c0
    return base, r0, int(vx) - base * TUILE, int(vy) - r0 * TUILE


def convertir(dst):
    """Les huit images arcade, converties sur la palette du stage."""
    orig = os.path.join(dst, 'images', 'original')
    for k in range(4):
        src = os.path.join(ARCADE, 'out', 'sprites', 'gomander', 'tube-%d' % k)
        if not os.path.isdir(src):
            sys.exit('%s : absent. Exporter le catalogue arcade d\'abord.' % src)
        d = os.path.join(orig, 'tube-%d' % k)
        os.makedirs(d, exist_ok=True)
        for f in sorted(glob.glob(os.path.join(src, '*.png'))):
            Image.open(f).save(os.path.join(d, os.path.basename(f)))
    subprocess.run([sys.executable, os.path.join(RACINE, 'tools', 'arcade_to_sprites.py'),
                    dst, '--palette', '02'], check=True)
    return [sorted(glob.glob(os.path.join(dst, 'images', 'tube-%d' % k, '*.png')))
            for k in range(4)]


def main():
    tmp = os.path.join(RACINE, 'gen', 'stages', '02', 'tubes-src')
    frames = convertir(tmp)

    carte = Image.open(os.path.join(RACINE, 'src/stages/02/map/in.png'))
    if carte.mode != 'P':
        sys.exit('map/in.png n\'est pas indexee : la composition se fait en INDEX')
    ref = carte.getpalette()[:17 * 3]
    src = carte.load()

    w, h = COLS * TUILE, ROWS * TUILE
    bande = Image.new('P', (w * 8, h), 0)
    bande.putpalette(carte.getpalette())
    pix = bande.load()

    print('bande : 8 images de %dx%d cellules (%dx%d px)' % (COLS, ROWS, w, h))
    slot = 0
    for k, (ax, ay, cx, cy) in enumerate(TUBES):
        col, row, ox, oy = place(ax, ay, cx, cy)
        print('  tube %d : rectangle (%2d,%2d)  art a l\'offset (%2d,%2d)  first=%d'
              % (k, col, row, ox, oy, slot))
        for f in frames[k][:2]:
            ov = Image.open(f)
            if ov.mode != 'P' or ov.getpalette()[:17 * 3] != ref:
                sys.exit('%s : palette differente de celle de la carte' % f)
            o = ov.load()
            ow, oh = ov.size
            # arcade_to_sprites cale son cadre sur des multiples de 8 et 4, donc
            # l'art converti ne demarre pas exactement au coin du blit. L'ecart
            # se lit dans geometrie.txt : ancre_to8 est le coin de l'art vs le
            # CENTRE du canevas, et le blit etant centre, son coin est a
            # (-cx*8/2*0.375, -cy*8/2*0.75). La difference est ce decalage.
            g = os.path.join(os.path.dirname(f), 'geometrie.txt')
            anc = [float(v) for v in
                   [l.split()[1:] for l in open(g) if l.startswith('ancre_to8')][0]]
            dx = round(anc[0] + cx * 8 / 2 * 0.375)
            dy = round(anc[1] + cy * 8 / 2 * 0.75)
            for y in range(h):
                for x in range(w):
                    # le sol : NOTRE carte, pour que la marge du rectangle ne
                    # soit pas du vide mais le decor qui s'y trouve deja
                    v = src[col * TUILE + x, row * TUILE + y]
                    px, py = x - (ox + dx), y - (oy + dy)
                    if 0 <= px < ow and 0 <= py < oh:
                        t = o[px, py]
                        if t != 0:
                            v = t
                    pix[slot * w + x, y] = v
            slot += 1

    dst = os.path.join(RACINE, 'src', 'stages', '02', 'tubes')
    os.makedirs(dst, exist_ok=True)
    out = os.path.join(dst, 'in.png')
    bande.save(out)
    print('%s ecrit' % out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
