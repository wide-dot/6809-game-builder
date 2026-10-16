#!/usr/bin/env python3
"""Modèle exécutable de l'essaim de Dops (boss du stage 6), calé sur la borne.

Le « boss » du stage 6 est un gestionnaire (40:B111) qui lâche seize Dops
(40:5F3C) au même point, un toutes les 100 trames, puis termine le stage à
la trame 0x800. Un Dop ne tire rien au hasard : il avance sur une table de
vitesses par « voie » (droite, bas, gauche, haut) et tourne quand une sonde
à trois pas devant lui touche une tuile pleine. Toute sa trajectoire se lit
donc dans la carte de tuiles : la trace MAME en porte un vidage
(PILOT_TILEDUMP), et ce modèle sonde ce vidage comme la borne sonde sa RAM.

    python3 dopswarm_model.py <trace MAME brute .jsonl> <vidage de tuiles>
    python3 dopswarm_model.py <trace> <vidage> --to8 <level6_fc.bin> <col0>

La seconde forme sonde la carte de collision du TO8 au lieu du vidage
(une colonne de la carte TO8 par colonne de tuiles arcade, col0 = la colonne
de la carte TO8 qui tombe sous la colonne 0 de l'écran arcade) : si elle
reste identique à la borne, le terrain du TO8 suffit au portage 1:1.
"""
import json
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
_rom = open(ROM, 'rb').read()
D = 0x10000


def w16(a):
    return struct.unpack_from('<H', _rom, D + a)[0]


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def move(pos, v):
    return (pos + s16(v)) & 0xFFFFFF


def ipart(pos):
    return (pos >> 8) & 0xFFFF


def visible(x, y):
    """is_visible_range 0x40:1D6B"""
    return ((x - 300) & 0xFFFF) < 424 and ((y - 124) & 0xFFFF) < 280


SCRIPT = 0xC5E3               # the swarm's spawn script, {cursor, token}
END = 0x800                   # b11b: the stage ends there


class ArcadeTiles:
    """probe_foreground_tile 0x40:1E6C on a dump of the tile RAM"""

    def __init__(self, dump, cam):
        self.ram, self.cam = dump, cam

    def solid(self, x, y):
        cam = self.cam
        bx = ((cam >> 1) & 0xFC) + 0x1020
        ax = (((x + (cam & 7) - 0x140) & 0xFFFF) >> 1) & 0xFFFC
        bx = (bx + ax) & 0x10FF
        row = (0x17F - y) & 0xFFFF
        if y > 0x17F:
            row = 0
        bx = (bx + ((row & 0xFFF8) << 5)) & 0x3FFF
        tile = struct.unpack_from('<H', self.ram, bx)[0] & 0xFFF
        return tile < 0xDFC


class To8Tiles:
    """the same cell, read in the TO8 collision map (one bit per arcade cell,
    48 bytes per row, 30 rows, msb first)"""

    def __init__(self, bitmap, col0, cam):
        self.bits, self.col0, self.cam = bitmap, col0, cam

    def solid(self, x, y):
        col = ((x + (self.cam & 7) - 0x140) >> 3) + (self.cam >> 3) + self.col0
        row = max(0, 0x17F - y) >> 3
        if not (0 <= row < 30) or not (0 <= col < 48 * 8):
            return False
        return bool(self.bits[row * 48 + (col >> 3)] & (0x80 >> (col & 7)))


