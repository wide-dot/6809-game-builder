#!/usr/bin/env python3
"""examples/layers dungeon generator (vscroll data, 1bpp $26 flavour).

Produces the vertically scrolling decor for the layers demo : a 320x640
dungeon shaft (20x40 tiles of 16x16), everything on RAMB (plane 1, scrolled
alone, vscroll.planes = 2), RAMA left empty for the sprites ($26 shows RAMA
in front, so sprites cover the scroll). Same v1 binary layouts as
examples/vscroll (the engine moves 2 bytes per tile line either way, so only
the contents are 1bpp) :

  assets/scroll/map.bin          tile ids, v1 packing (ids pre-doubled,
                                   12-bit pairs, rows by pairs, 60 bytes/pair)
  assets/scroll/tiles.0.bin      RAMA tileset, all zeros (kept : the id stays
                                   wired, the bytes never scroll)
  assets/scroll/tiles.1.bin      RAMB tileset, line-major
  assets/scroll/start.1.vscroll  initial code buffer (ldd/ldx/ldy/ldu/pshs
                                   chunks, reverse order), view at camera 440
  assets/scroll/map_preview.png  visual control (320x640, green on black)

Tile sources : Kenney 1-Bit Pack (CC0) cells for stone/props (see
ATTRIBUTION.txt), hand-drawn ticks and borders. Tile 0 stays empty.

The 8 motif rows repeat 5 times, so the wrap is seamless by construction.
Left-edge ticks (one per 4 rows) let a screenshot prove scroll position.

usage : python3 tools/gen_dungeon.py  (from examples/layers)
"""
import os

from PIL import Image

SHEET = '/tmp/kenney1bit/Tilesheet/monochrome_transparent_packed.png'

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
    """A 16x16 hand tile from a pixel predicate."""
    return tuple(1 if fn(x, y) else 0
                 for y in range(16) for x in range(16))


EMPTY = tuple([0] * 256)
# -- RAMB (plane 1) tiles : the whole dungeon lives on this plane ------------
T_FLOOR_A = grab(1, 0)           # dotted noise
T_FLOOR_B = grab(3, 0)           # other noise
T_WALL_L = grab(8, 1)            # wall with window, left edge
T_WALL_R = grab(8, 1, mirror=True)
T_PILLAR = grab(1, 3)            # fence block
T_BORDER = hand(lambda x, y: (x // 2 + y // 2) & 1 == 0)
T_CRYSTAL = hand(lambda x, y: abs(x - 7) + abs(y - 7) <= 5)          # diamond
T_SKULL = grab(26, 9)            # skull face
_T_TICK = hand(lambda x, y: y == 15 or (1 <= x <= 5 and y >= 12))    # edge tick
T_WALL_TICK = tuple(a | b for a, b in zip(T_WALL_L, _T_TICK))        # overlaid


def motif_tiles():
    """The 8 seamless motif rows : (empty A, B tile) per cell, 20 cells."""
    F, W, P = T_FLOOR_A, T_WALL_L, T_PILLAR
    FB = T_FLOOR_B
    WR = T_WALL_R
    C, S, WT = T_CRYSTAL, T_SKULL, T_WALL_TICK
    E = EMPTY
    rows = []
    rows.append([(E, WT)] + [(E, F)] * 18 + [(E, WR)])               # 0 tick row base
    rows.append([(E, W)] + [(E, FB)] * 8 + [(E, P)] + [(E, FB)] * 9 + [(E, WR)])
    rows.append([(E, W)] + [(E, F)] * 5 + [(E, C)] + [(E, F)] * 12 + [(E, WR)])
    rows.append([(E, W)] + [(E, P)] + [(E, FB)] * 16 + [(E, P)] + [(E, WR)])
    rows.append([(E, WT)] + [(E, F)] * 11 + [(E, S)] + [(E, F)] * 6 + [(E, WR)])
    rows.append([(E, W)] + [(E, FB)] * 18 + [(E, WR)])
    rows.append([(E, W)] + [(E, F)] * 3 + [(E, C)] + [(E, F)] * 14 + [(E, WR)])
    rows.append([(E, W)] + [(E, FB)] * 7 + [(E, P)] + [(E, FB)] * 10 + [(E, WR)])
    return rows


def main():
    motif = motif_tiles()
    grid = [motif[r % MOTIF] for r in range(MAP_ROWS)]

    # dedupe into tileset, tile 0 empty
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
    print('%d unique tiles (max %d)' % (len(tiles), MAX_TILES))
    if len(tiles) > MAX_TILES:
        raise SystemExit('tile budget blown')

    # ---- map.bin : same v1 packing as gen_ship (20 cols) ----
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

    # ---- tiles.<p>.bin : 2 bytes per tile line (16px 1bpp), line-major ----
    # Blocks are N*2 bytes wide where N is the REAL tile count : the runtime
    # address table (_vscroll.setTileNb) steps by exactly that. No 16KB pad
    # and no halves swap at this size : the whole set fits one data page and
    # the lookup table never wraps past $A000+$4000.
    ntiles = len(tiles)
    padded = tiles
    for plane in (0, 1):
        outb = bytearray()
        for l in range(16):
            for (ta, tb) in padded:
                t = ta if plane == 0 else tb
                px = t[l * 16:(l + 1) * 16]
                outb.append(sum(v << (7 - b) for b, v in enumerate(px[:8])))
                outb.append(sum(v << (7 - b) for b, v in enumerate(px[8:])))
        with open('assets/scroll/tiles.%d.bin' % plane, 'wb') as f:
            f.write(outb)

    # ---- start.1.vscroll : camera view as code buffer (plane 1 only : no
    # bufA file anymore, RAMA holds sprites and never scrolls) ----
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
        with open('assets/scroll/start.%d.vscroll' % plane, 'wb') as f:
            f.write(chunks)

    # ---- preview : plane 1 in green on black (RAMA empty by design) ----
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
    print('map %d bytes, tiles 2x%d, preview saved' % (len(mapdata), len(outb)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
