#!/usr/bin/env python3
"""Construire la bande d'animation de l'engulf du gomander (stage 2).

Le boss du stage 2 avale l'outslay dans son tube : l'orbe — son point faible —
se referme puis se rouvre. L'arcade ne fait pas ca avec un sprite, elle
REPEINT un rectangle de sa tilemap de fond (gomander_helper_blit_recipe,
0x40:A578, huit charges utiles de 6x4 cellules). Chez nous c'est
`tilemap.patch` (voir docs/lang/en/tilemaps.md).

## Ou, exactement

L'arcade sonde une position ECRAN fixe — (0x1EC, 0x10C) posee juste avant
`probe_foreground_tile` en 0x40:A344 — et blitte a la case ainsi trouvee. La
conversion Conv donne l'ecran v2 (72.5, 97), mais la colonne de carte ne s'en
deduit PAS : notre carte est une fenetre de la carte arcade, la numerotation
absolue ne se transpose pas.

La position a donc ete RETROUVEE par correlation, une fois l'art converti sur
la palette du stage (avant conversion, comparer du RGB n'a aucun sens) : la
derniere image de orb-close, celle ou l'orbe est entierement recouvert, se
recale en (1047, 84) de `map/in.png` avec un ecart moyen de 23 par composante
contre 49 au deuxieme candidat. Pic net, pas une coincidence.

    x=1047 -> colonne 87.25, l'art est decale de 3 px dans la colonne 87
    y=  84 -> ligne 7.00, les lignes tombent pile

L'art fait 18x24 et couvre donc DEUX colonnes (87, 88) et DEUX lignes (7, 8).
Le rectangle du patch est 2x2 cellules, soit 24x24 px, l'art centre dedans a
l'offset (3, 0).

## Comment

Chaque image de la bande est le sol — les 24x24 px de NOTRE carte a cet
endroit — avec l'engulf converti pose par-dessus. Le sol, et non du vide :
l'art de l'arcade ne remplit pas les 24 px de large, et sans lui les 3 px de
marge de chaque cote seraient transparents alors que la carte y a du decor.

Le boss applique l'image de repos a son init, de sorte que la carte d'origine
ne soit jamais celle qu'on voit : la conversion n'etant pas identique au pixel
pres a l'art de la carte (elle a suivi une autre histoire de palette), passer
de l'une a l'autre en cours de sequence ferait un saut.

    usage : tools/gen_engulf.py [--frames N]

Sortie : src/stages/02/engulf/in.png, bande de N images de 24x24 posees COTE
A COTE — la forme que <leanscroll> decoupe et que <tilepatch> tranche par
plage.
"""
import argparse
import os
import subprocess
import sys
import glob

from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCADE = os.path.expanduser('~/Documents/Claude/Projects/re.arcade.r-type')

# Le recalage, mesure (voir l'en-tete). En pixels de map/in.png.
ANCRE_X, ANCRE_Y = 1047, 84
COLS, ROWS, TUILE = 2, 2, 12
CELL_X = (ANCRE_X // TUILE) * TUILE      # 1044, le coin de la colonne 87
CELL_Y = (ANCRE_Y // TUILE) * TUILE      # 84, le coin de la ligne 7
OFFSET_X = ANCRE_X - CELL_X              # 3
OFFSET_Y = ANCRE_Y - CELL_Y              # 0

COLONNE_CARTE = CELL_X // TUILE
LIGNE_CARTE = CELL_Y // TUILE


def convertir_frames(dst):
    """Convertit les frames arcade sur la palette du stage 2, via l'outil commun."""
    src = os.path.join(ARCADE, 'out', 'sprites', 'gomander', 'orb-close')
    if not os.path.isdir(src):
        sys.exit('%s : absent. Exporter le catalogue arcade d\'abord '
                 '(CatalogExporter gere tile_grid depuis le 21/08/2026).' % src)
    orig = os.path.join(dst, 'images', 'original', 'orb-close')
    os.makedirs(orig, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(src, '*.png'))):
        Image.open(f).save(os.path.join(orig, os.path.basename(f)))
    outil = os.path.join(RACINE, 'tools', 'arcade_to_sprites.py')
    subprocess.run([sys.executable, outil, dst, '--palette', '02'], check=True)
    return sorted(glob.glob(os.path.join(dst, 'images', 'orb-close', '*.png')))


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('--frames', type=int, default=8)
    ap.add_argument('-h', '--help', action='store_true')
    a = ap.parse_args()
    if a.help:
        print(__doc__)
        return 0

    tmp = os.path.join(RACINE, 'gen', 'stages', '02', 'engulf-src')
    frames = convertir_frames(tmp)
    if len(frames) < a.frames:
        sys.exit('%d images converties, %d demandees' % (len(frames), a.frames))
    frames = frames[:a.frames]

    carte = Image.open(os.path.join(RACINE, 'src/stages/02/map/in.png'))
    if carte.mode != 'P':
        sys.exit('map/in.png n\'est pas indexee : la composition se fait en INDEX')

    # Composer EN INDEX, jamais en RGB. Les deux sources vivent deja sur la
    # palette du stage — arcade_to_sprites.py a converti les frames dessus —
    # et un aller-retour par la couleur (convert/quantize) reaffecte les index
    # par proximite : l'encodeur de tuiles recevait alors des index hors des
    # seize materiels et sortait des `LDA #$f0f0`. On recopie donc les octets.
    w, h = COLS * TUILE, ROWS * TUILE
    ref = carte.getpalette()[:17 * 3]
    src = carte.load()
    bande = Image.new('P', (w * len(frames), h), 0)
    bande.putpalette(carte.getpalette())
    pix = bande.load()
    for i, f in enumerate(frames):
        ov = Image.open(f)
        if ov.mode != 'P' or ov.getpalette()[:17 * 3] != ref:
            sys.exit('%s : palette differente de celle de la carte' % f)
        o = ov.load()
        ow, oh = ov.size
        for y in range(h):
            for x in range(w):
                v = src[CELL_X + x, CELL_Y + y]          # le sol : notre carte
                ox, oy = x - OFFSET_X, y - OFFSET_Y
                if 0 <= ox < ow and 0 <= oy < oh:
                    t = o[ox, oy]
                    if t != 0:                            # 0 = transparent
                        v = t
                pix[i * w + x, y] = v
    dst = os.path.join(RACINE, 'src', 'stages', '02', 'engulf')
    os.makedirs(dst, exist_ok=True)
    out = os.path.join(dst, 'in.png')
    bande.save(out)

    print('%s : %d images de %dx%d cellules (%dx%d px)'
          % (out, len(frames), COLS, ROWS, w, h))
    print('  ancre mesuree (%d, %d) -> carte colonne %d ligne %d, art a l\'offset (%d, %d)'
          % (ANCRE_X, ANCRE_Y, COLONNE_CARTE, LIGNE_CARTE, OFFSET_X, OFFSET_Y))
    print('  a declarer : <tilepatch cols="%d" rows="%d" frames="%d" col="%d" row="%d"/>'
          % (COLS, ROWS, len(frames), COLONNE_CARTE, LIGNE_CARTE))
    return 0


if __name__ == '__main__':
    sys.exit(main())
