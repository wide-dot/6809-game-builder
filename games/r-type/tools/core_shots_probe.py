#!/usr/bin/env python3
"""Trois captures du noyau du stage 3 — au repos, en glissade, ouvert — pour
mesurer ou tombe le bord de coque par rapport a ses colonnes (11/09/2026).

    python3 tools/core_shots_probe.py      (depuis games/r-type ; ecrit
                                            core_repos/glisse/ouvert.png a cote)

Boote, seme le stage 3 par le cheat (le prelude de warship_video.py), attend
le noyau (find_core), capture a la routine 1, 2 et 4. Le decodage : echantillon
(32 + 4x + 1, 112 + 2y) de la capture 704x624 = le pixel de jeu (x, y) ; on
aligne les rangees de la pose (colonne la plus a gauche par rangee) et on lit
la premiere colonne de couleur coque. Resultat : doc/etude-noyau-sans-cache § 6.
"""
import os, re, sys
os.environ['TOJE_FAST'] = '1'; sys.path.insert(0, os.path.abspath('../../ci/toje-bench'))
src = open('tools/warship_video.py').read().split('out = os.path.abspath(')[0]
exec(src)
SP = os.path.dirname(os.path.abspath(__file__))
t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try: t.call(what, {'id': i})
        except Exception: pass
t.boot_floppy(os.path.abspath('dist/to8.fd'))
t.call('run_frames', {'n': 1200})
page, addr = cheat_state_addr()
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch')
pstage = equ('gen/title/build/cheat.lwmap', 'tct.pstage')
base = addr - pstage
t.call('set_breakpoint', {'pc': '%04X' % WAIT})
t.call('run_to_breakpoint', {'timeout_ms': 120000})
t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(addr), 'bytes': ['03', '01']})
t.call('set_register', {'reg': 'dp', 'value': '9F'})
t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)})
t.call('step')
for _ in range(60):
    t.call('run_frames', {'n': 250, 'timeout_ms': 600000})
    if t.read(hex(BSTAGE), 1)[0] == 3: break
print('stage 3', flush=True)
def xpix(c): return t.read('%04X' % (c[0] + 38 + 3), 2)   # core.AABB cx, cy
shots = {}
for it in range(400):
    c = find_core(t)
    if c is not None:
        rt = c[1]; xy = xpix(c)
        if rt == 1 and 'repos' not in shots and 30 < xy[0] < 130:
            t.call('run_frames', {'n': 3, 'timeout_ms': 600000, 'fast': False})
            p = os.path.join(SP, 'core_repos.png'); t.call('screenshot', {'path': p}); shots['repos'] = (p, xpix(find_core(t)))
            print('repos capture, x_pixel', shots['repos'][1], flush=True)
        if rt == 4 and 'ouvert' not in shots:
            t.call('run_frames', {'n': 3, 'timeout_ms': 600000, 'fast': False})
            p = os.path.join(SP, 'core_ouvert.png'); t.call('screenshot', {'path': p}); shots['ouvert'] = (p, xpix(find_core(t)))
            print('ouvert capture, x_pixel', shots['ouvert'][1], flush=True)
            break
        if rt == 2 and 'glisse' not in shots and 'repos' in shots:
            p = os.path.join(SP, 'core_glisse.png'); t.call('screenshot', {'path': p}); shots['glisse'] = (p, xpix(c))
            print('glisse capture, x_pixel', shots['glisse'][1], flush=True)
    t.call('run_frames', {'n': 40, 'timeout_ms': 600000})
print(shots)
t.close()
