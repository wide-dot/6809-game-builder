#!/usr/bin/env python3
"""Le Boldo en quatre tranches verticales, comme la borne le dessine.

run_boldo (40:6EF2) emet quatre recettes de deux cellules (1000:3042,
304E, 305A, 3066), une par colonne de 32 px arcade : x -64, -32, 0, +32 du
centre. Chez nous une colonne de 32 px fait 12 px, et le Boldo converti
(images/default/00.png, tools/arcade_to_sprites.py boldo) fait 48 x 36 : on
le coupe en quatre images de 12 x 36, centres a -18, -6, +6, +18 du sien.

Pourquoi des tranches : notre moteur de sprites ne rogne pas. Un sprite
entierement dans la fenetre se dessine, sinon il saute (ou deborde par
retour de ligne). Le Boldo nait a moitie hors de l'ecran a gauche et en sort
lentement : en quatre tranches il entre colonne par colonne, au lieu
d'apparaitre d'un bloc 450 trames plus tard.

Sortie : images/slices/00.png .. 03.png (indexees, palette de l'original).

Usage : python3 tools/gen_boldo_slices.py [--check]   (depuis games/r-type)
"""
import io
import os
import sys
from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(RACINE, 'src/enemies/boldo/images/default/00.png')
DST = os.path.join(RACINE, 'src/enemies/boldo/images/slices')
LARGE = 12


def slices():
    im = Image.open(SRC)
    if im.mode != 'P':
        sys.exit('00.png n\'est pas une image indexee')
    if im.width != 4 * LARGE:
        sys.exit('00.png fait %d px de large, 48 attendus' % im.width)
    out = []
    for k in range(4):
        t = im.crop((k * LARGE, 0, (k + 1) * LARGE, im.height))
        t.info = dict(im.info)
        buf = io.BytesIO()
        t.save(buf, 'PNG', transparency=im.info.get('transparency', 0))
        out.append(('%02d.png' % k, buf.getvalue()))
    return out


def main():
    check = '--check' in sys.argv[1:]
    ok = True
    if not check:
        os.makedirs(DST, exist_ok=True)
    for name, data in slices():
        path = os.path.join(DST, name)
        if check:
            try:
                cur = Image.open(path)
                ref = Image.open(io.BytesIO(data))
                same = (cur.size == ref.size and cur.mode == ref.mode
                        and cur.tobytes() == ref.tobytes()
                        and cur.getpalette() == ref.getpalette())
            except OSError:
                same = False
            ok &= same
        else:
            with open(path, 'wb') as f:
                f.write(data)
    if check:
        print('tranches du Boldo : %s' % ('a jour' if ok else 'PERIMEES — relancer tools/gen_boldo_slices.py'))
        sys.exit(0 if ok else 1)
    print('4 tranches de 12 x 36 -> %s' % os.path.relpath(DST, RACINE))


if __name__ == '__main__':
    main()
