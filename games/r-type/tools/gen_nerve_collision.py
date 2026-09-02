#!/usr/bin/env python3
"""Tables de collision des nerfs optiques du Dobkeratops (stage 1).

Les quatre nerfs sont solides dans la carte d'AVANT-PLAN (level1_fc.bin, un bit
par tuile de 3x6 px, 66 octets par ligne). L'arcade efface chaque nerf en
parcourant une table de decalages de cellules depuis la cellule sous l'oeil
(dobkeratops_erase_optical_nerves, tables 0x146CC/0x14754/0x147C6/0x1482E) ;
sa grille de 8x8 coincide avec la notre tuile pour tuile. On rejoue ces
tables sur notre carte — le depart est cherche autour de l'oeil, le seul qui
tombe entierement sur des tuiles solides — et on en tire, par nerf, les
octets de carte touches avec le masque des bits du nerf : effacer = ET NON,
restaurer = OU. Analyse : doc/analyse-collision-nerfs.md.

Usage : python3 tools/gen_nerve_collision.py   (depuis games/r-type)
Ecrit src/stages/01/collision/nerve-collision.tables.asm
"""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.dirname(HERE)
FC = os.path.join(G, 'src/stages/01/collision/level1_fc.bin')
OUT = os.path.join(G, 'src/stages/01/collision/nerve-collision.tables.asm')
W, H = 66, 30
# les quatre tables arcade, transcrites (mot = dx octets | dy lignes, fin 0x8000)
STREAMS = {
0: "00 01 04 ff 00 01 04 ff 00 01 04 fe 00 01 04 ff 00 01 04 ff 00 01 04 fe 00 01 04 ff 00 01 04 00 04 00 00 01 04 ff 00 01 04 ff 00 01 04 00 00 01 04 ff 00 01 04 ff 00 01 04 ff 00 01 04 00 00 ff 00 ff fc 00 00 00 00 00 00 00 00 00 00 00 00 00 e8 ff 04 00 04 00 04 00 00 01 04 ff 00 01 04 ff 00 01 04 ff 04 00 04 00 04 00 00 01 04 ff 00 01 00 01 00 01 04 fe 00 01 00 01 04 fe 00 01 04 ff 00 01 04 ff 00 01 00 80",
1: "00 01 04 ff 00 01 04 ff 00 01 04 ff 00 00 00 00 00 00 00 00 00 00 00 00 10 fd 00 01 04 ff 04 00 00 01 fc 00 00 01 04 00 00 01 fc 00 fc ff 00 01 00 01 fc 00 04 01 fc 00 00 01 fc ff 00 01 fc ff 00 01 fc 00 fc 00 fc 00 00 ff 04 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 1c fd 00 ff 00 ff 04 01 00 ff 04 01 00 ff 00 ff 00 80",
2: "00 01 04 ff 00 01 04 ff 00 01 04 ff 00 01 04 00 00 00 00 00 00 00 00 00 00 00 00 00 1c 01 04 ff 00 ff fc 01 00 ff fc 00 00 01 fc ff 00 01 00 01 fc ff 00 01 fc ff 00 01 fc 00 00 01 fc ff 00 01 fc ff fc 00 00 01 00 01 04 00 00 ff 00 00 00 00 00 00 00 00 00 00 00 00 18 00 00 01 04 ff 00 01 04 00 00 ff 00 ff 00 80",
3: "00 01 04 ff 00 01 04 00 00 01 04 ff 00 01 04 00 00 01 04 ff 00 01 04 ff 00 01 04 00 00 ff 04 01 00 ff fc ff 04 00 04 00 00 ff 04 01 00 ff 04 00 04 00 00 01 04 ff 00 01 04 00 fc 01 04 00 00 01 04 ff 00 01 04 00 04 00 00 ff 00 00 00 00 00 00 00 00 f4 fe 04 00 00 01 04 ff 00 01 04 ff 00 01 04 ff 00 01 04 00 00 01 04 ff 00 01 00 01 04 ff 00 01 04 fe 00 01 04 ff 00 01 00 80",
}
# nos yeux (EMOffsets autour de l'ancre 1507,100), en tuiles : le depart est cherche autour
EYES = {0: (491, 6), 1: (502, 14), 2: (502, 20), 3: (491, 27)}

def steps(s):
    b = bytes.fromhex(s.replace(' ', '')); out = []
    for i in range(0, len(b), 2):
        lo, hi = b[i], b[i + 1]
        if lo == 0 and hi == 0x80:
            break
        dx = lo - 256 if lo > 127 else lo
        dy = hi - 256 if hi > 127 else hi
        assert dx % 4 == 0, 'une cellule fait 4 octets'
        out.append((dx // 4, dy))
    return out

def main():
    d = open(FC, 'rb').read()
    assert len(d) == W * H, len(d)
    solid = {(c, r) for r in range(H) for c in range(W * 8) if (d[r * W + c // 8] >> (7 - c % 8)) & 1}
    wall = {(c, r) for (c, r) in solid if r <= 1 or r >= H - 2}
    tables = {}
    seen = set()
    for n, s in STREAMS.items():
        offs = steps(s); ex, ey = EYES[n]; best = None
        for sy in range(max(0, ey - 10), min(H, ey + 11)):
            for sx in range(ex - 25, ex + 26):
                c, r = sx, sy; pts = [(c, r)]
                for dx, dy in offs:
                    c += dx; r += dy; pts.append((c, r))
                u = set(pts)
                if any(c < 0 or c >= W * 8 or r < 0 or r >= H for c, r in u):
                    continue
                hit = sum(1 for p in u if p in solid and p not in wall)
                pen = sum(1 for p in u if p in wall) + sum(1 for p in u if p not in solid)
                score = (hit - 3 * pen, -sx, -sy)
                if best is None or score > best[0]:
                    best = (score, sx, sy, u)
        (score, _, _), sx, sy, u = best
        assert all(p in solid and p not in wall for p in u), \
            'nerf %d : la table arcade ne tombe pas entierement sur des tuiles solides hors murs' % n
        assert not (u & seen), 'nerf %d : recouvrement avec un autre nerf' % n
        seen |= u
        by = {}
        for c, r in u:
            by.setdefault(r * W + c // 8, 0)
            by[r * W + c // 8] |= 1 << (7 - c % 8)
        tables[n] = (sx, sy, len(u), by)
    with open(OUT, 'w') as f:
        f.write('; genere par tools/gen_nerve_collision.py — NE PAS EDITER\n')
        f.write('; par nerf : fcb nb, puis fdb offset (dans level1_fc.bin), fcb masque des\n')
        f.write('; bits du nerf. Effacer = ET NON, restaurer = OU. Analyse :\n')
        f.write('; doc/analyse-collision-nerfs.md\n')
        for n in range(4):
            sx, sy, nt, by = tables[n]
            f.write('terrainCollision.nerve%d ; %d tuiles, depart col %d ligne %d\n' % (n, nt, sx, sy))
            f.write('        fcb   %d\n' % len(by))
            for off in sorted(by):
                f.write('        fdb   %d\n        fcb   $%02X\n' % (off, by[off]))
        f.write('terrainCollision.nerves\n')
        for n in range(4):
            f.write('        fdb   terrainCollision.nerve%d\n' % n)
    for n in range(4):
        sx, sy, nt, by = tables[n]
        print('nerf %d : %d tuiles, %d octets, depart (%d,%d)' % (n, nt, len(by), sx, sy))
    print('->', os.path.relpath(OUT, G))

if __name__ == '__main__':
    main()
