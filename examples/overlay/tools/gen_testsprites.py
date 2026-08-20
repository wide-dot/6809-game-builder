from PIL import Image

# TO8-ish palette. Index 0 is transparent, 1..16 are colours 0..15.
# Same test art as examples/sprites (glyph + marker), band excluded : the
# overlay pack has no background format, zx0 images are out of its scope.
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
# plausible one — the bench compares VRAM checksums of the four mirror
# variants against each other, which only works if all four differ.
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

# marker : 4x4, opaque, one corner different so orientation is readable.
# Compiled with the shift 0 draw routine only : it is the bench's probe for
# the missing-frame fallback path (@nodefinedframe) at odd positions.
m = new(4,4,6)                       # colour 5, yellow
mp = m.load()
mp[0,0] = 3                          # red corner
m.save('marker.png')

# probes : opaque rectangles, every width and height 12..15 — one pixel
# steps across a 4 pixel range cover every mod-4 anchoring class of the
# encoders. The bench draws each one's bdraw AND draw routine at the same
# screen address and measures the VRAM bounding box : the diff of the two
# anchors, per (w,h), is the centering law of the encoders.
for w in range(12, 16):
    for h in range(12, 16):
        p = new(w, h, 2)               # colour 1, white — uniform on purpose
        p.save(f'probe_{w}x{h}.png')

for n in ('glyph.png','marker.png'):
    im = Image.open(n)
    print(f"  {n:<12} {im.size[0]}x{im.size[1]}")
print("  probes 12..15 x 12..15")
