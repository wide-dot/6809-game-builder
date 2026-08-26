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

              moitie top (y1 = -24)     moitie bottom (y1 = 0)
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

LA POSE D'ATTENTE PART DANS SON PROPRE REPERTOIRE (`<moitie>-idle`). Elle est
la seule que le gouger tienne immobile sur un decor qui defile d'un pixel a la
fois, donc la seule a avoir besoin de sa variante pre-decalee — et `shifts` se
declare par repertoire. Elle n'est PAS dupliquee : l'animation se sert de la
meme image, le code eteignant la variante decalee par la parite de la position
(voir gouger.Snap dans obj.asm).

ATTENTION AU NUMEROTAGE : le suffixe des symboles suit l'ORDINAL de l'image
dans son entree `<images>`, pas le nom du fichier. Sortir la pose 1 du
repertoire principal y renumerote donc les quatre autres 0..3 — la table
gouger.SetsXX porte la correspondance en clair.

Usage : python3 tools/gen_gouger_halves.py   (depuis games/r-type)
"""
import os
import sys
from PIL import Image

TRANSPARENT = 0
HEIGHT = 48
MIDDLE = HEIGHT // 2
# meme ordre de variantes que gen_gouger_hit.py — gauche et droite sont
# l'inverse de ce que le signe de vx laisse croire, c'est mesure.
DIRECTIONS = (('top-left', 'tl'), ('top-right', 'tr'),
              ('bottom-left', 'bl'), ('bottom-right', 'br'))
# la pose que la phase A montre en permanence — slot 1 du cycle arcade
IDLE_POSE = '01.png'
HALVES = ('top', 'bottom')


def cut(src, dst, keep):
    """Ecrit src dans dst en effacant la moitie qui n'est pas `keep`."""
    im = Image.open(src)
    if im.mode != 'P':
        sys.exit('%s n\'est pas une image indexee' % src)
    w, h = im.size
    if (w, h) != (24, HEIGHT):
        sys.exit('%s fait %dx%d, attendu 24x%d' % (src, w, h, HEIGHT))
    px = bytearray(im.tobytes())
    y0, y1 = (MIDDLE, h) if keep == 'top' else (0, MIDDLE)
    for y in range(y0, y1):                      # on efface l'AUTRE moitie
        px[y * w:(y + 1) * w] = bytes([TRANSPARENT]) * w
    out = Image.frombytes('P', im.size, bytes(px))
    out.putpalette(im.getpalette())
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)


# L'ordonnee d'attente de chaque direction, et la moitie qui y est ENFOUIE.
# Doit rester d'accord avec gouger.PresetY dans obj.asm.
IDLE_Y = {'tl': 15, 'tr': 15, 'bl': 183, 'br': 183}
BURIED = {'tl': 'top', 'tr': 'top', 'bl': 'bottom', 'br': 'bottom'}
SCREEN_H = 200


def check_buried(base, short):
    """La moitie enfouie doit vraiment etre rejetee par BuildSprites.

    Elle seule justifie que sa pose d'attente soit compilee SANS variante
    pre-decalee (voir le config.xml) : un sprite jamais dessine n'a pas besoin
    de se caler au pixel. Si l'art ou l'ordonnee changeaient au point de la
    rendre visible, elle retomberait en silence sur le repli du moteur et
    tremblerait d'un pixel sur la roche. On casse ici plutot que la.

    Le critere est celui de BuildSprites, chemin playfield :
        rejet si  y_pos + y1 < 0  ou  y_pos + y1 + y_size >= 200
    ou y1 et y_size sortent du rognage des marges transparentes, face au
    centre du canevas — exactement ce que gfxcomp recalculera.
    """
    half = BURIED[short]
    y = IDLE_Y[short]
    p = os.path.join(base, 'half', short, half + '-idle', '00.png')
    im = Image.open(p)
    px = im.load()
    w, h = im.size
    rows = [r for r in range(h)
            if any(px[x, r] != TRANSPARENT for x in range(w))]
    y1 = rows[0] - h // 2
    size = rows[-1] - rows[0] + 1
    if y + y1 >= 0 and y + y1 + size < SCREEN_H:
        sys.exit('%s : la moitie %s du gouger %s est DESSINEE a y=%d '
                 '(%d..%d) alors que le config.xml la compile sans variante '
                 'pre-decalee. Rendre shifts="0,1" a son entree <images>, ou '
                 'corriger IDLE_Y ici.'
                 % (p, half, short, y, y + y1, y + y1 + size))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(root, 'src/enemies/gouger/images')
    n = 0
    for long, short in DIRECTIONS:
        poses = sorted(f for f in os.listdir(os.path.join(base, long))
                       if f.endswith('.png'))
        for half in HALVES:
            rank = 0
            for f in poses:
                if f == IDLE_POSE:
                    dst = os.path.join(base, 'half', short,
                                       half + '-idle', '00.png')
                else:
                    dst = os.path.join(base, 'half', short, half,
                                       '%02d.png' % rank)
                    rank += 1
                cut(os.path.join(base, long, f), dst, half)
                n += 1
            cut(os.path.join(base, 'hit', short, '00.png'),
                os.path.join(base, 'half', 'hit', short, half, '00.png'),
                half)
            n += 1
    for _, short in DIRECTIONS:
        check_buried(base, short)
    print('%d demi-images ecrites sous images/half/ '
          '(moities enfouies verifiees rejetees)' % n)


if __name__ == '__main__':
    main()
