#!/usr/bin/env python3
"""Generate the tile scroll example's tileset.

Not artwork : four 12x12 tiles built so that a wrong column, a wrong row or a
missing one pixel shift is visible rather than plausible.

  tile0  flat, colour 1        — reads as a background
  tile1  flat, colour 2        — the other background, so column parity shows
  tile2  diagonal              — a shift or a mirror breaks the line across
                                 the tile boundary
  tile3  framed with a corner  — asymmetric on both axes
"""
from PIL import Image

rgb = [(0,0,0),(255,255,255),(255,0,0),(0,255,0),(0,0,255),(255,255,0),
       (255,0,255),(0,255,255),(128,128,128),(255,128,0),(128,255,0),
       (0,128,255),(187,187,187),(255,128,128),(128,255,128),(128,128,255)]
pal = [0,0,0]*256
pal[0:3] = [204,0,255]
for i,c in enumerate(rgb): pal[(i+1)*3:(i+1)*3+3] = list(c)

S = 12
def new(bg):
    im = Image.new('P',(S,S),bg); im.putpalette(pal); return im

t = new(2); t.save('src/assets/tiles/tile0.png')          # colour 1, white
t = new(9); t.save('src/assets/tiles/tile1.png')          # colour 8, grey

t = new(2); px = t.load()                                  # diagonal on white
for i in range(S): px[i,i] = 3; px[S-1-i,i] = 5
t.save('src/assets/tiles/tile2.png')

t = new(6); px = t.load()                                  # framed, one corner
for i in range(S):
    px[i,0] = px[i,S-1] = px[0,i] = px[S-1,i] = 3
for y in range(1,4):
    for x in range(1,4):
        if x+y < 5: px[x,y] = 1
t.save('src/assets/tiles/tile3.png')

print("4 tuiles 12x12 ecrites")
