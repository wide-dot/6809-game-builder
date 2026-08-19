#!/usr/bin/env python3
"""Rend transparents les BLOCS de ciel uniforme des in.png — prealable overlay.

    python3 tools/sky_transparent.py [01 02 ...]      # defaut : les 8 stages

En overlay, le champ de jeu est efface au noir (stackblast) en tete de trame
et DrawTiles repeint chaque trame. Les cellules de ciel pur n'ont donc pas
besoin de tuile : l'effacement porte deja leur noir. Mais le noir INTERIEUR
des formes doit rester PEINT — un pixel transparent au milieu d'un octet
force l'encodeur a masquer l'autre quartet (lecture-modification-ecriture),
ce qui grossit et ralentit la tuile la ou des octets pleins partent en
stack-blast.

La regle est donc PAR BLOC de 3x6 (largeur x hauteur — l'equivalent TO8
exact d'une tuile arcade 8x8 : reduction 3/8 en X, 3/4 en Y) : un bloc
ENTIEREMENT a l'index 1 (le ciel, noir) devient transparent (index 0) ;
tout autre bloc est laisse intact, son noir compris. Plus fin que la maille
de tuile 12x12 (4x2 blocs par tuile), il vide aussi le ciel des tuiles de
bord de terrain ; la largeur 3 n'est pas alignee octet (2 px), la frontiere
art/ciel peut donc couter un octet masque — le gain des pixels non peints
l'emporte.

Verifie avant remap : l'index 1 est noir (0,0,0) sur les 8 stages ; l'index 0
n'est utilise nulle part dans les sources. Le remap est idempotent.

NOTE : tools/arcade_to_in.py regenere un in.png au ciel peint — rejouer CE
script apres toute regeneration.
"""
import sys
from PIL import Image

BW, BH = 3, 6          # arcade 8x8 -> TO8 3x6 (3/8 en X, 3/4 en Y)
stages = sys.argv[1:] or [f"{n:02d}" for n in range(1, 9)]
for st in stages:
    p = f"src/stages/{st}/map/in.png"
    im = Image.open(p)
    assert im.mode == "P", f"{p}: attendu du PNG indexe"
    pal = im.getpalette()
    assert pal[3:6] == [0, 0, 0], f"{p}: l'index 1 n'est pas noir ({pal[3:6]})"
    px = im.load()
    W, H = im.size
    blocks = 0
    # la rangee de tuiles du BAS reste peinte : l'effaceur de fond s'arrete a
    # la ligne 178 (clearblast.asm), c'est la tilemap qui porte ce bandeau —
    # un bloc transparent ici laisserait des residus a l'ecran
    H_CLEAR = H - 12
    for cy in range(0, H_CLEAR, BH):
        for cx in range(0, W, BW):
            if all(px[cx + i, cy + j] == 1
                   for j in range(min(BH, H - cy))
                   for i in range(min(BW, W - cx))):
                for j in range(min(BH, H - cy)):
                    for i in range(min(BW, W - cx)):
                        px[cx + i, cy + j] = 0
                blocks += 1
    im.save(p, optimize=True)
    total = ((W + BW - 1) // BW) * ((H + BH - 1) // BH)
    print(f"{p}: {blocks}/{total} blocs de ciel pur -> transparents")
