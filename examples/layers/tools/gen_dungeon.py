#!/usr/bin/env python3
"""Generate the layers dungeon (vscroll data, 1bpp flavour)."""
#
# Produces the vertically scrolling decor for the layers demo : a 320x640
# dungeon shaft (20x40 tiles of 16x16), everything on RAMB (plane 1, scrolled
# alone, vscroll.planes = 2), RAMA left empty for the sprites ($26 shows RAMA
# in front, so sprites cover the scroll). Same v1 binary layouts as
# examples/vscroll (the engine moves 2 bytes per tile line either way, so only
# the contents are 1bpp) :
#
#   assets/scroll/map.bin          tile ids, v1 packing (ids pre-doubled,
#                                    12-bit pairs, rows by pairs, 60 bytes/pair)
#   assets/scroll/tiles.0.bin      RAMA tileset, all zeros (kept : the id stays
#                                    wired, the bytes never scroll)
#   assets/scroll/tiles.1.bin      RAMB tileset, line-major
#   assets/scroll/start.1.vscroll  initial code buffer (ldd/ldx/ldy/ldu/pshs
#                                    chunks, reverse order), view at camera 440
#   assets/scroll/map_preview.png  visual control (320x640, green on black)
#
# Tile sources : Kenney 1-Bit Pack (CC0) cells for stone/props (see
# ATTRIBUTION.txt), hand-drawn ticks and borders. Tile 0 stays empty.
#
# The 8 motif rows repeat 5 times, so the wrap is seamless by construction.
# Left-edge ticks (one per 4 rows) let a screenshot prove scroll position.
#
# usage : python3 tools/gen_dungeon.py  (from examples/layers)
import os
import tempfile

from PIL import Image

SHEET = os.path.join(tempfile.gettempdir(), 'kenney1bit', 'Tilesheet',
                     'monochrome_transparent_packed.png')

MAP_COLS, MAP_ROWS = 20, 40      # tiles ; 320x640 px
TILE = 16
VIEW_H = 200                     # start buffer height, one full screen
CAMERA_Y = 440                   # start view (bottom of map)
MAX_TILES = 256
MOTIF = 8                        # seamless repeat, rows


def grab(col, row, mirror=False):
    """One 16x16 Kenney cell as a bit tuple, 1 = ink."""
    sheet = Image.open(SHEET)
    box = (col * 16, row * 16, (col + 1) * 16, (row + 1) * 16)
    cell = sheet.crop(box)
    data = list(cell.getdata())
    assert set(data) <= {0, 1}, (col, row, set(data))
    if mirror:
        rows = [data[y * 16:(y + 1) * 16][::-1] for y in range(16)]
        data = [v for r in rows for v in r]
    return tuple(data)


def hand(fn):
    """Build a 16x16 hand tile from a pixel predicate."""
    return tuple(1 if fn(x, y) else 0
                 for y in range(16) for x in range(16))


EMPTY = tuple([0] * 256)
# -- RAMB (plane 1) tiles : the whole dungeon lives on this plane ------------
T_FLOOR_A = grab(1, 0)           # dotted noise
T_FLOOR_B = grab(3, 0)           # other noise
T_WALL_L = grab(8, 1)            # wall with window, left edge
T_WALL_R = grab(8, 1, mirror=True)
T_PILLAR = grab(1, 3)            # fence block


def _border(x, y):
    """Checkerboard border : dark on even 2px block sums."""
    block = x // 2 + y // 2
    return not block & 1


T_BORDER = hand(_border)
T_CRYSTAL = hand(lambda x, y: abs(x - 7) + abs(y - 7) <= 5)          # diamond
T_SKULL = grab(26, 9)            # skull face
_T_TICK = hand(lambda x, y: y == 15 or (1 <= x <= 5 and y >= 12))    # edge tick
T_WALL_TICK = tuple(a | b for a, b in zip(T_WALL_L, _T_TICK))        # overlaid


def motif_tiles():
    """Return the 8 seamless motif rows : (empty A, B tile) per cell, 20 cells."""
    fa, wl, pi = T_FLOOR_A, T_WALL_L, T_PILLAR
    fb = T_FLOOR_B
    wr = T_WALL_R
    cr, sk, wt = T_CRYSTAL, T_SKULL, T_WALL_TICK
    e = EMPTY
    rows = []
    rows.append([(e, wt)] + [(e, fa)] * 18 + [(e, wr)])               # 0 tick row base
    rows.append([(e, wl)] + [(e, fb)] * 8 + [(e, pi)] + [(e, fb)] * 9 + [(e, wr)])
    rows.append([(e, wl)] + [(e, fa)] * 5 + [(e, cr)] + [(e, fa)] * 12 + [(e, wr)])
    rows.append([(e, wl)] + [(e, pi)] + [(e, fb)] * 16 + [(e, pi)] + [(e, wr)])
    rows.append([(e, wt)] + [(e, fa)] * 11 + [(e, sk)] + [(e, fa)] * 6 + [(e, wr)])
    rows.append([(e, wl)] + [(e, fb)] * 18 + [(e, wr)])
    rows.append([(e, wl)] + [(e, fa)] * 3 + [(e, cr)] + [(e, fa)] * 14 + [(e, wr)])
    rows.append([(e, wl)] + [(e, fb)] * 7 + [(e, pi)] + [(e, fb)] * 10 + [(e, wr)])
    return rows


