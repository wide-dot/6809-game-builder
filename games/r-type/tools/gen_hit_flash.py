#!/usr/bin/env python3
"""Le flash de coup du brood et du zoid : la silhouette blanche de CHAQUE pose.

L'arcade fait clignoter l'objet touche en echangeant sa palette (le brood par
draw_brood_with_hit_blink 40:8035, le zoid par draw_zoid_sprite_with_hit_blink,
palette 0x55, 12 trames a 25 % de rapport cyclique). La palette TO8 est
GLOBALE au stage : on echange l'IMAGE, comme le gouger et le serpent.

DECISION AUTEUR (26/08/2026, apres l'etude a huit poses) : le brood recoit
QUATRE blanches — la pose fermee (0/1) et la pose a moitie ouverte (4/5), la
mi-ouverte couvrant toutes les poses non fermees. Le zoid n'en recoit qu'UNE
(pose 0) : ses quatre poses de rodage sont trop proches pour que la
difference se voie sur un eclat d'une trame. Numerotation de sortie serree :
  00 = plafond ferme (source 00)    02 = plafond mi-ouvert (source 04)
  01 = sol ferme     (source 01)    03 = sol mi-ouvert     (source 05)
et le code choisit par `orientation + 2 x (pose != fermee)`.

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
    # (source, destination, selection source -> nom de sortie)
    ('src/enemies/brood/images/embedded', 'src/enemies/brood/images/hit',
     (('00', '00'), ('01', '01'), ('04', '02'), ('05', '03'))),
    ('src/enemies/zoid/images/zoid',      'src/enemies/zoid/images/hit',
     (('00', '00'),)),
)


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for src_rel, dst_rel, sel in JEUX:
        src = os.path.join(racine, src_rel)
        dst = os.path.join(racine, dst_rel)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(dst):           # jamais de reste d'une selection passee
            if f.endswith('.png'):
                os.remove(os.path.join(dst, f))
        for nom_src, nom_dst in sel:
            im = Image.open(os.path.join(src, nom_src + '.png'))
            if im.mode != 'P':
                sys.exit('%s n\'est pas une image indexee' % nom_src)
            px = bytearray(im.tobytes())
            for k, v in enumerate(px):
                if v != TRANSPARENT:
                    px[k] = BLANC
            out = Image.frombytes('P', im.size, bytes(px))
            out.putpalette(im.getpalette())
            out.save(os.path.join(dst, nom_dst + '.png'))
        print('%s : %d silhouettes blanches' % (dst_rel, len(sel)))


if __name__ == '__main__':
    main()
