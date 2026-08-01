#!/usr/bin/env python3
"""Generate the tile scroll example's tileset, as one sheet.

Not artwork : a vertical strip of 12x12 tiles, the file shape leanscroll
writes and gfxcomp's grid attribute slices. Tile ids follow reading order,
top to bottom here.

  tile 0  poison, solid colour 4 — index 0 means "draw nothing" to the
          <tilemap> element (the v1 convention), so this tile must never
          reach the screen ; a blue square showing up is a broken build
  tile 1  flat, colour 1        — reads as a background
  tile 2  flat, colour 8        — the other background, so column parity shows
  tile 3  diagonal              — a shift or a mirror breaks the line across
                                 the tile boundary
  tile 4  framed with a corner  — asymmetric on both axes
"""
from PIL import Image

rgb = [(0,0,0),(255,255,255),(255,0,0),(0,255,0),(0,0,255),(255,255,0),
       (255,0,255),(0,255,255),(128,128,128),(255,128,0),(128,255,0),
       (0,128,255),(187,187,187),(255,128,128),(128,255,128),(128,128,255)]
pal = [0,0,0]*256
pal[0:3] = [204,0,255]
for i,c in enumerate(rgb): pal[(i+1)*3:(i+1)*3+3] = list(c)

S = 12
sheet = Image.new('P', (S, S*5), 0)
sheet.putpalette(pal)
px = sheet.load()

def fill(t, colour):
    for y in range(S):
        for x in range(S):
            px[x, t*S+y] = colour

fill(0, 5)                                                 # poison, blue
fill(1, 2)                                                 # colour 1, white
fill(2, 9)                                                 # colour 8, grey

fill(3, 2)                                                 # diagonal on white
for i in range(S):
    px[i, 3*S+i] = 3
    px[S-1-i, 3*S+i] = 5

fill(4, 6)                                                 # framed, one corner
for i in range(S):
    px[i, 4*S] = px[i, 4*S+S-1] = px[0, 4*S+i] = px[S-1, 4*S+i] = 3
for y in range(1,4):
    for x in range(1,4):
        if x+y < 5: px[x, 4*S+y] = 1

sheet.save('src/assets/tiles/tiles.png')
print("tiles.png : strip de 5 tuiles 12x12 (0 = poison)")
