#!/usr/bin/env python3
"""Modèle exécutable de Bronco (boss du stage 7), calé sur la borne.

La famille (40:B7FB..40:C0A8) : un gestionnaire minuté (40:B8D5), cinq
segments (40:B997), un répartiteur qui lâche des débris au hasard
(40:BAA7, installateurs 40:BB40..BC63, débris 40:BC95), un lanceur de
poursuivants (40:BD32 / BDB2), l'attaquant principal (40:BE81) et ses
sous-enfants scriptés (40:C03F / C069). Une trame arcade à la fois, dans
l'ordre de la liste (priorités croissantes).

Le flux de random_ax est partagé avec la wave du stage (les pata-patas
40:599B, les roquettes 40:77E6) : comme pour le Compiler, les tirages de la
famille sont REJOUÉS depuis la trace (appelants `rc`). Le défilement
(scroll_amount, -1 une trame sur deux jusqu'à l'arrêt) est une entrée lue
dans la trace, ainsi que les résidus de fraction des records recyclés.

    python3 bronco_model.py <trace MAME brute .jsonl>
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


OWN = {0xBAE1, 0xBB4D, 0xBBC6, 0xBBDC, 0xBC3E, 0xBC70, 0xBD29, 0xBEE2,
       0xBA6F, 0xBFF2, 0xC00B, 0xC017}

# the installers (40:BB40..BC63) by the address the dispatch table holds
INSTALLERS = {
    0xBB40: ('gen', 0x616C), 0xBB72: ('gen', 0x6178), 0xBB7E: ('gen', 0x6184),
    0xBB8A: ('gen', 0x6190), 0xBB96: ('gen', 0x619C), 0xBBA2: ('gen', 0x61A8),
    0xBBAE: ('strong', 0x61B4), 0xBBC3: ('rare', 0x61C0),
    0xBC08: ('anim', 0x61CC), 0xBC31: ('jit2', 0x622C), 0xBC63: ('jit2', 0x6238),
}
AABB = {0x622C: 0x624C}                         # every other one is 0x6244


class Model:
    def __init__(self, gc0):
        self.gc = gc0
        self.draws = []
        self.scroll = 0                          # this frame's scroll_amount
        self.m = {'st': 'init', 'c10': 0, 'f30': 0, 'f31': 0, 'c32': 0}
        self.segs, self.debris, self.chasers, self.subs = [], [], [], []
        self.disp = self.spawner = self.ma = None
        self.freeze = False
        self.halted = False

    def rand(self, caller):
        c, ax = self.draws.pop(0)
        if c != caller:
            raise AssertionError('draw order: model %04X, borne %04X' % (caller, c))
        return ax

    # ------------------------------------------------------------------ 40:B805
    def init(self):
        c20, x = 0x3C0, 0x2D0
        for i in range(5):
            self.segs.append({'st': 'run', 'x': x, 'y': 0x160, 'c30': 0, 'c20': c20,
                              'born': self.gc})
            c20 -= 0x20
            x += 0x40
        self.disp = {'c30': 0, 'cur': 0x611E, 'c32': 0x20, 'c34': 0x20, 'c36': 0x20,
                     'born': self.gc}
        self.spawner = {'c20': 0, 'cur': 0x627C, 'born': self.gc}
        self.ma = {'st': 'run', 'x': 0x2E8 << 8, 'y': 0x110 << 8, 'c30': 0xFFFF,
                   'c32': 0x17F, 'f3d': 0, 'born': self.gc}
        self.m['st'] = 'life'

    # ------------------------------------------------------------------ 40:B8D5
    def manager(self):
        m = self.m
        if m['st'] == 'life':
            m['c10'] = (m['c10'] + 1) & 0xFFFF
            if m['c10'] == 0x2E0:
                self.halted = True
            if m['c10'] >= 0x1120:
                m['f30'] = 0xFF
            if m['c10'] == 0x1160 or m['f31']:
                m['c32'] = 0xC0
                m['st'] = 'pre'
        elif m['st'] == 'pre':                   # 40:B950
            m['c32'] -= 1
            if m['c32'] == 0:
                self.freeze = True               # b976 game_tick_disable
                m['st'] = 'gone'

    # ------------------------------------------------------------------ 40:B997
    def segment(self, s):
        if self.freeze:
            s['st'] = None
            return
        s['x'] = (s['x'] + self.scroll) & 0xFFFF
        s['c30'] = (s['c30'] + 1) & 0xFFFF
        if s['st'] == 'run':
            if self.m['f30']:
                s['c30'] = 0
                s['st'] = 'alt'
            elif self.m['f31']:
                s['st'] = None                   # ba4e: 12 explosions (draws)
                for _ in range(12):
                    self.rand(0xBA6F)
        else:                                     # 40:B9FD
            if s['x'] < 0x120:
                s['st'] = None

    # ------------------------------------------------------------------ 40:BAA7
    def dispatcher(self):
        d = self.disp
        if self.freeze:
            self.disp = None
            return
        d['c30'] = (d['c30'] + 1) & 0xFFFF
        if d['c30'] >= 0x360:
            d['c36'] -= 1
            if d['c36'] == 0:
                d['c36'] = 0x40
                d['c32'] -= 1
                if d['c32'] < 8:
                    d['c32'] = 8
            d['c34'] -= 1
            if d['c34'] == 0:
                d['c34'] = d['c32']
                idx = self.rand(0xBAE1) & 0x3E
                inst = w16(0x612C + idx)
                cur = d['cur']
                self.debris.append({'st': 'new', 'inst': inst, 'x': w16(cur),
                                    'y': 0x168 << 8,
                                    'vy': (-(0x400 - (d['c32'] << 4))) & 0xFFFF,
                                    'born': self.gc})
                d['cur'] += 2
                if w16(cur + 2) == 0x8000:
                    d['cur'] = 0x611E
        if self.m['f30'] or self.m['f31']:      # bb34: a WORD test
            self.disp = None

    # ------------------------------------------------------- 40:BB40..BC63
    def install(self, r):
        kind, p22 = INSTALLERS[r['inst']]
        r.update({'p22': p22, 'p24': AABB.get(p22, 0x6244), 'f26': 0, 'hp': 1,
                  'f32': 0, 'f33': 0})
        if kind == 'gen':
            if self.rand(0xBB4D) & 8:
                r['p22'] += 6
        elif kind == 'strong':
            r.update({'p24': 0x6254, 'f26': 1, 'hp': 0x0C})
        elif kind == 'rare':
            if (self.rand(0xBBC6) + self.gc) & 7:
                r['st'] = None                   # bc04: unloaded
                return
            if self.rand(0xBBDC) & 4:
                r['p22'] += 6
            r['f32'] = 1
        elif kind == 'anim':
            r['f33'] = 1
        elif kind == 'jit2':
            if self.rand(0xBC3E if r['inst'] == 0xBC31 else 0xBC70) & 2:
                r['p22'] += 6
        r['st'] = 'fall'

    # ------------------------------------------------------------------ 40:BC95
    def debris_tick(self, r):
        if self.freeze:
            r['st'] = None
            return
        if r['st'] == 'new':
            return self.install(r)
        r['y'] = move(r['y'], r['vy'])
        dead = r.get('dmg', 0) >= r['hp']
        if not dead and ipart(r['y']) >= 0xB0 and not self.m['f31']:
            return
        # bd03 / bd11: the explosion, or the bonus for the rare one
        if r['f32']:
            self.rand(0xBD29)
        r['st'] = None

    # ------------------------------------------------------------------ 40:BD32
    def spawn_tick(self):
        sp = self.spawner
        if self.freeze:
            self.spawner = None
            return
        sp['c20'] = (sp['c20'] + 1) & 0xFFFF
        if sp['c20'] >= 0x360 and not (sp['c20'] & 0x7F):
            cur = sp['cur']
            if w16(cur) != 0x8000:
                self.chasers.append({'x': w16(cur) << 8, 'y': 0x90 << 8, 'c30': 0,
                                     'born': self.gc, 'st': 1})
            sp['cur'] += 2
            if w16(cur + 2) == 0:
                sp['cur'] = 0x627C
        if self.m['f30'] or self.m['f31']:      # bda6: a WORD test
            self.spawner = None

    # ------------------------------------------------------------------ 40:BDB2
    def chaser(self, c):
        if self.freeze:
            c['st'] = None
            return
        if c['c30'] >= 0xC0:
            c['y'] = move(c['y'], 0xFF00)
        if c['c30'] < 0x40:
            c['y'] = move(c['y'], 0x0100)
        if c.get('dmg', 0) >= 2 or self.m['f31']:
            c['st'] = None
            return
        c['c30'] = (c['c30'] + 1) & 0xFFFF
        if c['c30'] == 0x100:
            c['st'] = None

    # ------------------------------------------------------------------ 40:BE81
    def main_attack(self):
        a = self.ma
        if self.freeze:
            self.ma = None
            return
        if a['st'] == 'fade':                     # 40:BFE8
            if not (self.gc & 3):
                self.rand(0xBFF2)
            self.rand(0xC00B)
            self.rand(0xC017)
            a['c30'] -= 1
            if a['c30'] == 0:
                self.ma = None
            return
        a['c30'] = (a['c30'] + 1) & 0xFFFF
        if a['c30'] < 0x500:
            return
        if a['c32'] >= 0x100 and self.m['f30']:
            self.ma = None
            return
        a['c32'] += 1
        if a['c32'] >= 0x180:
            a['c32'] = 0
            img = w16(0x6312 + (self.rand(0xBEE2) & 6))
            self.subs.append({'st': 1, 'x': ((ipart(a['x']) - 0x30) & 0xFFFF),
                              'y': ((ipart(a['y']) - 0x18) & 0xFFFF), 'img': img,
                              's12': 0xA7FC, 's14': w16(0xA7FC), 's16': 0, 's17': 1,
                              'born': self.gc})
        if a['c32'] >= 0x100:
            return
        a['x'] = move(a['x'], w16(0x631A + ((a['c32'] & 0xF0) >> 3)))
        if a['f3d']:
            a['f3d'] -= 1
        if a.get('dmg', 0) >= 0xA0:
            self.m['f31'] = 0xFF
            a['st'] = 'fade'
            a['c30'] = 0x80

    # ------------------------------------------------------------------ 40:F5C1
    def move_by_script(self, s):
        cl = s['s17']
        while cl:
            al = b8(s['s14'])
            if al & 0x80:                        # SetImage
                s['s16'] = al & 0x1F
                s['s14'] += 1
                continue
            if al & 0x40:                        # bit 6: -X if bit 5
                if al & 0x20:
                    s['x'] = (s['x'] - 1) & 0xFFFF
            elif al & 0x20:
                s['x'] = (s['x'] + 1) & 0xFFFF
            if al & 0x10:                        # bit 4: -Y if bit 3
                if al & 0x08:
                    s['y'] = (s['y'] - 1) & 0xFFFF
            elif al & 0x08:
                s['y'] = (s['y'] + 1) & 0xFFFF
            if al & 0x04:                        # end of segment
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

    # ------------------------------------------------------------------ 40:C03F
    def sub_tick(self, s):
        if self.freeze:
            s['st'] = None
            return
        ended = self.move_by_script(s)
        if s['st'] == 1:
            if ended:
                s['st'] = 2
                s['s17'] = 3
            elif s.get('dmg'):
                s['st'] = None
        else:
            if ended or s.get('dmg'):
                s['st'] = None

    # one arcade frame, in list order
    def frame(self, scroll):
        self.gc = (self.gc + 1) & 0xFFFF
        self.scroll = scroll
        for r in self.debris:                    # 0x0F00
            if r['st']:
                self.debris_tick(r)
        for s in self.subs:                      # 0x1000
            if s['st']:
                self.sub_tick(s)
        for c in self.chasers:                   # 0x2000
            if c['st']:
                self.chaser(c)
        for s in self.segs:                      # 0xA100
            if s['st']:
                self.segment(s)
        if self.disp:                            # 0xA110
            self.dispatcher()
        if self.spawner:                         # 0xA120
            self.spawn_tick()
        if self.ma:                              # 0xA130
            self.main_attack()
        if self.m['st'] == 'init':               # 0xA200
            self.init()
        elif self.m['st'] in ('life', 'pre'):
            self.manager()
        self.debris = [r for r in self.debris if r['st']]
        self.subs = [s for s in self.subs if s['st']]
        self.chasers = [c for c in self.chasers if c['st']]
        self.segs = [s for s in self.segs if s['st']]


# ---------------------------------------------------------------------------
# the arcade side
# ---------------------------------------------------------------------------
SEG = {0xB997: 'run', 0xB9FD: 'alt'}
DEBRIS_T = set(INSTALLERS) | {0xBC95}


def rec(o):
    b = bytes.fromhex(o['r'])
    w = lambda k: b[k] | (b[k + 1] << 8)
    pos = lambda k: ((w(k + 1) << 8) | b[k]) & 0xFFFFFF
    return b, w, pos


def arcade_view(f):
    v = {'m': None, 'segs': [], 'disp': None, 'spawner': None, 'ma': None,
         'debris': [], 'chasers': [], 'subs': []}
    for o in f['o']:
        t = o['t']
        b, w, pos = rec(o)
        if t in (0xB8D5, 0xB950):
            v['m'] = {'st': 'life' if t == 0xB8D5 else 'pre', 'c10': w(0x10),
                      'f30': b[0x30], 'f31': b[0x31]}
            if t == 0xB950:
                v['m']['c32'] = w(0x32)
        elif t in SEG:
            v['segs'].append((w(4), w(8), w(0x30), SEG[t]))
        elif t == 0xBAA7:
            v['disp'] = {'c30': w(0x30), 'cur': w(0x20), 'c32': w(0x32), 'c34': w(0x34),
                         'c36': w(0x36)}
        elif t == 0xBD32:
            v['spawner'] = {'c20': w(0x20), 'cur': w(0x22)}
        elif t in (0xBE81, 0xBFE8):
            v['ma'] = {'x': pos(3), 'y': w(8), 'c30': w(0x30), 'c32': w(0x32),
                       'st': 'run' if t == 0xBE81 else 'fade'}
        elif t in DEBRIS_T:
            d = {'x': w(4), 'y': pos(7), 'vy': w(0x20), 'st': 'new' if t != 0xBC95 else 'fall',
                 'a': o['a']}
            if t == 0xBC95:
                d.update({'p22': w(0x22), 'p24': w(0x24), 'f26': w(0x26), 'hp': b[0x2F],
                          'f32': b[0x32], 'f33': b[0x33]})
            else:
                d['inst'] = t
            v['debris'].append(d)
        elif t == 0xBDB2:
            v['chasers'].append((w(4), pos(7), w(0x30)))
        elif t in (0xC03F, 0xC069):
            v['subs'].append((w(4), w(8), w(0x12), w(0x14), b[0x16], b[0x17], w(0x34),
                              1 if t == 0xC03F else 2))
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


def segx(f):
    xs = [w for t, w in ((o['t'], rec(o)[1](4)) for o in f['o']) if t in SEG]
    return xs


def check(path):
    fr = merged(path)
    m = Model(fr[0]['gc'])
    errors, first = {}, {}

    def cmp(k, tag, a, b):
        if a != b:
            errors[tag] = errors.get(tag, 0) + 1
            first.setdefault(tag, (k, a, b))
    for k in range(1, len(fr)):
        f, prev = fr[k], fr[k - 1]
        m.draws = draws_of(prev['rng'], f)
        # the scroll: an input, read off the segments (they ride it)
        a0, a1 = segx(prev), segx(f)
        scroll = (a1[0] - a0[0]) if (a0 and a1 and len(a0) == len(a1)) else 0
        m.frame(scroll)
        av = arcade_view(f)
        if m.draws:
            cmp(k, 'draws.left', [], m.draws)
            m.draws = []
        # leftovers of recycled records: fractions at birth (inputs)
        for r in m.debris:
            if r['born'] == m.gc:
                for d in av['debris']:
                    if d['x'] == r['x'] and ipart(d['y']) == ipart(r['y']):
                        r['y'] = (r['y'] & ~0xFF) | (d['y'] & 0xFF)
        for c in m.chasers:
            if c['born'] == m.gc:
                for x, y, c30 in av['chasers']:
                    if (x == ipart(c['x'])) and (y >> 8) == ipart(c['y']):
                        c['y'] = y
        for sb in m.subs:                        # +0x16, set only by SetImage
            if sb['born'] == m.gc:
                for t in av['subs']:
                    if t[0] == sb['x'] and t[1] == sb['y']:
                        sb['s16'] = t[4]
        if m.ma and m.ma['born'] == m.gc and av['ma']:
            m.ma['x'] = av['ma']['x']
        if not av['m'] and m.m['st'] == 'gone':
            break
        # compare
        mm = m.m
        if av['m']:
            cmp(k, 'm.st', av['m']['st'], mm['st'])
            for fld in ('c10', 'f30', 'f31') + (('c32',) if av['m']['st'] == 'pre' else ()):
                cmp(k, 'm.' + fld, av['m'][fld], mm[fld])
        cmp(k, 'segs', sorted(av['segs']),
            sorted((s['x'], s['y'], s['c30'], s['st']) for s in m.segs))
        for name, mine, flds in (('disp', m.disp, ('c30', 'cur', 'c32', 'c34', 'c36')),
                                 ('spawner', m.spawner, ('c20', 'cur'))):
            a = av[name]
            if (a is None) != (mine is None):
                cmp(k, name, a, mine)
            elif a:
                for fld in flds:
                    cmp(k, name + '.' + fld, a[fld], mine[fld])
        a, mine = av['ma'], m.ma
        if (a is None) != (mine is None):
            cmp(k, 'ma', a, mine)
        elif a:
            for fld in ('c30', 'c32', 'st'):
                cmp(k, 'ma.' + fld, a[fld], mine[fld])
            cmp(k, 'ma.x', a['x'], mine['x'])
            cmp(k, 'ma.y', a['y'], ipart(mine['y']))
        ad = sorted((d['x'], d['y'], d['vy'], d['st'], d.get('p22'), d.get('hp'), d.get('f32'),
                     d.get('f33'), d.get('f26')) for d in av['debris'])
        md = sorted((r['x'], r['y'], r['vy'], r['st'], r.get('p22') if r['st'] == 'fall' else None,
                     r.get('hp') if r['st'] == 'fall' else None,
                     r.get('f32') if r['st'] == 'fall' else None,
                     r.get('f33') if r['st'] == 'fall' else None,
                     r.get('f26') if r['st'] == 'fall' else None) for r in m.debris)
        cmp(k, 'debris', ad, md)
        cmp(k, 'chasers', sorted(av['chasers']),
            sorted((ipart(c['x']), c['y'], c['c30']) for c in m.chasers))
        cmp(k, 'subs', sorted(av['subs']),
            sorted((s['x'], s['y'], s['s12'], s['s14'], s['s16'], s['s17'], s['img'], s['st'])
                   for s in m.subs))
    print('%d trames de jeu modelisees' % k)
    if not errors:
        print('IDENTIQUE — aucune divergence')
        return 0
    for tag in sorted(first, key=lambda t: first[t][0]):
        k, a, b = first[tag]
        print('%-14s %5d ecarts, premier trame %5d :\n   borne  %s\n   modele %s' % (tag, errors[tag], k, a, b))
    return 1


if __name__ == '__main__':
    sys.exit(check(sys.argv[1]))
