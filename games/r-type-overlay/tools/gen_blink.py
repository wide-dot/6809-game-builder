#!/usr/bin/env python3
"""Le clignotement de degats du gomander, derive de la carte du niveau.

L'arcade ne redessine rien pour ce flash : _arm_engulf_with_sfx (0x40:a2da)
cree deux acteurs run_blackout_pulse_palette qui repointent les BANCS de
palette 7 et 8 — ceux du corps du boss, cf. les attributs 0x0087/0x0088 des
recettes — vers le banc 4, seize trames durant, en alternant toutes les
quatre trames.

Nous n'avons qu'UNE palette de seize cases pour tout l'ecran, donc pas de
banc a repointer ; et aucune de nos couleurs n'appartient au boss en propre
(indices 3, 4, 8, 9, 10, 13, 14, 15 servent tous aussi au decor). Un flash de
palette globale ferait donc clignoter la roche. D'ou ce tileset : on recolore
les pixels, et le patch de tuiles ne touche que le boss.

La table de recoloration n'est pas choisie a l'oeil. Pour chacune de nos
seize couleurs on prend sa plus proche dans les bancs 7/8 (0x3DB50 / 0x3DB80),
puis la couleur du banc 4 (0x3DAC0) AU MEME EMPLACEMENT, puis notre index le
plus proche de celle-la. C'est la transposition exacte du swap arcade.

Elle s'effondre sur trois couleurs — blanc, cyan, bleu sombre — ce que montre
aussi la capture d'ecran de l'arcade.
"""
import os
from PIL import Image

MAP = 'src/stages/02/map/in.png'
OUT = 'src/stages/02/blink/in.png'
TUILE = 12
# La boite des bancs 7/8, mesuree sur level2_f.png (x 2688..2943, y 96..239)
# et ramenee a notre echelle (0.375 en x — le wide-dot —, 0.75 en y).
COL, ROW, COLS, ROWS = 84, 6, 8, 9
# Derivee par tools/gen_blink.py --table (voir l'en-tete).
FLASH = {1: 4, 2: 7, 3: 4, 4: 7, 5: 5, 6: 7, 7: 7, 8: 5,
         9: 7, 10: 7, 11: 4, 12: 4, 13: 4, 14: 7, 15: 7}


def main():
    im = Image.open(MAP)
    box = im.crop((COL * TUILE, ROW * TUILE,
                   (COL + COLS) * TUILE, (ROW + ROWS) * TUILE))
    px = box.load()
    w, h = box.size
    vus = {}
    for y in range(h):
        for x in range(w):
            v = px[x, y]
            if v == 0:                     # le crayon transparent reste vide :
                continue                   # ces cellules-la ne sont pas au boss
            n = FLASH.get(v, v)
            px[x, y] = n
            vus[(v, n)] = vus.get((v, n), 0) + 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    box.putpalette(im.getpalette())
    box.save(OUT)
    print('%s : %dx%d px, %d x %d cellules' % (OUT, w, h, COLS, ROWS))
    for (a, b), n in sorted(vus.items(), key=lambda kv: -kv[1]):
        print('   %2d -> %2d   %6d px' % (a, b, n))


if __name__ == '__main__':
    main()
