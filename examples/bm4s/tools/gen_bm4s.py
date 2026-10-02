#!/usr/bin/env python3
"""Generate the bm4s test images : drawn at 320x200 in 4 colours, recoded for BM16.

In the $41 display mode (bitmap 4 "special", TO8 / TO8D / TO9+) a screen
byte holds four 2-bit pixels, leftmost in bits 7-6, and the RAMA byte of an
address shows the four pixels to the left of its RAMB byte : the byte layout
of BM16, where a byte holds two 4-bit pixels. A BM16 nibble therefore covers
two $41 pixels, and a 320 pixel wide 4 colour picture is byte for byte the
160 pixel wide BM16 picture whose pixel is (left << 2) | right. That is the
whole trick : the recoded PNG goes through gfxcomp, the sprite runtime and
the scroll engines unchanged.

The one constraint : BM16 transparency is per nibble, so a pair of $41
pixels is transparent as a whole or not at all. A half-transparent pair is
refused here rather than drawn wrong.

Source convention (the 320 pictures, kept in src/assets/sprites/src320/ as
the reference a screenshot is compared against) : index 0 transparent, 1..4
the four colours 0..3. Recoded convention (what gfxcomp reads) : index 0
transparent, 1..16 the BM16 colour + 1.

The pictures are test patterns, not drawings : single-pixel features
everywhere, so a lost bit or a swapped pair shows as a wrong picture.

    python3 tools/gen_bm4s.py      (from examples/bm4s)
"""
import os

from PIL import Image

OUT = 'src/assets/sprites'
REF = os.path.join(OUT, 'src320')

# the four colours as the bench palette sets them (Pal_bm4s in main.asm)
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


def recode(src):
    """Return the 160-convention picture of a 320-convention one."""
    w, h = src.size
    if w % 2:
        raise SystemExit('width %d is odd : pixels go by pairs' % w)
    sp = src.load()
    dst = Image.new('P', (w // 2, h), 0)
    pal = [204, 0, 255]
    for n in range(16):                # the pair colour, as a mid grey ramp
        pal += [n * 17] * 3
    dst.putpalette(pal + [0] * (768 - len(pal)))
    dp = dst.load()
    for y in range(h):
        for x in range(0, w, 2):
            left, right = sp[x, y], sp[x + 1, y]
            if (left == T) != (right == T):
                raise SystemExit('pixel pair (%d,%d) is half transparent' % (x, y))
            if left != T:
                dp[x // 2, y] = ((left - 1) << 2 | (right - 1)) + 1
    return dst


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
    """Draw the three pictures, keep the 320 references, write the recodings."""
    os.makedirs(REF, exist_ok=True)
    for name, make in (('glyph', glyph), ('marker', marker), ('band', band)):
        src = make()
        src.save(os.path.join(REF, name + '.png'))
        dst = recode(src)
        dst.save(os.path.join(OUT, name + '.png'))
        print('  %-7s %3dx%-3d -> %3dx%d' % (name, src.size[0], src.size[1],
                                           dst.size[0], dst.size[1]))


if __name__ == '__main__':
    main()
