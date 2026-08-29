#!/usr/bin/env python3
"""Les 27 sous-parties de coque du vaisseau : leurs boites, extraites de la ROM.

Une sous-partie n'a PAS de sprite — son corps visible est la couche mscroll,
deja peinte. Ce qu'il lui faut, c'est sa BOITE, et celle-ci se lit en deux
sauts depuis la vignette d'installation :

  vignette (40:c656 + 12i)  MOV [BP+0x10],<recette> ; MOV [BP+0x3c],<face>
  recette  (1000:73xx)      fdb boite, fdb dx, fdb dy, fcb lignes, colonnes,
                            puis les tuiles de l'epave
  boite    (1000:77b8+8k)   fdb x_min, x_max, y_min, y_max

Rien n'est recopie a la main : on relit le dump arcade, on suit les deux
indirections et on convertit par la formule de la table (x par 0,375, y par
0,75 avec inversion d'axe). Le fichier produit cite chaque adresse arcade.

L'ecart dx/dy de la recette n'est PAS lu : il ancre l'epave, differee a la
tranche 3 (doc/warship-parts-plan.md). Les positions de naissance viennent du
script de spawn, pas d'ici.

Usage : python3 tools/gen_warship_parts.py   (depuis games/r-type)
"""
import os
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
CODE = 0x40 * 16          # segment de code, adresse lineaire
DATA = 0x1000 * 16        # segment de donnees
THUNK0 = 0xC656           # la premiere vignette
NPARTS = 27
VIGNETTE = 12             # 5 + 4 + 3 octets


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if not os.path.exists(ROM):
        sys.exit('dump arcade absent : ' + ROM)
    rom = open(ROM, 'rb').read()

    def w(base, off):
        return rom[base + off] | (rom[base + off + 1] << 8)

    def sw(base, off):
        v = w(base, off)
        return v - 0x10000 if v >= 0x8000 else v

    lignes = [
        "; Les boites des 27 sous-parties de coque — GENERE par",
        "; tools/gen_warship_parts.py depuis le dump arcade (deux indirections :",
        "; vignette 40:c656+12i -> recette 1000:73xx -> boite 1000:77b8+8k).",
        ";",
        "; Une entree : fcb rx, ry, cx, cy — rayons et EXCENTRAGE du centre, en",
        "; pixels v2. Les boites arcade sont asymetriques (le corps deborde vers",
        "; le haut de l'ancre), d'ou l'excentrage ; l'axe y arcade monte, donc le",
        "; signe s'inverse a la conversion.",
        "",
        "part.Boxes",
    ]
    for i in range(NPARTS):
        t = CODE + THUNK0 + i * VIGNETTE
        assert rom[t] == 0xC7 and rom[t + 1] == 0x46 and rom[t + 2] == 0x10, \
            'vignette %d inattendue' % i
        recette = rom[t + 3] | (rom[t + 4] << 8)
        face = rom[t + 8]
        boite = w(DATA + recette, 0)
        x0, x1 = sw(DATA + boite, 0), sw(DATA + boite, 2)
        y0, y1 = sw(DATA + boite, 4), sw(DATA + boite, 6)
        rx = round((x1 - x0) * 0.375 / 2)
        ry = round((y1 - y0) * 0.75 / 2)
        cx = round((x0 + x1) / 2 * 0.375)
        cy = round(-(y0 + y1) / 2 * 0.75)          # l'axe y arcade monte
        for v, nom in ((rx, 'rx'), (ry, 'ry'), (cx, 'cx'), (cy, 'cy')):
            assert -128 <= v <= 127, 'partie %d : %s hors octet (%d)' % (i, nom, v)
        # PAS d'alignement par %3d : lwasm refuse l'espace APRES la virgule
        # (piege deja paye sur les vitesses du wick, 25/08).
        lignes.append('        fcb   %d,%d,%d,%d ; #%d recette %04X boite %04X '
                      'face %d — arcade x[%d..%d] y[%d..%d]'
                      % (rx, ry, cx, cy, i, recette, boite, face, x0, x1, y0, y1))
    lignes.append('')
    dst = os.path.join(racine, 'src/enemies/warship-elements/part/boxes.asm')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, 'w') as f:
        f.write('\n'.join(lignes))
    print('%d boites extraites -> src/enemies/warship-elements/part/boxes.asm'
          % NPARTS)


if __name__ == '__main__':
    main()
