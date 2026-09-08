#!/usr/bin/env python3
"""Sonde ciblee : la mort du Gomander — cascade + retrait des outslay.

Usage : python3 tools/gomander_death_probe.py dist/to8.fd   (captures dans
PROBE_OUT ou a cote de l'image). Resultat du 08/09/2026 : cascade nee a +2,
outslay 3 -> 0 a +20, 3-6 explosions en vol jusqu'a +340, cascade rendue a
+360, bossDefeated a +256, stage 3 atteint.

Joue stage 1 -> stage 2 (protocole rtype_bench), attend le gomander, le tue
en posant sa boite a 0 dans un etat ou HitCheck tourne, puis observe :
  - l'enfant cascade (id 29) nait ;
  - les objets outslay (39, 41..44) disparaissent ;
  - les explosions (id 2) s'egrenent pendant ~352 trames ;
  - le stage enchaine (bossDefeated puis stage 3).
Captures d'ecran en cours de cascade.
"""
import os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, os.pardir, os.pardir, 'ci', 'toje-bench'))
import re
from mcp import Toje, bench_block, globals_block

image = sys.argv[1]
OUT = os.environ.get('PROBE_OUT', os.path.dirname(os.path.abspath(image)))
os.makedirs(OUT, exist_ok=True)
BLOCK = bench_block(image)
LIVES = globals_block(image) + 4
BOSSDEF = globals_block(image) + 8
DROP = globals_block(image) + 162             # globals.tilesDrop (signe)
_lay = open(os.path.join(_dist := os.path.dirname(os.path.abspath(image)) or '.', os.pardir, 'gen', 'layout.asm')).read()
STAGE = int(re.search(r'^stage.address equ \$([0-9A-Fa-f]+)', _lay, re.M).group(1), 16)
# scroll_vp_y_pos vit dans le moteur resident (le module de scroll y est
# inclus, api.asm l'exporte) : base de common.engine + offset du .lwmap
_dist = os.path.dirname(os.path.abspath(image)) or "."
_occ = open(os.path.join(_dist, "occupancy-fd.html")).read()
_base = int(re.search(r'"name":"common\.engine","container":"[^"]*","page":\d+,"address":(\d+)', _occ).group(1))
INV = None
VPY = None
PALCUR = None
for _l in open(os.path.join(_dist, os.pardir, "gen", "common", "build", "engine.lwmap")):
    _mm = re.match(r"Symbol: cheat\.invincible \(.*\) = ([0-9A-Fa-f]+)", _l)
    if _mm:
        INV = _base + int(_mm.group(1), 16)
    _mm = re.match(r"Symbol: scroll_vp_y_pos \(.*\) = ([0-9A-Fa-f]+)", _l)
    if _mm:
        VPY = _base + int(_mm.group(1), 16)
    _mm = re.match(r"Symbol: Pal_current \(.*\) = ([0-9A-Fa-f]+)", _l)
    if _mm:
        PALCUR = _base + int(_mm.group(1), 16)


def palette():
    """la palette courante (16 mots), l'etat de l'objet de fondu"""
    cur = t.read("%04X" % PALCUR, 2)
    cur = (cur[0] << 8) | cur[1]
    pal = t.read("%04X" % cur, 32)
    fr = t.read("%04X" % (POOL + NOBJ * OSZ + ROUTINE), 1)[0]   # palettefade, l'OST statique
    return cur, ' '.join('%02X%02X' % (pal[2*i], pal[2*i+1]) for i in range(16)), fr

POOL, NOBJ, OSZ = 0x4000, 60, 63
ID_EXPL, ID_CASC, ID_OUTSLAY, ID_GOM = 2, 29, 39, 40
OUTSLAY_IDS = {39, 41, 42, 43, 44}
ROUTINE, EXT = 34, 38
GOM_P, GOM_HP = EXT + 0, EXT + 16

t = Toje()
t.boot_floppy(image)
frames = 215
t0 = time.time()


def run(n):
    global frames
    r = t.call("run_frames", {"n": n, "timeout_ms": 20000})
    ran = r.get("frames", n)
    frames += ran if isinstance(ran, int) else n
    return r


def witnesses():
    b = t.read("%04X" % BLOCK, 9)
    return {"magic": b[0], "stage": b[1], "cam": (b[3] << 8) | b[4], "spawns": (b[5] << 8) | b[6]}


def pool():
    """[(slot, id, routine)] des objets vivants + le dump brut"""
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read("%04X" % (POOL + off), min(256, NOBJ * OSZ - off))
    objs = []
    for i in range(NOBJ):
        o = raw[i * OSZ:(i + 1) * OSZ]
        if o[0]:
            objs.append((i, o[0], o[ROUTINE]))
    return objs, raw


