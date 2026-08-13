#!/usr/bin/env python3
"""Replay the games/r-type stage-swap bench under toje, headless.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/rtype_bench.py dist/to8.fd [max_frames]

Witnesses at bench.BLOCK = $8766 (src/common/bench.const.asm, the
layout's <reserved name="bench"> block): magic $CA, stage, frame counter,
camera (word), spawns (word), then t1..t5 at +7..+11 — [1,1,1,1,1] is the
5/5 pass. The scenario runs
at the game's real scroll speed, so a full pass is ~25000 emulated
frames. On a wedge (run_frames stops advancing), the engine log block,
registers, disassembly and a screenshot are dumped.

Since T4 the image boots on the TITLE: the bench walks through the real
game entry — it repeatedly presses a key until the stage seeds the bench
block (the title only arms its trigger once the logo holds), then runs
the usual scenario. One image, one truth: the attract chain is covered by
the same lane.

Exit code: 0 pass, 1 wedge/abort, 2 frame budget exceeded.
"""
import os, sys, time
from mcp import Toje

image = sys.argv[1]
max_frames = int(sys.argv[2]) if len(sys.argv) > 2 else 60000

t = Toje()
t.boot_floppy(image)

# press start until the stage has seeded the bench block ($CA). The title
# needs ~1700 frames of loading plus the logo animation before its trigger
# is armed; pressing earlier is simply ignored, so poke every 200 frames.
frames = 215
while frames < 6000:
    b = t.read("8766", 1)
    if b[0] == 0xCA:
        break
    t.press()
    r = t.call("run_frames", {"n": 200, "timeout_ms": 20000})
    ran = r.get("frames", 200)
    frames += ran if isinstance(ran, int) else 200
else:
    print("TITLE NEVER HANDED OVER — no bench magic after press-start loop")
    t.dump("title ")
    t.close()
    sys.exit(1)
print(f"title -> stage 1 hand-over at f={frames}", flush=True)
last = None
stuck = 0
verdict = 2
t0 = time.time()
while frames < max_frames:
    r = t.call("run_frames", {"n": 500, "timeout_ms": 20000})
    ran = r.get("frames", 0)
    frames += ran if isinstance(ran, int) else 500
    b = t.read("8766", 16)
    magic, stage = b[0], b[1]
    cam = (b[3] << 8) | b[4]
    tflags = b[7:12]
    print(f"f={frames:6d} wall={time.time() - t0:5.0f}s ran={ran} "
          f"to={r.get('timed_out')} magic={magic:02X} stage={stage:02X} "
          f"cam={cam:5d} t={tflags}", flush=True)
    if tflags == [1, 1, 1, 1, 1]:
        print("R-TYPE BENCH 5/5 PASS")
        verdict = 0
        break
    key = (magic, stage, cam, tuple(tflags))
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
    print("FRAME BUDGET EXCEEDED without 5/5")

t.close()
sys.exit(verdict)
