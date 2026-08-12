#!/usr/bin/env python3
"""Generate the collection example's tileset, as one sheet.

Not artwork : a vertical strip of forty 12x12 tiles, the file shape
gfxcomp's grid attribute slices. Each tile is a measuring pattern that
encodes its own index — a frame, plus the index rendered as a 6-bit row
of blocks — so any confusion between members after the cut would show a
wrong number, not a plausible tile. Content varies from tile to tile on
purpose : compiled sizes differ, and the packer's cut point moves with
the data rather than falling on a round number.
"""
from PIL import Image

rgb = [(0,0,0),(255,255,255),(255,0,0),(0,255,0),(0,0,255),(255,255,0),
       (255,0,255),(0,255,255),(128,128,128),(255,128,0),(128,255,0),
       (0,128,255),(187,187,187),(255,128,128),(128,255,128),(128,128,255)]
pal = [0,0,0]*256
pal[0:3] = [204,0,255]
for i,c in enumerate(rgb): pal[(i+1)*3:(i+1)*3+3] = list(c)

S = 12
N = 40
sheet = Image.new('P', (S, S*N), 0)
sheet.putpalette(pal)
px = sheet.load()

for t in range(N):
    base = t*S
    bg = (t % 14) + 2                 # background colour cycles, never 0/1
    for y in range(S):
        for x in range(S):
            px[x, base+y] = bg
    for i in range(S):                # frame, colour 1
        px[i, base] = px[i, base+S-1] = px[0, base+i] = px[S-1, base+i] = 1
    for b in range(6):                # index bits, 6 blocks of 1x2
        if t & (1 << b):
            px[2+b, base+5] = 1
            px[2+b, base+6] = 1

sheet.save('src/assets/tiles/glyphs.png')
print(f"glyphs.png : strip de {N} tuiles 12x12, index encode dans la mire")