def counts():
    objs, _ = pool()
    ids = [o[1] for o in objs]
    return {"expl": ids.count(ID_EXPL), "casc": ids.count(ID_CASC),
            "outslay": sum(1 for i in ids if i in OUTSLAY_IDS),
            "gom": ids.count(ID_GOM), "total": len(ids)}


def shot(name):
    p = os.path.join(OUT, name)
    t.call("screenshot", {"path": p})
    return p


def press_until_stage1(budget):
    deadline = frames + budget
    while frames < deadline:
        w = witnesses()
        if w["magic"] == 0xCA and w["stage"] == 0x01:
            return
        t.press()
        run(200)
    sys.exit("title never handed over")


press_until_stage1(6000)
t.call("write_memory", {"addr": "%04X" % INV, "bytes": ["01"]})
print(f"stage 1 at f={frames}", flush=True)
# stage 1 jusqu'au bout, puis stage 2
while True:
    run(500)
    w = witnesses()
    if w["stage"] == 0x02 and w["magic"] == 0xCA:
        break
    if frames > 90000:
        sys.exit("stage 2 never reached")
print(f"stage 2 at f={frames} wall={time.time()-t0:.0f}s", flush=True)
run(800)                                   # le run silencieux apres le temoin
t.call("write_memory", {"addr": "%04X" % INV, "bytes": ["01"]})

# attendre le gomander
gom = None
while gom is None:
    run(300)
    objs, _ = pool()
    for slot, oid, rt in objs:
        if oid == ID_GOM:
            gom = slot
    w = witnesses()
    print(f"f={frames} cam={w['cam']} objs={len(objs)} gom={gom}", flush=True)
    if frames > 120000:
        sys.exit("gomander never spawned")
base = POOL + gom * OSZ
print(f"gomander slot {gom} at ${base:04X}", flush=True)

# attendre un etat ou HitCheck tourne (phaseA 2, orbArm 3, phaseB 4, engulf 5)
while True:
    run(10)
    rt = t.read("%04X" % (base + ROUTINE), 1)[0]
    if rt in (2, 3, 4, 5):
        break
    if rt >= 6:
        sys.exit(f"gomander already dying/finished (routine {rt})")
hp = t.read("%04X" % (base + GOM_HP), 1)[0]
before = counts()
print(f"f={frames} routine={rt} hp={hp} before={before}", flush=True)
# le coup fatal : la boite a 0, HitCheck voit p != hp et hp devient 0
t.call("write_memory", {"addr": "%04X" % (base + GOM_P), "bytes": ["00"]})
run(2)
rt = t.read("%04X" % (base + ROUTINE), 1)[0]
c = counts()
print(f"+2  routine={rt} {c}", flush=True)
# le suivi de la cascade : 400 trames video par pas de 20
log = []
for k in range(1, 26):
    run(20)
    c = counts()
    bd = t.read("%04X" % BOSSDEF, 1)[0]
    rt = t.read("%04X" % (base + ROUTINE), 1)[0]
    vp = t.read("%04X" % VPY, 1)[0]
    dr = t.read("%04X" % DROP, 1)[0]
    dr = dr - 256 if dr > 127 else dr
    log.append((k * 20, c["expl"], c["casc"], c["outslay"], bd, rt))
    print(f"+{k*20:3d} expl={c['expl']:2d} casc={c['casc']} outslay={c['outslay']} "
          f"bossDefeated={bd} gom.rt={rt} vp_y={vp} drop={dr:+d} total={c['total']}", flush=True)
    if k % 4 == 0:
        cur, pal, fr = palette()
        print(f"      palette @{cur:04X} fade.rt={fr} : {pal}", flush=True)
    if k in (3, 8, 14, 16, 18, 19):
        print("shot", shot(f"cascade-{k*20}.png"), flush=True)
# la suite de la sequence : le noir, puis le releve sous le fondu d'entree
for k in range(4):
    run(100)
    w = witnesses()
    cur, pal, fr = palette()
    print(f"+{500+(k+1)*100} stage={w['stage']:02X} fade.rt={fr} palette @{cur:04X} : {pal}", flush=True)
    print("      shot", shot(f"after-{500+(k+1)*100}.png"), flush=True)
# la fin du stage
for _ in range(60):
    run(500)
    w = witnesses()
    if w["stage"] == 0x03:
        print(f"stage 3 at f={frames}", flush=True)
        break
else:
    print("stage 3 NOT reached in 30000 frames", flush=True)
t.close()
