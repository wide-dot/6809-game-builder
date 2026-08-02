#!/usr/bin/env python3
"""Extraire la section d'ouverture d'un niveau, tuiles et carte.

Les niveaux complets ne tiennent pas dans une page de 16 Ko une fois leurs
tuiles compilées : le niveau 1 en compte 245 (plan pair) et 304 (impair), le
niveau 2 191 et 230. Le placement multi-pages des tuiles — le bin-packing du
pipeline v1 — n'existe pas encore côté v2 ; en attendant, un stage se construit
sur la PREMIÈRE SECTION du niveau, tuiles et carte réelles, renumérotées pour
ne garder que ce que la section utilise.

Les deux plans sont des jeux de tuiles indépendants avec leur propre
numérotation : le plan impair est le décalage d'un pixel précalculé par
leanscroll, et le décalage casse des équivalences (d'où ses tuiles en plus).
Chacun garde donc sa carte et son strip.

    usage : tools/crop_stage.py <NN> <colonnes> [premiere colonne]

La fenêtre n'est pas forcément le début du niveau : le niveau 2 ouvre sur sa
partie la plus dense (100 tuiles distinctes en 24 colonnes, 18 Ko compilés),
alors qu'une fenêtre de même largeur prise plus loin n'en demande que 60. Le
choix est mesuré, pas esthétique.

Entrées  : src/stages/NN/map/{0,1}/{0,1}.png et {0,1}.0.bin (sorties leanscroll)
Sorties  : src/stages/NN/map/intro/{even,odd}.png et .bin, et intro/map.const.asm
"""
import os
import struct
import sys

from PIL import Image

ROWS = 15
TILE = 12


def crop(stage, columns, first, plane, name):
    base = f'src/stages/{stage}/map/{plane}'
    raw = open(f'{base}/{plane}.0.bin', 'rb').read()
    ids = [(raw[i] << 8) | raw[i + 1] for i in range(0, len(raw), 2)]
    total = len(ids) // ROWS
    if first + columns > total:
        raise SystemExit(f'niveau {stage} : {total} colonnes seulement')

    kept = [ids[c * ROWS + r] for c in range(first, first + columns) for r in range(ROWS)]
    used = sorted(set(kept) - {0})
    # 0 reste 0 : la convention « ne rien dessiner » du buffer de carte
    renum = {old: new for new, old in enumerate(used, start=1)}

    sheet = Image.open(f'{base}/{plane}.png')
    out = Image.new('P', (TILE, TILE * (len(used) + 1)), 0)
    out.putpalette(sheet.getpalette())
    # position 0 : la tuile vide du tileset d'origine, gardée pour que les
    # indexes de la feuille restent lisibles face à la source
    out.paste(sheet.crop((0, 0, TILE, TILE)), (0, 0))
    for new, old in enumerate(used, start=1):
        out.paste(sheet.crop((0, old * TILE, TILE, (old + 1) * TILE)), (0, new * TILE))

    os.makedirs(f'src/stages/{stage}/map/intro', exist_ok=True)
    out.save(f'src/stages/{stage}/map/intro/{name}.png')
    with open(f'src/stages/{stage}/map/intro/{name}.bin', 'wb') as f:
        for tile in kept:
            f.write(struct.pack('>H', renum.get(tile, 0)))
    print(f'  {name} : colonnes {first}..{first + columns - 1}, {len(used)} tuiles sur {max(ids) + 1}, '
          f'{kept.count(0) * 100 // len(kept)}% de vides')
    return len(used)


def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit(__doc__)
    stage, columns = sys.argv[1], int(sys.argv[2])
    first = int(sys.argv[3]) if len(sys.argv) == 4 else 0
    print(f'niveau {stage} :')
    crop(stage, columns, first, '0', 'even')
    crop(stage, columns, first, '1', 'odd')
    open(f'src/stages/{stage}/map/intro/map.const.asm', 'w').write(
        f"""* ===========================================================================
* Geometrie de la section — genere par tools/crop_stage.py {stage} {columns} {first}
* ===========================================================================
map.COLS  equ {columns}
map.ROWS  equ {ROWS}
""")


main()
