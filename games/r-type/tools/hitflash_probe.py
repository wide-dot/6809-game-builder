#!/usr/bin/env python3
"""Le flash de coup sous toje (11-12/09/2026) : stage 3 en invincible, le vaisseau
pousse a gauche devant la coque, le bouton de tir alterne ; la machine avance
BOUCLE DE JEU PAR BOUCLE (run_until_pc sur gfxlock.bufferSwap.wait, la fin
du rendu) et a chaque boucle on cherche dans le pool l'objet explosion de
sous-type $80 en routine 1 — son Init a tourne dans CETTE boucle, son sprite
est dans le tampon que toje rend. On capture, et on compte les pixels blancs
dans la fenetre de sa boite. Attendu : des dizaines (l'ellipse), pas zero.

    python3 tools/hitflash_probe.py     (depuis games/r-type)
"""
import os, re, sys, collections
os.environ['TOJE_FAST'] = '1'; sys.path.insert(0, os.path.abspath('../../ci/toje-bench'))
src = open('tools/warship_video.py').read().split('out = os.path.abspath(')[0]
exec(src)
SP = os.environ.get('OUT', '/tmp')   # ou vont les captures
def lwmap_sym(path, name):
    for l in open(path):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m: return int(m.group(1), 16)
    raise SystemExit(name)
BULLETS = lwmap_sym('gen/common/build/engine.lwmap', 'objects.bullets.address') if 'objects.bullets.address' in open('gen/common/build/engine.lwmap').read() else None
if BULLETS is None:
    import glob
    for f in glob.glob('gen/**/*.lwmap', recursive=True):
        if 'objects.bullets.address' in open(f).read(): BULLETS = lwmap_sym(f, 'objects.bullets.address'); break
ID_WEAPON = 5   # ObjID_Weapon
print('bullets @%04X' % BULLETS, flush=True)
t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try: t.call(what, {'id': i})
        except Exception: pass
t.boot_floppy(os.path.abspath('dist/to8.fd'))
t.call('set_pointer_device', {'device': 'none'})   # la souris occupe la manette 0
t.call('run_frames', {'n': 1200})

page, addr = cheat_state_addr()
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch'); pstage = equ('gen/title/build/cheat.lwmap', 'tct.pstage'); base = addr - pstage
t.call('set_breakpoint', {'pc': '%04X' % WAIT}); t.call('run_to_breakpoint', {'timeout_ms': 120000}); t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(addr), 'bytes': ['03', '01']})
t.call('set_register', {'reg': 'dp', 'value': '9F'}); t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)}); t.call('step')
for _ in range(60):
    t.call('run_frames', {'n': 250, 'timeout_ms': 600000})
    if t.read(hex(BSTAGE), 1)[0] == 3: break
print('stage 3', flush=True)
def bullets():
    raw = t.read('%04X' % BULLETS, 24 * 21)
    out = []
    for i in range(24):
        s = raw[i * 21:(i + 1) * 21]
        if s[9]:
            y = (s[14] << 8) | s[15]; y = y - 65536 if y > 32767 else y
            out.append(y)
    return out
def pool():
    raw = []
    for off in range(0, NOBJ * OSZ, 256): raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    return [raw[i * OSZ:(i + 1) * OSZ] for i in range(NOBJ)]


GCOUNT = ENGINE_BASE + equ('gen/common/build/engine.lwmap', 'gfxlock.frame.gameCount')
def until(pc):
    # WAIT est l'ENTREE de gfxlock.bufferSwap.wait (un clr, puis la boucle
    # d'attente) : elle ne s'execute qu'une fois par boucle de jeu. Un step la
    # franchit, run_until_pc revient a la fin de la boucle suivante.
    t.call('step'); t.call('run_until_pc', {'pc': '%04X' % pc, 'max_instructions': 600000})
for k in range(60):
    t.call('run_frames', {'n': 50, 'timeout_ms': 600000})
t.call('press_joystick', {'joystick': 0, 'direction': 'left', 'hold_frames': 60})
t.call('press_joystick', {'joystick': 0, 'button_a': True, 'hold_frames': 3})   # la chauffe
t.call('run_frames', {'n': 30, 'timeout_ms': 600000})
found = []
from PIL import Image
# LES POSES BLANCHES DE REMPLACEMENT (12/09/2026) : reacteurs de ventre et
# multi par image_set dans leurs jeux _hit ; pieces wsmgr par la liste
# blanche dans un slot du manager (wsmgr.Slots : page, liste, x, y, page).
def syms(mapfile, pat):
    out = {}
    for l in open(mapfile):
        m = re.match(r'Symbol: (%s) \(.*\) = ([0-9A-Fa-f]+)' % pat, l)
        if m: out[int(m.group(2), 16)] = m.group(1)
    return out
