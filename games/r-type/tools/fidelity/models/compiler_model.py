#!/usr/bin/env python3
"""Modèle exécutable du Compiler (boss du stage 4), calé sur la borne.

Une trame arcade à la fois, dans l'ordre de la liste arcade, avec les
tirages de random_ax REJOUÉS depuis la trace MAME (le flux de la borne est
entrelacé avec celui du champ d'étoiles : le port ne peut pas le
reproduire, il rejoue les valeurs que le Compiler a reçues). C'est la
spécification exécutable du portage 6809 : chaque routine cite son adresse
arcade, et `check` compare le modèle à la trace, trame par trame.

    python3 compiler_model.py <trace MAME brute .jsonl>

Ce que le modèle ne calcule pas, il le lit dans la trace comme une ENTRÉE :
la mort d'un segment de laser roulant sur le décor (la sonde lit la RAM des
tuiles de la borne) et les résidus de fraction des records recyclés.
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


# ---------------------------------------------------------------------------
# 16.8 positions, 8.8 moves (move_x_pos_8_8 0x40:0672)
# ---------------------------------------------------------------------------
def move(pos, v):
    """pos = 24-bit (int << 8 | frac), v = signed 8.8 word"""
    return (pos + s16(v)) & 0xFFFFFF


def ipart(pos):
    return (pos >> 8) & 0xFFFF


# set_direction_to 0x40:1D89 (unsigned compares, as in the code)
def direction(fx, fy, tx, ty):
    if ((fy + 8) & 0xFFFF) < ty:                 # 1d9c JC: target above
        if ((fx + 8) & 0xFFFF) < tx:
            return quad(tx - fx, ty - fy, (0x04, 0x08, 0x0C))      # NE
        if ((fx - 8) & 0xFFFF) >= tx:
            return quad(fx - tx, ty - fy, (0x3C, 0x38, 0x34))      # NW
        return 0x00
    if ((fy - 8) & 0xFFFF) >= ty:                # 1da5 JNC: target below
        if ((fx + 8) & 0xFFFF) < tx:
            return quad(tx - fx, fy - ty, (0x1C, 0x18, 0x14))      # SE
        if ((fx - 8) & 0xFFFF) >= tx:
            return quad(fx - tx, fy - ty, (0x24, 0x28, 0x2C))      # SW
        return 0x20
    return 0x10 if fx < tx else 0x30


def quad(dx, dy, codes):
    ax = (dx - dy + 0x20) & 0xFFFF
    if ax < 0x40:
        return codes[1]
    if ax & 0x8000:
        return codes[0]
    return codes[2]


def visible(x, y):
    """is_visible_range 0x40:1D6B"""
    return ((x - 300) & 0xFFFF) < 424 and ((y - 124) & 0xFFFF) < 280


# ---------------------------------------------------------------------------
# the family
# ---------------------------------------------------------------------------
TURRET_DIR = 0x5870
CFG_A, CFG_B = 0x5ABA, 0x5ABC


class Model:
    def __init__(self, gc0, player, diff=0):
        self.gc = gc0
        self.px, self.py = player
        self.diff = diff
        self.draws = []          # [(caller, ax)] for the current frame
        self.o = None            # orchestrator
        self.parts = {}          # 'R','B','L'
        self.turrets = []        # list order: b1, L, b2
        self.lasers = []         # right ones (0x401F) and left ones (0x3FFF)
        self.rolls = []          # 0xC000
        self.fx_spawns = []      # explosions requested this frame (not traced)

    def rand(self, caller):
        c, ax = self.draws.pop(0)
        if c != caller:
            raise AssertionError('draw order: model %04X, borne %04X' % (caller, c))
        return ax

    # 40:A71D create_compiler (frame 0)
    def create(self):
        ax = self.rand(0xA72B)
        v = (ax + self.py + self.px) & 7
        self.o = {'st': 'init', 'v10': v * 8, 'f30': 7, 'f32': 0, 'f34': 0, 'c36': 0}

    # 40:A762
    def init(self):
        o = self.o
        cad = b8(0x5844 + self.diff)

        def part(key, slot_off, bit):
            o['f30'] &= ~bit
            cfg = w16(0x5ABA + o['v10'] + slot_off)
            scr = w16(cfg)
            p = {'st': 'live', 'x': 0x100 << 8, 'y': 0x108 << 8, 'cfg': cfg,
                 'cur': scr, 'vx': w16(scr), 'vy': w16(scr + 2), 'dur': w16(scr + 4),
                 'dmg': 0, 'h32': 0, 'f28': 0, 'w34': 0, 'bit': bit}
            if key != 'B':                       # a7d6/a903: right and left only
                p['c20'] = p['c22'] = cad
            self.parts[key] = p
            return p

        part('R', 0, 1)
        b = part('B', 2, 2)
        t1 = self.turret(b, 'B', 0x30, -32, -40)
        t2 = self.turret(b, 'B', 0x40, -24, -64)
        lp = part('L', 4, 4)
        o['L34_reset'] = True
        tl = self.turret(lp, 'L', 0x30, -72, 24)
        # list order for equal priority: the newest first (0x4012: L before b2)
        self.turrets = [t for t in (t1, tl, t2) if t]
        o['f32'] = 0
        o['f34'] = 0
        o['st'] = 'monitor'

    def turret(self, parent, key, preset, ox, oy):
        idx = preset >> 4
        base = 0x8E10 + idx * 6 + self.diff * 96
        thr, rst = w16(base), w16(base + 2)
        ax = self.rand(0xF8E7)
        return {'st': 'live', 'pk': key, 'ox': ox, 'oy': oy, 'x': 0, 'y': 0,
                'a16': 0, 's14': 0, 'c26': (ax * 4) & (thr - 1), 'thr': thr, 'rst': rst,
                'dir': 0, 'shots': 0}

    # 40:A982
    def monitor(self):
        o = self.o
        o['f34'] = 0
        if (o['f30'] | o['f32']) == 7:
            o['f34'] = 1
            o['f32'] = 0
        if (o['f30'] & 7) == 7:
            o['c36'] = 0x100
            o['st'] = 'death'

    # 40:A9C1
    def death(self):
        o = self.o
        o['c36'] -= 1
        if o['c36'] == 0:
            o['st'] = 'gone'

    # 40:AFE6 compiler_part_motion_step
    def motion(self, p):
        o = self.o
        if p['dur']:
            p['dur'] -= 1
            p['x'] = move(p['x'], p['vx'])
            p['y'] = move(p['y'], p['vy'])
            return
        o['f32'] |= p['bit']
        if not o['f34']:
            return
        p['cur'] = (p['cur'] + 6) & 0xFFFF
        if w16(p['cur']) == 0x8000:
            p['cfg'] = (p['cfg'] + 2) & 0xFFFF
            nxt = w16(p['cfg'])
            if nxt == 0:                         # b04a terminator
                p['vx'], p['vy'] = 0x200, 0
                o['f30'] |= p['bit']
                p['cfg'] = (p['cfg'] - 2) & 0xFFFF
                p['f28'] = (p['f28'] + 1) & 0xFFFF
                return
            p['cur'] = nxt
        c = p['cur']
        p['vx'] = (w16(c) * 2) & 0xFFFF
        p['vy'] = (w16(c + 2) * 2) & 0xFFFF
        p['dur'] = w16(c + 4) >> 1

    # 40:AB01 / 40:ADFB
    def volley(self, p, side):
        if self.px < ipart(p['x']):
            return
        a = (self.py + 0x10 - ipart(p['y'])) & 0xFFFF
        if a & 0x8000 or self.py + 0x10 < ipart(p['y']):
            return
        win = 0x50 if side == 'R' else 0x30
        if a >= win:
            return
        p['c22'] = (p['c22'] - 1) & 0xFFFF
        if p['c22']:
            return
        p['c22'] = p['c20']
        ahead, pool, caller = (0x50, 0x5850, 0xAB3B) if side == 'R' else (0x10, 0x5860, 0xAE35)
        ax = self.rand(caller)
        lz = {'st': 'new', 'side': side, 'x': (ipart(p['x']) + ahead) << 8,
              'y': (ipart(p['y']) + s16(w16(pool + (ax & 0xE)))) & 0xFFFF,
              'vx': w16(0x5848 + 2 * self.diff)}
        self.lasers.append(lz)
        return lz

    # 40:AE5C
    def rolling(self, p):
        for dx, c1, c2 in ((-8, 0xAE87, 0xAE9F), (-0x28, 0xAED2, 0xAEEA)):
            ax = self.rand(c1)
            vx = ((ax >> 8) & 0xFF) + 0x80
            if ax & 0x20:
                vx = -vx
            ax2 = self.rand(c2)
            # XCHG AL,AH ; AND AX,0x1FF ; ADD AX,0x280
            life = ((((ax2 & 0xFF) << 8) | (ax2 >> 8)) & 0x1FF) + 0x280
            r = {'st': 1, 'x': ((ipart(p['x']) + dx) & 0xFFFF) << 8,
                 'y': ((ipart(p['y']) + 0x38) & 0xFFFF) << 8,
                 'vx': vx & 0xFFFF, 'w20': life, 'born': self.gc}
            self.rolls.append(r)

    def part_tick(self, key):
        p = self.parts[key]
        if p['st'] == 'cascade':
            return self.cascade(p)
        if key == 'R':
            self.volley(p, 'R')
        self.motion(p)
        if p['h32']:
            p['h32'] -= 1
        if p['f28']:
            return                               # fade path: nothing else
        if key == 'L':
            self.volley(p, 'L')
            if ipart(p['y']) < 0xB8:
                p['w34'] = (p['w34'] + 1) & 0xFFFF
                if p['w34'] < 0x40 and not (p['w34'] & 0xF):
                    self.rolling(p)
            else:
                p['w34'] = 0
        if p['dmg'] >= 0x28:
            self.o['f30'] |= p['bit']
            p['st'] = 'cascade'
            p['cl'] = {'R': 0x58EE, 'B': 0x594E, 'L': 0x59A6}[key]
            p['cl0'] = p['cl']
            p['c20'] = 0x40

    # 40:B073
    def cascade(self, p):
        if not (self.gc & 1):
            if not (self.gc & 3):
                self.rand(0xB084)
            self.rand(0xB09E)
            p['cl'] += 4
            if w16(p['cl']) == 0x8000:          # next entry checked at +4 of old
                p['cl'] = p['cl0']
        p['c20'] -= 1
        if p['c20'] == 0:
            p['st'] = 'gone'

    # 40:AC4C
    def turret_tick(self, t):
        if t['st'] != 'live':
            return
        if t['a16']:
            t['c26'] = (t['c26'] + 1) & 0xFFFF
            if t['c26'] == t['thr']:
                t['shots'] += 1
            elif t['c26'] >= t['rst']:
                t['c26'] = 0
                t['shots'] += 1
        par = self.parts[t['pk']]
        t['x'] = (ipart(par['x']) + t['ox']) & 0xFFFF
        t['y'] = (ipart(par['y']) + t['oy']) & 0xFFFF
        d = direction(t['x'], t['y'], self.px, self.py)
        t['dir'] = d
        t['a16'] = w16(TURRET_DIR + d)
        t['s14'] = w16(TURRET_DIR + d + 2)
        if par['st'] != 'live':
            t['st'] = 'boom'

    def laser_tick(self, lz):
        if lz['st'] == 'new':
            lz['st'] = 'fly'
        lz['x'] = move(lz['x'], lz['vx'])
        if not visible(ipart(lz['x']), lz['y']):
            lz['st'] = 'gone'

    # 40:AEFB phase 1 / 40:AF6F phase 2
    def roll_tick(self, r):
        r['x'] = move(r['x'], r['vx'])
        if r['st'] == 2:                         # af7b: SUB before the probe
            r['y'] = move(r['y'], r['w20'])
            r['w20'] = (r['w20'] - 0x10) & 0xFFFF
        else:
            r['y'] = move(r['y'], r['w20'])
        if r.get('kill') == self.gc or not visible(ipart(r['x']), ipart(r['y'])):
            r['st'] = 0
            return
        if r['st'] == 1:                         # af49: SUB after, JC -> phase 2
            if r['w20'] < 0x10:
                r['w20'] = 0
                r['st'] = 2
            else:
                r['w20'] -= 0x10

    # one arcade frame, in list order
    def frame(self):
        self.gc = (self.gc + 1) & 0xFFFF
        o = self.o
        # orchestrator 0x1000
        if o['st'] == 'init':
            self.init()
        elif o['st'] == 'monitor':
            self.monitor()
        elif o['st'] == 'death':
            self.death()
        # left lasers 0x3FFF (spawned this frame by the left part come AFTER
        # its turn: they wait for the next frame)
        for lz in [l for l in self.lasers if l['side'] == 'L']:
            self.laser_tick(lz)
        for key in ('L', 'B'):
            if key in self.parts and self.parts[key]['st'] != 'gone':
                self.part_tick(key)
        for t in self.turrets:
            self.turret_tick(t)
        for lz in [l for l in self.lasers if l['side'] == 'R']:
            self.laser_tick(lz)
        if 'R' in self.parts and self.parts['R']['st'] != 'gone':
            self.part_tick('R')
        for r in self.rolls:
            if r['st']:
                self.roll_tick(r)
        self.lasers = [l for l in self.lasers if l['st'] != 'gone']
        self.rolls = [r for r in self.rolls if r['st']]


# ---------------------------------------------------------------------------
# the checker: the model against the MAME trace, frame by frame
# ---------------------------------------------------------------------------
FAMILY = {0xA762: 'O', 0xA982: 'O', 0xA9C1: 'O', 0xAA0F: 'R', 0xAB62: 'B',
          0xACE7: 'L', 0xB073: 'C', 0xAC4C: 'T', 0xE6AB: 'Z', 0xE6C0: 'Z',
          0xAEFB: 'W', 0xAF6F: 'W'}
OWN_DRAWS = {0xA72B, 0xAB3B, 0xAE35, 0xAE87, 0xAE9F, 0xAED2, 0xAEEA,
             0xF8E7, 0xB084, 0xB09E}


def rec(o):
    b = bytes.fromhex(o['r'])
    w = lambda k: b[k] | (b[k + 1] << 8)
    return b, w


def arcade_view(f):
    """the arcade state of one frame, in the model's terms"""
    v = {'parts': {}, 'turrets': [], 'lasers': [], 'rolls': [], 'o': None}
    for o in f['o']:
        kind = FAMILY.get(o['t'])
        b, w = rec(o)
        pos = lambda k: (w(k + 1) << 8) | b[k]          # +3/+4/+5, +7/+8/+9
        if kind == 'O':
            v['o'] = {'t': o['t'], 'f30': w(0x30), 'f32': w(0x32), 'f34': w(0x34),
                      'c36': w(0x36)}
        elif kind in ('R', 'B', 'L'):
            v['parts'][kind] = {'x': pos(3) & 0xFFFFFF, 'y': pos(7) & 0xFFFFFF,
                                'cur': w(0x12), 'cfg': w(0x10), 'dur': w(0x3C),
                                'vx': w(0x38), 'vy': w(0x3A), 'c22': w(0x22),
                                'f28': w(0x28), 'w34': w(0x34) if kind == 'L' else 0}
        elif kind == 'T':
            v['turrets'].append({'x': w(4), 'y': w(8), 'c26': w(0x26), 'a16': w(0x16),
                                 'ox': s16(w(0x30))})
        elif kind == 'Z':
            v['lasers'].append((w(4), w(8)))
        elif kind == 'W':
            v['rolls'].append((w(4), w(8), w(0x20)))
            v.setdefault('roll24', []).append(((w(4) << 8) | b[3], (w(8) << 8) | b[7], w(0x20)))
    return v


