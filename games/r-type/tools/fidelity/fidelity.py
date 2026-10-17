#!/usr/bin/env python3
"""Fidelite arcade : rejouer un boss sur TO8 et le comparer a la borne, trame par trame.

LA METHODE (16/10/2026). Un port est fidele quand, aux memes entrees, il passe
par les memes etats aux memes trames. On le verifie sans jugement visuel :

  1. ARCADE. MAME charge l'etat d'entree du stage (sta/rtype/stageN.sta,
     invulnerable), epingle le vaisseau sur un point fixe et enregistre les
     records de la famille du boss a chaque trame (le script Lua
     pilot/tools/trace_actors.lua du fork MAME). Ce script-ci les DECODE
     selon le profil du boss et ecrit la reference normalisee
     tools/fidelity/ref/<boss>.ref.jsonl.gz (commitee).

  2. TO8. toje amorce l'image, saute au stage par le cheat du title, pose un
     point d'arret sur le crochet de spawn du boss (`<boss>.Seeded`) et y
     ECRIT l'horloge globale et l'etat du generateur aleatoire de la borne a
     cette trame, epingle le vaisseau sur l'image TO8 exacte du meme point,
     puis releve l'etat du boss a chaque rendu (crochet `<boss>.Sample`).

  3. COMPARAISON. Les deux traces portent l'horloge globale arcade (le port
     la reproduit) : un rendu TO8 se compare a la trame arcade de meme
     horloge, champ par champ, en unites ARCADE — le port calcule en repere
     arcade et ne convertit qu'au dessin, d'ou une egalite stricte attendue.
     Le rapport donne la premiere divergence de chaque champ et le compte.

Pourquoi ca marche : pendant un combat de boss, tous les tirages de
random_ax viennent de la famille du boss (mesure : chaque transition de
l'etat 0x2F28 s'explique par ses tirages et le reensemencement des 512
trames). Avec la meme graine, la meme horloge et le meme vaisseau, la borne
est deterministe ; le port doit l'etre au meme octet.

Quand le flux aleatoire est PARTAGE (le Compiler et le champ d'etoiles), la
reference porte la valeur recue par chaque tirage de la famille et le banc
l'ecrit dans D au crochet `<boss>.Drawn` (profil avec `draws`).

Usage (depuis games/r-type/), <boss> = bellmite | compiler | dopswarm | bronco | bydo | ending :
  python3 tools/fidelity/fidelity.py arcade <boss>          # MAME -> ref
  python3 tools/fidelity/fidelity.py arcade <boss> --check  # ref a jour ?
  python3 tools/fidelity/fidelity.py to8 <boss> dist/to8.fd [--out f]
  python3 tools/fidelity/fidelity.py compare <boss> [--to8 f]
  --scenario kill (les trois commandes) : la mise a mort injectee
  --shots k1,k2 (arcade, to8) : captures appariees

Le build ne l'appelle jamais : c'est un banc d'analyse (grille de revue,
point 1).
"""
import gzip
import json
import os
import re
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, '..', '..'))
REPO = os.path.normpath(os.path.join(GAME, '..', '..'))
MAME_FORK = os.environ.get('MAME_FORK',
                           os.path.join(os.path.dirname(REPO), 'mame'))
MAME_BIN = os.environ.get('MAME_BIN', 'mame')
SCRATCH = os.environ.get('FIDELITY_TMP', tempfile.gettempdir())

sys.path.insert(0, os.path.join(REPO, 'ci', 'toje-bench'))


def s16(v):
    return v - 0x10000 if v >= 0x8000 else v


def s8(v):
    return v - 0x100 if v >= 0x80 else v


# =============================================================================
# PROFILES — what a boss is, on both sides
# =============================================================================
class Bellmite:
    name = 'bellmite'
    stage = 5
    unit = 'stage5.bellmite'
    lwmap = 'gen/enemies/build/stage5-bellmite.lwmap'
    ticks = (0xB1FA, 0xB2DC, 0xB473, 0xB40A, 0xB521, 0xB645, 0xB6AE,
             0xB6C4, 0xB491)
    start = 0xB1FA
    budget = 4200
    pin_arcade = (512, 228)          # x-320 multiple of 8, y multiple of 4
    pin_to8 = (80, 126)              # 8 + 192*3/8, 297 - 228*3/4
    # damage scenarios: (frame after the spawn, target) — target 0 is the
    # core, n the satellite n. 'kill': 26 satellites one every 6 frames
    # (the core loses its shield under 12), then the core.
    scenarios = {'idle': [],
                 'kill': [(400 + 6 * i, i + 1) for i in range(26)] + [(700, 0)]}
    PARENT = {0xB1FA: 1, 0xB2DC: 2, 0xB473: 3, 0xB40A: 4}
    SAT = {0xB521: 1, 0xB645: 2, 0xB6AE: 3, 0xB6C4: 4}
    HELPER = 0xB491
    stage_boxes = True               # its boxes live in the stage (main.asm)

    # --- arcade record -> normalized state ------------------------------
    def arcade(self, frame, seen_parent):
        par, sats, helper = None, {}, 0
        for o in frame['o']:
            b = bytes.fromhex(o['r'])
            w = lambda k: b[k] | (b[k + 1] << 8)
            t = o['t']
            if t in self.PARENT:
                st = self.PARENT[t]
                par = {'st': st, 'x': w(4), 'xf': b[3], 'y': w(8), 'yf': b[7]}
                if st >= 2:
                    par.update({'vx': w(0x20), 'vy': w(0x22), 'c24': w(0x24),
                                'c26': w(0x26), 'c12': w(0x12), 'f30': int(w(0x30) != 0),
                                'f32': w(0x32) & 0x3F, 'f34': w(0x34) & 0x3F,
                                'd36': w(0x36), 'n38': w(0x38) & 0xFF, 'fl': b[0x3D]})
                if st == 4:
                    par['c3e'] = w(0x3E)
            elif t in self.SAT:
                sid = w(0x18) & 0x3F
                sats[sid] = {'st': self.SAT[t], 'x': w(4), 'xf': b[3], 'y': w(8),
                             'yf': b[7], 'dx': s16(w(0x24)) & 0xFF,
                             'dy': s16(w(0x26)) & 0xFF, 'seed': b[0x12],
                             'c38': w(0x38) & 0xFF, 'fl': b[0x3D]}
                if self.SAT[t] == 2:
                    sats[sid].update({'vx': w(0x30), 'vy': w(0x32)})
                if self.SAT[t] == 3:
                    sats[sid]['c36'] = w(0x36) & 0xFF
            elif t == self.HELPER:
                helper = w(0x3E) & 0xFF
        if par is None:
            par = {'st': 5 if seen_parent else 0}
        return {'gc': frame['gc'], 'rng': frame['rng'], 'p': par,
                's': {str(k): v for k, v in sorted(sats.items())}, 'h': helper}

    # --- a scenario hit, on both sides -------------------------------------
    def hit_arcade(self, target):
        # (priority word +0x18, damage byte +0x1F): 14 kills a satellite
        # (40:B59D), 0x28 the core (its HP_max, 40:B2AD)
        return 0x7D00 + target, (14 if target else 0x28)

    def hit_to8(self, t, sym, base, target, boxes):
        put = lambda a, v: t.call('write_memory', {'addr': '%04X' % a,
                                                   'bytes': ['%02X' % v]})
        put(boxes + target * 9, 0)            # AABB.p: the points are gone
        if target:                            # and seen gone: no hit flash,
            r = base + sym['bm.Sats'] + (target - 1) * sym['S.SZ']   # the
            put(r + sym['S.pp'], 0)           # arcade arms it on a real hit
        else:
            put(base + sym['bm.ppp'], 0)

    # --- the arcade's leftovers, written at <boss>.Spawned ----------------
    def inject(self, t, sym, base, ref):
        first = next(s for s in ref if s['p']['st'] == 2)
        put = lambda a, v: t.call('write_memory', {'addr': '%04X' % a,
                                                   'bytes': ['%02X' % v]})
        put(base + sym['bm.pxf'], first['p']['xf'])
        put(base + sym['bm.pyf'], first['p']['yf'])
        for sid, d in first['s'].items():
            r = base + sym['bm.Sats'] + (int(sid) - 1) * sym['S.SZ']
            put(r + sym['S.xf'], d['xf'])
            put(r + sym['S.yf'], d['yf'])

    # --- TO8 memory -> normalized state ---------------------------------
    def to8(self, sym, mem, base):
        def b(name, off=0):
            return mem[sym[name] - base + off]

        def w(name, off=0):
            return (b(name, off) << 8) | b(name, off + 1)
        st = b('bm.pst')
        par = {'st': st}
        if st and st != 5:
            par.update({'x': w('bm.px'), 'xf': b('bm.pxf'), 'y': w('bm.py'),
                        'yf': b('bm.pyf')})
        if st >= 2 and st != 5:
            par.update({'vx': w('bm.pvx'), 'vy': w('bm.pvy'), 'c24': w('bm.c24'),
                        'c26': w('bm.c26'), 'c12': w('bm.c12'), 'f30': b('bm.f30'),
                        'f32': b('bm.f32'), 'f34': b('bm.f34'), 'd36': w('bm.d36'),
                        'n38': b('bm.n38'), 'fl': b('bm.pfl')})
        if st == 4:
            par['c3e'] = w('bm.c3e')
        sats = {}
        sz, s0 = sym['S.SZ'], sym['bm.Sats'] - base
        for n in range(37):
            r = s0 + n * sz
            g = lambda f: mem[r + sym[f]]
            gw = lambda f: (mem[r + sym[f]] << 8) | mem[r + sym[f] + 1]
            sst = g('S.st')
            if not sst:
                continue
            d = {'st': sst, 'x': gw('S.x'), 'xf': g('S.xf'), 'y': gw('S.y'),
                 'yf': g('S.yf'), 'dx': g('S.dx'), 'dy': g('S.dy'),
                 'seed': g('S.seed'), 'c38': g('S.c38'), 'fl': g('S.fl')}
            if sst == 2:
                d.update({'vx': gw('S.vx'), 'vy': gw('S.vy')})
            if sst == 3:
                d['c36'] = g('S.c36')
            sats[str(g('S.id'))] = d
        return {'gc': w('bm.gc'), 'rng': [b('bm.rng'), b('bm.rng', 1), b('bm.rng', 2)],
                'p': par, 's': sats, 'h': b('bm.helper')}


