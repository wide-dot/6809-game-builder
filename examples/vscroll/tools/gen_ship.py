#!/usr/bin/env python3
"""examples/vscroll asset generator (vscroll = the v1 vertical scroll, 1:1).

The example's artwork is the real thing this module is being built for : the
stage 3 battleship, i.e. the arcade back plane of R-Type level 3, reduced with
the exact recipe of the r-type pipeline (x3/8 in X, x3/4 in Y, nearest
neighbour — see games/r-type/tools/arcade_to_in.py). The reduced ship carries
exactly 15 non-black colours : with black that fills the 16 TO8 slots, no
quantization needed.

Outputs (committed, like the leanscroll outputs of games/r-type) :

  assets/ship.png        the 160x640 map image, indexed PNG (visual reference
                         and palette source for <png2pal>)
  assets/map.bin         tile ids, v1 vscroll packing : ids pre-doubled,
                         12-bit pairs packed on 3 bytes, rows stored by pairs
                         (even row at +0, odd row at +30, 60 bytes per pair)
  assets/tiles.0.bin     tileset plane 0 (RAMA) — line-major (all tiles line 0,
  assets/tiles.1.bin     then line 1, ...), padded to 16KB, 8KB halves swapped
                         (v1 VerticalScrollTile layout, kept verbatim)
  assets/start.0.vscroll initial code buffers (v1 VerticalScroll layout :
  assets/start.1.vscroll ldd/ldx/ldy/ldu/pshs chunks, reverse order), built
                         from map rows 0..199 — the view at camera position 0

Map layout (160x640 px = 20x40 tiles of 8x16) :
  row 0 and row 39      border pattern rows (asymmetric checker)
  rows 8..16            the central 160px slice of the battleship
  left edge, every 4 rows a marker tile encoding row/4 as tick marks, so a
                        screenshot proves the scroll position

usage : python3 tools/gen_ship.py  (from examples/vscroll)
"""
import os
import sys
from collections import Counter

from PIL import Image

SRC = os.environ.get(
    'MSCROLL_SRC',
    '../../games/r-type/src/stages/03/map/images/original/level3_b.png')
# The stage 3 game palette, shaped by the r-type palette campaign with the
# battleship pixels weighed in (arcade_to_in.py --plan level3_b.png). Mapping
# the ship on it shows the example exactly as the game will show the layer,
# and avoids the naive-quantization trap : the TO8 gamma has no dark levels
# (level 1 is already 97/255), a per-colour nearest turns dark olive shadows
# into glowing green.
PAL = os.environ.get(
    'MSCROLL_PAL',
    '../../games/r-type/src/stages/03/palette/pal.png')

MAP_W, MAP_H = 160, 640          # pixels ; 20x40 tiles of 8x16
TILE_W, TILE_H = 8, 16
VIEW_H = 200                     # start buffer height, one full screen
SHIP_ROW = 8                     # tile row where the ship slice lands
MAX_TILES = 256                  # _vscroll.setTileset256 in the game mode
SCALE_X, SCALE_Y = 3 / 8, 3 / 4