def build_index(motif):
    """Dedupe the motif grid into a tileset (tile 0 empty) and an id grid."""
    grid = [motif[r % MOTIF] for r in range(MAP_ROWS)]
    tiles, ids = [(EMPTY, EMPTY)], {}
    index = []
    for row in grid:
        line = []
        for cell in row:
            if cell not in ids:
                ids[cell] = len(tiles)
                tiles.append(cell)
            line.append(ids[cell])
        index.append(line)
    print(f'{len(tiles)} unique tiles (max {MAX_TILES})')
    if len(tiles) > MAX_TILES:
        raise SystemExit('tile budget blown')
    return tiles, index


def write_map(index):
    """map.bin : tile ids, v1 12-bit pair packing (ids pre-doubled)."""
    mapdata = bytearray()
    for pair in range(0, len(index), 2):
        for row in (index[pair], index[pair + 1]):
            for i in range(0, 20, 2):
                id0, id1 = row[i] * 2, row[i + 1] * 2
                mapdata += bytes(((id0 >> 4) & 0xFF,
                                  ((id0 & 0x0F) << 4) | ((id1 >> 8) & 0x0F),
                                  id1 & 0xFF))
    os.makedirs('assets/scroll', exist_ok=True)
    with open('assets/scroll/map.bin', 'wb') as f:
        f.write(mapdata)
    return mapdata


def write_tiles(tiles):
    """tiles.<p>.bin : 2 bytes per tile line (16px 1bpp), line-major."""
    # Blocks are N*2 bytes wide where N is the REAL tile count : the runtime
    # address table (_vscroll.setTileNb) steps by exactly that. No 16KB pad
    # and no halves swap at this size : the whole set fits one data page and
    # the lookup table never wraps past $A000+$4000.
    outb = bytearray()
    for plane in (0, 1):
        for ln in range(16):
            for (ta, tb) in tiles:
                t = ta if not plane else tb
                px = t[ln * 16:(ln + 1) * 16]
                outb.append(sum(v << (7 - b) for b, v in enumerate(px[:8])))
                outb.append(sum(v << (7 - b) for b, v in enumerate(px[8:])))
        with open(f'assets/scroll/tiles.{plane}.bin', 'wb') as f:
            f.write(outb)
    return outb


def write_start(tiles, index):
    """start.1.vscroll : camera view as code buffer (plane 1 only)."""
    # No bufA file anymore, RAMA holds sprites and never scrolls.
    for plane in (1,):
        raw = bytearray()
        for y in range(CAMERA_Y, CAMERA_Y + VIEW_H):
            row = index[(y // 16) % MAP_ROWS]
            ty = y % 16
            for col in range(20):
                t = tiles[row[col]][plane]
                px = t[ty * 16:(ty + 1) * 16]
                raw.append(sum(v << (7 - b) for b, v in enumerate(px[:8])))
                raw.append(sum(v << (7 - b) for b, v in enumerate(px[8:])))
        chunks = bytearray()
        for i in range(len(raw) - 8, -1, -8):
            chunks += bytes((0xCC, raw[i], raw[i + 1],
                             0x8E, raw[i + 2], raw[i + 3],
                             0x10, 0x8E, raw[i + 4], raw[i + 5],
                             0xCE, raw[i + 6], raw[i + 7],
                             0x34, 0x76))
        with open(f'assets/scroll/start.{plane}.vscroll', 'wb') as f:
            f.write(chunks)


def write_preview(tiles, index):
    """map_preview.png : plane 1 in green on black, visual control."""
    prev = Image.new('RGB', (320, 640))
    pp = prev.load()
    for y in range(640):
        row = index[(y // 16) % MAP_ROWS]
        ty = y % 16
        for col in range(20):
            ta, tb = tiles[row[col]]
            assert not any(ta), 'RAMA must stay empty'
            for x in range(16):
                b = tb[ty * 16 + x]
                pp[col * 16 + x, y] = (0, 255, 0) if b else (0, 0, 0)
    prev.save('assets/scroll/map_preview.png')


def main():
    """Write all layers scroll assets from the motif grid."""
    tiles, index = build_index(motif_tiles())
    mapdata = write_map(index)
    outb = write_tiles(tiles)
    write_start(tiles, index)
    write_preview(tiles, index)
    print(f'map {len(mapdata)} bytes, tiles 2x{len(outb)}, preview saved')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
