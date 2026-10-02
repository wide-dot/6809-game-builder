#!/usr/bin/env python3
"""Les poses BLANCHES de coup des pieces du vaisseau qui les dessinent EN
REMPLACEMENT de leur sprite (decision auteur, 12/09/2026) : capsules, triangle,
reacteur arriere (pieces wsmgr, tranchees ensuite par gen_warship_slices.py),
reacteurs de ventre et tourelles multiples (sprites BuildSprites). Les
tourelles a roue et le Cytron, eux, recoivent l'ellipse du manager
(tools/gen_hitflash_manager.py) par-dessus.

    python3 tools/gen_warship_hit.py ; python3 tools/gen_warship_slices.py

Une pose blanche = la silhouette EXACTE de la pose (index 4, transparence 0),
chaque plage opaque etendue a la paire de pixels de l'encodeur (un bord sur un
pixel impair coute une ecriture d'un octet). Meme canevas, meme ancre.
Sorties : images/<dossier>-hit/00.png (+ geometrie.txt des pieces wsmgr).
"""
import os
import shutil

from PIL import Image

B = 'src/enemies/warship-elements/images/'
WHITE = 4
# (dossier source, pose) ; les pieces wsmgr en tete (leur geometrie suit)
WSMGR = ['rear-reactor', 'escape-capsule', 'small-escape-capsule', 'falling-triangle']
SPRITES = ['bottom-reactor-bottom', 'bottom-reactor-bottom-left', 'bottom-reactor-bottom-left-full',
           'bottom-reactor-bottom-right', 'bottom-reactor-bottom-right-full',
           'multi-turret-top-left', 'multi-turret-bottom-left', 'multi-turret-top-right', 'multi-turret-bottom-right']


def blanche(src):
    im = Image.open(src)
    assert im.mode == 'P', src
    p = im.load()
    w, h = im.size
    out = Image.new('P', im.size, 0)
    out.putpalette(im.getpalette())
    o = out.load()
    # LA SILHOUETTE EXACTE, pas le remplissage de la rangee (12/09/2026, vu sur
    # la planche : le reacteur arriere et la capsule devenaient des paves).
    # Chaque PLAGE opaque de la rangee est etendue a la paire de pixels de
    # l'encodeur ; les trous d'un pixel se comblent, les autres restent.
    for y in range(h):
        x = 0
        while x < w:
            if not p[x, y]:
                x += 1
                continue
            a = x
            while x < w and p[x, y]:
                x += 1
            b = x - 1
            a -= a % 2                 # la paire de l'encodeur commence sur un x pair
            b += (b + 1) % 2
            for xx in range(a, min(b, w - 1) + 1):
                o[xx, y] = WHITE
    return out


def main():
    for d in WSMGR + SPRITES:
        src = os.path.join(B, d, '00.png')
        dst = os.path.join(B, d + '-hit')
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(dst):
            if f.endswith('.png'):
                os.remove(os.path.join(dst, f))
        blanche(src).save(os.path.join(dst, '00.png'))
        geo = os.path.join(B, d, 'geometrie.txt')
        if os.path.exists(geo):
            shutil.copyfile(geo, os.path.join(dst, 'geometrie.txt'))
        print('%s-hit : %s' % (d, Image.open(src).size))


if __name__ == '__main__':
    main()
