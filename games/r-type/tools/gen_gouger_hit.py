#!/usr/bin/env python3
"""Le flash de coup du gouger : UNE image blanche par orientation.

L'arcade fait clignoter le gouger touche en echangeant sa palette d'objet
(40:7168, une trame sur quatre pendant le recul). La palette TO8 est GLOBALE
au stage : on echange donc l'IMAGE, comme pour le serpent.

QUELLE POSE ? Une seule par orientation, donc quatre en tout (decision
auteur). Le choix se justifie par le comportement, pas par l'esthetique : la
POSE 2 est celle que l'arcade FIGE pendant toute la plongee — 40:7096 force
l'offset 4, soit le mot 2 de la table de poses — et elle revient deux fois
dans le cycle de reptation (slots 2 et 4). C'est de loin la pose la plus vue.

Le critere « la plus discrete » ne departageait rien : entre les trois poses
qui reviennent deux fois, l'ecart de surface est de 1 % (454 a 470 pixels
opaques), et la plus petite n'est meme pas la meme selon l'orientation.

Blanc = index PNG 4 = MAT 3 = (250,250,242) dans la palette du stage 2. Le
zero reste la transparence : la silhouette doit rester exacte.

Usage : python3 tools/gen_gouger_hit.py   (depuis games/r-type)
"""
import os, sys
from PIL import Image

BLANC = 4
POSE = '02'          # celle que la plongee fige
TRANSPARENT = 0
# DANS L'ORDRE DES VARIANTES DE WAVE, et il n'est pas celui qu'on croit :
# gauche et droite sont l'inverse de ce que le signe de vx laisse penser. La
# correspondance est mesuree sur les adresses arcade portees par les noms des
# fichiers sources, pas deduite. Voir la fiche dans gouger/obj.asm.
#   var 0 -> top-left    var 1 -> top-right
#   var 2 -> bottom-left var 3 -> bottom-right
DIRECTIONS = ('top-left', 'top-right', 'bottom-left', 'bottom-right')

def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/gouger/images')
    dst = os.path.join(base, 'hit')
    os.makedirs(dst, exist_ok=True)
    for i, d in enumerate(DIRECTIONS):
        src = os.path.join(base, d, POSE + '.png')
        im = Image.open(src)
        if im.mode != 'P':
            sys.exit('%s n\'est pas une image indexee' % src)
        px = bytearray(im.tobytes())
        for k, v in enumerate(px):
            if v != TRANSPARENT:
                px[k] = BLANC
        out = Image.frombytes('P', im.size, bytes(px))
        out.putpalette(im.getpalette())
        # numerotees dans l'ordre des variantes de wave (cf. DIRECTIONS)
        out.save(os.path.join(dst, '%02d.png' % i))
    print('%d images blanches ecrites (pose %s de chaque orientation)'
          % (len(DIRECTIONS), POSE))

if __name__ == '__main__':
    main()
