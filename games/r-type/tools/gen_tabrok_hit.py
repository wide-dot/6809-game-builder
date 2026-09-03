#!/usr/bin/env python3
"""Le flash de coup du Tabrok : DEUX images blanches, une au sol, une en vol.

La borne ne blanchit pas des images : elle echange la palette de l'objet
(kind 0x55, `draw_tarok_sprite_with_hit_blink` a 0x40:661a) une trame sur
quatre pendant douze trames, soit trois flashs par coup encaisse. Cette
palette porte douze blancs purs et trois bleus lavande pales.

Notre palette est GLOBALE au stage : on echange donc l'IMAGE, comme pour le
gouger et le serpent. Et le bleu pale n'a pas d'equivalent chez nous — la
transposition couleur par couleur (via la palette arcade 0x21 puis 0x55)
envoie quatorze teintes sur quinze vers le blanc, la quinzieme vers un gris.
Le rendu fidele est donc un blanc plat, ce que fait ce script.

DEUX images seulement, choix de l'auteur (03/09/2026) :
  * ground.png <- 02.png, la pose du sol. C'est la pose de base, celle du
    tir, et trois temps sur quatre de la marche courte : de loin la plus
    vue. Elle sert de jumelle blanche a TOUTES les poses au sol.
  * flight.png <- 00.png, une des deux poses de vol. La flamme alterne entre
    00 et 01 ; une seule suffit au flash, qui ne dure qu'une trame.

Le zero reste la transparence : la silhouette doit rester exacte.

Usage : python3 tools/gen_tabrok_hit.py   (depuis games/r-type)
"""
import os, sys
from PIL import Image

BLANC = 4            # #FAFAF2 dans la palette du stage 1
TRANSPARENT = 0
SOURCES = (('02', 'ground'), ('00', 'flight'))


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/tabrok/images')
    dst = os.path.join(base, 'hit')
    os.makedirs(dst, exist_ok=True)
    for src, nom in SOURCES:
        im = Image.open(os.path.join(base, src + '.png'))
        if im.mode != 'P':
            sys.exit('%s.png n\'est pas une image indexee' % src)
        px = bytearray(im.tobytes())
        for k, v in enumerate(px):
            if v != TRANSPARENT:
                px[k] = BLANC
        out = Image.frombytes('P', im.size, bytes(px))
        out.putpalette(im.getpalette())
        out.save(os.path.join(dst, nom + '.png'))
        print('%s.png -> hit/%s.png (%dx%d)' % (src, nom, *im.size))


if __name__ == '__main__':
    main()
