#!/usr/bin/env python3
"""Capture video+son du stage 2 SEUL, en mode INVINCIBLE.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/stage2_video.py dist/to8.fd [dist/stage2.avi]

Meme methode que warship_video.py, dont il reprend les pieges :

  - un point d'arret laisse par une sonde fige les run_frames suivants en
    silence : on purge avant de commencer ;
  - tout poke de $E7E6 passe par le point sur gfxlock.bufferSwap.wait, sinon
    la sonde tue le jeu qu'elle filme ;
  - le declencheur de capture est un PC et non une trame : un declencheur
    frame/seconds coupe le turbo des l'armement, un declencheur pc le laisse
    disponible pour tout le rodage et ne le coupe qu'a l'instant voulu ;
  - le temoin ne s'ecrit pas en dur, il vient des .lwmap et de layout.asm.

Le declencheur est l'entree de la REGION stage : le loader y saute quand le
stage 1 prend la main, et le title — qui vit a la meme adresse — a rendu la
sienne bien avant.

DIFFERENCE avec stage1_video.py : on entre DIRECTEMENT au stage 2 (tct.pstage
= 2), sans jouer le stage 1. Le declencheur reste l'entree de la region stage,
ou le loader saute quand le stage 2 prend la main. La capture s'arrete quand
bench.stage n'est plus 2.

Options d'environnement (08/09/2026) :
  FRAMEDROP_MAX=N  pose gfxlock.frameDrop.max a N une fois le stage en place
                   (et le repose a chaque pas). 0 = PLUS DE PLAFOND : le jeu
                   avance de toutes les trames ecoulees, la video est au
                   rythme arcade quel que soit le debit du rendu. Le stage
                   ecrit 8 a son entree ; la capture rend la valeur du jeu.

LA VIDEO N'AGIT PAS SUR LE JEU par defaut (decision auteur, 08/09/2026) :
aucune mort scriptee, aucune action joueur — elle enregistre le comportement
du jeu livre a lui-meme, pour la comparaison cote a cote avec la borne. Le
boss se termine donc par son timeout, comme sur la borne sans joueur.

  KILL_BOSS=1      EXCEPTION EXPLICITE, pour VOIR la sequence de mort (le
                   vaisseau ne tire pas) : la boite du Gomander est posee a 0
                   dans un etat ou HitCheck tourne, le geste de
                   tools/gomander_death_probe.py. Jamais pour une comparaison.
  KILL_AFTER=N     avec KILL_BOSS : trames de combat laissees avant le coup
                   fatal (defaut 0 = sa premiere fenetre, ~10 s).
"""
import os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def equ(mapfile, name):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return int(m.group(1), 16)
    raise SystemExit('symbole %s absent de %s' % (name, mapfile))


def layout(name):
    for l in open('gen/layout.asm'):
        m = re.match(r'%s equ \$?([0-9A-Fa-f]+)\s*$' % re.escape(name), l.strip())
        if m:
            return int(m.group(1), 16)
    raise SystemExit('equate %s absente de gen/layout.asm' % name)


def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))


MAIN    = 'gen/stages/01/build/stage01-main.lwmap'
BSTAGE  = equ(MAIN, 'bench.stage')
TRIGGER = layout('stage.address')            # ou le loader saute pour le stage
_, ENG  = unit_base('common.engine')
WAIT    = ENG + equ('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait')
INV     = ENG + equ('gen/common/build/engine.lwmap', 'cheat.invincible')
FDMAX   = ENG + equ('gen/common/build/engine.lwmap', 'gfxlock.frameDrop.max')
FRAMEDROP_MAX = os.environ.get('FRAMEDROP_MAX')
KILL_BOSS = os.environ.get('KILL_BOSS') == '1'
KILL_AFTER = int(os.environ.get('KILL_AFTER', '0'))

# le pool d'objets, pour trouver le boss (ram.const.asm / constants.asm)
POOL, NOBJ, OSZ, ROUTINE, EXT = 0x4000, 60, 63, 34, 38
ID_GOMANDER = 40                             # src/stages/02/objid.const.asm


def find_gomander(t):
    """(adresse OST, routine) du gomander vivant, ou None."""
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    for i in range(NOBJ):
        o = raw[i * OSZ:(i + 1) * OSZ]
        if o[0] == ID_GOMANDER:
            return POOL + i * OSZ, o[ROUTINE]
    return None

