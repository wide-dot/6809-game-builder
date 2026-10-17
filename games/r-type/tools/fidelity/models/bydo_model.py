#!/usr/bin/env python3
"""Modèle exécutable du Bydo core (boss du stage 8), calé sur la borne.

La famille : le noyau (40:C0CA) et sa chronologie de 1000:6416, l'enfant
de la bouche (40:C39C / C3EE), les Win (40:983B / 98A8) qu'il lâche, ses
phases de mort (40:C1EB / C238 / C275) et sa cascade d'explosions
(40:C284). Le noyau ne meurt qu'au délai (0x2000) ou par la Force gardée
0x500 trames dans sa bouche ; les Win sont invulnérables et explosent avec
lui. Seule la cascade tire des nombres (le flux est partagé : rejoués).

Entrées lues dans la trace : le défilement du fond (0x2ED4, la bouche le
suit), les résidus des records recyclés (fractions, octet d'image des Win).

    python3 bydo_model.py <trace MAME brute .jsonl>
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


def b8(a):
    return _rom[D + a]


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def move(pos, v):
    return (pos + s16(v)) & 0xFFFFFF


def ipart(pos):
    return (pos >> 8) & 0xFFFF


OWN = {0xC28E, 0xC2B0, 0xC2BB, 0xC2D1, 0xC2DD}
WINS = {0x9758: (0xA872, 3, 0x278, 0x90), 0x978D: (0xA90C, 8, 0x2A0, 0x108),
        0x97C7: (0xA96C, 8, 0x2A0, 0x108), 0x9801: (0xA9F6, 8, 0x2A0, 0x108)}


def direction(fx, fy, tx, ty):
    def quad(dx, dy, codes):
        ax = (dx - dy + 0x20) & 0xFFFF
        if ax < 0x40:
            return codes[1]
        if ax & 0x8000:
            return codes[0]
        return codes[2]
    if ((fy + 8) & 0xFFFF) < ty:
        if ((fx + 8) & 0xFFFF) < tx:
            return quad(tx - fx, ty - fy, (0x04, 0x08, 0x0C))
        if ((fx - 8) & 0xFFFF) >= tx:
            return quad(fx - tx, ty - fy, (0x3C, 0x38, 0x34))
        return 0x00
    if ((fy - 8) & 0xFFFF) >= ty:
        if ((fx + 8) & 0xFFFF) < tx:
            return quad(tx - fx, fy - ty, (0x1C, 0x18, 0x14))
        if ((fx - 8) & 0xFFFF) >= tx:
            return quad(fx - tx, fy - ty, (0x24, 0x28, 0x2C))
        return 0x20
    return 0x10 if fx < tx else 0x30


def move_by_script(s):
    """40:F5C1 — s: x, y (int), s12, s14, s16, s17 ; True when it ended"""
    cl = s['s17']
    while cl:
        al = b8(s['s14'])
        if al & 0x80:
            s['s16'] = al & 0x1F
            s['s14'] += 1
            continue
        if al & 0x40:
            if al & 0x20:
                s['x'] = move(s['x'], 0xFF00)
        elif al & 0x20:
            s['x'] = move(s['x'], 0x0100)
        if al & 0x10:
            if al & 0x08:
                s['y'] = move(s['y'], 0xFF00)
        elif al & 0x08:
            s['y'] = move(s['y'], 0x0100)
        if al & 0x04:
            while True:
                s['s12'] += 2
                ax = w16(s['s12'])
                if ax == 0:
                    s['s12'] = w16(s['s12'] + 2)
                    s['s14'] = w16(s['s12'])
                    return True
                if (ax >> 8) == 0xF0:
                    s['s17'] = ax & 0xFF
                    continue
                s['s14'] = ax
                return False
        s['s14'] += 1
        cl -= 1
    return False


class Model:
    def __init__(self, gc0, player):
        self.gc = gc0
        self.px, self.py = player
        self.draws = []
        self.core = {'st': 'run', 'c30': 0, 'cur': 0x6416, 'x': 0, 'y': 0, 'f32': 0,
                     'f33': 0, 'f36': 0, 'f38': 0, 'c10': 0}
        self.mouth = None
        self.wins = []
        self.cascade = None
        self.freeze = False
        self.bgdelta = 0

    def rand(self, caller):
        c, ax = self.draws.pop(0)
        if c != caller:
            raise AssertionError('draw order: model %04X, borne %04X' % (caller, c))
        return ax

    # -------------------------------------------------- the timeline's calls
    def call(self, fn):
        c = self.core
        if fn in WINS:
            scr, s17, x, y = WINS[fn]
            self.wins.append({'st': 1, 'x': x << 8, 'y': y << 8, 's12': scr, 's14': w16(scr),
                              's16': 0, 's17': s17, 'c20': 0, 'c22': 0, 'born': self.gc})
        elif fn == 0xC37F:
            self.mouth = {'st': 1, 'x': 0x2C4, 'y': 0x11C, 'c20': 0, 'born': self.gc}
        elif fn == 0xC30A:
            c['x'], c['y'] = 0x2C4, 0x124
        elif fn in (0xC31B, 0xC326, 0xC32C, 0xC332, 0xC315):
            c['x'], c['y'] = 0x284, 0x124
        elif fn == 0xC37A:
            c['f36'] = 0xFF
        elif fn == 0xC305:
            c['f33'] = 0xFF
        # 0xF366 music, 0xC2F6 scroll stop, 0xC2F0 sound: no state here

    # ---------------------------------------------------------- 40:C0CA
    def core_tick(self):
        c = self.core
        if c['st'] == 'run':
            c['c30'] = (c['c30'] + 1) & 0xFFFF
            if c['c30'] >= w16(c['cur']):
                self.call(w16(c['cur'] + 2))
                c['cur'] += 4
            if c['c30'] >= 0xBC0:
                c['x'], c['y'] = 0x28C, 0x100     # c0ec the mouth probe
            if c['c30'] >= 0x2000:
                self.death_init()
        elif c['st'] == 'ph1':                    # 40:C1EB
            if c['c30'] == 0x17C:
                self.freeze = False
            c['c30'] -= 1
            if c['c30'] == 0:
                c['st'] = 'ph2'                   # c21c
                c['c10'] = 0xE0
        elif c['st'] == 'ph2':                    # 40:C238
            c['c10'] -= 1
            if c['c10'] == 0:
                c['c10'] = 0x40
                c['st'] = 'ph3'
        elif c['st'] == 'ph3':                    # 40:C275
            c['c10'] -= 1
            if c['c10'] == 0:
                c['st'] = 'gone'

    def death_init(self):
        c = self.core
        c['f32'] = 0xFF
        self.cascade = {'c20': 0x160, 'born': self.gc}
        c['c30'] = 0x180
        c['st'] = 'ph1'
        self.freeze = True

    # ---------------------------------------------------------- 40:C284
    def cascade_tick(self):
        k = self.cascade
        if not (self.gc & 3):
            self.rand(0xC28E)
            self.rand(0xC2B0)
            self.rand(0xC2BB)
            self.rand(0xC2D1)
            self.rand(0xC2DD)
        k['c20'] -= 1
        if k['c20'] == 0:
            self.cascade = None

    # ------------------------------------------------- 40:C39C / C3EE
    def mouth_tick(self):
        m, c = self.mouth, self.core
        if c['f32'] or c['f33']:                 # c39f: a WORD test of +0x32
            self.mouth = None
            return
        if m['st'] == 1:
            if not (m['c20'] & 0x3F) and c['f36']:
                m['c20'] = 0x7F
                m['st'] = 2
            else:
                m['x'] = (m['x'] + self.bgdelta) & 0xFFFF
                m['c20'] = (m['c20'] + 1) & 0xFFFF
                if self.freeze:
                    self.mouth = None
                return
        m['x'] = (m['x'] + self.bgdelta) & 0xFFFF          # phase B
        m['c20'] -= 1
        if m['c20'] == 0:
            c['f36'] = 0
            m['st'] = 1
        elif self.freeze:
            self.mouth = None

    # ------------------------------------------------- 40:983B / 98A8
    def win_tick(self, w):
        if w['st'] == 1:
            if move_by_script(w) and w['s17'] >= 4:
                w['s17'] -= 1
            w['c20'] = (w['c20'] + 1) % 3
            if self.freeze:
                w['st'] = 0
                return
            if self.core['f32']:
                w['st'] = 0                       # explodes (leaves the family)
                return
            if self.core['f33']:
                w['c22'] = 0
                w['st'] = 2
            return
        if self.freeze:
            w['st'] = 0
            return
        d = direction(ipart(w['x']), ipart(w['y']), self.px, self.py)
        w['c22'] = (w['c22'] + 1) & 0xFFFF
        tab = 0x8F90 if w['c22'] < 0x80 else 0x9090
        w['x'] = move(w['x'], w16(tab + d))
        w['y'] = move(w['y'], w16(tab + d + 2))
        w['c20'] = (w['c20'] + 1) % 3

    # one arcade frame, in list order: wins 0x8040, the core 0xC800, the
    # cascade 0xEF00 ; the mouth 0x1D00 first
    def frame(self, bgdelta):
        self.gc = (self.gc + 1) & 0xFFFF
        self.bgdelta = bgdelta
        if self.mouth:
            self.mouth_tick()
        for w in self.wins:
            if w['st']:
                self.win_tick(w)
        self.wins = [w for w in self.wins if w['st']]
        if self.core['st'] != 'gone':
            self.core_tick()
        if self.cascade:                         # 0xEF00: after the core, it
            self.cascade_tick()                  # ticks in its birth frame


CORE = {0xC0CA: 'run', 0xC1EB: 'ph1', 0xC238: 'ph2', 0xC275: 'ph3'}


def arcade_view(f):
    v = {'core': None, 'mouth': None, 'wins': [], 'cascade': None}
    for o in f['o']:
        b = bytes.fromhex(o['r'])
        w = lambda k: b[k] | (b[k + 1] << 8)
        pos = lambda k: ((w(k + 1) << 8) | b[k]) & 0xFFFFFF
        t = o['t']
        if t in CORE:
            v['core'] = {'st': CORE[t], 'c30': w(0x30), 'cur': w(0x34), 'x': w(4), 'y': w(8),
                         'f32': b[0x32], 'f33': b[0x33], 'f36': b[0x36], 'f38': w(0x38),
                         'c10': w(0x10)}
        elif t in (0xC39C, 0xC3EE):
            v['mouth'] = {'st': 1 if t == 0xC39C else 2, 'x': w(4), 'y': w(8), 'c20': w(0x20)}
        elif t in (0x983B, 0x98A8):
            v['wins'].append((1 if t == 0x983B else 2, pos(3), pos(7), w(0x12), w(0x14), b[0x16],
                              b[0x17], b[0x20], w(0x22)))
        elif t == 0xC284:
            v['cascade'] = {'c20': w(0x20)}
    v['wins'].sort()
    return v


def merged(path):
    fr = []
    for line in open(path):
        f = json.loads(line)
        if fr and f['gc'] == fr[-1]['gc']:
            f['rc'] = fr[-1].get('rc', []) + f.get('rc', [])
            fr[-1] = f
        else:
            fr.append(f)
    return fr


def draws_of(prev_rng, f):
    a, b, c = prev_rng
    if (f['gc'] & 0x1FF) == 0:
        a, b, c = 5, 1, 3
    out = []
    for caller in f.get('rc', []):
        na = (b + c) & 0xFF
        if caller in OWN:
            out.append((caller, (c << 8) | na))
        a, b, c = na, a, b
    return out


def check(path):
    fr = merged(path)
    m = Model(fr[0]['gc'], tuple(fr[0]['p']))
    av0 = arcade_view(fr[0])
    m.core.update({'c30': av0['core']['c30'], 'cur': av0['core']['cur']})
    errors, first = {}, {}

    def cmp(k, tag, a, b):
        if a != b:
            errors[tag] = errors.get(tag, 0) + 1
            first.setdefault(tag, (k, a, b))
    for k in range(1, len(fr)):
        f, prev = fr[k], fr[k - 1]
        m.draws = draws_of(prev['rng'], f)
        a0, a1 = arcade_view(prev)['mouth'], arcade_view(f)['mouth']
        bg = (a1['x'] - a0['x']) if (a0 and a1 and a1['st'] == 1 and a0['st'] == 1) else 0
        m.frame(s16(bg))
        if m.draws:
            cmp(k, 'draws.left', [], m.draws)
            m.draws = []
        av = arcade_view(f)
        for w in m.wins:                          # the leftovers at birth
            if w['born'] == m.gc:
                for t in av['wins']:
                    if t[3] == w['s12'] and t[4] == w['s14'] and t[1] >> 8 == ipart(w['x']):
                        w['x'], w['y'], w['s16'], w['c22'] = t[1], t[2], t[5], t[8]
        if m.mouth and m.mouth['born'] == m.gc and av['mouth']:
            m.mouth['c20'] = av['mouth']['c20']   # +0x20, a leftover
        if av['core']:
            c = m.core
            for fld in ('st', 'c30', 'cur', 'x', 'y', 'f32', 'f33', 'f36', 'f38') + \
                    (('c10',) if c['st'] in ('ph2', 'ph3') else ()):
                cmp(k, 'core.' + fld, av['core'][fld], c[fld])
        else:
            cmp(k, 'core.st', 'gone', m.core['st'])
        cmp(k, 'mouth', av['mouth'], m.mouth and {'st': m.mouth['st'], 'x': m.mouth['x'],
                                                 'y': m.mouth['y'], 'c20': m.mouth['c20']})
        cmp(k, 'wins', av['wins'], sorted((w['st'], w['x'], w['y'], w['s12'], w['s14'],
                                           w['s16'], w['s17'], w['c20'], w['c22'])
                                          for w in m.wins))
        cmp(k, 'cascade', av['cascade'], m.cascade and {'c20': m.cascade['c20']})
        if not av['core'] and m.core['st'] == 'gone':
            break
    print('%d trames de jeu modelisees' % k)
    if not errors:
        print('IDENTIQUE — aucune divergence')
        return 0
    for tag in sorted(first, key=lambda t: first[t][0]):
        k, a, b = first[tag]
        print('%-12s %5d ecarts, premier trame %5d :\n   borne  %s\n   modele %s' % (tag, errors[tag], k, a, b))
    return 1


if __name__ == '__main__':
    sys.exit(check(sys.argv[1]))