class Compiler:
    """The Compiler (stage 4). Its draws share random_ax with the starfield
    (star_ctor draws three times per star during the fight), so the port
    cannot reproduce the stream : the reference carries the AX each family
    caller received, and the bench REPLAYS them at `compiler.Drawn`."""
    name = 'compiler'
    stage = 4
    unit = 'lib.compiler'
    lwmap = 'gen/enemies/build/compiler.lwmap'
    hook = 'compiler'
    data = ('cpl.Data', 'cpl.DataEnd')
    gcsym, rngsym = 'cpl.gc', 'cpl.rng'
    ticks = (0xA762, 0xA982, 0xA9C1, 0xAA0F, 0xAB62, 0xACE7, 0xB073, 0xAC4C,
             0xE6AB, 0xE6C0, 0xAEFB, 0xAF6F)
    budget = 7400
    # the first frame after the creation is BLIND: its leftovers (position
    # fractions, turret clocks) are written at the Tick of the NEXT frame
    # (tick(), gc0+2), so a render that falls on gc0+1 cannot match. Seen
    # once a timing change made the first render fall there (16/10/2026).
    blind = 1
    env = {'PILOT_RNGLOG': '1'}
    pin_arcade = (512, 228)
    pin_to8 = (80, 126)
    # damage scenarios: (frame after the spawn, part) — 0 right, 1 bottom,
    # 2 left. 'kill': the three parts, each cascade played out before the next
    scenarios = {'idle': [], 'kill': [(600, 2), (800, 1), (1000, 0)]}
    ORCH = {0xA762: 1, 0xA982: 2, 0xA9C1: 3}
    PART = {0xAA0F: 'R', 0xAB62: 'B', 0xACE7: 'L'}
    OWN = {0xA72B, 0xAB3B, 0xAE35, 0xAE87, 0xAE9F, 0xAED2, 0xAEEA,
           0xF8E7, 0xB084, 0xB09E}
    ROLL_DRAWS = {0xAE87, 0xAED2}

    def __init__(self):
        self.reset()

    def reset(self):
        self.prev, self.where = None, {}

    # --- the AX each family caller got this frame -------------------------
    def draws(self, f):
        if self.prev is None:
            # the creation frame: the state BEFORE it is unknown, the state
            # after its single draw is known — invert one step
            a, b, c = f['rng']
            st = (b, c, (a - c) & 0xFF)
        else:
            st = tuple(self.prev)
            if (f['gc'] & 0x1FF) == 0:
                st = (5, 1, 3)
        out = []
        for caller in f.get('rc', []):
            a, b, c = st
            na = (b + c) & 0xFF
            if caller in self.OWN:
                out.append([caller, (c << 8) | na])
            st = (na, a, b)
        self.prev = f['rng']
        return out

    @staticmethod
    def aim(o):
        # from the end-level flag on (countdown 0x80) the arcade autopilot
        # moves the ship inside the frame : the turrets' aim is not compared
        return not (o.get('st') == 3 and o.get('c36', 0x100) <= 0x80)

    def arcade(self, frame, seen):
        st = {'gc': frame['gc'], 'd': self.draws(frame), 'o': None,
              'parts': {}, 'cas': {}, 't': [], 'z': [], 'w': []}
        for o in frame['o']:
            b = bytes.fromhex(o['r'])
            w = lambda k: b[k] | (b[k + 1] << 8)
            pos = lambda k: ((w(k + 1) << 8) | b[k]) & 0xFFFFFF
            t = o['t']
            if t in self.ORCH:
                # the creation frame leaves +0x32/+0x34 to the record's previous
                # occupant: the init (a972) clears them
                st['o'] = {'st': self.ORCH[t], 'f30': w(0x30)}
                if t != 0xA762:
                    st['o'].update({'f32': w(0x32), 'f34': w(0x34)})
                if t == 0xA9C1:
                    st['o']['c36'] = w(0x36)
            elif t in self.PART:
                k = self.PART[t]
                self.where[o['a']] = k
                d = {'x': pos(3), 'y': pos(7), 'cur': w(0x12), 'cfg': w(0x10),
                     'dur': w(0x3C), 'vx': w(0x38), 'vy': w(0x3A), 'f28': w(0x28)}
                if k != 'B':
                    d['c22'] = w(0x22)
                if k == 'L':
                    d['w34'] = w(0x34)
                st['parts'][k] = d
            elif t == 0xB073:
                st['cas'][self.where.get(o['a'], '?')] = {'cl': w(0x10), 'c20': w(0x20)}
            elif t == 0xAC4C:
                st['t'].append({'x': w(4), 'y': w(8), 'c26': w(0x26), 'fire': b[0x16]})
            elif t in (0xE6AB, 0xE6C0):
                st['z'].append([w(4), w(8)])
            elif t in (0xAEFB, 0xAF6F):
                st['w'].append([w(4), w(8), w(0x20), pos(3), pos(7)])
        if st['o'] is None:
            st['o'] = {'st': 4 if seen else 0}
        if not self.aim(st['o']):
            for d in st['t']:
                d.pop('fire')
        st['z'].sort()
        st['w'].sort()
        # what makes the family "seen": its orchestrator
        st['p'] = {'st': st['o']['st']}
        return st

    # --- TO8 memory -> normalized state ---------------------------------
    def to8(self, sym, mem, base):
        def b(name, off=0):
            return mem[sym[name] - base + off]

        def w(name, off=0):
            return (b(name, off) << 8) | b(name, off + 1)

        def rec(r, f, n=1):
            v = 0
            for i in range(n):
                v = (v << 8) | mem[r + sym[f] + i]
            return v
        ost = b('cpl.ost')
        o = {'st': ost}
        if ost in (1, 2, 3):
            o['f30'] = w('cpl.f30')
        if ost in (2, 3):
            o.update({'f32': w('cpl.f32'), 'f34': b('cpl.f34')})
            if ost == 3:
                o['c36'] = w('cpl.c36')
        st = {'gc': w('cpl.gc'), 'o': o, 'parts': {}, 'cas': {}, 't': [],
              'z': [], 'w': [], 'p': {'st': ost}}
        p0 = sym['cpl.Parts'] - base
        for i, k in enumerate('RBL'):
            r = p0 + i * sym['P.SZ']
            pst = rec(r, 'P.st')
            if pst == 1:
                d = {'x': (rec(r, 'P.x', 2) << 8) | rec(r, 'P.xf'),
                     'y': (rec(r, 'P.y', 2) << 8) | rec(r, 'P.yf'),
                     'cur': rec(r, 'P.cur', 2), 'cfg': rec(r, 'P.cfg', 2),
                     'dur': rec(r, 'P.dur', 2), 'vx': rec(r, 'P.vx', 2),
                     'vy': rec(r, 'P.vy', 2), 'f28': rec(r, 'P.f28', 2)}
                if k != 'B':
                    d['c22'] = rec(r, 'P.c22', 2)
                if k == 'L':
                    d['w34'] = rec(r, 'P.w34', 2)
                st['parts'][k] = d
            elif pst == 2:
                st['cas'][k] = {'cl': rec(r, 'P.cl', 2), 'c20': rec(r, 'P.life')}
        t0 = sym['cpl.Turrets'] - base
        for i in range(3):
            r = t0 + i * sym['T.SZ']
            if rec(r, 'T.st') == 1:
                st['t'].append({'x': rec(r, 'T.x', 2), 'y': rec(r, 'T.y', 2),
                                'c26': rec(r, 'T.c26', 2), 'fire': rec(r, 'T.fire')})
        z0 = sym['cpl.Lasers'] - base
        for i in range(sym['cpl.NLASER']):
            r = z0 + i * sym['Z.SZ']
            if rec(r, 'Z.st'):
                st['z'].append([rec(r, 'Z.x', 2), rec(r, 'Z.y', 2)])
        w0 = sym['cpl.Rolls'] - base
        for i in range(sym['cpl.NROLL']):
            r = w0 + i * sym['W.SZ']
            if rec(r, 'W.st'):
                st['w'].append([rec(r, 'W.x', 2), rec(r, 'W.y', 2), rec(r, 'W.w20', 2),
                                (rec(r, 'W.x', 2) << 8) | rec(r, 'W.xf'),
                                (rec(r, 'W.y', 2) << 8) | rec(r, 'W.yf')])
        if not self.aim(o):
            for d in st['t']:
                d.pop('fire')
        st['z'].sort()
        st['w'].sort()
        return st

    def done(self, st):
        return st['o']['st'] == 4

    @staticmethod
    def flat(st):
        out = {'o.' + k: v for k, v in st['o'].items()}
        for grp in ('parts', 'cas'):
            for k, d in st[grp].items():
                out.update({'%s.%s.%s' % (grp, k, f): v for f, v in d.items()})
            for k in 'RBL':
                out.setdefault('%s.%s' % (grp, k), k in st[grp])
        out['t.n'] = len(st['t'])
        for i, d in enumerate(st['t']):
            out.update({'t%d.%s' % (i, f): v for f, v in d.items()})
        out['z'] = st['z']
        out['w'] = st['w']
        return out

    # --- a scenario hit, on both sides -------------------------------------
    def hit_arcade(self, target):
        # (priority word +0x18, damage byte +0x1F): 0x28 is the parts' HP_max
        return (0x4020, 0x4010, 0x4000)[target], 0x28

    def hit_to8(self, t, sym, base, target, boxes):
        # the part's box potential to 0: its tick destroys it this frame
        r = base + sym['cpl.Parts'] + target * sym['P.SZ'] + sym['P.pup']
        pup = t.read('%04X' % r, 2)
        pup = (pup[0] << 8) | pup[1]
        if not pup:
            raise SystemExit('coup sur une piece sans marionnette (hors ecran ?)')
        t.call('write_memory', {'addr': '%04X' % (pup + sym['AABB_0'] + sym['AABB.p']),
                                'bytes': ['00']})

    # --- the bench: residues and inputs ---------------------------------
    def tick(self, t, sym, base, refs, g, gc0):
        """at compiler.Tick of frame g, before any actor"""
        put = lambda a, vals: t.call('write_memory', {
            'addr': '%04X' % a, 'bytes': ['%02X' % v for v in vals]})
        a = refs.get(g - 1)
        if g != gc0 + 2 or a is None:
            return
        # the parts' position fractions (+3/+7, the record's previous
        # occupant) and the turrets' fire clock (their gate +0x16 was a
        # leftover: the first tick already counted), as frame gc0+1 left them
        for i, k in enumerate('RBL'):
            r = base + sym['cpl.Parts'] + i * sym['P.SZ']
            if k in a['parts']:
                put(r + sym['P.xf'], [a['parts'][k]['x'] & 0xFF])
                put(r + sym['P.yf'], [a['parts'][k]['y'] & 0xFF])
        for i, d in enumerate(a['t']):
            r = base + sym['cpl.Turrets'] + i * sym['T.SZ']
            put(r + sym['T.c26'], [d['c26'] >> 8, d['c26'] & 0xFF])

    def settle(self, t, sym, base, refs, g, live, stats):
        """the rolling segments once frame g is played (at the next Tick or
        before a render is read). Born this frame: the arcade's leftover
        fractions. Gone on the arcade, alive here, everything else equal:
        the arcade's terrain probe killed it on the gum chains, which the
        TO8 does not draw nor probe during the fight (stage-main.asm,
        plainBackdrop) — an input, killed here and counted."""
        a = refs.get(g)
        if a is None or live.get('g') == g:
            return
        live['g'] = g
        sz, n = sym['W.SZ'], sym['cpl.NROLL']
        r0 = base + sym['cpl.Rolls']
        m = list(t.read('%04X' % r0, n * sz))
        put = lambda ad, vals: t.call('write_memory', {
            'addr': '%04X' % ad, 'bytes': ['%02X' % v for v in vals]})
        gw = lambda i, f: (m[i * sz + sym[f]] << 8) | m[i * sz + sym[f] + 1]
        now = {i for i in range(n) if m[i * sz + sym['W.st']]}
        for i in sorted(now - live.get('slots', set())):
            x, y, w20 = gw(i, 'W.x'), gw(i, 'W.y'), gw(i, 'W.w20')
            for ax, ay, aw, x24, y24 in a['w']:
                if aw == w20 and abs(ax - x) <= 1 and abs(ay - y) <= 1:
                    put(r0 + i * sz + sym['W.x'], [x24 >> 16, (x24 >> 8) & 0xFF, x24 & 0xFF])
                    put(r0 + i * sz + sym['W.y'], [y24 >> 16, (y24 >> 8) & 0xFF, y24 & 0xFF])
                    m[i * sz + sym['W.x']:i * sz + sym['W.x'] + 3] = [x24 >> 16, (x24 >> 8) & 0xFF, x24 & 0xFF]
                    m[i * sz + sym['W.y']:i * sz + sym['W.y'] + 3] = [y24 >> 16, (y24 >> 8) & 0xFF, y24 & 0xFF]
                    break
        arc = {(ax, ay, aw) for ax, ay, aw, _, _ in a['w']}
        mine = {i: (gw(i, 'W.x'), gw(i, 'W.y'), gw(i, 'W.w20')) for i in now}
        gone = [i for i, v in mine.items() if v not in arc]
        if gone and arc <= set(mine.values()) and len(mine) - len(gone) == len(arc):
            for i in gone:
                put(r0 + i * sz + sym['W.st'], [0])
                now.discard(i)
            stats['roll.terrain'] = stats.get('roll.terrain', 0) + len(gone)
        live['slots'] = now