class Model:
    def __init__(self, gc0, tiles):
        self.gc = gc0
        self.tiles = tiles
        self.cur, self.ptr = 0, SCRIPT
        self.dops = []
        self.done = False

    # 40:B111 the manager, once per frame
    def manager(self):
        self.cur += 1
        if self.cur >= END:
            self.done = True                       # b18f: the freeze flag
            return
        if self.cur >= w16(self.ptr):
            tok = w16(self.ptr + 2)
            self.dops.append({
                'A': int(bool(tok & 0x100)), 'B': int(bool(tok & 0x40)),
                'p22': w16(0x931C + ((tok >> 4) & 3) * 2),
                'x': 0x200 << 8, 'y': 0x190 << 8, 'lane': 1,
                'born': self.gc, 'st': 1})
            self.ptr += 4

    # 40:5F3C run_dop (no hit, no scroll during the fight)
    def dop(self, d):
        if self.done:                              # 5f5c: game_tick_disable
            d['st'] = 0
            return
        v = 0x2A80 + d['p22'] + d['lane'] * 4
        d['x'] = move(d['x'], w16(v))
        d['y'] = move(d['y'], w16(v + 2))
        x, y = ipart(d['x']), ipart(d['y'])
        if not visible(x, y):
            d['st'] = 0
            return
        la = 0x2A40 + (0x20 if d['B'] else 0) + d['lane'] * 8
        x = (x + s16(w16(la))) & 0xFFFF
        y = (y + s16(w16(la + 2))) & 0xFFFF
        hit = False
        for _ in range(3):
            if x < 0x2C0 and self.tiles.solid(x, y):
                hit = True
            x = (x + s16(w16(la + 4))) & 0xFFFF
            y = (y + s16(w16(la + 6))) & 0xFFFF
            if hit:
                break
        if hit:
            d['lane'] = (d['lane'] + (1 if d['A'] else -1)) & 3

    def frame(self):
        self.gc = (self.gc + 1) & 0xFFFF
        if not self.done:
            self.manager()
        # the Dops sit after the manager in the list (0x4030 > 0x1000);
        # a Dop born this frame already ticks (it is linked behind)
        for d in self.dops:
            if d['st']:
                self.dop(d)
        self.dops = [d for d in self.dops if d['st']]


def arcade_dops(f, born_after):
    out = []
    for o in f['o']:
        if o['t'] != 0x5F3C or o['a'] in born_after:
            continue
        b = bytes.fromhex(o['r'])
        w = lambda k: b[k] | (b[k + 1] << 8)
        out.append(((w(4) << 8) | b[3], (w(8) << 8) | b[7], b[0x20]))
    return sorted(out)


def check(path, tiles_of, verbose=False):
    fr = [json.loads(l) for l in open(path)]
    # the Dops alive before the manager came are the wave's, not the boss's
    early = {o['a'] for o in fr[0]['o'] if o['t'] == 0x5F3C}
    m = Model(fr[0]['gc'], tiles_of)              # frame 0: the creation
    errors, first = 0, None
    for k, f in enumerate(fr):
        if k:
            m.frame()
        a = arcade_dops(f, early)
        # the leftovers of the recycled record: a Dop born this frame takes
        # the arcade's position fractions (+3/+7) — an input, like the seed
        born = [d for d in m.dops if d['born'] == m.gc]
        if born:
            seen = {o['a'] for o in fr[k - 1]['o']} if k else set()
            new = [arcade_dops({'o': [o]}, early)[0] for o in f['o']
                   if o['t'] == 0x5F3C and o['a'] not in seen | early]
            for d, (x, y, _) in zip(born, new):
                d['x'] = (d['x'] & ~0xFF) | (x & 0xFF)
                d['y'] = (d['y'] & ~0xFF) | (y & 0xFF)
                d['res'] = (x & 0xFF, y & 0xFF)
        mine = sorted((d['x'], d['y'], d['lane']) for d in m.dops)
        if a != mine:
            errors += 1
            if first is None:
                first = (k, a, mine)
        if not any(o['t'] == 0xB111 for o in f['o']) and not a and k > 10:
            break
    print('%d trames de jeu modelisees' % k)
    if not errors:
        print('IDENTIQUE — aucune divergence')
        return 0
    k, a, mine = first
    print('%d trames divergentes, premiere %d :\n  borne  %s\n  modele %s' % (errors, k, a, mine))
    return 1


if __name__ == '__main__':
    trace, dump = sys.argv[1], open(sys.argv[2], 'rb').read()
    fr0 = json.loads(open(trace).readline())
    cam = 124
    if '--to8' in sys.argv:
        i = sys.argv.index('--to8')
        tiles = To8Tiles(open(sys.argv[i + 1], 'rb').read(), int(sys.argv[i + 2]), cam)
    else:
        tiles = ArcadeTiles(dump, cam)
    sys.exit(check(trace, tiles))
