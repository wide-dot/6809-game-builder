#!/usr/bin/env python3
"""Write the reference of png2pal's near and steps, on rgb12-mire.bin."""

# Rgb12Test's second reference : png2pal's conversion written again apart from its Java, with
# lift="5,15,42" darkest="black" zeros="keep" apart="6" near="8" steps="6,35,12,12".
#
#     python3 gen_rgb12_darks_reference.py            # writes rgb12-mire-darks.ref
#     python3 gen_rgb12_darks_reference.py --check    # exit 1 if it differs from what it computes
#
# Without near and steps, it gives the Java's levels to the bit on Another World's water and
# jail (64 palettes) ; rgb12-mire-darks.ref : GGGGRRRR then 0000BBBB a colour, as rgb12-mire.ref.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = [0, 97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255]
LIFT, APART, NEAR = (5, 15, 42), 6.0, 8.0
STEP, DARKS, ALIKE, MOVE = 6.0, 35.0, 12.0, 12.0


def lab(r, g, b):
    def lin(c):
        v = c / 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    r, g, b = lin(r), lin(g), lin(b)
    x = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047)
    y = f(0.2126 * r + 0.7152 * g + 0.0722 * b)
    z = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
    return (116 * y - 16, 500 * (x - y), 200 * (y - z))


def mod360(d):
    m = math.fmod(d, 360)
    return m + 360 if m < 0 else m


def ciede2000(l1, l2):
    c1, c2 = math.hypot(l1[1], l1[2]), math.hypot(l2[1], l2[2])
    cm7 = ((c1 + c2) / 2) ** 7
    g = 0.5 * (1 - math.sqrt(cm7 / (cm7 + 25 ** 7)))
    a1, a2 = (1 + g) * l1[1], (1 + g) * l2[1]
    c1p, c2p = math.hypot(a1, l1[2]), math.hypot(a2, l2[2])
    h1, h2 = mod360(math.degrees(math.atan2(l1[2], a1))), mod360(math.degrees(math.atan2(l2[2], a2)))
    dl, dc, dh = l2[0] - l1[0], c2p - c1p, h2 - h1
    if c1p * c2p == 0:
        dh = 0
    elif dh > 180:
        dh -= 360
    elif dh < -180:
        dh += 360
    dhp = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dh / 2))
    lpm, cpm = (l1[0] + l2[0]) / 2, (c1p + c2p) / 2
    if c1p * c2p == 0:
        hpm = h1 + h2
    elif abs(h1 - h2) <= 180:
        hpm = (h1 + h2) / 2
    else:
        hpm = (h1 + h2 + 360) / 2 if h1 + h2 < 360 else (h1 + h2 - 360) / 2
    t = (1 - 0.17 * math.cos(math.radians(hpm - 30)) + 0.24 * math.cos(math.radians(2 * hpm))
         + 0.32 * math.cos(math.radians(3 * hpm + 6)) - 0.20 * math.cos(math.radians(4 * hpm - 63)))
    sl = 1 + 0.015 * (lpm - 50) ** 2 / math.sqrt(20 + (lpm - 50) ** 2)
    sc, sh = 1 + 0.045 * cpm, 1 + 0.015 * cpm * t
    cpm7 = cpm ** 7
    rt = -2 * math.sqrt(cpm7 / (cpm7 + 25 ** 7)) * math.sin(math.radians(60 * math.exp(-((hpm - 275) / 25) ** 2)))
    return math.sqrt((dl / sl) ** 2 + (dc / sc) ** 2 + (dhp / sh) ** 2 + rt * (dc / sc) * (dhp / sh))


TABLE = [lab(LEVELS[x >> 8], LEVELS[x >> 4 & 15], LEVELS[x & 15]) for x in range(4096)]


def convert(pal):
    """A palette of (r, g, b) : its levels [r, g, b]."""
    labs = [lab(*c) for c in pal]
    dark = min(range(len(pal)), key=lambda i: labs[i][0])          # the first of the darkest

    def target(i):
        t = labs[i]
        if t[0] > LIFT[0] and not ciede2000(t, labs[dark]) <= NEAR:
            t = (LIFT[2] + max(0.0, t[0] - LIFT[1]) * (100 - LIFT[2]) / (100 - LIFT[1]), t[1], t[2])
        return t

    def kept(c, x):
        return not ((c[0] == 0 and x >> 8) or (c[1] == 0 and x >> 4 & 15) or (c[2] == 0 and x & 15))

    out = []
    for i, c in enumerate(pal):
        if labs[i][0] == labs[dark][0]:
            out.append(0)
            continue
        t = target(i)
        x = min(range(4096), key=lambda x: ciede2000(t, TABLE[x]))  # the first of the nearest
        out.append((0 if c[0] == 0 else x >> 8) << 8 | (0 if c[1] == 0 else x >> 4 & 15) << 4 | (0 if c[2] == 0 else x & 15))
    placed = []
    for j in sorted(range(len(pal)), key=lambda i: labs[i][0]):
        c = pal[j]
        need = [(k, min(ciede2000(labs[j], labs[k]), APART),
                 min(STEP, abs(target(j)[0] - target(k)[0])) if labs[j][0] <= DARKS else 0)
                for k in placed if pal[k] != c]

        def far(l):
            for k, d, s in need:
                e = ciede2000(l, TABLE[out[k]])
                if e < d or abs(l[0] - TABLE[out[k]][0]) < s and e < ALIKE:
                    return False
            return True

        if out[j] != 0 and not far(TABLE[out[j]]):
            t = target(j)
            cur = ciede2000(t, TABLE[out[j]])
            best, mn = -1, float("inf")
            for x in range(4096):
                if kept(c, x) and far(TABLE[x]):
                    d = ciede2000(t, TABLE[x])
                    if d < mn:
                        mn, best = d, x
            if best >= 0 and mn <= cur + MOVE:
                out[j] = best
        placed.append(j)
    return out


def main():
    words = open(os.path.join(HERE, "rgb12-mire.bin"), "rb").read()
    colours = [((w >> 8 & 15) * 17, (w >> 4 & 15) * 17, (w & 15) * 17)
               for w in (words[i] << 8 | words[i + 1] for i in range(0, len(words), 2))]
    ref = bytearray()
    for p in range(0, len(colours), 16):
        for x in convert(colours[p:p + 16]):
            ref += bytes([(x >> 4 & 15) << 4 | x >> 8, x & 15])
    path = os.path.join(HERE, "rgb12-mire-darks.ref")
    if "--check" in sys.argv:
        sys.exit(0 if open(path, "rb").read() == bytes(ref) else 1)
    open(path, "wb").write(ref)


if __name__ == "__main__":
    main()
