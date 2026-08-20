#!/usr/bin/env python3
"""Convertir le plan ARRIÈRE d'un niveau arcade en carte mscroll.

La couche mobile du stage 3 (le battleship) est rendue par le module mscroll
résident : une carte 2D que le blast repeint en entier — pas de transparence,
le ciel est peint. L'entrée du builder est un PNG indexé à la convention des
images du jeu (index 0 = magenta inutilisé, index i+1 = couleur matérielle i,
la palette du stage) que l'élément <mscroll> découpe en tuiles 8x16.

Géométrie :
  - réduction 3/8 en X, 3/4 en Y au plus proche voisin (arcade_to_in.py) ;
  - largeur tronquée à MSCROLL_W px v2 : la chorégraphie caméra du warship
    parcourt [0..285] px et la fenêtre fait 160 — tout au-delà de la bande
    utile n'est que du ciel (le vaisseau vit en v2 x 216..435) ;
  - hauteur complétée à MSCROLL_H par du ciel : l'équivalent v2 du wrap
    vertical 512 de la couche arcade — la caméra du script monte jusqu'à
    y=-66, le wrap doit montrer du ciel, jamais le vaisseau.

Couleurs : chaque pixel est ramené à la couleur du stage la plus proche en
CIE Lab ΔE76 — la métrique maison (arcade_to_in.py, dont on importe la
distance : mêmes chiffres, même cache), retenue sur planches d'essai par
l'auteur (20/08, variante 2 : Lab sur la palette du stage inchangée).
La comparaison se fait contre le RENDU de chaque emplacement, calculé par
`to8disp` (algorithme exact de png2pal, CIEDE2000) — pas contre la valeur
stockée, et pas contre une approximation ΔE76 de la quantification.

    usage : tools/arcade_to_mscroll.py 03 ~/.../out/tiles/level3_b.png
            [--force R,G,B=IDX ...]
    sortie : src/stages/03/map/battleship.png (+ stats)

`--force` affecte une couleur SOURCE à un emplacement nommé (index PNG), quoi
qu'en dise la distance — même mécanisme et même raison d'être que dans
arcade_to_in.py : le plus proche voisin ne voit que des couleurs isolées,
jamais un dégradé, et il écrase toute une rampe sur un seul emplacement. Ici
c'est la coque du vaisseau : ses trois verts sombres tombent sinon sur le gris
commun, alors que l'olive #616100 leur donne un second niveau de vert.
"""
import importlib.util
import os
import sys
from PIL import Image

_spec = importlib.util.spec_from_file_location(
    'arcade_to_in', os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 'arcade_to_in.py'))
_a2i = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_a2i)
dist_lab = _a2i.dist_lab

MSCROLL_W, MSCROLL_H = 640, 384    # v2 px — multiples de 8 et 16
SKY_HW = 0                          # la couleur materielle du ciel (noir)

stage, src = sys.argv[1], sys.argv[2]
# --force R,G,B=IDX : une couleur SOURCE va dans CET emplacement (index PNG),
# quoi qu'en dise la distance. Meme mecanisme et meme raison d'etre que dans
# arcade_to_in.py : le plus proche voisin ne voit que des couleurs isolees,
# jamais un degrade, et il ecrase toute une rampe sur un seul emplacement.
# Ici c'est la coque du vaisseau — ses trois verts sombres tombent sinon sur
# le gris commun, alors que l'olive #616100 leur donne un second niveau.
forces = {}
_args = sys.argv[3:]
while _args:
    a = _args.pop(0)
    if a != '--force':
        raise SystemExit('argument inconnu : %s' % a)
    rgb, idx = _args.pop(0).split('=')
    forces[tuple(int(v) for v in rgb.split(','))] = int(idx)
    print('force %s -> emplacement PNG %d' % (rgb, int(idx)))
ref = Image.open(f"src/stages/{stage}/map/in.png")
refpal = ref.getpalette()
# la palette du stage : couleurs materielles 0..15 = entrees PNG 1..16
hw = [tuple(refpal[(i + 1) * 3:(i + 1) * 3 + 3]) for i in range(16)]

# Le mapping se fait contre ce que l'ECRAN affichera, pas contre les valeurs
# stockees : png2pal quantifie chaque couleur sur le gamut TO8 (16 niveaux
# par composante, rien entre 0 et 97) et certains emplacements bougent
# beaucoup. Le rendu se calcule avec `to8disp`, qui reproduit l'algorithme
# EXACT de png2pal (CIEDE2000) — approcher cette quantification par un dE76,
# comme ici jusqu'au 20/08/2026, donne des couleurs franchement fausses sur
# les tons sombres : (48,64,32) s'affiche (0,97,0), un vert vif, la ou dE76
# annoncait un gris-vert. La coque du battleship a ete convertie et jugee
# deux fois sur ce mauvais rendu.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from to8disp import displayed
hw_disp = [displayed(c) for c in hw]
for i, (c, q) in enumerate(zip(hw, hw_disp)):
    if c != q:
        print(f"  hw{i} #{'%02x%02x%02x' % c} s'affichera #{'%02x%02x%02x' % q}")

im = Image.open(src).convert("RGB")
W, H = im.size
w, h = round(W * 3 / 8), round(H * 3 / 4)
im = im.resize((w, h), Image.NEAREST)

out = Image.new("P", (MSCROLL_W, MSCROLL_H), SKY_HW + 1)
flat = [204, 0, 255]
for rgb in hw:
    flat += list(rgb)
out.putpalette(flat + [0, 0, 0] * (256 - 17))

cache = {}
def nearest(c):
    if c not in cache:
        if c in forces:
            cache[c] = forces[c] - 1          # index PNG -> couleur materielle
        else:
            cache[c] = min(range(16), key=lambda i: dist_lab(hw_disp[i], c))
    return cache[c]

px, po = im.load(), out.load()
exact = 0
for y in range(min(h, MSCROLL_H)):
    for x in range(min(w, MSCROLL_W)):
        i = nearest(px[x, y])
        po[x, y] = i + 1
        if hw[i] == px[x, y]:
            exact += 1

dst = f"src/stages/{stage}/map/battleship.png"
out.save(dst, optimize=True)
n = min(h, MSCROLL_H) * min(w, MSCROLL_W)
print(f"{dst}: {MSCROLL_W}x{MSCROLL_H} (contenu {min(w,MSCROLL_W)}x{h}), "
      f"{len(cache)} couleurs source, {100*exact/n:.1f}% exactes sur la palette du stage")
