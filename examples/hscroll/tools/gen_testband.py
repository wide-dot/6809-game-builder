#!/usr/bin/env python3
"""Generate the hscroll example's test band.

Not artwork : a measuring pattern. Everything in it has a period that divides
160, so the band tiles with itself and any visible seam at the wrap is a
defect rather than a property of the image.

  rows 0-3   ruler : a tick every 16 px, which is one entry chunk of the
             generated code buffer, and a taller one every 80 px
  rows 4-15  triangle wave across the palette, symmetric so it meets itself
  rows 16-23 8 px checkerboard, period 16

Palette convention of png2bin -hs : index 0 is transparent, indices 1..16 are
TO8 colours 0..15. Index 12 (colour 11) is the guard colour the driver refills
the wrapped bytes with, so the pattern leaves it out of the artwork.
"""
from PIL import Image

W, H = 160, 24
SKY = 12          # colour 11, the guard colour
INK = 2           # colour 1
TICK = 16         # one entry chunk

# TO8-ish palette, only the entries the pattern uses need to be right
pal = [0, 0, 0] * 256
rgb = [(0,0,0),(255,255,255),(255,0,0),(0,255,0),(0,0,255),(255,255,0),
       (255,0,255),(0,255,255),(128,128,128),(255,128,0),(128,255,0),
       (0,128,255),(187,187,187),(255,128,128),(128,255,128),(128,128,255)]
for i, c in enumerate(rgb):
    pal[(i+1)*3:(i+1)*3+3] = list(c)
pal[0:3] = [204, 0, 255]          # index 0, transparent marker

img = Image.new('P', (W, H), SKY)
img.putpalette(pal)
px = img.load()

for x in range(W):
    # ruler
    if x % TICK == 0:
        h = 4 if x % 80 == 0 else 2
        for y in range(h):
            px[x, y] = INK
    # triangle wave : 0..15..0 over 160 px, so f(159) sits next to f(0)
    t = x * 2 * 15 // W
    c = t if t <= 15 else 30 - t
    for y in range(4, 16):
        px[x, y] = c + 1
    # checkerboard
    for y in range(16, H):
        px[x, y] = (INK if ((x // 8) + (y // 4)) % 2 == 0 else SKY)

img.save('band.png')
print(f"band.png {W}x{H} written")
