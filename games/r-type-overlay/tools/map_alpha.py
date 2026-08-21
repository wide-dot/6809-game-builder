#!/usr/bin/env python3
"""Reporte la TRANSPARENCE ARCADE dans les in.png — remplace sky_transparent.py.

    python3 tools/map_alpha.py [01 02 ...]      # defaut : les 8 stages

## Ce que porte la source

Les plans de niveau exportes par `re.arcade.r-type` (out/tiles/levelN_{f,b}.png,
copies dans src/stages/NN/map/images/original/) portent depuis 08/2026 un chunk
tRNS : le pen 0 de chacune des 16 banques de couleur est le pen TRANSPARENT de
la couche — le materiel y montre ce qu'il y a derriere (l'autre plan de tuiles,
puis le fond). L'information n'est PAS dans le pixel : le pen 0 d'une banque a
une couleur comme les autres, en general du noir. Elle ne peut voyager qu'en
alpha. Les indices, eux, sont intacts : un index stocke vaut toujours
banque*16 + pen, et un lecteur qui ignore tRNS voit exactement l'image d'avant.

## Ce que fait ce script

En overlay, le champ de jeu est efface au noir (stackblast) en tete de trame et
DrawTiles repeint chaque trame. Une cellule sans pixel opaque n'a donc pas de
tuile : l'effacement porte deja son noir. Ce script marque donc, dans l'in.png
converti, les pixels que l'arcade declare transparents — index 0, la convention
de transparence de toute la chaine gfxcomp.

La regle, VOLONTAIREMENT CONSERVATRICE :

    un pixel devient transparent s'il est NOIR (index 1) dans l'in.png
    ET transparent dans le plan arcade.

Elle ne peut donc jamais effacer de l'art : un pixel colore reste peint quoi
qu'en dise la source. Mesure du 21/08/2026 — sur les stages 02 a 08 la regle ne
coute RIEN, le masque arcade tombe a 100 % sur des pixels noirs (0 pixel colore
concerne, 0 pixel transparent que l'arcade dise opaque). Le seul ecart est au
stage 01, dont l'in.png ne vient pas de l'arcade mais de l'art v1 migre
(palette_migrate) : 1 083 pixels y sont colores la ou l'arcade est transparente
— ils restent peints — et 1 287 pixels y sont deja transparents (l'ancien
decoupage 3x6) la ou l'arcade est opaque — ils restent transparents, ce qui est
l'etat livre aujourd'hui et ne change rien a l'ecran (noir peint et noir efface
sont le meme noir, le second est gratuit). Le rapport les affiche a chaque
execution : c'est la mesure de la derive entre l'art v1 et l'arcade.

## Ce que ce script REMPLACE

`tools/sky_transparent.py` (supprime) : il ne connaissait pas la transparence
et devinait le ciel par BLOCS de 3x6 pixels entierement noirs — la maille d'une
tuile arcade 8x8 reduite. Deux defauts : la maille rate tout ciel plus fin
qu'un bloc, et elle efface du noir INTERIEUR aux formes des qu'il remplit un
bloc. Le masque arcade est exact au pixel et n'a besoin d'aucune heuristique.
Il gagne ~2 % de pixels transparents en plus sur les stages 01 et 03, les seuls
qui etaient traites.

## Rejeu

Le script est idempotent, et il se rejoue apres toute regeneration d'un in.png.
`tools/arcade_to_in.py` pose desormais l'alpha lui-meme a la conversion : ce
script reste le chemin pour les images DEJA converties (dont le stage 01, hors
chaine arcade) et le garde-fou qui verifie l'accord entre les deux.
"""
import sys

from PIL import Image

# Le plan arcade de chaque stage — le MEME que celui de tools/palette-replay.sh.
# Stage 08 : son art est dans le plan ARRIERE (le plan avant reduit est tout
# noir), d'ou le 'b'. C'est la couche du bas : ce que son pen 0 laisse voir est
# le fond, noir lui aussi — l'effacement overlay en fait autant.
PLANE = {'01': 'f', '02': 'f', '03': 'f', '04': 'f',
         '05': 'f', '06': 'f', '07': 'f', '08': 'b'}

SCALE_X, SCALE_Y = 3 / 8, 3 / 4      # la reduction TO8, cf. arcade_to_in.py

TRANSPARENT, NOIR = 0, 1             # index PNG : 0 transparent, 1 = materiel 0


def stamp(stage, ecrire=True):
    plan = f'src/stages/{stage}/map/images/original/level{int(stage)}_{PLANE[stage]}.png'
    src = Image.open(plan)
    if src.mode != 'P':
        raise SystemExit(f'{plan}: attendu du PNG indexe')
    trns = src.info.get('transparency')
    if trns is None:
        raise SystemExit(f'{plan}: pas de chunk tRNS — re-exporter le plan avec '
                         "re.arcade.r-type --extract-tiles (l'export d'avant "
                         '08/2026 ne portait pas la transparence)')
    sp = src.load()
    w, h = src.size

    dst = f'src/stages/{stage}/map/in.png'
    im = Image.open(dst)
    if im.mode != 'P':
        raise SystemExit(f'{dst}: attendu du PNG indexe')
    pal = im.getpalette()
    if pal[3:6] != [0, 0, 0]:
        raise SystemExit(f'{dst}: index 1 non noir ({pal[3:6]})')
    px = im.load()
    W, H = im.size
    if (W, H) != (round(w * SCALE_X), round(h * SCALE_Y)):
        raise SystemExit(f'{dst}: {W}x{H} n\'est pas la reduction de {plan} '
                         f'({w}x{h} -> {round(w * SCALE_X)}x{round(h * SCALE_Y)})')

    pose = deja = colore = opaque_mais_vide = 0
    for y in range(H):
        ay = y * h // H                       # plus proche voisin, phase 0 —
        for x in range(W):                    # le meme calcul que arcade_to_in
            v = px[x, y]
            if trns[sp[x * w // W, ay]] == 0:
                if v == NOIR:
                    if ecrire:
                        px[x, y] = TRANSPARENT
                    pose += 1
                elif v == TRANSPARENT:
                    deja += 1
                else:
                    colore += 1               # de l'art la ou l'arcade ne voit rien
            elif v == TRANSPARENT:
                opaque_mais_vide += 1         # deja vide la ou l'arcade peint

    if ecrire:
        im.save(dst, optimize=True)
    total = W * H
    ecart = ''
    if colore or opaque_mais_vide:
        ecart = (f' | ecart art/arcade : {colore} px colores gardes peints, '
                 f'{opaque_mais_vide} px deja vides')
    print(f'{dst}: {pose + deja} px transparents ({100 * (pose + deja) / total:.1f} %), '
          f'dont {pose} poses ici{ecart}')
    return pose, deja, colore, opaque_mais_vide


if __name__ == '__main__':
    for st in (sys.argv[1:] or sorted(PLANE)):
        stamp(st)
