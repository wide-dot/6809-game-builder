#!/usr/bin/env python3
"""Le flash de coup du P-Staff : DEUX images blanches tachees de gris.

La borne echange la palette de l'objet pour la palette de flash 0x55
(draw_p_staff_sprite_with_hit_blink a 0x40:779e, palette de corps 0x2B) une
trame sur quatre pendant douze trames — trois flashs par coup encaisse.

Notre palette est GLOBALE au stage : on echange l'IMAGE, comme le tabrok, le
gouger et le serpent. Mais ici, contrairement au tabrok, l'auteur ne veut pas
le blanc plat : les teintes SOMBRES vont au gris moyen et le reste au blanc,
ce qui garde un peu de structure interne dans un sprite de 16x32.

DEUX images, et elles suivent les etats (decision auteur, 03/09/2026) :
  * wait.png  <- 02.png, la pose d'attente, qui est aussi deux temps sur huit
    de la marche et la derniere image de la sequence de tir. Elle sert de
    jumelle a l'ARRET et a la MARCHE.
  * fire.png  <- 03.png, le recul d'apres-tir. Elle sert de jumelle a toute
    la SEQUENCE DE TIR.

Sans decalage 1 (decision auteur) : deux sprites compiles par image, ses deux
orientations, et rien de plus.

Le zero reste la transparence : la silhouette doit rester exacte.

Usage : python3 tools/gen_pstaff_hit.py   (depuis games/r-type)
"""
import os, sys
from PIL import Image

BLANC, GRIS = 4, 3        # #FAFAF2 et #ABABAB
SEUIL = 110               # sous cette luminance, la teinte passe au gris
TRANSPARENT = 0
SOURCES = (('02', 'wait'), ('03', 'fire'))


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/p-staff/images')
    dst = os.path.join(base, 'hit')
    os.makedirs(dst, exist_ok=True)
    for src, nom in SOURCES:
        im = Image.open(os.path.join(base, src + '.png'))
        if im.mode != 'P':
            sys.exit('%s.png n\'est pas une image indexee' % src)
        pal = im.getpalette()
        lum = [0.299 * pal[i*3] + 0.587 * pal[i*3+1] + 0.114 * pal[i*3+2]
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
              % (src, nom, blancs, gris))


if __name__ == '__main__':
    main()