class Dopswarm:
    """The Dop swarm (stage 6): a manager releasing sixteen Dops. No random
    draw at all; the Dops' path is written in the tile map, which the port
    reads from the stage's collision map. The Dops alive before the manager
    (the stage's own wave) are not the boss's and are left out."""
    name = 'dopswarm'
    stage = 6
    unit = 'stage6.dopswarm'
    lwmap = 'gen/enemies/build/stage6-dopswarm.lwmap'
    hook = 'dopswarm'
    data = ('dsw.Data', 'dsw.DataEnd')
    gcsym, rngsym = 'dsw.gc', None
    ticks = (0xB111, 0xB1AC, 0x5F3C)
    budget = 2400
    env = {'PILOT_START': 'b111'}
    pin_arcade = (512, 228)
    pin_to8 = (80, 126)
    # 'kill': every live Dop takes its 10 points at once (they share the
    # priority word the arcade injection keys on), twice
    scenarios = {'idle': [], 'kill': [(450, 0), (1450, 0)]}
    stage_boxes = True               # its boxes live in the stage (main.asm)
    MGR = {0xB111: 1, 0xB1AC: 2}

    def hit_arcade(self, target):
        return 0x4030, 10                      # +0x1F >= 0x0A: 40:5FCA

    def hit_to8(self, t, sym, base, target, boxes):
        # every live Dop: its rear box potential to 0, it dies this frame
        sz = sym['D.SZ']
        r0 = base + sym['dsw.Dops']
        m = t.read('%04X' % r0, sym['dsw.NDOP'] * sz)
        for i in range(sym['dsw.NDOP']):
            if m[i * sz + sym['D.st']]:
                rid = m[i * sz + sym['D.id']]
                t.call('write_memory', {'addr': '%04X' % (boxes + (2 * rid + 1) * 9 + sym['AABB.p']),
                                        'bytes': ['00']})

    def __init__(self):
        self.reset()

    def reset(self):
        self.early = None

    def arcade(self, frame, seen):
        if self.early is None:
            self.early = {o['a'] for o in frame['o'] if o['t'] == 0x5F3C}
        m, dops = {'st': 3 if seen else 0}, []
        for o in frame['o']:
            b = bytes.fromhex(o['r'])
            w = lambda k: b[k] | (b[k + 1] << 8)
            if o['t'] in self.MGR:
                m = {'st': self.MGR[o['t']]}
                if o['t'] == 0xB111:
                    m['cur'] = w(0x12)
                else:
                    m['c30'] = w(0x30)
            elif o['t'] == 0x5F3C and o['a'] not in self.early:
                dops.append([(w(4) << 8) | b[3], (w(8) << 8) | b[7], b[0x20],
                             b[0x1E], b[0x2E], w(0x22) & 0xFF])
        return {'gc': frame['gc'], 'm': m, 'd': sorted(dops), 'p': {'st': m['st']}}

    def to8(self, sym, mem, base):
        def b(name, off=0):
            return mem[sym[name] - base + off]

        def w(name, off=0):
            return (b(name, off) << 8) | b(name, off + 1)
        st = b('dsw.st')
        m = {'st': st}
        if st == 1:
            m['cur'] = w('dsw.cur')
        elif st == 2:
            m['c30'] = w('dsw.c30')
        dops = []
        d0 = sym['dsw.Dops'] - base
        for i in range(sym['dsw.NDOP']):
            r = d0 + i * sym['D.SZ']
            g = lambda f, n=1: int.from_bytes(bytes(mem[r + sym[f]:r + sym[f] + n]), 'big')
            if g('D.st'):
                dops.append([g('D.x', 3), g('D.y', 3), g('D.lane'), g('D.A'),
                             g('D.B'), g('D.vs')])
        return {'gc': w('dsw.gc'), 'm': m, 'd': sorted(dops), 'p': {'st': st}}

    def done(self, st):
        return st['m']['st'] == 3

    @staticmethod
    def flat(st):
        out = {'m.' + k: v for k, v in st['m'].items()}
        out['d'] = st['d']
        return out

    def tick(self, t, sym, base, refs, g, gc0):
        pass

    def settle(self, t, sym, base, refs, g, live, stats):
        """a Dop born in frame g: the arcade's leftover fractions (+3/+7)"""
        a = refs.get(g)
        if a is None or live.get('g') == g:
            return
        live['g'] = g
        sz, n = sym['D.SZ'], sym['dsw.NDOP']
        r0 = base + sym['dsw.Dops']
        m = list(t.read('%04X' % r0, n * sz))
        now = {i for i in range(n) if m[i * sz + sym['D.st']]}
        for i in sorted(now - live.get('slots', set())):
            x = (m[i * sz + sym['D.x']] << 8) | m[i * sz + sym['D.x'] + 1]
            y = (m[i * sz + sym['D.y']] << 8) | m[i * sz + sym['D.y'] + 1]
            for ax, ay, *_ in a['d']:
                if ax >> 8 == x and ay >> 8 == y:
                    t.call('write_memory', {'addr': '%04X' % (r0 + i * sz + sym['D.xf']),
                                            'bytes': ['%02X' % (ax & 0xFF)]})
                    t.call('write_memory', {'addr': '%04X' % (r0 + i * sz + sym['D.yf']),
                                            'bytes': ['%02X' % (ay & 0xFF)]})
                    break
        live['slots'] = now