import glob
WHITE_SETS = {}
for f in glob.glob('gen/enemies/build/stage3-cast-img*.lwmap'):
    WHITE_SETS.update(syms(f, r'set_\w+_hit_\d+'))
WHITE_LISTS = syms('gen/stages/03/build/stage03-cast.lwmap', r'react\.sl\.\w+_hit\.0')
_, WSM = unit_base('stage3.wsmgr.res')
WSLOTS = WSM + equ('gen/stages/03/build/wsmgr-res.lwmap', 'wsmgr.Slots')
WCOUNT = WSM + equ('gen/stages/03/build/wsmgr-res.lwmap', 'wsmgr.count')
print('%d jeux blancs, %d listes blanches' % (len(WHITE_SETS), len(WHITE_LISTS)), flush=True)
whites = []
def shot(tag, x, y):
    p = os.path.join(SP, 'hitflash_%s_%d.png' % (tag, len(whites) + 1)); t.call('screenshot', {'path': p})
    im = Image.open(p).convert('RGB'); px = im.load()
    n = sum(1 for yy in range(y - 12, y + 12) for xx in range(x - 12, x + 12) if 0 <= xx < 160 and 0 <= yy < 200 and px[32 + 4 * xx + 1, 112 + 2 * yy] == (251, 251, 247))
    im.crop((32 + 4 * (x - 24), 112 + 2 * (y - 24), 32 + 4 * (x + 24), 112 + 2 * (y + 24))).resize((384, 384), Image.NEAREST).save(os.path.join(SP, 'hitflash_%s_zoom_%d.png' % (tag, len(whites) + 1)))
    return p, n
for loop in range(900):
    t.call('set_joystick', {'joystick': 0, 'button_a': (loop // 3) % 2 == 0,      # un appui toutes les six boucles
                            'direction': ['center', 'up', 'center', 'down'][(loop // 120) % 4]})   # et un balayage vertical
    until(WAIT)
    for i, o in enumerate(pool()):
        if o[0] and ((o[16] << 8) | o[17]) in WHITE_SETS and len(whites) < 6:
            x, y = o[38 + 3], o[38 + 4]          # la boite (ext+0), en coordonnees ecran :
                                                 # x/y_pixel n'est pas encore pose (coordonnees de terrain)
            p, n = shot('sprite', x, y); whites.append(('sprite', WHITE_SETS[(o[16] << 8) | o[17]], n))
            print('pose blanche %s (objet id %d) a l ecran (%d,%d) : %d px blancs dans 24x24 -> %s' % (WHITE_SETS[(o[16] << 8) | o[17]], o[0], x, y, n, p), flush=True)
    cnt = 24                              # le compte est consomme par le dessin : on lit tous les slots
    if cnt:
        raw = t.read('%04X' % WSLOTS, 6 * cnt)
        for k in range(cnt):
            sl = raw[6 * k:6 * k + 6]; lst = (sl[1] << 8) | sl[2]
            if lst in WHITE_LISTS and len(whites) < 6:
                x, y = sl[3] - 48, sl[4] - 28
                p, n = shot('wsmgr', x, y); whites.append(('wsmgr', WHITE_LISTS[lst], n))
                print('liste blanche %s a l ecran (%d,%d) : %d px blancs dans 24x24 -> %s' % (WHITE_LISTS[lst], x, y, n, p), flush=True)
    for i, o in enumerate(pool()):
        if o[0] == 2 and (o[1] & 0x80) and o[34] == 1:
            box = (o[38] << 8) | o[39]; b = t.read('%04X' % box, 5); xy = (o[24], o[25])
            p = os.path.join(SP, 'hitflash_%d.png' % (len(found) + 1)); t.call('screenshot', {'path': p})
            im = Image.open(p).convert('RGB'); px = im.load()
            x, y = xy[0] - 48, xy[1] - 28
            nw = sum(1 for yy in range(y - 8, y + 8) for xx in range(x - 6, x + 6) if 0 <= xx < 160 and 0 <= yy < 200 and px[32 + 4 * xx + 1, 112 + 2 * yy] == (251, 251, 247))
            found.append((loop, xy, tuple(b), nw))
            print('flash %d : boucle %d, ecran (%d,%d), boite p=%d rx=%d ry=%d cx=%d cy=%d, %d px blancs dans 12x16 -> %s' % (len(found), loop, x, y, b[0], b[1], b[2], b[3], b[4], nw, p), flush=True)
            im.crop((32 + 4 * (x - 20), 112 + 2 * (y - 20), 32 + 4 * (x + 20), 112 + 2 * (y + 20))).resize((320, 320), Image.NEAREST).save(os.path.join(SP, 'hitflash_zoom_%d.png' % len(found)))
    if len(found) >= 3 and len(whites) >= 6: break
print('flashs du manager :', len(found), '; poses blanches :', whites)
t.close()
