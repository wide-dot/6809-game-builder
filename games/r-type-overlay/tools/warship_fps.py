#!/usr/bin/env python3
"""Releve de cadence d'un stage, trame video par trame video.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 STAGE=2 \
    python3 tools/warship_fps.py dist/to8.fd [out_dir]

Le stage se choisit par la variable STAGE (defaut 3, le releve d'origine du
cuirasse). STAGE_FRAMES borne le releve, STEP donne la largeur de fenetre.

Aucune instrumentation dans le jeu : le temoin `bench.frames` ($87DD) est
incremente une fois par TOUR DE BOUCLE de `stage.loop` (stage-main.asm, juste
avant `gfxlock.loop`), et l'horloge video 50 Hz est `gfxlock.frame.count`. Le
releve avance d'UNE trame video a la fois et regarde si le compteur de boucles
a bouge : on sait donc, pour chaque trame video, si une boucle s'y est
terminee. La duree d'une boucle en trames video EST son frame-drop.

Le turbo est legitime ici : il n'change ni les instructions ni les cycles CPU,
et preserve l'horloge de trame — le frame-drop en depend seul.

Sorties : fps.csv (une ligne par boucle), fps.svg (le graphe), et un resume.
"""
import os, re, sys, csv, json

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))

def sym(mapfile, name, base):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return base + int(m.group(1), 16)
    raise SystemExit('symbole %s absent' % name)

_, ENGINE = unit_base('common.engine')
FRAMEDROP = sym('gen/common/build/engine.lwmap', 'gfxlock.frameDrop.count', ENGINE)
FRAMECNT  = sym('gen/common/build/engine.lwmap', 'gfxlock.frame.count', ENGINE)
INV       = sym('gen/common/build/engine.lwmap', 'cheat.invincible', ENGINE)
# un PC en RAM FIXE, traverse a chaque tour de la boucle gfxlock : le seul
# endroit ou l'on ait le droit de toucher a $E7E6
SAFE      = sym('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait', ENGINE)
# un PC en RAM FIXE, traverse a chaque tour de boucle par le title comme par un
# stage : le seul endroit ou l'on ait le droit de toucher a $E7E6
BENCH     = 0x87DB          # magic, stage, boucles, camera(2)

def cheat_state_addr():
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
    page, addr = int(m.group(1)), int(m.group(2))
    for l in open('gen/title/build/cheat.lwmap'):
        m2 = re.match(r'Symbol: tct\.pstage \(.*\) = ([0-9A-Fa-f]+)', l)
        if m2:
            return page, addr + int(m2.group(1), 16)
    raise SystemExit('tct.pstage absent')

STAGE = int(os.environ.get('STAGE', '3'))
out = sys.argv[2] if len(sys.argv) > 2 else 'dist/stage%d-fps' % STAGE
os.makedirs(out, exist_ok=True)

t = Toje()
page, addr = cheat_state_addr()

# --- l'amorce, calquee A L'IDENTIQUE sur la sequence manuelle qui passe ----
# Toute variante essayee le 20/08/2026 (pokes repetes, verification du cheat
# en boucle, appuis multiples sur start, blocs de 250 trames) fige le stage 3
# sur une lecture disque autour de camera 170. La sequence ci-dessous, elle,
# traverse : un seul poke, un seul appui, et de GROS blocs. On n'y touche pas
# sans re-verifier le passage de camera 173.
t.call('mount_disk', {'path': os.path.abspath(sys.argv[1])})
t.call('reset')
t.call('run_frames', {'n': 90})
t.call('press_key', {'scancode': '0F', 'down': True})
t.call('run_frames', {'n': 5})
t.call('press_key', {'scancode': '0F', 'down': False})
t.call('run_frames', {'n': 3000, 'timeout_ms': 600000})

def safe_point(tries=40):
    """amener le CPU sur un PC de RAM FIXE avant de toucher a $E7E6.

    Ecrire $E7E6 pendant que PC est dans $0000-$3FFF retire le code sous les
    pieds du processeur. Deux temps, parce qu'aucun des deux seul ne suffit :
    `run_until_pc` sur le symbole du moteur n'aboutit pas pendant un
    chargement de scene, et attendre une frontiere de trame ne sort jamais de
    la fenetre cartouche (la boucle du title y vit).
    """
    for _ in range(tries):
        r = t.call('run_until_pc', {'pc': '%04X' % SAFE, 'max_instructions': 400000})
        if isinstance(r, dict) and r.get('reached'):
            return
        t.call('run_frames', {'n': 60})
    raise SystemExit('point sur jamais atteint : poke refuse')

safe_point()
t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(addr), 'bytes': ['%02X' % STAGE, '01']})  # stage + invincible
ok = t.read(hex(addr), 2) == [STAGE, 1]
t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
if not ok:
    raise SystemExit('le cheat n a pas pris')

t.call('press_key', {'scancode': '0F', 'down': True})
t.call('run_frames', {'n': 10})
t.call('press_key', {'scancode': '0F', 'down': False})

