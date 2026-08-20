#!/usr/bin/env python3
"""Le JOURNAL RUNTIME du pilote warship (stage 3), trame par trame.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/warship_log.py dist/to8.fd [out_dir]

Le build doit porter l'instrumentation (define WARSHIP_LOG_PAGE dans
to8.config.xml, journal dans src/stages/03/warship/pilot.asm) : le pilote
ecrit UN enregistrement de 16 octets PAR TRAME VIDEO depilee, dans un anneau
de 1008 entrees loge en page $16. Cette sonde boote, arme le cheat
(stage 3 + INVINCIBLE), verifie l'invincibilite EN RAM, puis draine l'anneau
regulierement et confronte chaque trame a l'integrale du script arcade lue
dans le ROM.

Lecture de l'anneau : la page du journal n'est montee dans la fenetre
cartouche que le temps des lectures, CPU gele (aucun cycle ne s'ecoule entre
deux appels MCP, donc aucune IRQ ne peut voir la fenetre deplacee), et la
page d'origine — relue par read_page_map — est remise avant toute reprise.
"""
import os, re, sys, json, csv

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

ROM = os.path.expanduser(
    '~/Documents/Claude/Projects/re.arcade.r-type/out/rom/maincpu.bin')
INNER   = 0x16F8A
MAP_H   = 384
LOGPAGE = 0x16
REC     = 16
RING_START, RING_END = 0x0100, 0x4000
NRECS   = (RING_END - RING_START) // REC
MAGIC   = 0x57DB

# --- adresses du build courant -------------------------------------------
def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    if not m:
        raise SystemExit('unite %s absente du rapport d occupation' % name)
    return int(m.group(1)), int(m.group(2))

def sym(mapfile, name, base):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return base + int(m.group(1), 16)
    raise SystemExit('symbole %s absent de %s' % (name, mapfile))

_, MSCROLL_BASE = unit_base('common.mscroll')
_, ENGINE_BASE  = unit_base('common.engine')
CAMX = sym('gen/common/build/mscroll.lwmap', 'mscroll.camera.x', MSCROLL_BASE)
CAMY = sym('gen/common/build/mscroll.lwmap', 'mscroll.camera.y', MSCROLL_BASE)
INV  = sym('gen/common/build/engine.lwmap', 'cheat.invincible', ENGINE_BASE)

def cheat_state_addr():
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
    page, addr = int(m.group(1)), int(m.group(2))
    for l in open('gen/title/build/cheat.lwmap'):
        m2 = re.match(r'Symbol: tct\.pstage \(.*\) = ([0-9A-Fa-f]+)', l)
        if m2:
            return page, addr + int(m2.group(1), 16)
    raise SystemExit('tct.pstage absent de cheat.lwmap')

# --- le script arcade, segment par segment --------------------------------
rom = open(ROM, 'rb').read()
def s8(b): return b - 256 if b >= 128 else b
segs, off = [], INNER
while rom[off + 2] != 0x80:
    segs.append((s8(rom[off + 1]) * 6, s8(rom[off]) * 12, rom[off + 2]))
    off += 3
# l'etat attendu du pilote a la n-ieme trame vive (n = 1 pour la premiere) :
# (index d'entree, sx, sy, counter apres decompte)
EXPECT = []
for i, (sx, sy, fr) in enumerate(segs):
    for k in range(fr):
        EXPECT.append((i, sx, sy, fr - k))

# --- la machine ----------------------------------------------------------
out = sys.argv[2] if len(sys.argv) > 2 else 'dist/warship-log'
os.makedirs(out, exist_ok=True)
t = Toje()
t.boot_floppy(os.path.abspath(sys.argv[1]))

def rd(addr, n):
    return t.read(hex(addr) if isinstance(addr, int) else addr, n)
def w16(b, i): 
    v = (b[i] << 8) | b[i + 1]
    return v - 65536 if v >= 32768 else v
def u16(b, i):
    return (b[i] << 8) | b[i + 1]

page, addr = cheat_state_addr()
t.call('run_frames', {'n': 2700})

def poke_cheat():
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + page)]})
    t.call('write_memory', {'addr': hex(addr), 'bytes': ['03', '01']})  # stage 3 + invincible
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})

