#!/usr/bin/env python3
"""Variantes BLANCHES des poses du serpent, pour le flash de coup.

L'arcade fait clignoter un segment touche en echangeant sa palette d'objet
(40:7d22, douze trames, trois sur quatre en palette de flash). La palette TO8
est GLOBALE au stage : on ne peut pas la permuter pour un seul sprite. On
remplace donc l'echange de palette par un JEU D'IMAGES : la meme silhouette,
tous ses pixels a l'unique blanc de la palette.

Le blanc du stage 5 est l'index PNG 4 = (250,250,242), soit le MAT 3 (la
regle du 18/08 : MAT = index PNG - 1). L'index 0 reste la transparence et
n'est PAS touche — c'est la silhouette qui doit rester exacte.

Le cout est faible parce que gfxcomp groupe les valeurs identiques : une image
unie se compile en UN chargement suivi d'une rafale d'ecritures. Mesure au
moment de l'ecriture de ce script : les seize corps passent de 8 546 a 2 968
octets de code compile.

Usage : python3 tools/gen_slither_hit.py   (depuis games/r-type)
"""
import glob, os, sys
from PIL import Image

BLANC = 4          # index PNG du blanc de la palette du stage 5
TRANSPARENT = 0

def variante(src, dst):
    im = Image.open(src)
    if im.mode != 'P':
        sys.exit('%s n\'est pas une image indexee' % src)
    px = bytearray(im.tobytes())
    for i, v in enumerate(px):
        if v != TRANSPARENT:
            px[i] = BLANC
    out = Image.frombytes('P', im.size, bytes(px))
    out.putpalette(im.getpalette())
    out.save(dst)

def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/slither/images')
    total = 0
    # Le CORPS n'a plus de jeu blanc : son flash est un DISQUE unique, produit
    # par gen_slither_hit_round.py — les seize poses du corps sont dessinees
    # par le renderer groupe, qui ne monte qu'une page, et une image ronde tient
    # avec elles sur la page du cast. Restent la tete et la queue, qui sont des
    # objets a OST et basculent d'identifiant le temps de leur flash.
    for partie in ('head', 'tail'):
        src_dir = os.path.join(base, partie)
        dst_dir = os.path.join(base, partie + '_hit')
        os.makedirs(dst_dir, exist_ok=True)
        for src in sorted(glob.glob(os.path.join(src_dir, '*.png'))):
            variante(src, os.path.join(dst_dir, os.path.basename(src)))
            total += 1
    print('%d variantes blanches ecrites' % total)

if __name__ == '__main__':
    main()
