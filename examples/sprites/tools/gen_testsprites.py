from PIL import Image

# TO8-ish palette. Index 0 is transparent, 1..16 are colours 0..15.
rgb = [(0,0,0),(255,255,255),(255,0,0),(0,255,0),(0,0,255),(255,255,0),
       (255,0,255),(0,255,255),(128,128,128),(255,128,0),(128,255,0),
       (0,128,255),(187,187,187),(255,128,128),(128,255,128),(128,128,255)]
pal = [0,0,0]*256
pal[0:3] = [204,0,255]
for i,c in enumerate(rgb): pal[(i+1)*3:(i+1)*3+3] = list(c)

def new(w,h,bg=0):
    im = Image.new('P',(w,h),bg); im.putpalette(pal); return im

# glyph : 12x24, fully opaque, deliberately asymmetric on both axes so a
# mirror or a one pixel shift shows up as a wrong picture rather than a
# plausible one. A frame, a chevron pointing right, a notch top-left.
W,H = 12,24
g = new(W,H,2)                       # colour 1, white
px = g.load()
for x in range(W):
    for y in range(H):
        edge = x in (0,W-1) or y in (0,H-1)
        px[x,y] = 3 if edge else 2   # red frame, white inside
for y in range(2,H-2):               # chevron : one pixel per line, drifting
    t = abs((y-2) - (H-5)//2)
    x = 2 + (H-5)//2 - t
    if 0 < x < W-1: px[x,y] = 5      # blue
for y in range(1,4):                 # notch, top left only
    for x in range(1,4):
        if x+y < 5: px[x,y] = 1      # black
g.save('glyph.png')

# marker : 4x4, opaque, one corner different so orientation is readable
m = new(4,4,6)                       # colour 5, yellow
mp = m.load()
mp[0,0] = 3                          # red corner
m.save('marker.png')

for n in ('glyph.png','marker.png'):
    im = Image.open(n)
    print(f"  {n:<12} {im.size[0]}x{im.size[1]}")
