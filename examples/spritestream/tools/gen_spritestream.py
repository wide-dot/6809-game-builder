#!/usr/bin/env python3
"""Draw the spritestream bench's pictures : bm4s (320x200 in 4 colours), indexed.

The build reads them as they are : <spritestream> encodes each picture and
its shifted copy (the same moved right by 2 pixels) as a sprite. This script
only draws them (authoring, not a build step) ; its outputs are committed,
and --check tells whether they are the pictures it would draw.

Convention : index 0 transparent, 1..4 the colours 0..3 of the $41 palette,
one PNG pixel a screen pixel. Transparency goes by pixel here (a stream masks
each pixel), so half transparent bytes are drawn on purpose.

The pictures are test patterns, not drawings, each asymmetric so that a
mirror, a lost byte or a byte one plane off gives a wrong picture :
  flag   22x30 : a striped bar, a stem repeated over 8 rows (multi-row
         records), 4 empty rows (a nop record), a holed diagonal (per pixel
         masks), a checker block ; 22 = 2 mod 4 : its mirror swaps the 2
         pixel steps
  flagm  flag mirrored : the second facing, stored, of flag
  slab   40x24 : diagonal colour bands scattered with holes, long rows cut
         in segments
  tall   12x60 : rows repeated by two (2-row records), a gap of 5 rows
Each has its shifted copy, <name>_s : 2 transparent columns on its left.

    python3 tools/gen_spritestream.py [--check]      (from examples/spritestream)
"""
import os
import sys

from PIL import Image

OUT = 'src/assets/sprites'

RGB = [(0, 0, 0), (255, 255, 255), (255, 0, 0), (0, 255, 255)]
T = 0                                  # transparent
BLACK, WHITE, RED, CYAN = 1, 2, 3, 4   # source indexes = colour + 1


def new(w, h):
    im = Image.new('P', (w, h), T)
    pal = [204, 0, 255]                # index 0 : transparent, magenta
    for c in RGB:
        pal += list(c)
    im.putpalette(pal + [0] * (768 - len(pal)))
    return im


def flag():
    w, h = 22, 30
    im = new(w, h)
    px = im.load()
    for y in range(0, 2):              # a striped bar : single pixel detail
        for x in range(w):
            px[x, y] = 1 + (x + y) % 4
    for y in range(2, 10):             # a stem, the same 8 rows
        for x in range(2, 10):
            px[x, y] = CYAN if x == 5 else RED
    for y in range(14, 25):            # a diagonal with holes
        for x in range(y - 14, y - 8):
            if (x + y) % 7:
                px[x, y] = WHITE if x % 3 else BLACK
    for y in range(25, 30):            # a checker block on the right
        for x in range(14, 22):
            if y != 27 or x % 2 == 0:
                px[x, y] = WHITE if (x + y) % 2 else BLACK
    px[w - 1, 0] = T                   # the top right corner off : the mirror shows
    return im


def slab():
    w, h = 40, 24
    im = new(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            if (x * 7 + y * 3) % 11:
                px[x, y] = 1 + (x // 3 + y // 2) % 4
    return im


def tall():
    w, h = 12, 60
    im = new(w, h)
    px = im.load()
    for y in range(h):
        if 40 <= y < 45:
            continue
        for x in range(w):
            px[x, y] = 1 + (x + y // 2) % 4
    px[w - 1, h - 1] = T
    return im


def mirrored(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def shifted(im):
    w, h = im.size
    out = new(w + 2, h)
    out.paste(im, (2, 0))
    return out


def pictures():
    base = {'flag': flag(), 'slab': slab(), 'tall': tall()}
    base['flagm'] = mirrored(base['flag'])
    out = {}
    for name in ('flag', 'flagm', 'slab', 'tall'):
        out[name] = base[name]
        out[name + '_s'] = shifted(base[name])
    return out


def main():
    check = '--check' in sys.argv[1:]
    stale = []
    for name, im in pictures().items():
        path = os.path.join(OUT, name + '.png')
        if check:
            old = Image.open(path) if os.path.exists(path) else None
            if old is None or old.size != im.size or old.tobytes() != im.tobytes() \
                    or old.getpalette()[:15] != im.getpalette()[:15]:
                stale.append(path)
            continue
        im.save(path)
        print('  %-8s %3dx%d' % (name, im.size[0], im.size[1]))
    if stale:
        print('stale (run tools/gen_spritestream.py) : ' + ', '.join(stale))
        sys.exit(1)


if __name__ == '__main__':
    main()