for _ in range(12):
    t.call('run_frames', {'n': 500, 'timeout_ms': 600000})
    b = t.read(hex(BENCH), 3)
    if b[0] == 0xCA and b[1] == STAGE:
        break
    if b[0] == 0xCA and b[1] not in (0, STAGE):
        raise SystemExit('parti au stage %d — le cheat n a pas tenu' % b[1])
else:
    raise SystemExit('le stage %d n a jamais seme son bloc' % STAGE)

inv = t.read(hex(INV), 1)[0]
print('stage %d en place — cheat.invincible = %d %s'
      % (STAGE, inv, 'OK' if inv else '*** NON ***'), flush=True)
if not inv:
    raise SystemExit('invincible non arme')

BUDGET = int(os.environ.get('STAGE_FRAMES', '8000'))
STEP = int(os.environ.get('STEP', '50'))     # 50 trames video = 1 seconde

# --- le releve : par blocs de trames, jamais a l'instruction ---------------
# DEUX methodes plus fines ont ete essayees et ECARTEES le 20/08/2026, toutes
# deux bloquant le jeu au MEME point (boucle 160, trame video 896, camera 173,
# ou le stage 3 declenche un chargement disque) :
#   - `run_frames(1)` repete, avec ET sans turbo ;
#   - une surveillance memoire sur bench.frames + `run_to_breakpoint`.
# Diagnostic au blocage : PC en ROM moniteur, X=$E7D0 (registres du controleur
# de disquette), compteurs gfxlock a zero. Le controleur emule ne survit pas a
# une execution decoupee a l'instruction ; en blocs de trames le meme build
# traverse le point sans broncher (verifie a la main : camera 366 passee).
# Consequence de mesure : on compte les boucles TERMINEES par fenetre de STEP
# trames — c'est un comptage exact, seul le rattachement d'une boucle a SA
# trame de fin est perdu.
loops_at = []          # (trame video, boucles de la fenetre, camera x)
rows_load = []         # trames ou un chargement disque a ete traverse
total_loops = 0
prev_loop = t.read(hex(BENCH), 5)[2]
n = 0
stall = 0
while n < BUDGET:
    r = t.call('run_frames', {'n': STEP, 'timeout_ms': 600000})
    n += STEP
    b = t.read(hex(BENCH), 5)
    if b[1] != STAGE:
        print('le stage %d a rendu la main a la trame %d' % (STAGE, n), flush=True)
        break
    inc = (b[2] - prev_loop) & 0xFF
    prev_loop = b[2]
    total_loops += inc
    loops_at.append((n, inc, (b[3] << 8) | b[4]))
    if inc == 0:
        # fenetre sans aucune boucle : le stage est en CHARGEMENT DISQUE.
        # C'est une vraie seconde a 0 fps, on la garde telle quelle.
        rows_load.append(n)
        stall += 1
        if stall == 20:
            print('*** 20 fenetres sans boucle (trame %d) : blocage ***' % n, flush=True)
            t.call('screenshot', {'path': os.path.abspath(os.path.join(out, 'blocage.png'))})
            print('registres :', t.call('read_registers'), flush=True)
            break
    else:
        stall = 0
    if n % 1000 == 0:
        print('  trame %5d  %5d boucles  camera %4d'
              % (n, total_loops, (b[3] << 8) | b[4]), flush=True)

print('%d boucles sur %d trames video' % (total_loops, n), flush=True)

rows = [dict(trame=f, seconde=round(f / 50.0, 2), camera=cam,
             boucles=inc, fps=round(inc * 50.0 / STEP, 2))
        for f, inc, cam in loops_at]
with open(os.path.join(out, 'fps.csv'), 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)

from collections import Counter
span = n
total = total_loops
avg = total * 50.0 / span
serie = [(r['trame'] * 1.0 / 50.0, r['fps']) for r in rows]
hist = Counter(r['fps'] for r in rows)
print('\n=== CADENCE DU STAGE %d ===' % STAGE)
print('boucles de jeu : %d' % total)
print('trames video   : %d  (%.1f s)' % (span, span / 50.0))
print('fps moyen      : %.2f   (soit %.2f trames video par boucle)'
      % (avg, 50.0 / avg))
print('fps min / max  : %.1f / %.1f' % (min(v for _, v in serie), max(v for _, v in serie)))
print('\nrepartition des fenetres de %d trames :' % STEP)
for k in sorted(hist):
    print('  %5.1f fps : %4d fenetres  %5.1f %%  %s'
          % (k, hist[k], 100.0 * hist[k] / len(rows), '#' * int(50.0 * hist[k] / len(rows))))
json.dump(dict(loops=total, frames=span, fps_moyen=avg, step=STEP,
               fps_min=min(v for _, v in serie), fps_max=max(v for _, v in serie),
               hist={str(k): v for k, v in hist.items()}),
          open(os.path.join(out, 'resume.json'), 'w'), indent=1)

# --- le graphe : sorti dans tools/fps_plot.py, pour pouvoir le refaire depuis
# un fps.csv deja pris (comparer deux releves ne doit pas coter deux campagnes)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fps_plot import plot
plot(rows, os.path.join(out, 'fps.svg'),
     'R-Type TO8 — cadence du stage %d' % STAGE)
print('\nfps.csv + fps.svg + resume.json dans', out)