class Bronco:
    """Bronco (stage 7): a timed manager, five lamps, junk launched at
    random, chasers, the main attacker and its scripted sub-children. Its
    draws share random_ax with the stage's wave (the pata-patas, the
    rockets): replayed at bronco.Drawn, as for the Compiler."""
    name = 'bronco'
    stage = 7
    unit = 'stage7.bronco'
    lwmap = 'gen/enemies/build/stage7-bronco.lwmap'
    hook = 'bronco'
    data = ('bro.Data', 'bro.DataEnd')
    gcsym, rngsym = 'bro.gc', 'bro.rng'
    ticks = ('b7fb-c0a0',)
    budget = 5000
    env = {'PILOT_RNGLOG': '1', 'PILOT_START': 'b805'}
    pin_arcade = (512, 228)
    pin_to8 = (80, 126)
    # 'kill': the main attacker takes its 160 points at frame 2000 (it wakes
    # at 0x500): its fall broadcasts +0x31 and the whole family goes
    scenarios = {'idle': [], 'kill': [(2000, 0)]}
    OWN = {0xBAE1, 0xBB4D, 0xBBC6, 0xBBDC, 0xBC3E, 0xBC70, 0xBD29, 0xBEE2,
           0xBA6F, 0xBFF2, 0xC00B, 0xC017}
    INST = {0xBB40, 0xBB72, 0xBB7E, 0xBB8A, 0xBB96, 0xBBA2, 0xBBAE, 0xBBC3,
            0xBC08, 0xBC31, 0xBC63}

    def __init__(self):
        self.reset()

    def reset(self):
        self.prev = None

    def draws(self, f):
        if self.prev is None:
            st = tuple(f['rng'])                 # nothing draws at creation
        else:
            st = tuple(self.prev)
            if (f['gc'] & 0x1FF) == 0:
                st = (5, 1, 3)
        out = []
        for caller in f.get('rc', []):
            a, b, c = st
            na = (b + c) & 0xFF
            if caller in self.OWN:
                out.append([caller, (c << 8) | na])
            st = (na, a, b)
        self.prev = f['rng']
        return out

    def arcade(self, frame, seen):
        st = {'gc': frame['gc'], 'd': self.draws(frame), 'rng': frame['rng'],
              'm': {'st': 4 if seen else 0}, 'segs': [], 'disp': None, 'spawner': None,
              'ma': None, 'debris': [], 'chasers': [], 'subs': []}
        for o in frame['o']:
            b = bytes.fromhex(o['r'])
            w = lambda k: b[k] | (b[k + 1] << 8)
            pos = lambda k: ((w(k + 1) << 8) | b[k]) & 0xFFFFFF
            t = o['t']
            if t in (0xB805, 0xB8D5, 0xB950):
                st['m'] = {'st': {0xB805: 1, 0xB8D5: 2, 0xB950: 3}[t]}
                if t != 0xB805:
                    st['m'].update({'c10': w(0x10), 'f30': b[0x30], 'f31': b[0x31]})
                if t == 0xB950:
                    st['m']['c32'] = w(0x32)
            elif t in (0xB997, 0xB9FD):
                st['segs'].append([w(4), w(8), w(0x30), 1 if t == 0xB997 else 2])
            elif t == 0xBAA7:
                st['disp'] = [w(0x30), w(0x20), w(0x32), w(0x34), w(0x36)]
            elif t == 0xBD32:
                st['spawner'] = [w(0x20), w(0x22)]
            elif t in (0xBE81, 0xBFE8):
                st['ma'] = [pos(3), w(8), w(0x30), w(0x32), 1 if t == 0xBE81 else 2]
            elif t in self.INST:
                st['debris'].append([w(4), pos(7), w(0x20), 1, 0, 0, 0, 0, 0])
            elif t == 0xBC95:
                st['debris'].append([w(4), pos(7), w(0x20), 2, w(0x22), b[0x2F], b[0x32],
                                     b[0x33], w(0x26)])
            elif t == 0xBDB2:
                st['chasers'].append([w(4), pos(7), w(0x30)])
            elif t in (0xC03F, 0xC069):
                st['subs'].append([w(4), w(8), w(0x12), w(0x14), b[0x16], b[0x17], w(0x34),
                                   1 if t == 0xC03F else 2])
        for k in ('segs', 'debris', 'chasers', 'subs'):
            st[k].sort()
        st['p'] = {'st': st['m']['st']}
        return st

    def to8(self, sym, mem, base):
        def b(name, off=0):
            return mem[sym[name] - base + off]

        def w(name, off=0):
            return (b(name, off) << 8) | b(name, off + 1)

        def recs(table, size, n):
            r0 = sym[table] - base
            for i in range(n):
                r = r0 + i * sym[size]
                yield (lambda f, k=1, r=r: int.from_bytes(bytes(mem[r + sym[f]:r + sym[f] + k]), 'big'))
        mst = b('bro.mst')
        m = {'st': mst}
        if mst in (2, 3):
            m.update({'c10': w('bro.c10'), 'f30': b('bro.f30'), 'f31': b('bro.f31')})
        if mst == 3:
            m['c32'] = w('bro.c32')
        st = {'gc': w('bro.gc'), 'm': m, 'p': {'st': mst},
              'segs': [], 'debris': [], 'chasers': [], 'subs': [],
              'disp': [w('bro.dc30'), w('bro.dcur'), w('bro.dc32'), w('bro.dc34'),
                       w('bro.dc36')] if b('bro.dst') else None,
              'spawner': [w('bro.sc20'), w('bro.scur')] if b('bro.sst') else None,
              'ma': [(w('bro.ax') << 8) | b('bro.axf'), w('bro.ay'), w('bro.ac30'),
                     w('bro.ac32'), b('bro.ast')] if b('bro.ast') else None}
        for g in recs('bro.Segs', 'G.SZ', sym['bro.NSEG']):
            if g('G.st'):
                st['segs'].append([g('G.x', 2), 0x160, g('G.c30', 2), g('G.st')])
        for g in recs('bro.Debris', 'R.SZ', sym['bro.NDEB']):
            s_ = g('R.st')
            if s_ == 1:
                st['debris'].append([g('R.x', 2), g('R.y', 3), g('R.vy', 2), 1, 0, 0, 0, 0, 0])
            elif s_ == 2:
                st['debris'].append([g('R.x', 2), g('R.y', 3), g('R.vy', 2), 2, g('R.p22', 2),
                                     g('R.hp'), g('R.f32'), g('R.f33'), g('R.f26')])
        for g in recs('bro.Chasers', 'C.SZ', sym['bro.NCH']):
            if g('C.st'):
                st['chasers'].append([g('C.x', 2), g('C.y', 3), g('C.c30', 2)])
        for g in recs('bro.Subs', 'B.SZ', sym['bro.NSUB']):
            if g('B.st'):
                st['subs'].append([g('B.x', 2), g('B.y', 2), g('B.s12', 2), g('B.s14', 2),
                                   g('B.s16'), g('B.s17'), g('B.p34', 2), g('B.st')])
        for k in ('segs', 'debris', 'chasers', 'subs'):
            st[k].sort()
        return st

    def done(self, st):
        return st['m']['st'] == 4

    @staticmethod
    def flat(st):
        out = {'m.' + k: v for k, v in st['m'].items()}
        for k in ('segs', 'disp', 'spawner', 'ma', 'debris', 'chasers', 'subs'):
            out[k] = st[k]
        return out

    def hit_arcade(self, target):
        return 0xA130, 0xA0                    # +0x1F >= HP 0xA0 (40:BF92)

    def hit_to8(self, t, sym, base, target, boxes):
        t.call('write_memory', {'addr': '%04X' % (base + sym['bro.admg']),
                                'bytes': ['00', 'A0']})

    def seed(self, t, sym, base, ref):
        """the autoscroll's phase: the frame of the lamps' first step"""
        put = lambda a, vals: t.call('write_memory', {
            'addr': '%04X' % a, 'bytes': ['%02X' % v for v in vals]})
        gc0, x0 = ref[0]['gc'], None
        for s_ in ref[1:]:
            if s_['segs']:
                x = s_['segs'][0][0]
                if x0 is not None and x != x0:
                    put(base + sym['bro.sacc'], [0x00 if (s_['gc'] - gc0) % 2 == 0 else 0x80])
                    return
                x0 = x

    def tick(self, t, sym, base, refs, g, gc0):
        pass

    def settle(self, t, sym, base, refs, g, live, stats):
        """records born in frame g: the arcade's leftovers (fractions, the
        sub-child's image byte). A birth is told by the record's state, not
        by its slot: a slot freed and taken again in the same frame (a
        chaser dying as the next one is born) keeps its place"""
        a = refs.get(g)
        if a is None or live.get('g') == g:
            return
        live['g'] = g
        put = lambda ad, vals: t.call('write_memory', {
            'addr': '%04X' % ad, 'bytes': ['%02X' % v for v in vals]})
        for table, size, n, kind in (('bro.Debris', 'R.SZ', 'bro.NDEB', 'd'),
                                     ('bro.Chasers', 'C.SZ', 'bro.NCH', 'c'),
                                     ('bro.Subs', 'B.SZ', 'bro.NSUB', 's')):
            sz, cnt = sym[size], sym[n]
            r0 = base + sym[table]
            m = list(t.read('%04X' % r0, cnt * sz))
            for i in range(cnt):
                r = i * sz
                gw = lambda f: (m[r + sym[f]] << 8) | m[r + sym[f] + 1]
                if kind == 'd' and m[r + sym['R.st']] == 1:          # not installed
                    for d in a['debris']:
                        if d[3] == 1 and d[0] == gw('R.x'):
                            put(r0 + r + sym['R.yf'], [d[1] & 0xFF])
                elif kind == 'c' and m[r + sym['C.st']] and gw('C.c30') == 0:
                    for c in a['chasers']:
                        if c[2] == 0 and c[0] == gw('C.x'):
                            put(r0 + r + sym['C.yf'], [c[1] & 0xFF])
                elif (kind == 's' and m[r + sym['B.st']] == 1 and gw('B.s12') == 0xA7FC
                      and gw('B.s14') == 0xAA5C):                    # not moved yet
                    for sb in a['subs']:
                        if sb[2] == 0xA7FC and sb[3] == 0xAA5C and sb[0] == gw('B.x'):
                            put(r0 + r + sym['B.s16'], [sb[4]])
        if a['ma'] and not live.get('ma') and t.read('%04X' % (base + sym['bro.ast']), 1)[0]:
            live['ma'] = True
            put(base + sym['bro.axf'], [a['ma'][0] & 0xFF])


