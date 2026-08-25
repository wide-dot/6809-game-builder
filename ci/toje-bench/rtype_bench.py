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
  C7  stage 2 hands back to the title

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
print("temoins : bench=$%04X lives=$%04X" % (BLOCK, LIVES), flush=True)

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

# C4 — exhaust the lives, expect the title
for k in (2, 3):
    run(400)                      # let the game settle back into RUNNING
    kill()
    run(600)
deadline = frames + 3000
while frames < deadline:
    w = witnesses()
    if w["stage"] == 0x00 and w["magic"] == 0xCA:
        break
    run(200)
else:
    fail("C4 FAIL — game over never returned to the title")
print(f"C4 game over -> title at f={frames}", flush=True)

# C5 — replay: a fresh game
press_until_stage1("C5", 8000)
run(300)
if lives() != 2:
    fail(f"C5 FAIL — lives not reseeded (got {lives()})")
print(f"C5 fresh game: lives reseeded to {lives()}", flush=True)

# C6/C7 — the full run: every stage in order (2..8, each on its own
# directory and map — spawns > 0 at stage 2 proves the re-linked index
# reaches the skeleton cast), then back to the title.
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
    if c6 and top_stage == 8 and w["stage"] == 0x00 and w["magic"] == 0xCA:
        c7 = 1
    print(f"f={frames:6d} wall={time.time() - t0:5.0f}s magic={w['magic']:02X} "
          f"stage={w['stage']:02X} cam={w['cam']:5d} spawns={w['spawns']} "
          f"top={top_stage} c6={c6} c7={c7}", flush=True)
    if c6 and c7:
        print("R-TYPE LANE C1..C7 7/7 PASS (tour complet stages 1..8)")
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
