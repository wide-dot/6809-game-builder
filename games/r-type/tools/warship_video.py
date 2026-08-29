#!/usr/bin/env python3
"""Capture video+son du stage 3 complet, en mode INVINCIBLE.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/warship_video.py dist/to8.fd [dist/stage3.avi]

Boote, arme le cheat (stage 3 + invincible), verifie l'invincibilite EN RAM,
et filme de l'entree du stage jusqu'a ce qu'il rende la main.

Le declencheur de capture est un PC : `mscroll.setup`, appele UNE seule fois,
par le stage 3 et par lui seul (le module est resident mais inerte ailleurs).
Un declencheur pc laisse le TURBO disponible pendant tout le rodage — boot,
title, cheat — et n'est coupe qu'a l'instant ou le stage demarre. Le film part
donc a la premiere trame du stage, pas une de plus.
"""
import os, re, sys

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

def equ(mapfile, name):
    """Une equate ABSOLUE de la carte (bench.* vient de gen/layout.asm)."""
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return int(m.group(1), 16)
    raise SystemExit('equate %s absente' % name)

# LE TEMOIN NE S'ECRIT PAS EN DUR. Son adresse vient de gen/layout.asm et
# BOUGE des qu'une unite de stage change de taille — bench.const.asm raconte
# les trois demenagements et les adresses perimees laissees derriere. Le
# 28/08/2026 le litteral $87DB, perime de 23 octets, a fait conclure « stage 3
# jamais seme » sur trois builds dont deux etaient bons.
BENCH  = equ('gen/stages/03/build/stage03-main.lwmap', 'bench.magic')
# bench.stage (BLOCK+1) est le stage QUI TOURNE ; bench.spawnStage (BLOCK+7)
# est celui dont le bouchon a tourne en dernier — ce n'est pas la meme chose.
BSTAGE = equ('gen/stages/03/build/stage03-main.lwmap', 'bench.stage')
_, MSCROLL_BASE = unit_base('common.mscroll')
_, ENGINE_BASE  = unit_base('common.engine')
SETUP = sym('gen/common/build/mscroll.lwmap', 'mscroll.setup', MSCROLL_BASE)
INV   = sym('gen/common/build/engine.lwmap', 'cheat.invincible', ENGINE_BASE)

def cheat_state_addr():
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
    page, addr = int(m.group(1)), int(m.group(2))
    for l in open('gen/title/build/cheat.lwmap'):
        m2 = re.match(r'Symbol: tct\.pstage \(.*\) = ([0-9A-Fa-f]+)', l)
        if m2:
            return page, addr + int(m2.group(1), 16)
    raise SystemExit('tct.pstage absent')

out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'dist/stage3.avi')
os.makedirs(os.path.dirname(out), exist_ok=True)
if os.path.exists(out):
    os.remove(out)

t = Toje()
# UNE SESSION D'EMULATEUR SE PARTAGE. Un point d'arret ou un watchpoint laisse
# par une sonde precedente fige les run_frames de celle-ci, en silence : le
# 28/08/2026 un watchpoint oublie a fait echouer quatre captures d'affilee sur
# des builds sains. On repart propre.
for i in range(1, 9):
    try:
        t.call('clear_watchpoint', {'id': i})
    except Exception:
        pass
    try:
        t.call('clear_breakpoint', {'id': i})
    except Exception:
        pass
t.boot_floppy(os.path.abspath(sys.argv[1]))
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
    raise SystemExit('title jamais pret')

# armer AVANT le depart : le declencheur pc ne coupe le turbo qu'au moment ou
# le stage 3 appelle mscroll.setup
r = t.call('arm_video_capture', {
    'path': out,
    'start': {'pc': '%04X' % SETUP},
    'max_bytes': 4000000000,
})
print('capture armee sur mscroll.setup ($%04X) :' % SETUP, r, flush=True)

# LE SIGNAL DE DEPART EST LA CAPTURE ELLE-MEME, pas le temoin RAM. L'adresse
# du temoin est ecrite en dur ($87DB) et suit la taille de l'unite residente du
# stage : elle se decale des qu'on ajoute ou retire une ligne d'index. On a
# perdu deux captures de cette facon le 28/08/2026 — le film etait bon, le
# script concluait « stage 3 jamais seme ». Le declencheur pc, lui, est sans
# ambiguite : mscroll.setup n'est appele que par le stage 3.
# LE CHEAT SE POSE, PUIS ON VERIFIE, PUIS ON APPUIE. Le title CYCLE (logo,
# textes, scores) et chaque bascule reecrit sa page : un appui lance juste
# apres une pose peut tomber sur une page deja effacee, et le jeu part au
# stage 1 — ou nulle part. Poser et appuyer dans la foulee rendait le semis
# ALEATOIRE (28/08/2026 : trois builds sur cinq n'entraient jamais, dont deux
# qui etaient bons). On relit donc la page juste avant l'appui, et on repose
# tant qu'elle ne tient pas.
for essai in range(60):
    poke_cheat()
    t.call('run_frames', {'n': 10})
    if not cheat_holds():
        continue                       # la page vient d'etre effacee : reposer
    t.press(hold=8)
    t.call('run_frames', {'n': 250})
    if t.call('video_capture_status').get('state') == 'recording':
        break                          # mscroll.setup n'appartient qu'au stage 3
    b = t.read(hex(BENCH), 2)
    print('  essai %d : temoin %02X stage %d' % (essai, b[0], b[1]), flush=True)
    if b[0] == 0xCA:
        if b[1] not in (0, 3):
            raise SystemExit('parti au stage %d — le cheat n\'a pas pris' % b[1])
else:
    raise SystemExit('stage 3 jamais seme')

inv = t.read(hex(INV), 1)[0]
print('stage 3 en place — cheat.invincible = %d %s'
      % (inv, 'OK' if inv else '*** PAS INVINCIBLE ***'), flush=True)
if not inv:
    t.call('stop_video_capture')
    raise SystemExit('invincible non arme : capture abandonnee')

# le turbo est coupe depuis que le declencheur est tombe : plus de fast
os.environ.pop('TOJE_FAST', None)
print(t.call('video_capture_status'), flush=True)

BUDGET = int(os.environ.get('STAGE_FRAMES', '9000'))
done = 0
while done < BUDGET:
    step = min(500, BUDGET - done)
    r = t.call('run_frames', {'n': step, 'timeout_ms': 600000})
    done += r.get('frames', step) if isinstance(r, dict) else step
    st = t.read(hex(BSTAGE), 1)
    vs = t.call('video_capture_status')
    print('t~%5d  stage=%d  film: %s img, %s o'
          % (done, st[0], vs.get('frames'), vs.get('bytes')), flush=True)
    if st[0] != 3:
        print('le stage 3 a rendu la main — 100 trames de queue', flush=True)
        t.call('run_frames', {'n': 100, 'timeout_ms': 600000})
        break

print(t.call('stop_video_capture'), flush=True)
print('AVI :', out, os.path.getsize(out), 'octets')
