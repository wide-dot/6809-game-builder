#!/usr/bin/env python3
"""Replay the games/r-type real game flow under toje, headless.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/rtype_bench.py dist/to8.fd [max_frames]

Witnesses at bench.BLOCK (src/common/bench.const.asm), whose address
comes from gen/layout.asm — never hardcode it: magic $CA, stage byte (00 =
title, 01/02 = stages), frame counter, camera (word), spawns (word).
bench.BLOCK+8 is the lane's COMMAND window (bench.request): writing a
non-zero byte kills the player on the next stage.loop tour — the lane's
ship never dies on its own (its constant fire mows everything down
before contact), and this is what makes the death path exercisable.
globals.lives is read at globals.address+4, resolved the same way.

The game carries NO verdict flags: the lane derives its seven checks
from observable state, driving the real flow — the image boots on the
title, a key press starts the game, level ends come from the real
endstage sequence, deaths come through the command window.

  C1  title -> stage 1 hand-over (press start until stage byte = 01)
  C2  stage 1 progresses (camera beyond 1000 of its 1440 px)
  C3  death & checkpoint: kill -> a life is lost, the camera is wound
      back to the checkpoint, the game returns to RUNNING
  C4  game over: two more kills exhaust the lives -> back to the title
  C5  replay: press start again -> stage 1 fresh (lives reseeded to 2)
  C6  stage 1 -> stage 2 through the real end sequence, and stage 2
      runs its own data (spawns > 0 — the placeholder cast is reached
      through the freshly re-linked index: the re-link proof)
  C7  the chain crosses into stage 4: stage 2 hands over to stage 3
      (the warship), which runs its own end sequence and hands over.
      Stage 4 is ported too (its boss is being tuned, 30/08/2026) and
      scrolls to its boss scroll-stop — the lane only requires the
      HAND-OVER, so boss tuning cannot shake it.  When the full game
      loops back to the title, restore the full-tour criterion (top
      stage 8, then back to the title).

On a wedge (state stops changing on timeouts), the engine log block,
registers, disassembly and a screenshot are dumped.

Exit code: 0 pass, 1 wedge/abort, 2 frame budget exceeded.
"""
import os, sys, time
from mcp import Toje, bench_block, globals_block

image = sys.argv[1]
max_frames = int(sys.argv[2]) if len(sys.argv) > 2 else 140000

# Les deux ancres, lues dans gen/layout.asm — la source du jeu lui-meme.
# Tout en derive : la fenetre de commande etait restee sur l'adresse d'AVANT le
# demenagement du 19/08, donc `kill` poussait son octet dans le binaire du stage
# au lieu de la lane, et le joueur ne mourait jamais.
BLOCK = bench_block(image)
REQUEST = BLOCK + 8                    # bench.request
LIVES = globals_block(image) + 4       # globals.lives

# cheat.invincible : base de common.engine (rapport d'occupation) + offset
# (carte de lien de l'engine) — la meme resolution que warship_fps.py.
import re as _re
_dist = os.path.dirname(os.path.abspath(image)) or "."
_occ = open(os.path.join(_dist, "occupancy-fd.html")).read()
_m = _re.search(r'"name":"common\.engine","container":"[^"]*","page":\d+,"address":(\d+)', _occ)
_base = int(_m.group(1))
INV = None
for _l in open(os.path.join(_dist, os.pardir, "gen", "common", "build", "engine.lwmap")):
    _mm = _re.match(r"Symbol: cheat\.invincible \(.*\) = ([0-9A-Fa-f]+)", _l)
    if _mm:
        INV = _base + int(_mm.group(1), 16)
if INV is None:
    sys.exit("cheat.invincible introuvable — le projet est-il construit ?")
print("temoins : bench=$%04X lives=$%04X invincible=$%04X"
      % (BLOCK, LIVES, INV), flush=True)


def arm_invincible(tag):
    """Armer et VERIFIER l'invincibilite, apres chaque entree en stage 1.

    Le vaisseau de la lane ne pilote pas et ne tire pas : sans elle il meurt
    seul des les premieres vagues (vies 2->1->0 au tout debut du stage 1,
    constate le 30/08/2026), et la comptabilite C3/C4 — fondee sur des morts
    COMMANDEES par bench.request — devient illisible. Le poser au boot ne
    suffit pas : title.cheat.launch REECRIT cheat.invincible depuis tct.pinv
    a chaque depart du title (« un depart sans cheat remet tout a zero »), il
    faut donc re-armer APRES chaque passage title -> stage. Les kills de la
    lane, eux, forcent mainloop.state et passent outre — c'est documente dans
    bench.const.asm."""
    t.call("write_memory", {"addr": "%04X" % INV, "bytes": ["01"]})
    got = t.read("%04X" % INV, 1)[0]
    if got != 1:
        fail(f"{tag} FAIL — cheat.invincible ne s'arme pas (lu {got})")

t = Toje()
t.boot_floppy(image)
t0 = time.time()
frames = 215


def witnesses():
    b = t.read("%04X" % BLOCK, 9)
    return {"magic": b[0], "stage": b[1],
            "cam": (b[3] << 8) | b[4], "spawns": (b[5] << 8) | b[6]}


def lives():
    return t.read("%04X" % LIVES, 1)[0]


def run(n):
    global frames
    r = t.call("run_frames", {"n": n, "timeout_ms": 20000})
    ran = r.get("frames", n)
    frames += ran if isinstance(ran, int) else n
    return r


def kill():
    t.call("write_memory", {"addr": "%04X" % REQUEST, "bytes": ["01"]})


def fail(msg):
    print(msg)
    t.dump("fail ")
    shot = os.path.join(os.path.dirname(image) or ".", "wedge.png")
    print("screenshot:", t.call("screenshot", {"path": os.path.abspath(shot)}))
    t.close()
    sys.exit(1)


