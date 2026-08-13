#!/usr/bin/env python3
"""Replay the games/r-type real game flow under toje, headless.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/rtype_bench.py dist/to8.fd [max_frames]

Witnesses at bench.BLOCK = $8766 (src/common/bench.const.asm, the
layout's <reserved name="bench"> block): magic $CA, stage byte (00 =
title, 01/02 = stages), frame counter, camera (word), spawns (word).
Since the de-benching (chantier 2) the game carries NO verdict flags:
the lane derives its five checks from that observable state, driving
the real flow — the image boots on the title, a key press starts the
game, level ends come from the real endstage sequence.

  C1  title -> stage 1 hand-over (press start until stage byte = 01)
  C2  stage 1 progresses (camera beyond 1000 of its 1440 px)
  C3  stage 1 -> stage 2 through the real end sequence (stage byte 02)
  C4  stage 2 runs its own data (spawns > 0 — the placeholder cast is
      reached through the freshly re-linked index: the re-link proof)
  C5  stage 2 hands back to the title (stage byte 00, magic still $CA)

On a wedge (state stops changing on timeouts), the engine log block,
registers, disassembly and a screenshot are dumped.

Exit code: 0 pass, 1 wedge/abort, 2 frame budget exceeded.
"""
import os, sys, time
from mcp import Toje

image = sys.argv[1]
max_frames = int(sys.argv[2]) if len(sys.argv) > 2 else 60000

t = Toje()
t.boot_floppy(image)

def witnesses():
    b = t.read("8766", 16)
    return {"magic": b[0], "stage": b[1],
            "cam": (b[3] << 8) | b[4], "spawns": (b[5] << 8) | b[6]}

# C1 — press start until the stage seeds the block. The title needs its
# loading plus the logo animation before the trigger is armed; pressing
# earlier is simply ignored, so poke every 200 frames.
frames = 215
while frames < 6000:
    w = witnesses()
    if w["magic"] == 0xCA and w["stage"] == 0x01:
        break
    t.press()
    r = t.call("run_frames", {"n": 200, "timeout_ms": 20000})
    ran = r.get("frames", 200)
    frames += ran if isinstance(ran, int) else 200
else:
    print("C1 FAIL — title never handed over to stage 1")
    t.dump("title ")
    t.close()
    sys.exit(1)
print(f"C1 title -> stage 1 hand-over at f={frames}", flush=True)

checks = {"C2": 0, "C3": 0, "C4": 0, "C5": 0}
last = None
stuck = 0
verdict = 2
t0 = time.time()
while frames < max_frames:
    r = t.call("run_frames", {"n": 500, "timeout_ms": 20000})
    ran = r.get("frames", 0)
    frames += ran if isinstance(ran, int) else 500
    w = witnesses()
    if w["stage"] == 0x01 and w["cam"] > 1000:
        checks["C2"] = 1
    if w["stage"] == 0x02:
        checks["C3"] = 1
        if w["spawns"] > 0:
            checks["C4"] = 1
    if checks["C3"] and w["stage"] == 0x00 and w["magic"] == 0xCA:
        checks["C5"] = 1
    flags = [checks[k] for k in ("C2", "C3", "C4", "C5")]
    print(f"f={frames:6d} wall={time.time() - t0:5.0f}s ran={ran} "
          f"to={r.get('timed_out')} magic={w['magic']:02X} "
          f"stage={w['stage']:02X} cam={w['cam']:5d} "
          f"spawns={w['spawns']} c={flags}", flush=True)
    if all(flags):
        print("R-TYPE LANE C1..C5 5/5 PASS")
        verdict = 0
        break
    key = (w["magic"], w["stage"], w["cam"], tuple(flags))
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
    print("FRAME BUDGET EXCEEDED without C1..C5")

t.close()
sys.exit(verdict)