class Bydo:
    """The Bydo core (stage 8): a clock that walks a timeline, its mouth's
    child, the wins it lets go, its death phases and explosion cascade. Its
    reading of the arcade records is the model's (models/bydo_model.py)."""
    name = 'bydo'
    stage = 8
    unit = 'stage8.bydo'
    lwmap = 'gen/enemies/build/stage8-bydo.lwmap'
    hook = 'bydo'
    data = ('bydo.Data', 'bydo.DataEnd')
    gcsym, rngsym = 'bydo.gc', 'bydo.rng'
    ticks = ('c0ca-c46d', 0x983B, 0x98A8)
    budget = 9300
    env = {'PILOT_RNGLOG': '1', 'PILOT_START': 'c0ca', 'PILOT_WAIT': '40000'}
    pin_arcade = (512, 228)
    pin_to8 = (80, 126)
    # the timeout kills it at 0x2000: the idle scenario plays the whole fight
    scenarios = {'idle': []}
    OWN = {0xC28E, 0xC2B0, 0xC2BB, 0xC2D1, 0xC2DD}
    CORE = {1: 'run', 2: 'ph1', 3: 'ph2', 4: 'ph3', 5: 'gone'}
    SCRIPTS = {0xA872: 0x278, 0xA90C: 0x2A0, 0xA96C: 0x2A0, 0xA9F6: 0x2A0}

    def __init__(self):
        from models import bydo_model
        self.model = bydo_model
        self.reset()

    def reset(self):
        self.prev = None

    def draws(self, f):
        if self.prev is None:
            st = tuple(f['rng'])                 # nothing draws at creation
        else:
            st = tuple(self.prev)
            if (f['gc'] & 0x1FF) == 0:
                st = (5, 1, 3)
        out = []
        for caller in f.get('rc', []):
            a, b, c = st
            na = (b + c) & 0xFF
            if caller in self.OWN:
                out.append([caller, (c << 8) | na])
            st = (na, a, b)
        self.prev = f['rng']
        return out

    def arcade(self, frame, seen):
        v = self.model.arcade_view(frame)
        core = v['core']
        if core is None:
            core = {'st': 'gone'}
        elif core['st'] not in ('ph2', 'ph3'):
            core = dict(core)
            del core['c10']
        rank = {n: k for k, n in self.CORE.items()}[core['st']] if (seen or v['core']) else 0
        return {'gc': frame['gc'], 'd': self.draws(frame), 'rng': frame['rng'],
                'core': core, 'mouth': v['mouth'], 'cascade': v['cascade'],
                'wins': [list(t) for t in v['wins']], 'p': {'st': rank}}

    def to8(self, sym, mem, base):
        def b(name, off=0):
            return mem[sym[name] - base + off]

        def w(name, off=0):
            return (b(name, off) << 8) | b(name, off + 1)
        st = self.CORE[b('bydo.cst')] if b('bydo.cst') else 'gone'
        core = {'st': st}
        if st != 'gone':
            core.update({'c30': w('bydo.c30'), 'cur': 0x6416 + 4 * b('bydo.ci'),
                         'x': w('bydo.x'), 'y': w('bydo.y'), 'f32': b('bydo.f32'),
                         'f33': b('bydo.f33'), 'f36': b('bydo.f36'), 'f38': w('bydo.f38')})
            if st in ('ph2', 'ph3'):
                core['c10'] = w('bydo.c10')
        mouth = None
        if b('bydo.mst'):
            mouth = {'st': b('bydo.mst'), 'x': w('bydo.mx'), 'y': 0x11C, 'c20': w('bydo.mc20')}
        wins = []
        r0 = sym['bydo.Wins'] - base
        for i in range(sym['bydo.NWIN']):
            r = r0 + i * sym['W.SZ']
            f = lambda k, n=1: int.from_bytes(bytes(mem[r + sym[k]:r + sym[k] + n]), 'big')
            if f('W.st'):
                wins.append([f('W.st'), f('W.x', 3), f('W.y', 3), f('W.s12', 2), f('W.s14', 2),
                             f('W.s16'), f('W.s17'), f('W.c20'), f('W.c22', 2)])
        wins.sort()
        return {'gc': w('bydo.gc'), 'core': core, 'mouth': mouth, 'wins': wins,
                'cascade': {'c20': w('bydo.kc20')} if b('bydo.kst') else None,
                'p': {'st': b('bydo.cst')}}

    def done(self, st):
        return st['core']['st'] == 'gone'

    @staticmethod
    def flat(st):
        out = {'core.' + k: v for k, v in st['core'].items()}
        for k in ('mouth', 'wins', 'cascade'):
            out[k] = st[k]
        return out

    def seed(self, t, sym, base, ref):
        """the background scroll's phase: the frame of the mouth's first step"""
        put = lambda a, vals: t.call('write_memory', {
            'addr': '%04X' % a, 'bytes': ['%02X' % v for v in vals]})
        gc0, x0 = ref[0]['gc'], None
        for s_ in ref[1:]:
            if s_['mouth']:
                x = s_['mouth']['x']
                if x0 is not None and x != x0:
                    put(base + sym['bydo.sacc'], [0x00 if (s_['gc'] - gc0) % 2 == 0 else 0x80])
                    return
                x0 = x

    def tick(self, t, sym, base, refs, g, gc0):
        pass

    def settle(self, t, sym, base, refs, g, live, stats):
        """records born in frame g: the arcade's leftovers (the wins' position
        fractions, image byte and chase counter, the mouth's +0x20). A birth
        is told by the record's state: not moved yet"""
        a = refs.get(g)
        if a is None or live.get('g') == g:
            return
        live['g'] = g
        put = lambda ad, vals: t.call('write_memory', {
            'addr': '%04X' % ad, 'bytes': ['%02X' % v for v in vals]})
        sz, cnt = sym['W.SZ'], sym['bydo.NWIN']
        r0 = base + sym['bydo.Wins']
        m = list(t.read('%04X' % r0, cnt * sz))
        for i in range(cnt):
            r = i * sz
            f = lambda k, n=1: int.from_bytes(bytes(m[r + sym[k]:r + sym[k] + n]), 'big')
            s12 = f('W.s12', 2)
            if (f('W.st') != 1 or s12 not in self.SCRIPTS or f('W.x', 2) != self.SCRIPTS[s12]
                    or f('W.c20') or live.get(('w', i, s12))):
                continue
            for tw in a['wins']:
                if tw[3] == s12 and tw[4] == f('W.s14', 2) and tw[1] >> 8 == f('W.x', 2):
                    put(r0 + r + sym['W.x'], [tw[1] >> 16, (tw[1] >> 8) & 0xFF, tw[1] & 0xFF])
                    put(r0 + r + sym['W.y'], [tw[2] >> 16, (tw[2] >> 8) & 0xFF, tw[2] & 0xFF])
                    put(r0 + r + sym['W.s16'], [tw[5]])
                    put(r0 + r + sym['W.c22'], [tw[8] >> 8, tw[8] & 0xFF])
                    live[('w', i, s12)] = True
                    break
        if a['mouth'] and not live.get('mouth'):
            mm = t.read('%04X' % (base + sym['bydo.mst']), 5)
            if mm[0] == 1 and (mm[1] << 8 | mm[2]) == 0x2C4 and mm[3] == 0 and mm[4] == 0:
                live['mouth'] = True
                c = a['mouth']['c20']
                put(base + sym['bydo.mc20'], [c >> 8, c & 0xFF])