def press_until_stage1(tag, budget):
    """press start until the stage seeds the block (the title needs its
    loading plus the logo animation before the trigger is armed; pressing
    earlier is simply ignored, so poke every 200 frames)."""
    deadline = frames + budget
    while frames < deadline:
        w = witnesses()
        if w["magic"] == 0xCA and w["stage"] == 0x01:
            print(f"{tag} title -> stage 1 hand-over at f={frames}", flush=True)
            return
        t.press()
        run(200)
    fail(f"{tag} FAIL — title never handed over to stage 1")


# C1 — first hand-over
press_until_stage1("C1", 6000)
arm_invincible("C1")

# C2 — stage 1 progresses
while True:
    if frames > max_frames:
        fail("C2 FAIL — camera never reached 1000")
    run(500)
    w = witnesses()
    print(f"f={frames:6d} wall={time.time() - t0:5.0f}s magic={w['magic']:02X} "
          f"stage={w['stage']:02X} cam={w['cam']:5d} lives={lives()}", flush=True)
    if w["stage"] == 0x01 and w["cam"] > 1000:
        break
print(f"C2 stage 1 at camera {w['cam']}", flush=True)

# C3 — death & checkpoint
cam_at_death = w["cam"]
lives_before = lives()
kill()
deadline = frames + 1500
while frames < deadline:
    run(100)
    w = witnesses()
    if lives() == lives_before - 1 and w["stage"] == 0x01 and w["cam"] < cam_at_death:
        break
else:
    fail("C3 FAIL — death/checkpoint did not come back")
print(f"C3 death handled: lives {lives_before}->{lives()}, "
      f"camera {cam_at_death}->{w['cam']} (checkpoint rewind)", flush=True)

# C4 — exhaust the lives, expect the title.
# Chaque kill attend d'abord que le jeu ROULE (la camera avance) : la fenetre
# de commande n'est consommee qu'en RUNNING, et la sequence mort/READY du jeu
# reel est longue a la cadence reelle — deux kills a l'aveugle separes de 600
# trames tombaient dans la sequence precedente et se perdaient (re-base du
# 30/08/2026). On tue jusqu'au title, en journalisant chaque etape.
deadline_total = frames + 24000
while frames < deadline_total:
    w = witnesses()
    if w["stage"] == 0x00 and w["magic"] == 0xCA:
        break
    # attendre le jeu ROULANT : la camera avance franchement
    c0 = witnesses()["cam"]
    settle = frames + 5000
    while frames < settle:
        run(200)
        w = witnesses()
        if w["stage"] == 0x00 and w["magic"] == 0xCA:
            break
        if w["cam"] >= c0 + 6:
            break
        c0 = min(c0, w["cam"])    # un rembobinage de checkpoint repart plus bas
    if w["stage"] == 0x00 and w["magic"] == 0xCA:
        break
    lb = lives()
    kill()
    print(f"C4 kill demande (vies={lb}, cam={w['cam']}, f={frames})", flush=True)
    hit = frames + 6000
    while frames < hit:
        run(200)
        w = witnesses()
        if (w["stage"] == 0x00 and w["magic"] == 0xCA) or lives() != lb:
            break
    print(f"C4 apres kill : vies={lives()} stage={w['stage']:02X} "
          f"cam={w['cam']} f={frames}", flush=True)
else:
    fail("C4 FAIL — game over never returned to the title")
w = witnesses()
if not (w["stage"] == 0x00 and w["magic"] == 0xCA):
    fail("C4 FAIL — game over never returned to the title")
print(f"C4 game over -> title at f={frames}", flush=True)

# C5 — replay: a fresh game
press_until_stage1("C5", 8000)
arm_invincible("C5")
run(300)
if lives() != 2:
    fail(f"C5 FAIL — lives not reseeded (got {lives()})")
print(f"C5 fresh game: lives reseeded to {lives()}", flush=True)

# C6/C7 — the chain: stage 2 on its own data (spawns > 0 proves the
# re-linked index reaches its cast), then stage 3 runs to ITS end
# sequence — proven by the hand-over to stage 4, the first stub stage.
c6 = c7 = 0
top_stage = 1
last = None
stuck = 0
verdict = 2
while frames < max_frames:
    r = run(500)
    w = witnesses()
    if w["magic"] == 0xCA and 2 <= w["stage"] <= 8 and w["stage"] >= top_stage:
        top_stage = w["stage"]
    if w["stage"] == 0x02 and w["spawns"] > 0:
        c6 = 1
    if c6 and top_stage >= 4:
        c7 = 1                         # le stage 3 est alle au bout de sa
                                       # sequence de fin ; le stage 4 (boss en
                                       # mise au point) n'est pas juge ici
    print(f"f={frames:6d} wall={time.time() - t0:5.0f}s magic={w['magic']:02X} "
          f"stage={w['stage']:02X} cam={w['cam']:5d} spawns={w['spawns']} "
          f"top={top_stage} c6={c6} c7={c7}", flush=True)
    if c6 and c7:
        print("R-TYPE LANE C1..C7 7/7 PASS (chaine stages 1->2->3 complete)")
        verdict = 0
        break
    key = (w["magic"], w["stage"], w["cam"], c6, c7)
    stuck = stuck + 1 if key == last else 0
    last = key
    if stuck >= 4 and r.get("timed_out"):
        print("MACHINE WEDGED — dumping state")
        t.dump("wedge ")
        shot = os.path.join(os.path.dirname(image) or ".", "wedge.png")
        print("screenshot:", t.call("screenshot", {"path": os.path.abspath(shot)}))
        verdict = 1
        break
else:
    print("FRAME BUDGET EXCEEDED without C1..C7")

t.close()
sys.exit(verdict)
