#!/usr/bin/env python3
"""
Write the reference of png2pal's format="rgb12" with lift and darkest="black".

Rgb12Test's reference : v1 Another World's palette conversion, its code as it was
(archive/v1/tools/gen_data.py of wide-dot/another-world, choice D), run on a mire ; only
its docstrings reshaped.

    python3 gen_rgb12_reference.py            # writes rgb12-mire.bin and rgb12-mire.ref
    python3 gen_rgb12_reference.py --check    # exit 1 if they differ from what it computes

rgb12-mire.bin : 256 palettes of 16 big endian $0RGB words, every one of the 4096 colours
once, spread (word n = n * 2731 mod 4096) so each palette mixes darks and lights.
rgb12-mire.ref : the same palettes in TO8 levels, GGGGRRRR then 0000BBBB a colour, the
lightness lifted (L* 15..100 to 42..100, L* 5 or less kept), the darkest colour of each
palette black.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# ---- v1 Another World, archive/v1/tools/gen_data.py, as it was ----
# The TO8 palette's 16 levels per channel are far from linear (level 1 is
# already 97/255) : the profile png2pal uses, toolbox/graphics/png2pal/.../to.txt
TO8_LEVELS = [0, 97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255]


def _lab(rgb):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def _ciede2000(l1, l2):
    import math
    L1, a1, b1 = l1
    L2, a2, b2 = l2
    c1, c2 = math.hypot(a1, b1), math.hypot(a2, b2)
    cm = (c1 + c2) / 2
    g = 0.5 * (1 - math.sqrt(cm ** 7 / (cm ** 7 + 25 ** 7)))
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360
    h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dlp, dcp = L2 - L1, c2p - c1p
    dh = h2p - h1p
    if c1p * c2p == 0:
        dh = 0
    elif dh > 180:
        dh -= 360
    elif dh < -180:
        dh += 360
    dhp = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dh / 2))
    lpm, cpm = (L1 + L2) / 2, (c1p + c2p) / 2
    if c1p * c2p == 0:
        hpm = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hpm = (h1p + h2p) / 2
    else:
        hpm = (h1p + h2p + 360) / 2 if h1p + h2p < 360 else (h1p + h2p - 360) / 2
    t = (1 - 0.17 * math.cos(math.radians(hpm - 30)) + 0.24 * math.cos(math.radians(2 * hpm))
         + 0.32 * math.cos(math.radians(3 * hpm + 6)) - 0.20 * math.cos(math.radians(4 * hpm - 63)))
    sl = 1 + 0.015 * (lpm - 50) ** 2 / math.sqrt(20 + (lpm - 50) ** 2)
    sc, sh = 1 + 0.045 * cpm, 1 + 0.015 * cpm * t
    rt = (-2 * math.sqrt(cpm ** 7 / (cpm ** 7 + 25 ** 7))
          * math.sin(math.radians(60 * math.exp(-((hpm - 275) / 25) ** 2))))
    return math.sqrt((dlp / sl) ** 2 + (dcp / sc) ** 2 + (dhp / sh) ** 2 + rt * (dcp / sc) * (dhp / sh))


_TO8_LAB = None
_LEVELS_CACHE = {}


# The TO8 has no colour between black and level 1 (L* 41) : the Amiga's darks would all
# meet there. Their lightness is spread above it instead : L* LIFT_FROM..100 to
# LIFT_FLOOR..100, black (L* <= LIFT_BLACK) kept.
LIFT_BLACK, LIFT_FROM, LIFT_FLOOR = 5, 15, 42


def to8_levels(rgb):
    """
    Return the TO8 (r, g, b) levels whose rendering is closest (CIEDE2000) to rgb.

    Its lightness lifted, as png2pal does.
    """
    global _TO8_LAB
    if rgb not in _LEVELS_CACHE:
        if _TO8_LAB is None:
            _TO8_LAB = [((r, g, b), _lab((TO8_LEVELS[r], TO8_LEVELS[g], TO8_LEVELS[b])))
                        for r in range(16) for g in range(16) for b in range(16)]
        target = _lab(rgb)
        if target[0] > LIFT_BLACK:         # above the TO8's darkest grey, the darks kept apart
            target = (LIFT_FLOOR + max(0.0, target[0] - LIFT_FROM) * (100 - LIFT_FLOOR) / (100 - LIFT_FROM),
                      target[1], target[2])
        _LEVELS_CACHE[rgb] = min(_TO8_LAB, key=lambda e: _ciede2000(target, e[1]))[0]
    return _LEVELS_CACHE[rgb]



# ---- end of v1 ----


def mire():
    return bytes(b for n in range(4096) for b in ((n * 2731 % 4096) >> 8, (n * 2731 % 4096) & 255))


def reference(data):
    out = bytearray()
    for p in range(len(data) // 32):
        rgbs = [(((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17)
                for c in ((data[p * 32 + 2 * i] << 8) | data[p * 32 + 2 * i + 1] for i in range(16))]
        dark = min(_lab(c)[0] for c in rgbs)
        for rgb in rgbs:
            r, g, b = (0, 0, 0) if _lab(rgb)[0] == dark else to8_levels(rgb)
            out += bytes(((g << 4) | r, b))
    return bytes(out)


if __name__ == "__main__":
    data = mire()
    files = {"rgb12-mire.bin": data, "rgb12-mire.ref": reference(data)}
    stale = [n for n, d in files.items()
             if not os.path.exists(os.path.join(HERE, n)) or open(os.path.join(HERE, n), "rb").read() != d]
    if "--check" in sys.argv:
        print("up to date" if not stale else "OUT OF DATE : " + " ".join(stale))
        sys.exit(1 if stale else 0)
    for n, d in files.items():
        open(os.path.join(HERE, n), "wb").write(d)
        print("wrote", n)
