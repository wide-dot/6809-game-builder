#!/usr/bin/env python3
"""Generate the fullscreen example's picture, src/mire.png."""

#     python3 tools/gen_mire.py            # write it
#     python3 tools/gen_mire.py --check    # exit 1 if the committed one differs
#
# Not artwork : a measuring pattern, 160 x 200, every pixel opaque, the 16
# colours on every pixel phase. The colour is (7x + 3y + (x*y >> 5)) mod 16 :
# two neighbours on a line never share a colour, and the pattern has no
# symmetry, so a 7-byte block copied to the wrong place, a swapped bank, a
# reversed block or a shifted line shows as a wrong colour, not as a
# plausible picture. A notch top left (lines 0-7, x 0-23) tells up from down
# and left from right at a glance.
#
# Palette convention of png2bin : index 0 unused, indices 1..16 the TO8
# colours 0..15.
import io
import os
import sys

from PIL import Image

W, H = 160, 200
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'mire.png')

# displayable TO8 values (the levels png2pal keeps), 16 distinct colours
RGB = [(0, 0, 0), (250, 0, 0), (0, 250, 0), (0, 0, 250), (250, 250, 0), (250, 0, 250),
       (0, 250, 250), (250, 250, 250), (97, 97, 97), (171, 0, 0), (0, 171, 0),
       (0, 0, 171), (171, 171, 0), (171, 0, 171), (0, 171, 171), (171, 171, 171)]


def pixel(x, y):
    if y < 8 and x < 24:
        return 1 + 15 - (x & 15)
    return 1 + (7 * x + 3 * y + (x * y >> 5)) % 16


def picture():
    im = Image.new('P', (W, H))
    pal = [204, 0, 255]                      # index 0 : unused
    for c in RGB:
        pal += list(c)
    im.putpalette(pal + [0, 0, 0] * (256 - 17))
    im.putdata([pixel(x, y) for y in range(H) for x in range(W)])
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
