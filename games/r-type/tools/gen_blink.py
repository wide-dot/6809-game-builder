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
ENGULF = 'src/stages/02/engulf/in.png'
OUT = 'src/stages/02/blink/in.png'
TUILE = 12
# La boite des bancs 7/8, mesuree sur level2_f.png (x 2688..2943, y 96..239)
# et ramenee a notre echelle (0.375 en x — le wide-dot —, 0.75 en y).
COL, ROW, COLS, ROWS = 84, 6, 8, 9
# L'oeil, et l'image de la bande engulf qui le montre OUVERT.
EYE_COL, EYE_ROW, EYE_COLS, EYE_ROWS = 87, 7, 2, 2
EYE_FRAME = 0                          # payload_00 arcade : « orb exposed »

# LA RAMPE. Le banc 4 de l'arcade (0x3DAC0) est un degrade blanc / cyan /
# bleu ; nos seize cases en contiennent quatre alignees dessus, du bleu
# sombre au blanc. On y projette la LUMINANCE de la couleur d'origine, ce qui
# garde le modele du dessin — un simple « plus proche voisin » couleur par
# couleur ecrasait tout sur trois teintes et applatissait le boss.
RAMPE = [5, 6, 7, 4]                   # #00618f  #009ecc  #00d4eb  #fafaf2


def luminance(rgb):
    r, g, b = rgb
    return 0.299 * r + 0.587 * g + 0.114 * b


def table(palette):
    """index d'origine -> index de la rampe, par rang de luminance."""
    lum = {i: luminance(palette[i]) for i in range(1, 16)}
    lo, hi = min(lum.values()), max(lum.values())
    out = {}
    for i, v in lum.items():
        t = 0.0 if hi == lo else (v - lo) / (hi - lo)
        out[i] = RAMPE[min(len(RAMPE) - 1, int(t * len(RAMPE)))]
    return out


def main():
    im = Image.open(MAP)
    pal = im.getpalette()
    rgb = [tuple(pal[i * 3:i * 3 + 3]) for i in range(16)]
    box = im.crop((COL * TUILE, ROW * TUILE,
                   (COL + COLS) * TUILE, (ROW + ROWS) * TUILE))

    # L'OEIL OUVERT, et pas celui de la carte. Le flash arcade demarre sur
    # payload_00 — _arm_engulf_with_sfx pose [+0x24]=15, _tick_engulf_loop
    # indexe la table rev par (15 & 0xe)/2 = 7, soit rev[7] = payload_00,
    # « orb exposed ». La carte, elle, porte l'oeil du niveau, qu'on ne voit
    # jamais : le boss stampe une pose des son init.
    eye = Image.open(ENGULF)
    w = EYE_COLS * TUILE
    frame = eye.crop((EYE_FRAME * w, 0, (EYE_FRAME + 1) * w, EYE_ROWS * TUILE))
    box.paste(frame, ((EYE_COL - COL) * TUILE, (EYE_ROW - ROW) * TUILE))

    FLASH = table(rgb)
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
    box.putpalette(pal)
    box.save(OUT)
    print('%s : %dx%d px, %d x %d cellules, oeil OUVERT (image %d)'
          % (OUT, w, h, COLS, ROWS, EYE_FRAME))
    for (a, b), n in sorted(vus.items(), key=lambda kv: -kv[1]):
        print('   %2d (lum %3d) -> %2d   %6d px'
              % (a, luminance(rgb[a]), b, n))


if __name__ == '__main__':
    main()
