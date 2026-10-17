#!/usr/bin/env python3
"""Les tuiles de la carte qui passent DERRIERE les sprites, lues dans la ROM.

La priorite du decor arcade est par CELLULE de 8x8 : bits 6-7 de l'attribut
(Irem M72, groupe de MAME). Groupe 0 : la cellule est derriere les sprites ;
groupe 2 : devant. Les stages 1 a 5 n'ont que du groupe 2 (le port y peint tout
le decor apres les sprites) ; le stage 6 n'a que du groupe 0 (stage.TILES_BEHIND) ;
les stages 7 et 8 melangent les deux, et ce script en tire les masques que
<tilecols behind=...> consomme (doc/etude-priorite-tilemap-2026-09.md §8).

Le plan de la carte : le plan AVANT au stage 7, le plan ARRIERE au stage 8 (le
plan avant y est vide). L'attribut d'une cellule vient de son enregistrement
de groupe de tuiles (ROM 1000:xxxx, 5 groupes de 8x6 cellules par colonne de
64 px, banque de motifs 0x30000) — le meme decodage que l'extracteur BallField
de re.arcade.r-type, qui retrouve l'export levelN_f_cellmeta.bin a 0 ecart.

Une tuile TO8 de 12x12 couvre 4x2 cellules arcade (3/8 en x, 3/4 en y) ; elle
est DERRIERE si ses pixels opaques (in.png, index 0 = transparent) tombent sur
des cellules de groupe 0. Plan pair : aucune tuile ne melange les deux. Plan
impair (leanscroll le decale d'un pixel a gauche : la tuile c couvre x 12c+1 a
12c+12) : une tuile au raccord d'une tuile devant et d'une derriere melange ;
elle prend la priorite de la majorite de ses pixels, et le script les compte.

Sortie : src/stages/NN/map/behind-even.bin et behind-odd.bin, un octet par
cellule de carte, colonne-majeur comme la carte de leanscroll, 1 = derriere.
Rejeu : python3 tools/gen_tile_priority.py (depuis games/r-type/) ;
        python3 tools/gen_tile_priority.py --check dit si les sorties sont a jour.
"""
import os
import sys

from PIL import Image

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
PATTERNS = 0x30000
# per stage : the plane of its map — (group record table, width in 64 px groups)
PLANES = {
    7: (0x1D21B, 48),           # foreground (TileMap.levelForegroundLoc)
    8: (0x1E85F, 31),           # background (TileMap.levelBackgroundLoc)
}
TILE, ROWS = 12, 15


def priorities(rom, loc, width):
    """{(cell col, cell row): True when behind the sprites}"""
    out = {}
    for tx in range(width):
        for ty in range(5):
            rec = loc + tx * 10 + ty * 2
            gid = rom[rec] | ((rom[rec + 1] & 0x3F) << 8)
            fx, fy = (rom[rec + 1] >> 6) & 1, (rom[rec + 1] >> 7) & 1
            for st in range(48):
                sx, sy = st % 8, st // 8
                attr = rom[PATTERNS + gid * 144 + st * 3 + 2]
                out[(tx * 8 + (7 - sx if fx else sx),
                     ty * 6 + (5 - sy if fy else sy))] = not attr & 0x80
    return out


def masks(stage, rom):
    prio = priorities(rom, *PLANES[stage])
    im = Image.open('src/stages/%02d/map/in.png' % stage)
    px = im.load()
    w, h = im.size
    cols = w // TILE
    out, mixed = [], []
    for shift in (0, 1):
        m = bytearray(cols * ROWS)
        nmix = 0
        for c in range(cols):
            for r in range(ROWS):
                back = front = 0
                for y in range(r * TILE, r * TILE + TILE):
                    for x in range(c * TILE + shift, c * TILE + TILE + shift):
                        x %= w
                        if px[x, y] == 0:
                            continue
                        if prio.get((x // 3, y // 6), False):
                            back += 1
                        else:
                            front += 1
                if back and front:
                    nmix += 1
                if back > front:
                    m[c * ROWS + r] = 1
        out.append(bytes(m))
        mixed.append(nmix)
    return out, mixed


def main():
    rom = open(ROM, 'rb').read()
    check = '--check' in sys.argv
    stale = 0
    for stage in sorted(PLANES):
        (even, odd), mixed = masks(stage, rom)
        for name, data, nmix in (('even', even, mixed[0]), ('odd', odd, mixed[1])):
            path = 'src/stages/%02d/map/behind-%s.bin' % (stage, name)
            if check:
                ok = os.path.exists(path) and open(path, 'rb').read() == data
                stale += not ok
                print('%s : %s' % (path, 'a jour' if ok else 'PERIME — relancer tools/gen_tile_priority.py'))
            else:
                open(path, 'wb').write(data)
                print('%s ecrit : %d tuiles derriere, %d melangees'
                      % (path, sum(data), nmix))
    return 1 if stale else 0


if __name__ == '__main__':
    sys.exit(main())