def cheat_holds():
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + page)]})
    ok = t.read(hex(addr), 2) == [3, 1]
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
    return ok

for _ in range(40):
    poke_cheat()
    t.call('run_frames', {'n': 60})
    if cheat_holds():
        break
else:
    raise SystemExit('title jamais pret (le poke cheat ne tient pas)')

for _ in range(40):
    poke_cheat()
    t.press(hold=8)
    t.call('run_frames', {'n': 250})
    b = rd(0x87DB, 3)
    if b[0] == 0xCA and b[1] == 3:
        break
    if b[0] == 0xCA and b[1] not in (0, 3):
        raise SystemExit('parti au stage %d — le cheat n a pas tenu' % b[1])
else:
    raise SystemExit('le stage 3 n a jamais seme son bloc')

inv = rd(INV, 1)[0]
print('stage 3 en place — cheat.invincible ($%04X) = %d %s'
      % (INV, inv, 'OK' if inv else '*** PAS INVINCIBLE ***'))
if not inv:
    raise SystemExit('le mode invincible n est pas arme : releve refuse')

# --- drainage de l'anneau -------------------------------------------------
def cart_page():
    pm = t.call('read_page_map', {'addr': '0x0000'})
    for k in ('page_at', 'cart_ram_page', 'page'):
        if isinstance(pm.get(k), int):
            return pm[k]
    raise SystemExit('read_page_map inattendu : %r' % pm)

def with_logpage(fn):
    """monte la page du journal, execute fn(), remet la page d'origine.
    Le CPU est gele pendant toute la sequence."""
    cur = cart_page()
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + LOGPAGE)]})
    try:
        return fn()
    finally:
        t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + cur)]})

def header():
    def f():
        h = rd(0x0000, 6)
        return u16(h, 0), u16(h, 2), u16(h, 4)   # magic, wptr, written
    return with_logpage(f)

def read_range(a, n):
    def f():
        b = []
        while n_left[0] > 0:
            k = min(4096, n_left[0])
            b += rd(a + len(b), k)
            n_left[0] -= k
        return b
    n_left = [n]
    return with_logpage(f)

# le pilote est instancie par la WAVE a t=$0100 (256 trames apres l'entree du
# stage) : l'en-tete n'existe pas avant. On laisse venir — l'anneau tient 20 s,
# rien n'est perdu.
for _ in range(20):
    mg, wptr, written = header()
    if mg == MAGIC:
        break
    t.call('run_frames', {'n': 60})
else:
    raise SystemExit('la page $%02X ne porte pas le journal (magic $%04X) — '
                     'le build est-il instrumente, le pilote instancie ?'
                     % (LOGPAGE, mg))
print('en-tete du journal : magic=$%04X wptr=$%04X ecrits=%d' % (mg, wptr, written))

records = []
# on repart de ZERO : les enregistrements deja ecrits depuis le spawn du
# pilote sont dans l'anneau (1008 entrees = 20 s), on les veut tous
last_written = 0
last_ptr = RING_START
BUDGET = int(os.environ.get('WARSHIP_FRAMES', '10000'))
overrun = 0
done = 0
while done < BUDGET:
    step = min(400, BUDGET - done)
    t.call('run_frames', {'n': step, 'timeout_ms': 600000})
    done += step
    mg, wptr, written = header()
    if mg != MAGIC:
        print('journal disparu a t~%d (magic $%04X) — le stage a rendu la main' % (done, mg))
        break
    new = (written - last_written) & 0xFFFF
    if new == 0:
        stage = rd(0x87DC, 1)[0]
        print('aucun enregistrement neuf a t~%d (bench.stage=%d)' % (done, stage))
        if stage != 3:
            break
        last_written = written
        continue
    if new > NRECS:
        overrun += new - NRECS
        new = NRECS
        last_ptr = wptr            # tout ce qui reste est le dernier tour
    # lire `new` enregistrements finissant a wptr
    start = wptr - new * REC
    if start >= RING_START:
        raw = read_range(start, new * REC)
    else:
        tail = RING_START - start           # octets pris en fin d'anneau
        raw = read_range(RING_END - tail, tail) + read_range(RING_START, wptr - RING_START)
    for i in range(new):
        r = raw[i * REC:(i + 1) * REC]
        records.append(dict(frame=u16(r, 0), fd=r[2], left=r[3],
                            cursor=u16(r, 4), counter=w16(r, 6),
                            sx=w16(r, 8), sy=w16(r, 10),
                            camx=w16(r, 12), camy=w16(r, 14)))
    last_written, last_ptr = written, wptr
    stage = rd(0x87DC, 1)[0]
    print('t~%5d  %6d enregistrements  (stage=%d, camx=%d camy=%d)'
          % (done, len(records), stage, records[-1]['camx'], records[-1]['camy']), flush=True)
    if stage != 3:
        print('le stage 3 a rendu la main a t~%d' % done)
        break

