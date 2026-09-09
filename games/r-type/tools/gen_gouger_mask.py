#!/usr/bin/env python3
"""Le masque de decor DU GOUGER : solide = toute cellule sauf 0xFA0.

    python3 tools/gen_gouger_mask.py \
        ../../../re.arcade.r-type/out/tiles/level2_f_tiles.bin \
        src/stages/02/terrain/level2_fc.bin \
        src/stages/02/terrain/level2_gouger.bin

Deux conventions de solidite cohabitent sur la borne (08/09/2026, code lu,
pas les plates) :

  - le vaisseau, les armes, run_cancer, run_pow_armor, le bink : une cellule
    est solide si son id est INFERIEUR a 0xDFC (`CMP AX,0xDFC / JC`). C'est le
    critere de l'export `levelN_fc.bin` de re.arcade.r-type
    (TileGroupSet, `t8Id < solidityTile`), donc de notre carte de collision ;
  - run_gouger (40:7051) : `CMP AX,0xFA0 / JZ` — il plonge sur la SEULE
    cellule vide, et rampe sur TOUT le reste.

Au stage 4 les deux se confondent (0xFA0 est le seul id >= 0xDFC). Au
stage 2, 245 cellules portent des ids 0xFA1..0xFB8 et 0xFFB..0xFFC : les
pointes claires des crocs du plafond (rangees 0-5) et du sol (rangees 24-29).
Le vaisseau les traverse, le gouger s'y accroche — et c'est exactement la
qu'il attend et rampe. Avec la carte du vaisseau, il plongeait des la
premiere pointe la ou la borne rampe dessus jusqu'a la roche vide.

Ce masque n'est PAS consulte a l'execution : c'est l'entree de
tools/gen_gouger_profiles.py, qui precalcule la plongee de chaque gouger
(decision auteur, 08/09/2026). Format : celui des cartes de collision,
48 octets par rangee (8 cellules de 3 px par octet, bit 7 = la premiere),
30 rangees.

L'entree `_f_tiles.bin` est l'export `--extract-tiles` de re.arcade.r-type :
un mot GRAND-boutiste par cellule, 384 colonnes x 30 rangees. Le fichier fc
sert de controle : le masque produit doit le contenir (toute cellule solide
pour le vaisseau l'est pour le gouger) et n'en differer que sur des ids
>= 0xDFC.
"""
import struct
import sys

W, H = 384, 30
EMPTY = 0xFA0
SHIP_THRESHOLD = 0xDFC


def main(tiles_path, fc_path, out_path):
    tiles = open(tiles_path, 'rb').read()
    fc = open(fc_path, 'rb').read()
    if len(tiles) != W * H * 2:
        raise SystemExit('%s : %d octets, attendu %d' % (tiles_path, len(tiles), W * H * 2))
    if len(fc) != W * H // 8:
        raise SystemExit('%s : %d octets, attendu %d' % (fc_path, len(fc), W * H // 8))

    out = bytearray(W * H // 8)
    extra = []
    for r in range(H):
        for c in range(W):
            tid = struct.unpack_from('>H', tiles, (r * W + c) * 2)[0]
            ship = (fc[r * 48 + c // 8] >> (7 - c % 8)) & 1
            if ship != (1 if tid < SHIP_THRESHOLD else 0):
                raise SystemExit('cellule (%d,%d) id %03X : le fc ne suit pas le seuil 0xDFC'
                                 % (c, r, tid))
            if tid != EMPTY:
                out[r * 48 + c // 8] |= 0x80 >> (c % 8)
                if not ship:
                    extra.append((c, r, tid))
    open(out_path, 'wb').write(out)
    rows = sorted(set(r for _, r, _ in extra))
    print('%s : %d cellules solides pour le gouger et vides pour le vaisseau, rangees %s'
          % (out_path, len(extra), rows))


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    main(*sys.argv[1:])