out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'dist/stage2.avi')
os.makedirs(os.path.dirname(out), exist_ok=True)
for stale in (out, os.path.splitext(out)[0] + '.mp4'):
    if os.path.exists(stale):
        os.remove(stale)

t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try:
            t.call(what, {'id': i})
        except Exception:
            pass
t.boot_floppy(os.path.abspath(sys.argv[1]))
t.call('run_frames', {'n': 1200})

occ = open('dist/occupancy-fd.html').read()
m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
page, base = int(m.group(1)), int(m.group(2))
pstage = equ('gen/title/build/cheat.lwmap', 'tct.pstage')
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch')

t.call('set_breakpoint', {'pc': '%04X' % WAIT})
t.call('run_to_breakpoint', {'timeout_ms': 120000})
t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(base + pstage), 'bytes': ['02', '01']})   # stage 2 + invincible
t.call('set_register', {'reg': 'dp', 'value': '9F'})
t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)})
print('lancement pose au point sur ($%04X)' % WAIT, flush=True)

r = t.call('arm_video_capture', {'path': out, 'start': {'pc': '%04X' % TRIGGER},
                                 'max_bytes': 4000000000})
print('capture armee sur l\'entree du stage ($%04X) :' % TRIGGER, r, flush=True)

for _ in range(30):
    t.call('run_frames', {'n': 250})
    if t.call('video_capture_status').get('state') == 'recording':
        break
else:
    raise SystemExit('le stage 2 n\'a jamais pris la main')

inv = t.read(hex(INV), 1)[0]
print('stage 2 en place — cheat.invincible = %d %s'
      % (inv, 'OK' if inv else '*** PAS INVINCIBLE ***'), flush=True)
if not inv:
    t.call('stop_video_capture')
    raise SystemExit('invincible non arme : capture abandonnee')

os.environ.pop('TOJE_FAST', None)            # le turbo est coupe de toute facon
BUDGET = int(os.environ.get('STAGE_FRAMES', '30000'))
done = 0
killed = False
boss_seen = None                             # t~ de l'apparition du boss
while done < BUDGET:
    if FRAMEDROP_MAX is not None:
        t.call('write_memory', {'addr': '%04X' % FDMAX,
                                'bytes': ['%02X' % int(FRAMEDROP_MAX)]})
    if KILL_BOSS and not killed:
        g = find_gomander(t)
        if g is not None and boss_seen is None:
            boss_seen = done
        if g is not None and done - boss_seen >= KILL_AFTER:
            # une passe fine : la fenetre vulnerable (phaseA 2, orbArm 3,
            # phaseB 4, engulf 5) dure 15 a 30 trames
            for _ in range(50):
                base, rt = g
                if rt in (2, 3, 4, 5):
                    t.call('write_memory', {'addr': '%04X' % (base + EXT), 'bytes': ['00']})
                    killed = True
                    print('t~%5d  gomander tue (routine %d)' % (done, rt), flush=True)
                    break
                if rt >= 6:
                    killed = True
                    break
                r = t.call('run_frames', {'n': 10, 'timeout_ms': 600000})
                done += r.get('frames', 10) if isinstance(r, dict) else 10
                g = find_gomander(t)
                if g is None:
                    break
    step = min(500, BUDGET - done)
    r = t.call('run_frames', {'n': step, 'timeout_ms': 600000})
    done += r.get('frames', step) if isinstance(r, dict) else step
    st = t.read(hex(BSTAGE), 1)[0]
    vs = t.call('video_capture_status')
    print('t~%5d  stage=%d  film: %s img, %s o' % (done, st, vs.get('frames'),
                                                   vs.get('bytes')), flush=True)
    if st != 2:
        print('le stage 2 a rendu la main (stage=%d) — 100 trames de queue'
              % st, flush=True)
        t.call('run_frames', {'n': 100, 'timeout_ms': 600000})
        break

print(t.call('stop_video_capture'), flush=True)
# H.264 OBLIGATOIRE : le defaut h265 sort du hev1 que l'iPhone refuse de lire.
print(t.call('encode_capture', {'path': out, 'codec': 'h264', 'quality': 18}), flush=True)
t.close()
