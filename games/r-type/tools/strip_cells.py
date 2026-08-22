#!/usr/bin/env python3
"""Retirer d'un `in.png` les cellules 3x6 désignées par un bitfield packé.

    python3 tools/strip_cells.py <in.png> <masque.bin> [--dry-run]

## À quoi ça sert

Une couche de rendu dédiée peut posséder certaines cellules de la carte. Le cas
du portage est le champ de gommes du stage 4 : 1 618 cellules que le runtime
dessine et détruit depuis le bitfield de collision, et qui n'ont donc rien à
faire dans les tuiles compilées. Les retirer de l'`in.png` fait disparaître les
tuiles correspondantes du tileset et vide les entrées de la carte — la salle
cesse de coûter 164 tuiles dessinées par trame.

Les pixels retirés passent en **index 0**, la convention de transparence de
toute la chaîne gfxcomp : plus de pixel opaque, donc plus de tuile. En overlay
le champ est effacé au noir puis repeint chaque trame, une cellule vide n'a
rien à dessiner.

## Pourquoi cet outil ET l'option `--masque` d'arcade_to_in.py

Les deux font la même chose à deux moments différents :

- `arcade_to_in.py --masque` l'applique **à la conversion**, depuis le plan
  arcade. C'est le chemin canonique : quand la campagne palette se rejoue, les
  cellules restent sorties sans qu'on ait à y penser ;
- celui-ci l'applique **à un `in.png` déjà converti**, sans le régénérer.

Le second existe parce que régénérer un `in.png` ne rejoue pas seulement le
masque : il rejoue aussi toutes les évolutions de l'outil depuis la dernière
conversion du stage. Sur le stage 4, régénérer déplaçait 1 649 pixels d'un
emplacement de palette à un autre (la correction « espace d'affichage » du
20/08, pas encore rejouée sur ce stage) — un changement visible, légitime, mais
qui est une décision de campagne palette et n'a rien à faire dans un commit qui
retire des gommes. Cet outil garantit que le diff ne contient QUE les cellules
masquées.

## Le format du masque

Celui des masques de collision du jeu : une cellule 3x6 par bit, `largeur en
cellules / 8` octets par rangée, bit 7 = cellule la plus à gauche. C'est le
format que produit `re.arcade.r-type --extract-ballfield`.
"""
import argparse
import sys

from PIL import Image


def strip(chemin_png, chemin_masque, ecrire=True):
    im = Image.open(chemin_png)
    if im.mode != 'P':
        raise SystemExit('%s n\'est pas une image indexee (mode %s)'
                         % (chemin_png, im.mode))
    width, height = im.size
    cols, rows = width // 3, height // 6
    stride = cols // 8

    with open(chemin_masque, 'rb') as f:
        data = f.read()
    attendu = stride * rows
    if len(data) != attendu:
        raise SystemExit('masque %s : %d octets, attendu %d (%d cellules x %d '
                         'rangees)' % (chemin_masque, len(data), attendu,
                                       cols, rows))

    px = im.load()
    cellules = 0
    pixels = 0
    deja = 0
    for cy in range(rows):
        for cx in range(cols):
            if not (data[cy * stride + cx // 8] >> (7 - (cx % 8))) & 1:
                continue
            cellules += 1
            for dy in range(6):
                for dx in range(3):
                    x, y = cx * 3 + dx, cy * 6 + dy
                    if px[x, y] == 0:
                        deja += 1
                    else:
                        pixels += 1
                        if ecrire:
                            px[x, y] = 0

    print('%s : %d cellules masquees, %d px passes en index 0 '
          '(%d etaient deja transparents)'
          % (chemin_png, cellules, pixels, deja))
    if ecrire:
        # la palette est inchangee : on ne touche qu'aux indices
        im.save(chemin_png)
        print('ecrit %s' % chemin_png)
    return cellules, pixels


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('image')
    ap.add_argument('masque')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('-h', '--help', action='store_true')
    args = ap.parse_args()
    if args.help:
        print(__doc__)
        return 0
    strip(args.image, args.masque, ecrire=not args.dry_run)
    return 0


if __name__ == '__main__':
    sys.exit(main())
