#!/usr/bin/env python3
"""Draw the bm4s test pictures : 320 pixels wide, in the 4 colours of the $41 mode.

The build reads them as they are : <gfxcomp videomode="bm4s"> packs them by
pixel pairs into the BM16 pictures its encoders draw, and <png2pal> takes
the palette from them. This script only draws them (authoring, not a build
step) ; its outputs are committed, and --check tells whether they are the
pictures it would draw.

Convention : index 0 transparent, 1..4 the colours 0..3 of the $41 palette.
Transparency goes by pixel pairs in bm4s (gfxcomp refuses a half
transparent pair), so the transparent hole is pair aligned.

The pictures are test patterns, not drawings : single-pixel features
everywhere, so a lost bit or a swapped pair shows as a wrong picture.
ci/toje-bench/bm4s_ut.py compares the screen against them.

    python3 tools/gen_bm4s.py [--check]      (from examples/bm4s)
"""
import os
import sys

from PIL import Image

OUT = 'src/assets/sprites'

# the four colours, palette entries 0..3 (png2pal reads them back as Pal_bm4s)
RGB = [(0, 0, 0), (255, 255, 255), (255, 0, 0), (0, 255, 255)]
T = 0                                  # transparent
BLACK, WHITE, RED, CYAN = 1, 2, 3, 4   # source indexes = colour + 1


def new320(w, h, fill):
    """Return a 320-convention picture filled with one source index."""
    im = Image.new('P', (w, h), fill)
    pal = [204, 0, 255]                # index 0 : transparent, magenta
    for c in RGB:
        pal += list(c)
    im.putpalette(pal + [0] * (768 - len(pal)))
    return im


def glyph():
    """24x24, asymmetric : a red frame, white inside, a cyan diagonal, a hole."""
    w, h = 24, 24
    im = new320(w, h, WHITE)
    px = im.load()
    for x in range(w):
        for y in range(h):
            if x in (0, w - 1) or y in (0, h - 1):
                px[x, y] = RED
    for y in range(2, h - 2):          # one pixel per line : 320 resolution
        px[2 + (y - 2) * 3 // 4, y] = CYAN
    for y in range(2, 6):              # the hole, top left only, pair aligned
        for x in range(2, 6):
            px[x, y] = T
    return im


def marker():
    """8x4, opaque : cyan, one red pixel in the top left corner."""
    im = new320(8, 4, CYAN)
    im.load()[0, 0] = RED
    return im


def band():
    """320x24, the background : three strips of single-pixel detail."""
    w, h = 320, 24
    im = new320(w, h, BLACK)
    px = im.load()
    for x in range(w):
        for y in range(0, 8):          # 1 px columns, white and red
            px[x, y] = WHITE if x % 2 == 0 else RED
        for y in range(8, 16):         # 8 px blocks cycling the 4 colours
            px[x, y] = 1 + (x // 8) % 4
        if x % 10 == 0:                # 1 px cyan ticks every 10 px
            for y in range(16, 24):
                px[x, y] = CYAN
    return im


def main():
    """Draw the three pictures ; --check compares them with the committed ones instead."""
    check = '--check' in sys.argv[1:]
    stale = []
    for name, make in (('glyph', glyph), ('marker', marker), ('band', band)):
        im = make()
        path = os.path.join(OUT, name + '.png')
        if check:
            old = Image.open(path) if os.path.exists(path) else None
            if old is None or old.size != im.size or old.tobytes() != im.tobytes() \
                    or old.getpalette()[:15] != im.getpalette()[:15]:
                stale.append(path)
            continue
        im.save(path)
        print('  %-7s %3dx%d' % (name, im.size[0], im.size[1]))
    if stale:
        print('stale (run tools/gen_bm4s.py) : ' + ', '.join(stale))
        sys.exit(1)


if __name__ == '__main__':
    main()