class Ending:
    """The end of the game (stage 8): the credits director, the fleet of R-9
    and the text's scroll, from the frame of the core's bg fade (16698, the
    first tick of 40:C275). The port's clock starts there (ending.gc0)."""
    name = 'ending'
    stage = 8
    unit = 'stage8.ending'
    lwmap = 'gen/stages/08/build/ending.lwmap'
    hook = 'ending'
    data = ('ending.Data', 'ending.DataEnd')
    gcsym, rngsym = 'ending.gc', None
    ticks = (0xC275, 'eeb5-efad', 0xFB53)
    budget = 2300
    env = {'PILOT_START': 'c275', 'PILOT_WAIT': '40000', 'PILOT_PEEK': '2ec4,2ec6,2ef0'}
    pin_arcade = (512, 228)
    pin_to8 = None
    scenarios = {'idle': []}
    DIR = {0xEEB5: 1, 0xEF09: 2, 0xEF1E: 3, 0xEF83: 4, 0xEF97: 5}

    def arcade(self, frame, seen):
        pk = frame['pk']
        d, ships = None, []
        for o in frame['o']:
            b = bytes.fromhex(o['r'])
            w = lambda k: b[k] | (b[k + 1] << 8)
            pos = lambda k: ((w(k + 1) << 8) | b[k]) & 0xFFFFFF
            t = o['t']
            if t in self.DIR:
                st = self.DIR[t]
                d = {'st': st}
                if st >= 2:
                    d10 = w(0x10)
                    d.update({'d10': (d10 - 0x88E8) // 2 if st in (2, 3) else d10,
                              'd12': w(0x12), 'd14': w(0x14)})
            elif t == 0xFB53:
                ships.append([pos(3), pos(7), w(0x10), w(0x12)])
        ships.sort()
        return {'gc': frame['gc'], 'd': [], 'dir': d, 'ships': ships,
                'y': ((pk[1] & 1) << 16) | pk[0], 'speed': pk[2],
                'p': {'st': 1 if (d or ships) else 0}}

    def to8(self, sym, mem, base):
        def b(name, off=0):
            return mem[sym[name] - base + off]

        def w(name, off=0):
            return (b(name, off) << 8) | b(name, off + 1)
        dst = b('ending.dst')
        d = None
        if dst and dst <= 5:
            d = {'st': dst}
            if dst >= 2:
                d.update({'d10': w('ending.d10'), 'd12': w('ending.d12'), 'd14': w('ending.d14')})
        # the fleet is precomputed since 17/10/2026 (fleet.unit): no ship
        # state in this page any more. Its flight is checked against this
        # reference OFFLINE, frame by frame (tools/gen_ending.py --check).
        y = (w('ending.y') << 8) | b('ending.yf')
        return {'gc': w('ending.gc'), 'dir': d, 'ships': [], 'y': y,
                'speed': w('ending.speed'), 'p': {'st': dst}}

    def done(self, st):
        return st['p']['st'] == 6

    @staticmethod
    def flat(st):
        return {'dir': st['dir'], 'y': st['y'], 'speed': st['speed']}

    def seed(self, t, sym, base, ref):
        """the creations fall at offsets from the clock's start: g0 too"""
        g = ref[0]['gc']
        t.call('write_memory', {'addr': '%04X' % (base + sym['ending.g0']),
                                'bytes': ['%02X' % (g >> 8), '%02X' % (g & 255)]})

    def tick(self, t, sym, base, refs, g, gc0):
        pass

    def settle(self, t, sym, base, refs, g, live, stats):
        """the fleet's leftover fractions are baked into its precomputed
        records (tools/gen_ending.py reads them from this reference)"""
        pass

PROFILES = {'bellmite': Bellmite(), 'compiler': Compiler(), 'dopswarm': Dopswarm(),
            'bronco': Bronco(), 'bydo': Bydo(),
            'ending': Ending()}


# =============================================================================
# ARCADE — MAME
# =============================================================================
def ref_path(prof, scen='idle'):
    tail = '' if scen == 'idle' else '-' + scen
    return os.path.join(HERE, 'ref', prof.name + tail + '.ref.jsonl.gz')


