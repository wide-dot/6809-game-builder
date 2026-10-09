#!/usr/bin/env python3
"""Replay examples/bm4s under toje, headless : the 320x200 4 colour ($41) bench.

    cd examples/bm4s
    python3 ../../ci/toje-bench/bm4s_ut.py dist/to8.fd [shots]

Two checks, both against what the example claims in its readme :

1. the witnesses at $9C00 (see the game mode's main.asm) : +0 magic $CA,
   +1..+4, +8, +9, +10 at $01, the frame counter (+5) moving, the head of
   the free cell list (+6) holding still ;
2. the screen, compared at 320x200 against the source pictures
   (src/assets/sprites/*.png, drawn at 320 in 4 colours) : on every capture
   the band matches exactly, the moving sprite (glyph or marker, the
   animation alternates them) matches exactly where it is found, and no
   pixel is lit outside them (the erase path leaves no trail). Over the run
   the glyph has to be seen on both pre-shifted variants (an even and an odd
   position unit, i.e. a screen x of 0 and 2 modulo 4).

toje's capture is 704x624 : the 320x200 screen sits at (32, 112), two
capture pixels per screen pixel both ways. The four colours are the
palette's (Pal_bm4s, read by png2pal from the same pictures).

Exit code: 0 pass, 1 fail, 2 no verdict.
"""
import os
import sys
import tempfile

from PIL import Image

from mcp import Toje

SPRITES = 'src/assets/sprites'
ORIGIN_X, ORIGIN_Y = 32, 112


def screen(png):
    """The 320x200 screen of a capture, as colour indexes 0..3 (None : not a palette colour)."""
    cap = Image.open(png).convert('RGB')
    pal = {}
    src = Image.open(os.path.join(SPRITES, 'glyph.png'))
    p = src.getpalette()
    for i in range(1, 5):
        pal[tuple(p[3 * i:3 * i + 3])] = i - 1
    return [[pal.get(cap.getpixel((ORIGIN_X + 2 * x, ORIGIN_Y + 2 * y)))
             for x in range(320)] for y in range(200)]


def picture(name):
    """A source picture as colour indexes, None where transparent (index 0)."""
    im = Image.open(os.path.join(SPRITES, name + '.png'))
    w, h = im.size
    px = im.load()
    return [[None if px[x, y] == 0 else px[x, y] - 1 for x in range(w)] for y in range(h)]


def matches(scr, pic, x0, y0):
    """The picture at (x0, y0) : its opaque pixels equal, its transparent ones the background 0."""
    for y, row in enumerate(pic):
        for x, c in enumerate(row):
            if scr[y0 + y][x0 + x] != (0 if c is None else c):
                return False
    return True


def find(scr, pic, skip_rows):
    """Every place the picture matches, outside the rows the band takes."""
    h, w = len(pic), len(pic[0])
    corner = 0 if pic[0][0] is None else pic[0][0]
    out = []
    for y0 in range(200 - h + 1):
        if any(y in skip_rows for y in range(y0, y0 + h)):
            continue
        for x0 in range(320 - w + 1):
            if scr[y0][x0] == corner and matches(scr, pic, x0, y0):
                out.append((x0, y0))
    return out


def check_screen(scr, band, sprites):
    """(error or None, the sprite found and where)."""
    bh = len(band)
    rows = [y for y in range(200 - bh + 1) if matches(scr, band, 0, y)]
    if len(rows) != 1:
        return 'the band is found %d times, not once' % len(rows), None
    by = rows[0]
    skip = set(range(by, by + bh))
    found = [(name, xy) for name, pic in sprites.items() for xy in find(scr, pic, skip)]
    if len(found) != 1:
        return 'the moving sprite is found %d times, not once : %s' % (len(found), found), None
    name, (sx, sy) = found[0]
    pic = sprites[name]
    for y in range(200):
        for x in range(320):
            if scr[y][x] is None:
                return 'pixel (%d,%d) is not a palette colour' % (x, y), None
            inside = y in skip or (sx <= x < sx + len(pic[0]) and sy <= y < sy + len(pic))
            if not inside and scr[y][x] != 0:
                return 'pixel (%d,%d) is lit outside the band and the sprite : a trail' % (x, y), None
    return None, (name, sx, sy)


def main():
    disk = sys.argv[1]
    shots = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    band = picture('band')
    sprites = {'glyph': picture('glyph'), 'marker': picture('marker')}

    t = Toje()
    t.boot_floppy(disk)
    verdict = 2
    for _ in range(60):
        t.call('run_frames', {'n': 25, 'timeout_ms': 20000})
        b = t.read('9C00', 11)
        if b[0] == 0xCA and b[8] == 0x01:
            break
    else:
        print('BM4S-UT NO VERDICT : the witnesses never settled')
        t.dump()
        t.close()
        sys.exit(2)

    errors = []
    expect = {1: 'glyph index', 2: 'marker index', 3: 'sprite drawn', 4: 'cell allocated',
              8: 'animation seen', 9: 'band index', 10: 'band drawn as an overlay'}
    for k, what in expect.items():
        if b[k] != 0x01:
            errors.append('$9C%02X (%s) is $%02X' % (k, what, b[k]))
    frame, cells = b[5], (b[6], b[7])

    variants = set()
    with tempfile.TemporaryDirectory() as tmp:
        for i in range(shots):
            t.call('run_frames', {'n': 7, 'timeout_ms': 20000})
            png = os.path.join(tmp, 'shot%02d.png' % i)
            t.call('screenshot', {'path': png})
            err, where = check_screen(screen(png), band, sprites)
            print('shot %2d : %s' % (i, err or '%s at (%d,%d)' % where), flush=True)
            if err:
                errors.append('shot %d : %s' % (i, err))
            elif where[0] == 'glyph':
                variants.add(where[1] % 4)
    b = t.read('9C00', 11)
    if b[5] == frame:
        errors.append('the frame counter ($9C05) does not move')
    if (b[6], b[7]) != cells:
        errors.append('the free cell list head ($9C06) moved : a leak')
    if variants != {0, 2}:
        errors.append('the glyph was seen at screen x mod 4 in %s, both 0 and 2 are needed'
                      ' (the two pre-shifted variants)' % sorted(variants))

    if errors:
        print('BM4S-UT FAIL\n  ' + '\n  '.join(errors))
        verdict = 1
    else:
        print('BM4S-UT PASS (%d captures, both glyph variants, no trail)' % shots)
        verdict = 0
    t.close()
    sys.exit(verdict)


if __name__ == '__main__':
    main()