print('total : %d enregistrements, %d perdus par debordement' % (len(records), overrun))

# --- confrontation --------------------------------------------------------
first = records[0]['cursor']
# l'entree lue a la trame n vive est EXPECT[n-1]; cursor pointe APRES elle
rows = []
first_div = None
for n, r in enumerate(records, start=1):
    if n - 1 >= len(EXPECT):
        exp_i, exp_sx, exp_sy, exp_cnt = (None, None, None, None)
    else:
        exp_i, exp_sx, exp_sy, exp_cnt = EXPECT[n - 1]
    got_i = (r['cursor'] - first) // 5      # index d'entree relatif a la 1re
    ok = (exp_i is not None and got_i == exp_i and r['sx'] == exp_sx
          and r['sy'] == exp_sy and r['counter'] == exp_cnt)
    if not ok and first_div is None and exp_i is not None:
        first_div = n
    rows.append(dict(n=n, frame=r['frame'], fd=r['fd'], left=r['left'],
                     entry=got_i, counter=r['counter'], sx=r['sx'], sy=r['sy'],
                     camx=r['camx'], camy=r['camy'],
                     exp_entry=exp_i, exp_counter=exp_cnt,
                     exp_sx=exp_sx, exp_sy=exp_sy, ok=int(bool(ok))))

with open(os.path.join(out, 'journal.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)

bad = [r for r in rows if not r['ok'] and r['exp_entry'] is not None]
print('\n=== CONFRONTATION SCRIPT (etat lu au runtime vs integrale du ROM) ===')
print('trames relevees      : %d' % len(rows))
print('trames divergentes   : %d' % len(bad))
if first_div:
    print('premiere divergence  : trame vive n=%d' % first_div)
    for r in rows[max(0, first_div - 4):first_div + 6]:
        print('  n=%5d frame=%5d fd=%d left=%3d | entree %s/%s counter %s/%s '
              'sx %s/%s sy %s/%s | cam %d,%d'
              % (r['n'], r['frame'], r['fd'], r['left'], r['entry'], r['exp_entry'],
                 r['counter'], r['exp_counter'], r['sx'], r['exp_sx'],
                 r['sy'], r['exp_sy'], r['camx'], r['camy']))
else:
    print('AUCUNE divergence : le pilote lit exactement ce que le ROM dit,')
    print('trame par trame, sur toute la duree relevee.')

# horloge : la n-ieme trame vive doit tomber sur frame.count = frame0 + n - 1
f0 = rows[0]['frame']
clock = [r for r in rows if r['frame'] - f0 != r['n'] - 1]
print('\n=== HORLOGE (une trame video = une trame de script) ===')
print('trames ou frame.count derive : %d' % len(clock))
if clock:
    c = clock[0]
    print('premiere derive : n=%d frame=%d attendu=%d (ecart %d)'
          % (c['n'], c['frame'], f0 + c['n'] - 1, c['frame'] - f0 - c['n'] + 1))
    print('derniere derive : n=%d ecart %d'
          % (clock[-1]['n'], clock[-1]['frame'] - f0 - clock[-1]['n'] + 1))

json.dump(dict(nrec=len(rows), overrun=overrun, first_div=first_div,
               clock_drift=len(clock), invincible=inv),
          open(os.path.join(out, 'resume.json'), 'w'), indent=1)
print('\njournal.csv + resume.json dans', out)
