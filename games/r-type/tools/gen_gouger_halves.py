#!/usr/bin/env python3
"""Le gouger en DEUX moities horizontales — parce que le moteur ne decoupe pas.

L'arcade dessine ses sprites decoupes aux bords de l'ecran. BuildSprites, lui,
rejette EN BLOC tout sprite qui deborde (BS_ylo/BS_yhi, pas de decoupe
partielle). Or le gouger attend a demi enterre dans la paroi — 15 au plafond,
183 au sol — et son sprite fait 48 de haut, ancre au centre : il debordait donc
toujours, et n'etait pas dessine DU TOUT pendant la phase d'attente, qui est
l'essentiel de sa vie.

En le coupant en deux, la moitie enfouie est la seule rejetee et la moitie
visible s'affiche a sa vraie place :

              moitie haute (y1 = -24)   moitie basse (y1 = 0)
  plafond 15  -9        -> REJETEE      15..39     -> dessinee
  sol    183  159..183  -> dessinee     183..207   -> REJETEE

C'est aussi un retour a la structure d'origine : une pose arcade est deja un
META-SPRITE de deux sprites (write_2_sprites), et nos PNG 24x48 sont ces deux
tranches deja composees.

LE CANEVAS RESTE 24x48. On efface une moitie au lieu de recadrer : gfxcomp
rogne les marges transparentes et derive l'ancre du coin de la boite rognee
face au CENTRE DU CANEVAS. Les deux moities recoivent donc automatiquement le
bon y1, et l'objet parent comme son enfant portent le MEME y_pos — aucun
decalage de +/-24 a ecrire, nulle part.

Usage : python3 tools/gen_gouger_halves.py   (depuis games/r-type)
"""
import os
import sys
from PIL import Image

TRANSPARENT = 0
HAUTEUR = 48
MILIEU = HAUTEUR // 2
# meme ordre de variantes que gen_gouger_hit.py — gauche et droite sont
# l'inverse de ce que le signe de vx laisse croire, c'est mesure.
DIRECTIONS = (('top-left', 'tl'), ('top-right', 'tr'),
              ('bottom-left', 'bl'), ('bottom-right', 'br'))


def coupe(src, dst, garder):
    """Ecrit src dans dst en effacant la moitie qui n'est pas `garder`."""
    im = Image.open(src)
    if im.mode != 'P':
        sys.exit('%s n\'est pas une image indexee' % src)
    w, h = im.size
    if (w, h) != (24, HAUTEUR):
        sys.exit('%s fait %dx%d, attendu 24x%d' % (src, w, h, HAUTEUR))
    px = bytearray(im.tobytes())
    y0, y1 = (MILIEU, h) if garder == 'haut' else (0, MILIEU)
    for y in range(y0, y1):                      # on efface l'AUTRE moitie
        px[y * w:(y + 1) * w] = bytes([TRANSPARENT]) * w
    out = Image.frombytes('P', im.size, bytes(px))
    out.putpalette(im.getpalette())
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/gouger/images')
    n = 0
    for long, court in DIRECTIONS:
        poses = sorted(f for f in os.listdir(os.path.join(base, long))
                       if f.endswith('.png'))
        for moitie in ('haut', 'bas'):
            for f in poses:
                coupe(os.path.join(base, long, f),
                      os.path.join(base, 'half', court, moitie, f), moitie)
                n += 1
            coupe(os.path.join(base, 'hit', court, '00.png'),
                  os.path.join(base, 'half', 'hit', court, moitie, '00.png'),
                  moitie)
            n += 1
    print('%d demi-images ecrites sous images/half/' % n)


if __name__ == '__main__':
    main()