def draws_of(prev, f):
    """the AX each caller got this frame (state stepped through all calls)"""
    a, b, c = prev['rng']
    if (f['gc'] & 0x1FF) == 0:
        a, b, c = 5, 1, 3
    out = []
    for caller in f.get('rc', []):
        na = (b + c) & 0xFF
        ax = (c << 8) | na
        a, b, c = na, a, b
        if caller in OWN_DRAWS:
            out.append((caller, ax))
    return out


def check(path, verbose=False):
    fr = [json.loads(l) for l in open(path)]
    fr2 = [fr[0]]
    for f in fr[1:]:                              # slowdown frames: nothing ran
        if f['gc'] != fr2[-1]['gc']:
            fr2.append(f)
    m = Model(fr2[0]['gc'], tuple(fr2[0]['p']), fr2[0]['diff'])
    m.draws = draws_of({'rng': fr[0]['rng']}, {'gc': fr2[0]['gc'], 'rc': fr2[0].get('rc', [])}) \
        if False else []
    # frame 0: the creation (its draw is in frame 0's caller list)
    first = fr2[0]
    m.draws = [(c, ax) for c, ax in draws_of({'rng': first['rng']}, {'gc': 0x1, 'rc': []})]
    errors, first_err = {}, {}
    prev = None
    for k, f in enumerate(fr2):
        if k == 0:
            # the creation's draw: rebuild from the state BEFORE frame 0 —
            # unknown; the state AFTER it is (rng): invert one step
            a, b, c = f['rng']
            # after one draw: a' = b+c, b' = a, c' = b  =>  before: a=b', b=c',
            # c = a' - c'
            pa, pb, pc = b, c, (a - c) & 0xFF
            draws = []
            st = (pa, pb, pc)
            for caller in f.get('rc', []):
                x, y, z = st
                na = (y + z) & 0xFF
                draws.append((caller, (z << 8) | na))
                st = (na, x, y)
            m.draws = [d for d in draws if d[0] in OWN_DRAWS]
            m.create()
            prev = f
            continue
        m.draws = draws_of(prev, f)
        av = arcade_view(f)
        # terrain deaths of rolling segments: an input
        alive = {(r[0], r[1]) for r in av['rolls']}
        if not av['o']:
            break                                 # the stage unloads the family
        m.frame()
        # the leftovers of the recycled records, rolling segments: their
        # fractions at spawn, read on the arcade at their first frame
        for r in [r for r in m.rolls if r['born'] == m.gc]:
            for x24, y24, w20 in av.get('roll24', []):
                if w20 == r['w20'] and abs(ipart(r['x']) - (x24 >> 8)) <= 1 \
                        and abs(ipart(r['y']) - (y24 >> 8)) <= 1:
                    r['x'], r['y'] = x24, y24
                    break
        if k == 1:
            # the turrets' fire gate (+0x16) is not set at creation: a
            # leftover. Non-zero, the first tick already counted; the arcade
            # counter at frame 1 says which (an input, like the fractions)
            for t, a in zip(m.turrets, av['turrets']):
                t['c26'] = a['c26']
            # the leftovers of the recycled records: part fractions
            for key, p in m.parts.items():
                ap = av['parts'][key]
                p['x'] = (p['x'] & ~0xFF) | (ap['x'] & 0xFF)
                p['y'] = (p['y'] & ~0xFF) | (ap['y'] & 0xFF)
        if m.draws:
            raise AssertionError('frame %d: draws not consumed %s' % (k, m.draws))

        def cmp(tag, a, b):
            if a != b:
                errors[tag] = errors.get(tag, 0) + 1
                first_err.setdefault(tag, (k, a, b))
        o = m.o
        if av['o']:
            cmp('o.state', {0xA762: 'init', 0xA982: 'monitor', 0xA9C1: 'death'}[av['o']['t']], o['st'])
            for fld in ('f30', 'f32', 'f34') + (('c36',) if o['st'] == 'death' else ()):
                cmp('o.' + fld, av['o'][fld], o[fld] & 0xFFFF)
        for key, ap in av['parts'].items():
            p = m.parts.get(key)
            if not p:
                cmp('part.' + key, 'present', 'absent')
                continue
            for fld in ('x', 'y', 'cur', 'cfg', 'dur', 'vx', 'vy', 'f28', 'w34') + (('c22',) if key != 'B' else ()):
                cmp('part.%s.%s' % (key, fld), ap[fld], p[fld] & (0xFFFFFF if fld in 'xy' else 0xFFFF))
        mt = [t for t in m.turrets if t['st'] == 'live']
        at = av['turrets']
        cmp('turret.count', len(at), len(mt))
        # from the end-level flag on (40:A9D9, countdown 0x80) the autopilot
        # moves the ship INSIDE the frame: the pinned position no longer
        # holds while the turrets aim, and their direction is not compared
        aim = not (o['st'] == 'death' and o['c36'] <= 0x80)
        for i, (a, t) in enumerate(zip(at, mt)):
            for fld in ('x', 'y', 'c26') + (('a16',) if aim else ()):
                cmp('turret%d.%s' % (i, fld), a[fld], t[fld])
        cmp('lasers', sorted(av['lasers']), sorted((ipart(l['x']), l['y']) for l in m.lasers))
        mr = sorted((ipart(r['x']), ipart(r['y']), r['w20']) for r in m.rolls)
        ar = sorted(av['rolls'])
        if mr != ar:
            # a segment the arcade lost while the model keeps it, everything
            # else equal: the terrain probe killed it — record and retry
            gone = [r for r in m.rolls if (ipart(r['x']), ipart(r['y']), r['w20']) not in set(ar)]
            if len(mr) - len(ar) == len(gone) and gone:
                m.rolls = [r for r in m.rolls if r not in gone]
                errors['roll.terrain'] = errors.get('roll.terrain', 0) + len(gone)
            else:
                cmp('rolls', ar, mr)
        prev = f
    print('%d frames de jeu modelises' % len(fr2))
    if not errors:
        print('IDENTIQUE — aucune divergence')
    for tag in sorted(first_err, key=lambda t: first_err[t][0]):
        k, a, b = first_err[tag]
        print('%-18s %6d ecarts, premier trame %5d : borne %s / modele %s' % (tag, errors[tag], k, a, b))
    if 'roll.terrain' in errors:
        print('roll.terrain       %6d segments tues par le decor (entree)' % errors['roll.terrain'])
    return 0 if set(errors) <= {'roll.terrain'} else 1


if __name__ == '__main__':
    sys.exit(check(sys.argv[1]))
