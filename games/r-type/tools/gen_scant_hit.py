#!/usr/bin/env python3
"""Le flash de coup du Scant : UNE image blanche tachee de gris.

La borne echange la palette de l'objet pour la palette de flash 0x55
(draw_scant_sprite_with_hit_blink a 0x40:8409, palette de corps 0x20) une
trame sur quatre pendant seize trames — quatre flashs par coup. Chez nous
c'est UNE trame (voir l'en-tete de scant.hitBlink : notre trame effective est
plus lente, le compte a rebours de la borne s'etire et le blanc colle).

Notre palette est GLOBALE au stage : on echange l'IMAGE. Blanc TACHE DE GRIS
comme le p-staff, les teintes sombres au gris moyen.

DEUX POSES (decision auteur, 03/09/2026). La 00 d'abord, celle du
deplacement, qui porte aussi trois temps sur quatre de la sequence de tir.
Puis la 01 : sa silhouette s'ecarte trop de la 00 (255 pixels de difference
sur ~320 opaques) et le flash se lisait comme un saut de pose au moment du
virage. La 02, elle, reste sur la jumelle de la 00 — mesure faite, elle en
est plus proche (153 pixels de difference) que de la 01 (170).

Sortie dans images/hit/, nommees 00.png et 01.png : le Scant declare son
dossier d'images en bloc (`<images dir=...>`) et non image par image, et le
selecteur ne retient que les fichiers numerotes — d'ou les noms.

Usage : python3 tools/gen_scant_hit.py   (depuis games/r-type)
"""
import os, sys
from PIL import Image

BLANC, GRIS, SEUIL, TRANSPARENT = 4, 3, 110, 0


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/scant/images')
    dst = os.path.join(base, 'hit')
    os.makedirs(dst, exist_ok=True)
    for nom in ('00', '01'):
        im = Image.open(os.path.join(base, nom + '.png'))
        if im.mode != 'P':
            sys.exit('%s.png n\'est pas une image indexee' % nom)
        pal = im.getpalette()
        lum = [0.299*pal[i*3] + 0.587*pal[i*3+1] + 0.114*pal[i*3+2]
               for i in range(16)]
        px = bytearray(im.tobytes())
        blancs = gris = 0
        for k, v in enumerate(px):
            if v == TRANSPARENT:
                continue
            if lum[v] < SEUIL:
                px[k] = GRIS; gris += 1
            else:
                px[k] = BLANC; blancs += 1
        out = Image.frombytes('P', im.size, bytes(px))
        out.putpalette(pal)
        out.save(os.path.join(dst, nom + '.png'))
        print('%s.png -> hit/%s.png : %d px blancs, %d px gris'
              % (nom, nom, blancs, gris))


if __name__ == '__main__':
    main()