def record_arcade(prof, snaps=(), scen='idle', gc0=None):
    raw = os.path.join(SCRATCH, 'fidelity-%s-arcade.jsonl' % prof.name)
    # a FRESH cfg directory, under the scratch area: the Invulnerability DIP
    # set from Lua is persisted on exit (pilot/tools/seed_stages.lua)
    cfg = tempfile.mkdtemp(prefix='fidelity-cfg-', dir=SCRATCH)
    os.rmdir(cfg)                       # MAME creates it
    env = dict(os.environ, PILOT_STAGE=str(prof.stage),
               PILOT_TICKS=','.join(t if isinstance(t, str) else '%x' % t for t in prof.ticks),
               PILOT_BUDGET=str(prof.budget),
               PILOT_PLAYER='%d,%d' % prof.pin_arcade, PILOT_OUT=raw,
               PILOT_SNAPS=','.join(str(v) for v in snaps), PILOT_SNAPDIR=SCRATCH,
               PILOT_HITS=';'.join('%d:%d:%d' % ((gc0 + k,) + prof.hit_arcade(tg))
                                   for k, tg in prof.scenarios[scen]),
               **getattr(prof, 'env', {}))
    lua = os.path.join(MAME_FORK, 'pilot', 'tools', 'trace_actors.lua')
    r = subprocess.run([MAME_BIN, 'rtype', '-video', 'none', '-sound', 'none',
                    '-nothrottle', '-noplugins', '-cfg_directory', cfg,
                    '-autoboot_script', lua], cwd=MAME_FORK, env=env, check=True,
                   capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith('[trace]'):
            print(line)
    frames = []
    for line in open(raw):
        f = json.loads(line)
        # A SLOWDOWN: one game frame spread over several video frames. The
        # first snapshot can catch it half played (lived on Bronco's creation
        # frame): the game frame's state is the LAST snapshot of its counter,
        # and its draws are those of every snapshot
        if frames and f['gc'] == frames[-1]['gc']:
            f['rc'] = frames[-1].get('rc', []) + f.get('rc', [])
            frames[-1] = f
        else:
            frames.append(f)
    if hasattr(prof, 'reset'):
        prof.reset()
    out, seen = [], False
    for f in frames:
        st = prof.arcade(f, seen)
        seen = seen or st['p']['st'] != 0
        out.append(st)
    return out


def write_ref(prof, states, scen='idle'):
    text = ''.join(json.dumps(s, sort_keys=True, separators=(',', ':')) + '\n'
                   for s in states)
    with gzip.GzipFile(ref_path(prof, scen), 'wb', mtime=0) as g:
        g.write(text.encode())
    return text


def read_states(path):
    op = gzip.open if path.endswith('.gz') else open
    with op(path, 'rt') as f:
        return [json.loads(l) for l in f]


def cmd_arcade(prof, check, shots=(), scen='idle'):
    # the spawn's counter: the idle reference's first frame (the state load
    # makes it the same in every run)
    gc0 = read_states(ref_path(prof))[0]['gc'] if (shots or scen != 'idle') else 0
    states = record_arcade(prof, [gc0 + k for k in shots], scen, gc0)
    if shots:
        for k in shots:
            src = os.path.join(SCRATCH, 'gc%d.png' % (gc0 + k))
            if os.path.exists(src):
                os.replace(src, os.path.join(SCRATCH, 'arcade_k%d.png' % k))
        return 0
    path = ref_path(prof, scen)
    if check:
        cur = read_states(path) if os.path.exists(path) else []
        if cur != states:
            print('%s : PERIMEE — relancer sans --check' % path)
            return 1
        print('%s : a jour (%d trames)' % (path, len(states)))
        return 0
    write_ref(prof, states, scen)
    print('%s : %d trames de jeu' % (path, len(states)))
    return 0


# =============================================================================
# TO8 — toje
# =============================================================================
def lwmap(path):
    sym = {}
    for line in open(os.path.join(GAME, path)):
        m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-Fa-f]+)$', line.strip())
        if m:
            sym[m.group(1)] = int(m.group(2), 16)
    return sym


def unit_place(image, name):
    h = open(os.path.join(os.path.dirname(image), 'occupancy-fd.html')).read()
    data = json.loads(re.search(r'const DATA\s*=\s*(\{.*?\});', h, re.S).group(1))
    for sc in data['ram']['scenes']:
        for l in sc['loads']:
            if l['name'] == name:
                return l['page'], l['address']
    raise SystemExit('%s introuvable dans le rapport d\'occupation' % name)


def run_to(t, slices, n=5000000):
    """run_to_breakpoint by slices of n instructions (toje stops at its
    instruction budget, not on a delay); True on a hit"""
    for _ in range(slices):
        r = t.call('run_to_breakpoint', {'max_instructions': n})
        if r.get('hit'):
            return r
    return None


def cmd_to8(prof, image, out, shots=(), scen='idle'):
    from mcp import Toje
    image = os.path.abspath(image)
    psym = lwmap(prof.lwmap)
    page, base = unit_place(image, prof.unit)
    esym = lwmap('gen/common/build/engine.lwmap')
    tsym = {}
    for root, _, files in os.walk(os.path.join(GAME, 'gen')):
        for f in files:
            if f.endswith('.lwmap'):
                m = lwmap(os.path.relpath(os.path.join(root, f), GAME))
                for k in ('tct.pstage', 'tct.pinv', 'title.cheat.launch'):
                    if k in m and 'cheat' in f:
                        tsym[k] = m[k]
    cpage, cbase = unit_place(image, 'title.cheat')
    hook = getattr(prof, 'hook', prof.name)
    dlo, dhi = getattr(prof, 'data', ('bm.Data', 'bm.DataEnd'))
    gcsym = getattr(prof, 'gcsym', 'bm.gc')
    rngsym = getattr(prof, 'rngsym', 'bm.rng')
    seeded = base + psym[hook + '.Seeded']
    sample = base + psym[hook + '.Sample']
    tick = base + psym[hook + '.Tick']
    data_lo = base + psym[dlo]
    data_hi = base + psym[dhi]
    player = esym['player1']
    xpos, ypos = esym['x_pos'], esym['y_pos']
    cam = esym['glb_camera_x_pos']
    ref = read_states(ref_path(prof, scen))
    refs = {s['gc']: s for s in ref}
    gc0 = ref[0]['gc']
    rng0 = ref[0].get('rng', [5, 1, 3])
    # the scenario's hits, at a game frame: stop at <boss>.Tick of that frame
    hits = sorted((gc0 + k, tg) for k, tg in prof.scenarios[scen])
    boxes = None
    if hits and getattr(prof, 'stage_boxes', False):
        ssym = lwmap('gen/stages/%02d/build/stage%02d-main.lwmap' % (prof.stage, prof.stage))
        _, sbase = unit_place(image, 'stage%d' % prof.stage)
        boxes = sbase + ssym[hook + '.boxes']
    # REPLAYED DRAWS (a profile with `draws`): the AX each family caller got
    # on the arcade, frame by frame, written in D at <boss>.Drawn
    replay = hasattr(prof, 'draws')
    drawn = base + psym[hook + '.Drawn'] if replay else None
    owed = {s['gc']: list(s['d']) for s in ref if s.get('d')}
    every_tick = hasattr(prof, 'tick')
    tick_bp = None
    diag = {'draw.extra': 0, 'draw.missing': 0}
    drawlog = []
    last_draw = []

    t = Toje()
    t.boot_floppy(image)
    t.call('run_frames', {'n': 1200})
    # the title cheat, set by hand (tools/goto_stage.py)
    t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + cpage)]})
    via = getattr(prof, 'via', prof.stage)
    t.call('write_memory', {'addr': '%04X' % (cbase + tsym['tct.pstage']),
                            'bytes': ['%02X' % via]})
    t.call('write_memory', {'addr': '%04X' % (cbase + tsym['tct.pinv']), 'bytes': ['01']})
    # A CLEAN MAIN THREAD. run_frames stops anywhere, IRQ handler included :
    # a PC hijacked there leaves the main thread on Irq_sys_stack, the next
    # interrupt then writes over its frames (lived 16/10/2026 : DKCONT
    # returned to $0005 during the stage load). System stack, DP, IRQ masked.
    t.call('set_register', {'reg': 's', 'value': '%04X' % esym['glb_system_stack']})
    t.call('set_register', {'reg': 'cc', 'value': 'D0'})
    t.call('set_register', {'reg': 'dp', 'value': '9F'})
    t.call('set_register', {'reg': 'pc', 'value': '%04X' % (cbase + tsym['title.cheat.launch'])})
    t.call('step')
    if via != prof.stage:
        # the normal hand-over of the stage before, at the top of its loop
        msym = lwmap('gen/stages/%02d/build/stage%02d-main.lwmap' % (via, via))
        _, mbase = unit_place(image, 'stage%d' % via)
        b = t.call('set_breakpoint', {'pc': '$%04X' % (mbase + msym['stage.loop'])})
        if not run_to(t, 400):
            raise SystemExit('le stage %d ne tourne jamais' % via)
        t.call('clear_breakpoint', {'id': b['id']})
        t.call('set_register', {'reg': 'dp', 'value': '9F'})
        t.call('set_register', {'reg': 'pc', 'value': '%04X' % (mbase + msym['stage.handOver'])})
        t.call('step')                  # toje: step after a stop, before running
        print('stage %d atteint, passation vers le stage %d' % (via, prof.stage), flush=True)

    def pin():
        # a profile without a pinned point leaves the ship alone (the
        # ending: the autopilot parks it, and a pinned ship never arrives)
        if prof.pin_to8 is None:
            return
        c = t.read('%04X' % cam, 2)
        x = ((c[0] << 8) | c[1]) + prof.pin_to8[0]
        t.call('write_memory', {'addr': '%04X' % (player + xpos),
                                'bytes': ['%02X' % (x >> 8), '%02X' % (x & 255)]})
        t.call('write_memory', {'addr': '%04X' % (player + ypos),
                                'bytes': ['00', '%02X' % prof.pin_to8[1]]})

    def put(a, vals):
        t.call('write_memory', {'addr': '%04X' % a, 'bytes': ['%02X' % v for v in vals]})

    def gc_now():
        g = t.read('%04X' % (base + psym[gcsym]), 2)
        return (g[0] << 8) | g[1]

    def replay_draw(g):
        # an IRQ taken ON the hook's rts returns to it: the same draw hits
        # twice. Every real draw steps the port's generator: a hit with the
        # same stack, return address and generator state as the previous one
        # is that re-hit
        regs = t.call('read_registers')
        sp = int(regs['s'], 16)
        ret = t.read('%04X' % sp, 2)
        ret = (ret[0] << 8) | ret[1]
        key = (sp, ret, tuple(t.read('%04X' % (base + psym[rngsym]), 3)))
        if last_draw and last_draw[0] == key:
            diag['draw.rehit'] = diag.get('draw.rehit', 0) + 1
            return
        q = owed.get(g)
        if not q:
            diag['draw.extra'] += 1
            drawlog.append((g - gc0, None, ret))
            return
        caller, ax = q.pop(0)
        drawlog.append((g - gc0, caller, ret))
        t.call('set_register', {'reg': 'd', 'value': '%04X' % ax})
        last_draw[:] = [key]

    print('stage %d : attente du spawn' % prof.stage, flush=True)
    t0 = time.time()
    bp = t.call('set_breakpoint', {'pc': '$%04X' % seeded, 'page': page})['id']
    dbp = t.call('set_breakpoint', {'pc': '$%04X' % drawn, 'page': page})['id'] if replay else None
    while True:
        r = run_to(t, 400)
        if not r:
            raise SystemExit('le spawn n\'est jamais venu')
        if replay and int(r['hit_pc'], 16) == drawn:
            # the creation draw, before the clock is set: frame gc0's own
            # draw, with the player where the arcade pins it
            replay_draw(gc0)
            if 'cpl.plx' in psym:
                put(base + psym['cpl.plx'], [prof.pin_arcade[0] >> 8, prof.pin_arcade[0] & 255])
                put(base + psym['cpl.ply'], [prof.pin_arcade[1] >> 8, prof.pin_arcade[1] & 255])
            continue
        break
    print('spawn en %.0f s' % (time.time() - t0), flush=True)
    # the arcade clock and random state at the creation frame
    put(base + psym[gcsym], [gc0 >> 8, gc0 & 255])
    if rngsym:
        put(base + psym[rngsym], rng0)
    if hasattr(prof, 'seed'):
        prof.seed(t, psym, base, ref)
    pin()
    t.call('clear_breakpoint', {'id': bp})
    if hasattr(prof, 'inject'):
        # the leftovers of the recycled arcade records: position fractions
        spawned = base + psym[hook + '.Spawned']
        bp = t.call('set_breakpoint', {'pc': '$%04X' % spawned, 'page': page})['id']
        if not run_to(t, 4):
            raise SystemExit('les records ne naissent pas')
        prof.inject(t, psym, base, ref)
        t.call('clear_breakpoint', {'id': bp})
    t.call('set_breakpoint', {'pc': '$%04X' % sample, 'page': page})
    if every_tick:
        tick_bp = t.call('set_breakpoint', {'pc': '$%04X' % tick, 'page': page})['id']
    n = 0
    want = sorted(gc0 + k for k in shots)
    shoot = None
    last_gc = gc0
    live_rolls = {}
    with open(out, 'w') as f:
        while True:
            if hits and tick_bp is None and hits[0][0] <= last_gc + 16:
                tick_bp = t.call('set_breakpoint', {'pc': '$%04X' % tick, 'page': page})['id']
            r = run_to(t, 4)
            if not r:
                print('plus de rendu du boss')
                break
            pc = int(r['hit_pc'], 16)
            if replay and pc == drawn:
                replay_draw(gc_now())
                continue
            if pc == tick:
                g = gc_now()
                if replay and owed.get(g - 1):
                    diag['draw.missing'] += len(owed[g - 1])
                    owed[g - 1] = []
                while hits and hits[0][0] <= g:
                    if hits[0][0] == g:
                        prof.hit_to8(t, psym, base, hits[0][1], boxes)
                    hits.pop(0)
                if every_tick:
                    if hasattr(prof, 'settle'):
                        prof.settle(t, psym, base, refs, g - 1, live_rolls, diag)
                    prof.tick(t, psym, base, refs, g, gc0)
                elif not hits or hits[0][0] > g + 16:
                    t.call('clear_breakpoint', {'id': tick_bp})
                    tick_bp = None
                continue
            if hasattr(prof, 'settle'):
                prof.settle(t, psym, base, refs, gc_now(), live_rolls, diag)
            mem = t.read('%04X' % data_lo, data_hi - data_lo)
            st = prof.to8(psym, mem, psym[dlo])
            last_gc = st['gc']
            f.write(json.dumps(st, sort_keys=True, separators=(',', ':')) + '\n')
            n += 1
            if shoot is not None:
                # the render that FOLLOWS the target : its picture is on screen
                t.call('screenshot', {'path': os.path.join(SCRATCH, 'to8_k%d.png' % shoot)})
                shoot = None
            if want and st['gc'] >= want[0]:
                shoot = want.pop(0) - gc0
            pin()
            if n % 50 == 0:
                print('rendu %d gc=%d etat=%d' % (n, st['gc'], st['p']['st']), flush=True)
            if hasattr(prof, 'done'):
                if prof.done(st) or st['gc'] > ref[-1]['gc']:
                    break
            elif st['p']['st'] == 5 and not st['s'] and not st['h']:
                break
    if replay:
        print('tirages rejoues : %d en trop, %d manquants, %d arrets doubles (IRQ sur le crochet)'
              % (diag['draw.extra'], diag['draw.missing'], diag.get('draw.rehit', 0)))
    if replay:
        with open(out + '.draws', 'w') as f:
            for e in drawlog:
                f.write(repr(e) + '\n')
    if 'roll.terrain' in diag:
        print('entrees : %d segments roulants tues par le decor de la borne' % diag['roll.terrain'])
    print('%d rendus -> %s' % (n, out))
    t.close()
    return 0


