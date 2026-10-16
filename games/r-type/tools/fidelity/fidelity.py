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

Usage (depuis games/r-type/) :
  python3 tools/fidelity/fidelity.py arcade bellmite          # MAME -> ref
  python3 tools/fidelity/fidelity.py arcade bellmite --check  # ref a jour ?
  python3 tools/fidelity/fidelity.py to8 bellmite dist/to8.fd [--out f]
  python3 tools/fidelity/fidelity.py compare bellmite [--to8 f]

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


PROFILES = {'bellmite': Bellmite()}


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
               PILOT_TICKS=','.join('%x' % t for t in prof.ticks),
               PILOT_BUDGET=str(prof.budget),
               PILOT_PLAYER='%d,%d' % prof.pin_arcade, PILOT_OUT=raw,
               PILOT_SNAPS=','.join(str(v) for v in snaps), PILOT_SNAPDIR=SCRATCH,
               PILOT_HITS=';'.join('%d:%d:%d' % ((gc0 + k,) + prof.hit_arcade(tg))
                                   for k, tg in prof.scenarios[scen]))
    lua = os.path.join(MAME_FORK, 'pilot', 'tools', 'trace_actors.lua')
    r = subprocess.run([MAME_BIN, 'rtype', '-video', 'none', '-sound', 'none',
                    '-nothrottle', '-noplugins', '-cfg_directory', cfg,
                    '-autoboot_script', lua], cwd=MAME_FORK, env=env, check=True,
                   capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith('[trace]'):
            print(line)
    frames = [json.loads(l) for l in open(raw)]
    out, seen, last_gc = [], False, None
    for f in frames:
        if f['gc'] == last_gc:              # a slowdown frame: nothing ran
            continue
        last_gc = f['gc']
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
    seeded = base + psym['bellmite.Seeded']
    sample = base + psym['bellmite.Sample']
    data_lo = base + psym['bm.Data']
    data_hi = base + psym['bm.DataEnd']
    player = esym['player1']
    xpos, ypos = esym['x_pos'], esym['y_pos']
    cam = esym['glb_camera_x_pos']
    ref = read_states(ref_path(prof))
    gc0, rng0 = ref[0]['gc'], ref[0]['rng']
    # the scenario's hits, at a game frame: stop at <boss>.Tick of that frame
    ssym = lwmap('gen/stages/%02d/build/stage%02d-main.lwmap' % (prof.stage, prof.stage))
    _, sbase = unit_place(image, 'stage%d' % prof.stage)
    boxes = sbase + ssym['bellmite.boxes']
    tick = base + psym['bellmite.Tick']
    hits = sorted((gc0 + k, tg) for k, tg in prof.scenarios[scen])
    tick_bp = None

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
    print('stage %d : attente du spawn' % prof.stage, flush=True)
    t0 = time.time()
    bp = t.call('set_breakpoint', {'pc': '$%04X' % seeded, 'page': page})['id']
    if not run_to(t, 400):
        raise SystemExit('le spawn n\'est jamais venu')
    print('spawn en %.0f s' % (time.time() - t0), flush=True)
    # the arcade clock and random state at the creation frame
    t.call('write_memory', {'addr': '%04X' % (base + psym['bm.gc']),
                            'bytes': ['%02X' % (gc0 >> 8), '%02X' % (gc0 & 255)]})
    t.call('write_memory', {'addr': '%04X' % (base + psym['bm.rng']),
                            'bytes': ['%02X' % v for v in rng0]})

    def pin():
        c = t.read('%04X' % cam, 2)
        x = ((c[0] << 8) | c[1]) + prof.pin_to8[0]
        t.call('write_memory', {'addr': '%04X' % (player + xpos),
                                'bytes': ['%02X' % (x >> 8), '%02X' % (x & 255)]})
        t.call('write_memory', {'addr': '%04X' % (player + ypos),
                                'bytes': ['00', '%02X' % prof.pin_to8[1]]})
    pin()
    t.call('clear_breakpoint', {'id': bp})
    # the leftovers of the recycled arcade records: position fractions
    spawned = base + psym['bellmite.Spawned']
    bp = t.call('set_breakpoint', {'pc': '$%04X' % spawned, 'page': page})['id']
    if not run_to(t, 4):
        raise SystemExit('les records ne naissent pas')
    prof.inject(t, psym, base, ref)
    t.call('clear_breakpoint', {'id': bp})
    t.call('set_breakpoint', {'pc': '$%04X' % sample, 'page': page})
    n = 0
    want = sorted(gc0 + k for k in shots)
    shoot = None
    last_gc = gc0
    with open(out, 'w') as f:
        while True:
            if hits and tick_bp is None and hits[0][0] <= last_gc + 16:
                tick_bp = t.call('set_breakpoint', {'pc': '$%04X' % tick, 'page': page})['id']
            r = run_to(t, 4)
            if not r:
                print('plus de rendu du boss')
                break
            if int(r['hit_pc'], 16) == tick:
                g = t.read('%04X' % (base + psym['bm.gc']), 2)
                g = (g[0] << 8) | g[1]
                while hits and hits[0][0] <= g:
                    if hits[0][0] == g:
                        prof.hit_to8(t, psym, base, hits[0][1], boxes)
                    hits.pop(0)
                if not hits or hits[0][0] > g + 16:
                    t.call('clear_breakpoint', {'id': tick_bp})
                    tick_bp = None
                continue
            mem = t.read('%04X' % data_lo, data_hi - data_lo)
            st = prof.to8(psym, mem, psym['bm.Data'])
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
                print('rendu %d gc=%d etat=%d sats=%d' % (n, st['gc'], st['p']['st'],
                                                         len(st['s'])), flush=True)
            if st['p']['st'] == 5 and not st['s'] and not st['h']:
                break
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
                key = tag + '.' + k
                count[key] = count.get(key, 0) + 1
                first.setdefault(key, (gc, a.get(k), b.get(k)))
    renders = 0
    for o in obs:
        a = ref.get(o['gc'])
        if a is None:
            continue
        renders += 1
        diff('rng', {'v': a['rng']}, {'v': o['rng']}, o['gc'])
        diff('parent', a['p'], o['p'], o['gc'])
        for sid in sorted(set(a['s']) | set(o['s']), key=int):
            sa, so = a['s'].get(sid, {'st': 0}), o['s'].get(sid, {'st': 0})
            diff('sat', sa, so, o['gc'])
        diff('helper', {'h': a['h']}, {'h': o['h']}, o['gc'])
    gc0 = min(ref)
    print('%s : %d rendus TO8 compares a la borne, %d valeurs'
          % (prof.name, renders, checked))
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