def downscale(src):
    """Nearest neighbour, phase 0 — the recipe that produced the stage maps."""
    w, h = src.size
    width, height = round(w * SCALE_X), round(h * SCALE_Y)
    out = Image.new('RGB', (width, height))
    sp, op = src.load(), out.load()
    for y in range(height):
        ay = y * h // height
        for x in range(width):
            op[x, y] = sp[x * w // width, ay]
    return out


def _lab(c):
    """sRGB 8 bits -> CIE Lab, D65 — the metric of arcade_to_in.py."""
    def lin(u):
        u /= 255.0
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in c)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b)
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def main():
    src = Image.open(SRC).convert('RGB')
    small = downscale(src)
    sw, sh = small.size
    sp = small.load()

    # the stage 3 palette, indices 1..16 (index 0 is the unused magenta)
    p = Image.open(PAL).getpalette()
    palette = [tuple(p[i * 3:i * 3 + 3]) for i in range(256)]
    palette[0] = (255, 0, 255)

    # every reduced ship colour goes to its Lab-nearest palette slot
    count = Counter(small.get_flattened_data())
    labs = {i: _lab(palette[i]) for i in range(1, 17)}

    def nearest(c):
        lc = _lab(c)
        return min(labs, key=lambda i: sum((u - v) ** 2
                                           for u, v in zip(lc, labs[i])))
    index = {c: nearest(c) for c in count}
    print('colour mapping (arcade -> stage 3 slot):')
    for c, n in count.most_common():
        print('  %-16s %6d px -> %2d %s' % (c, n, index[c], palette[index[c]]))
    BLACK = nearest((0, 0, 0))
    by_luma = sorted(range(1, 17), key=lambda i: sum(palette[i]))
    LIGHT, DARK = by_luma[-1], by_luma[2]

    # ship bounding box in the reduced plane
    xs = [x for y in range(sh) for x in range(sw) if sp[x, y] != (0, 0, 0)]
    ys = [y for y in range(sh) for x in range(sw) if sp[x, y] != (0, 0, 0)]
    bx0, bx1, by0, by1 = min(xs), max(xs), min(ys), max(ys)
    cx = (bx0 + bx1 + 1) // 2
    crop_x0 = max(0, cx - MAP_W // 2)
    crop_y0 = by0
    crop_h = min(by1 - by0 + 1, MAP_H - SHIP_ROW * TILE_H - TILE_H)
    print('ship bbox x %d..%d y %d..%d ; slice x %d..%d, %d lines'
          % (bx0, bx1, by0, by1, crop_x0, crop_x0 + MAP_W - 1, crop_h))

    # compose the map, in palette indices
    pix = [[BLACK] * MAP_W for _ in range(MAP_H)]
    for y in range(crop_h):
        for x in range(MAP_W):
            pix[SHIP_ROW * TILE_H + y][x] = index[sp[crop_x0 + x, crop_y0 + y]]

    def checker(y, x, invert):
        v = ((x // 2) + (y // 2)) & 1
        if x >= 6:
            return BLACK                      # black column : asymmetry
        return LIGHT if v ^ invert else DARK

    for y in range(TILE_H):                   # border rows 0 and 39
        for x in range(MAP_W):
            pix[y][x] = checker(y, x, 0)
            pix[(MAP_H - TILE_H) + y][x] = checker(y, x, 1)

    for row in range(0, MAP_H // TILE_H, 4):  # left edge markers, one per 4 rows
        n = row // 4                          # 0..9 tick marks + base line
        ty = row * TILE_H
        for y in range(TILE_H):
            for x in range(TILE_W):
                pix[ty + y][x] = DARK
        for x in range(TILE_W):               # base line at tile bottom
            pix[ty + TILE_H - 1][x] = LIGHT
        for k in range(n + 1):                # row/4 encoded as ticks
            for x in range(1, 6):
                pix[ty + 1 + k][x] = LIGHT

    # ---- ship.png -----------------------------------------------------------
    out = Image.new('P', (MAP_W, MAP_H))
    flat = []
    for rgb in palette:
        flat += list(rgb)
    out.putpalette(flat)
    op = out.load()
    for y in range(MAP_H):
        for x in range(MAP_W):
            op[x, y] = pix[y][x]
    os.makedirs('assets', exist_ok=True)
    out.save('assets/ship.png')

    # ---- tiles + map --------------------------------------------------------
    # a tile is its 8x16 cell of hardware values (png index - 1)
    def cell(row, col):
        return tuple(pix[row * TILE_H + y][col * TILE_W + x] - 1
                     for y in range(TILE_H) for x in range(TILE_W))

    tiles, ids = [], {}
    grid = []
    for row in range(MAP_H // TILE_H):
        line = []
        for col in range(MAP_W // TILE_W):
            c = cell(row, col)
            if c not in ids:
                ids[c] = len(tiles)
                tiles.append(c)
            line.append(ids[c])
        grid.append(line)
    print('%d unique tiles (max %d)' % (len(tiles), MAX_TILES))
    if len(tiles) > MAX_TILES:
        raise SystemExit('tile budget blown, raise the tileset size')

    # map.bin : ids pre-doubled, 12-bit pairs on 3 bytes, rows stored by pairs
    mapdata = bytearray()
    for pair in range(0, len(grid), 2):
        for row in (grid[pair], grid[pair + 1]):
            for i in range(0, 20, 2):
                id0, id1 = row[i] * 2, row[i + 1] * 2
                mapdata += bytes(((id0 >> 4) & 0xFF,
                                  ((id0 & 0x0F) << 4) | ((id1 >> 8) & 0x0F),
                                  id1 & 0xFF))
    with open('assets/map.bin', 'wb') as f:
        f.write(mapdata)

    # tiles.<p>.bin : line-major, 16KB padded, 8KB halves swapped (v1 layout).
    # plane bytes of one tile line : plane 0 gets pixels 0,1 and 4,5 ;
    # plane 1 gets pixels 2,3 and 6,7 (BM16 interleave)
    def tile_line_bytes(t, l, plane):
        px = t[l * TILE_W:(l + 1) * TILE_W]
        pairs = [(px[0], px[1]), (px[4], px[5])] if plane == 0 else \
                [(px[2], px[3]), (px[6], px[7])]
        return bytes((a << 4) | b for a, b in pairs)

    # the tile list is padded to MAX_TILES : a line block is nbtiles*2 bytes
    # and the runtime address table (_vscroll.setTileNb) steps by exactly
    # that, so the padding lives INSIDE each line block, not at file end
    padded = tiles + [tuple([0] * (TILE_W * TILE_H))] * (MAX_TILES - len(tiles))
    for plane in (0, 1):
        outb = bytearray()
        for l in range(TILE_H):
            for t in padded:
                outb += tile_line_bytes(t, l, plane)
        outb += bytes(0x4000 - len(outb))
        outb = outb[0x2000:] + outb[:0x2000]
        with open('assets/tiles.%d.bin' % plane, 'wb') as f:
            f.write(outb)

    # start.<p>.vscroll : map rows 0..199 as v1 code buffers, reverse order
    for plane in (0, 1):
        raw = bytearray()
        for y in range(VIEW_H):
            for x in range(0, MAP_W, 4):      # 4 px = 1 byte per plane
                a, b = (x, x + 1) if plane == 0 else (x + 2, x + 3)
                raw.append(((pix[y][a] - 1) << 4) | (pix[y][b] - 1))
        chunks = bytearray()
        for i in range(len(raw) - 8, -1, -8):
            chunks += bytes((0xCC, raw[i], raw[i + 1],
                             0x8E, raw[i + 2], raw[i + 3],
                             0x10, 0x8E, raw[i + 4], raw[i + 5],
                             0xCE, raw[i + 6], raw[i + 7],
                             0x34, 0x76))
        with open('assets/start.%d.vscroll' % plane, 'wb') as f:
            f.write(chunks)

    print('map %d bytes, tiles 2x16384, start buffers 2x%d bytes'
          % (len(mapdata), len(chunks)))
    print('map height %d px (%d tile rows), start view %d lines'
          % (MAP_H, MAP_H // TILE_H, VIEW_H))
    return 0


if __name__ == '__main__':
    sys.exit(main())
