#!/usr/bin/env python3
"""Replay examples/collection under toje, headless.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/collection_ut.py dist/to8.fd

Result table at $9C00 (see the game mode's main.asm): +0 magic $CA,
+1..+4 one byte per test, +7 final status ($0D = all pass, $E0+n = n
failures).

Exit code: 0 pass, 1 fail, 2 no verdict.
"""
import sys, time
from mcp import Toje

t = Toje()
t.boot_floppy(sys.argv[1])

t0 = time.time()
verdict = 2
for i in range(120):
    t.call("run_frames", {"n": 50, "timeout_ms": 20000})
    b = t.read("9C00", 8)
    status = b[7]
    print(f"i={i:3d} wall={time.time() - t0:4.0f}s magic={b[0]:02X} "
          f"t={' '.join(f'{x:02X}' for x in b[1:5])} status={status:02X}",
          flush=True)
    if status != 0:
        if status == 0x0D:
            print("COLLECTION-UT PASS (status $0D)")
            verdict = 0
        else:
            print(f"COLLECTION-UT FAIL (status ${status:02X})")
            verdict = 1
        break
else:
    print("COLLECTION-UT NO VERDICT")
    t.dump()

t.close()
sys.exit(verdict)
