#!/usr/bin/env python3
"""Les EPAVES des 27 sous-parties de coque du vaisseau (stage 3) : le fond
epave converti et les rectangles, pour l'element <mscroll patches=...>.

    python3 tools/gen_warship_wreck.py          (depuis games/r-type)

L'ARCADE. Une sous-partie qui tombe (12 coups) ne laisse pas la coque
intacte : warship_part_destroy_wreckage_paint_tick (40:c8d6 -> c8e8) blitte
sa RECETTE D'EPAVE — une grille de tuiles, lignes x colonnes — dans la
tilemap de fond, a la cellule de son ancre. La coque est detruite ZONE PAR
ZONE, au fil des attaques, et le reste jusqu'au rechargement de la tilemap
(retour a un checkpoint). Analyse et cellules : re.arcade.r-type,
extractor.Warship (--extract-warship), qui ecrit out/warship/warship-wreck.csv
et out/warship/level3_b_wrecked.png — le fond du stage 3 avec les 27 epaves
en place (aucune n'en recouvre une autre).

CHEZ NOUS, LE MEME GESTE : la coque est la carte mscroll (tuiles 8x16 de 32
octets, ids 16 bits dans la carte), et l'epave est un PATCH de cette carte —
les cellules de son rectangle recoivent des tuiles d'epave, ajoutees au jeu
par le builder (<mscroll patches=... patchimage=...>, qui ecrit
gen/stages/03/bship/battleship.patches.asm) ; le runtime reecrit la carte a
la mort de la piece et re-nourrit les colonnes visibles (src/stages/03/bship/
patch.asm), et la remet d'origine au retour au checkpoint. Cout par trame :
ZERO. La premiere version (10/09/2026) dessinait l'epave en SPRITE de fond
chez wsmgr : 1 700 cycles par epave et par rendu, mesures sous toje, neuf
epaves faisaient passer la periode de rendu de 8,3 a 9,1 trames — refuse par
l'auteur.

LA CONVERSION est celle de la coque elle-meme : arcade_to_mscroll.py sur le
fond epave, MEMES forces de couleurs que dans tools/palette-replay.sh (a
tenir a jour ensemble). Les rectangles sont les cellules arcade converties
(colonne x 3, ligne x 6 : une cellule arcade de 8x8 fait 3x6 chez nous) ;
le builder les decoupe en cellules 8x16 de SA carte et ne retient que
celles qui changent.

SORTIES (commitees, lues par le config) :
  src/stages/03/map/battleship-wrecked.png   le fond converti, epaves en place
  src/stages/03/map/battleship-wrecks.csv    name,x,y,w,h par piece (px v2)
"""
import csv
import os
import subprocess
import sys

EXPORT = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
          '/out/warship')
# les forces de couleurs de la coque — celles de tools/palette-replay.sh
FORCES = ['--force', '88,96,72=15', '--force', '48,64,32=15', '--force', '104,104,80=15']
DST_PNG = 'src/stages/03/map/battleship-wrecked.png'
DST_CSV = 'src/stages/03/map/battleship-wrecks.csv'


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(racine)
    src = os.path.join(EXPORT, 'level3_b_wrecked.png')
    if not os.path.exists(src):
        sys.exit('export absent : %s (re.arcade.r-type --extract-warship)' % src)
    subprocess.run([sys.executable, 'tools/arcade_to_mscroll.py', '03', src,
                    '--out', DST_PNG] + FORCES, check=True)
    parts = list(csv.DictReader(open(os.path.join(EXPORT, 'warship-wreck.csv'))))
    with open(DST_CSV, 'w') as f:
        f.write('name,x,y,w,h\n')
        for r in parts:
            f.write('part%02d,%s,%s,%s,%s\n' % (int(r['part']), r['x_v2'], r['y_v2'], r['w_v2'], r['h_v2']))
    print('%s et %s : %d epaves' % (DST_PNG, DST_CSV, len(parts)))


if __name__ == '__main__':
    main()
