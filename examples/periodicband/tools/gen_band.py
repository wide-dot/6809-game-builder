#!/usr/bin/env python3
"""Generate the periodicband example's test band, src/band.png."""

#     python3 tools/gen_band.py            # write it
#     python3 tools/gen_band.py --check    # exit 1 if the committed one differs
#
# Not artwork : a measuring pattern, period 48 px, two periods wide (96 x 40).
#
#   lines  0-7   FULL : every pixel opaque, drawn by the runtime's writer
#   lines  8-15  STEMS : diagonal strokes, transparent between them
#   lines 16-23  empty
#   lines 24-31  STEMS, the strokes the other way
#   lines 32-39  FULL
#
# On a full line the colour is 1 + (7x + y) mod 15 : two neighbours never share
# a colour (7 is prime to 15) and the period of the colours (15) is not the
# band's, so a pair taken one pixel off, a swapped plane or a wrong rotation
# shows a wrong colour instead of a plausible picture. The strokes leave half
# bytes transparent, the case where a compiled strip must mask.
#
# Palette convention of gfxcomp : index 0 transparent, indices 1..16 the TO8
# colours 0..15. Index 16 (colour 15) is left out of the band : it is the
# background the game mode fills the screen with, so a transparent pixel drawn
# by mistake, or a pixel spilled where it should not be, is seen.
import io
import os
import sys

from PIL import Image

W, H, PERIOD = 96, 40, 48
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'band.png')

# displayable TO8 values (the levels png2pal keeps), 16 distinct colours
RGB = [(0, 0, 0), (250, 0, 0), (0, 250, 0), (0, 0, 250), (250, 250, 0), (250, 0, 250),
       (0, 250, 250), (250, 250, 250), (97, 97, 97), (171, 0, 0), (0, 171, 0),
       (0, 0, 171), (171, 171, 0), (171, 0, 171), (0, 171, 171), (171, 171, 171)]


def pixel(x, y):
    i = x % PERIOD
    colour = 1 + (7 * i + y) % 15
    if y < 8 or y >= 32:
        return colour
    if 16 <= y < 24:
        return 0
    stroke = (i + 2 * y) % 6 if y < 16 else (i - 2 * y) % 6
    return colour if stroke < 2 else 0


def picture():
    im = Image.new('P', (W, H))
    pal = [204, 0, 255]                      # index 0 : the transparent key
    for c in RGB:
        pal += list(c)
    im.putpalette(pal + [0, 0, 0] * (256 - 17))
    for y in range(H):
        for x in range(W):
            im.putpixel((x, y), pixel(x, y))
    return im


def png_bytes(im):
    buf = io.BytesIO()
    im.save(buf, format='PNG', optimize=True)
    return buf.getvalue()


if __name__ == '__main__':
    data = png_bytes(picture())
    if '--check' in sys.argv:
        same = os.path.exists(OUT) and open(OUT, 'rb').read() == data
        print(f'{OUT}: {"up to date" if same else "OUT OF DATE"}')
        sys.exit(0 if same else 1)
    with open(OUT, 'wb') as f:
        f.write(data)
    print(f'wrote {OUT}')