# =============================================================================
# COMPARE
# =============================================================================
def cmd_compare(prof, to8_path, scen='idle'):
    ref = {s['gc']: s for s in read_states(ref_path(prof, scen))}
    obs = read_states(to8_path)
    first, count, checked = {}, {}, 0

    def diff(tag, a, b, gc):
        nonlocal checked
        for k in sorted(set(a) | set(b)):
            checked += 1
            if a.get(k) != b.get(k):
                key = tag + '.' + k if tag else k
                count[key] = count.get(key, 0) + 1
                first.setdefault(key, (gc, a.get(k), b.get(k)))
    renders, blinded = 0, 0
    gc_first = min(ref)
    for o in obs:
        a = ref.get(o['gc'])
        if a is None:
            continue
        if 0 < o['gc'] - gc_first <= getattr(prof, 'blind', 0):
            blinded += 1                # a state the bench completes later
            continue
        renders += 1
        if hasattr(prof, 'flat'):
            diff('', prof.flat(a), prof.flat(o), o['gc'])
            continue
        diff('rng', {'v': a['rng']}, {'v': o['rng']}, o['gc'])
        diff('parent', a['p'], o['p'], o['gc'])
        for sid in sorted(set(a['s']) | set(o['s']), key=int):
            sa, so = a['s'].get(sid, {'st': 0}), o['s'].get(sid, {'st': 0})
            diff('sat', sa, so, o['gc'])
        diff('helper', {'h': a['h']}, {'h': o['h']}, o['gc'])
    gc0 = min(ref)
    print('%s : %d rendus TO8 compares a la borne, %d valeurs'
          % (prof.name, renders, checked)
          + (' (%d rendu aveugle ecarte, trame gc0+1)' % blinded if blinded else ''))
    if not renders:
        print('AUCUN rendu compare — la trace TO8 est vide ou hors horloge')
        return 2
    if not count:
        print('IDENTIQUE — aucune divergence')
        return 0
    print('%-16s %8s %8s  %s' % ('champ', 'ecarts', 'trame', 'premier ecart (borne / TO8)'))
    for k in sorted(first, key=lambda k: first[k][0]):
        gc, va, vb = first[k]
        print('%-16s %8d %8d  %s / %s' % (k, count[k], gc - gc0, va, vb))
    return 1


def main():
    if len(sys.argv) < 3 or sys.argv[2] not in PROFILES:
        print(__doc__)
        return 2
    cmd, prof = sys.argv[1], PROFILES[sys.argv[2]]
    rest = sys.argv[3:]
    default_to8 = os.path.join(SCRATCH, 'fidelity-%s-to8.jsonl' % prof.name)
    scen = rest[rest.index('--scenario') + 1] if '--scenario' in rest else 'idle'
    if scen != 'idle':
        default_to8 = os.path.join(SCRATCH, 'fidelity-%s-%s-to8.jsonl' % (prof.name, scen))
    if cmd == 'arcade':
        shots = [int(v) for v in rest[rest.index('--shots') + 1].split(',')] \
            if '--shots' in rest else ()
        return cmd_arcade(prof, '--check' in rest, shots, scen)
    if cmd == 'to8':
        out = rest[rest.index('--out') + 1] if '--out' in rest else default_to8
        shots = [int(v) for v in rest[rest.index('--shots') + 1].split(',')] \
            if '--shots' in rest else ()
        return cmd_to8(prof, rest[0], out, shots, scen)
    if cmd == 'compare':
        p = rest[rest.index('--to8') + 1] if '--to8' in rest else default_to8
        return cmd_compare(prof, p, scen)
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main())
