#!/usr/bin/env python3
"""Harmoniser les 12 COMMUNS sur des valeurs que le TO8 sait afficher.

    python3 tools/palette_harmonise.py [--verifier]

## Pourquoi

Une valeur de palette n'est pas ce que la machine montre : `png2pal` remplace
au build chaque couleur par la plus proche des 4096 du gamut TO8 (CIEDE2000,
`Png2PalPlugin.getNearestColor`). Cinq des douze communs n'étaient pas
représentables : l'éditeur de palette de l'auteur montrait donc autre chose
que l'écran, et une campagne couleur pouvait se juger sur un rendu faux — ce
qui est arrivé deux fois sur le stage 3 (voir « L'espace d'affichage » dans
arcade_to_in.py).

La règle depuis le 20/08/2026 : **un emplacement porte une valeur
représentable**. `png2pal` la retrouve alors à l'identique, et ce qu'on voit
en éditant est ce qui s'affichera.

## Les cinq valeurs, et comment elles ont été choisies

Trois n'ont demandé aucun arbitrage : les deux méthodes de quantification
possibles — arrondi composante par composante, ou plus proche voisin
CIEDE2000 sur le gamut — y tombent d'accord, et sur la même valeur que
png2pal embarquait déjà. Leur gravure ne change RIEN à l'écran.

    hw2  #a8a8a8 -> #ababab
    hw6  #08d4eb -> #00d4eb
    hw8  #ac0000 -> #ab0000

Les deux autres demandaient une décision, parce que les deux méthodes
divergent. Elles ont été tranchées sur la RAMPE des rouges (hw7..hw11), pas
sur la distance à la couleur isolée — c'est la régularité de la rampe qui se
voit à l'écran :

    hw7 #610000  L*18
    hw8 #ab0000  L*35
    hw9    ?     L*54 attendu (le milieu perceptuel de ses deux voisines)
    hw10   ?     L*73
    hw11 #faf261 L*94

    hw9  #cc5a3c -> #cc6100   (décision auteur, sur planche)
    hw10 #f99b68 -> #fa9e61

Ce que png2pal embarquait pour hw9, #d47a61, est à L*61 : sept points trop
clair, il colle à hw10 et la rampe perd une marche — sur les sprites qui
l'exercent, ton moyen et pêche se confondent. Les candidats retenus sont à
L*53-54, avec des demi-pas équilibrés (22/18 contre 27/14). Entre l'orange
brûlé #cc6100 et la brique mate #cc6161, tous deux bien placés, l'auteur a
tranché à l'œil pour le premier. Pour hw10, #fa9e61 aligne le rouge sur celui
de hw11 (250) là où png2pal montait à 255.

## Portée

Tout PNG indexé de `src/` et `tools/` dont les 12 communs sont EXACTEMENT
ceux de la référence — 884 fichiers au 20/08/2026 : les huit palettes de
stage, leurs cartes, et les images du jeu. Les autres (sources arcade,
palettes d'avant la campagne) ne sont pas touchés : leur palette n'est pas
celle du jeu, et les reconnaître à leurs douze communs est le seul critère
sûr. **Seules les entrées de palette changent ; aucun index de pixel n'est
touché**, donc aucune image ne change de dessin.

Idempotent : un fichier déjà harmonisé est reconnu et passé.
`--verifier` ne récrit rien et rend un compte.
"""
import glob
import os
import sys

from PIL import Image

# les 12 communs AVANT harmonisation (l'état de la campagne 08/2026)
AVANT = [(0, 0, 0), (97, 97, 97), (168, 168, 168), (250, 250, 242),
         (0, 97, 143), (0, 158, 204), (8, 212, 235), (97, 0, 0),
         (172, 0, 0), (204, 90, 60), (249, 155, 104), (250, 242, 97)]

# les cinq valeurs harmonisées, par indice matériel (= index PNG - 1)
HARMONISE = {2: (171, 171, 171),    # #ababab
             6: (0, 212, 235),      # #00d4eb
             8: (171, 0, 0),        # #ab0000
             9: (204, 97, 0),       # #cc6100  <- décision auteur (rampe)
             10: (250, 158, 97)}    # #fa9e61

APRES = [HARMONISE.get(i, c) for i, c in enumerate(AVANT)]


def communs(im):
    p = im.getpalette()
    return [tuple(p[i * 3:i * 3 + 3]) for i in range(1, 13)]


def main():
    verifier = '--verifier' in sys.argv
    fichiers = sorted(set(glob.glob('src/**/*.png', recursive=True)
                          + glob.glob('tools/**/*.png', recursive=True)))
    fait = deja = ignore = 0
    for f in fichiers:
        try:
            im = Image.open(f)
        except Exception:
            continue
        if im.mode != 'P':
            continue
        cur = communs(im)
        if cur == APRES:
            deja += 1
            continue
        if cur != AVANT:
            ignore += 1          # une autre palette : ce n'est pas notre affaire
            continue
        fait += 1
        if verifier:
            continue
        pal = im.getpalette()
        for hw, rgb in HARMONISE.items():
            pal[(hw + 1) * 3:(hw + 1) * 3 + 3] = list(rgb)
        im.putpalette(pal)
        im.save(f, optimize=True)
    verbe = 'a harmoniser' if verifier else 'harmonises'
    print(f'{fait} fichiers {verbe} ; {deja} deja a jour ; '
          f'{ignore} hors campagne (autre palette, intacts)')
    return 1 if (verifier and fait) else 0


if __name__ == '__main__':
    sys.exit(main())
