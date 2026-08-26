#!/usr/bin/env python3
"""Le flash de coup du brood et du zoid : la silhouette blanche de CHAQUE pose.

L'arcade fait clignoter l'objet touche en echangeant sa palette (le brood par
draw_brood_with_hit_blink 40:8035, le zoid par draw_zoid_sprite_with_hit_blink,
palette 0x55, 12 trames a 25 % de rapport cyclique). La palette TO8 est
GLOBALE au stage : on echange l'IMAGE, comme le gouger et le serpent.

A la difference du gouger (UNE pose par orientation, decision auteur), ici
chaque pose recoit sa blanche : le brood est touche dans n'importe laquelle de
ses quatre poses x deux montages, le zoid dans ses quatre poses de rodage —
et c'est l'objet de l'etude, peser ce que coute la fidelite avant d'elaguer.

Sources :
  brood : images/embedded/ (la base amputee des lignes enfouies — la blanche
          doit avoir la MEME silhouette que la pose qu'elle remplace)
  zoid  : images/zoid/ (le parasite seul : l'arcade ne fait pas clignoter
          l'oeuf — un coup le fait eclore — et l'eclosion jette la collision)

Blanc = index PNG 4 = (250,250,242), transparence = index 0 (couleur cle),
memes conventions que gen_gouger_hit.py.

Usage : python3 tools/gen_hit_flash.py   (depuis games/r-type)
"""
import os
import sys
from PIL import Image

BLANC = 4
TRANSPARENT = 0

JEUX = (
    ('src/enemies/brood/images/embedded', 'src/enemies/brood/images/hit'),
    ('src/enemies/zoid/images/zoid',      'src/enemies/zoid/images/hit'),
)


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for src_rel, dst_rel in JEUX:
        src = os.path.join(racine, src_rel)
        dst = os.path.join(racine, dst_rel)
        os.makedirs(dst, exist_ok=True)
        n = 0
        for nom in sorted(os.listdir(src)):
            if not nom.endswith('.png'):
                continue
            im = Image.open(os.path.join(src, nom))
            if im.mode != 'P':
                sys.exit('%s n\'est pas une image indexee' % nom)
            px = bytearray(im.tobytes())
            for k, v in enumerate(px):
                if v != TRANSPARENT:
                    px[k] = BLANC
            out = Image.frombytes('P', im.size, bytes(px))
            out.putpalette(im.getpalette())
            out.save(os.path.join(dst, nom))
            n += 1
        print('%s : %d silhouettes blanches' % (dst_rel, n))


if __name__ == '__main__':
    main()
