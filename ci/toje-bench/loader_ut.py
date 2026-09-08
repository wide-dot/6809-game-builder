#!/usr/bin/env python3
"""Replay examples/loader-ut under toje, headless, including the disk swaps.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/loader_ut.py dist/to8.fd dist/to8-disk1.fd

Result table at $9C00 (see the game mode's main.asm): +0 magic $CA,
+1..+18 one byte per test, +27 disk handshake ($D1 = the bench waits for
disk 1, $D3 = for disk 0 — mount it and press any key), +31 final status
($0D = all pass, $E0+n = n failures). T18 wedges the machine ON PURPOSE
after +31 is written; on no-verdict the engine log block is dumped.

Exit code: 0 pass, 1 fail, 2 no verdict.
"""
import sys, os, time
from mcp import Toje

disk0, disk1 = sys.argv[1], sys.argv[2]
t = Toje()
t.boot_floppy(disk0)

t0 = time.time()
mounted = 0
verdict = 2
for i in range(600):
    t.call("run_frames", {"n": 100, "timeout_ms": 20000})
    b = t.read("9C00", 32)
    status, hand = b[31], b[27]
    print(f"i={i:3d} wall={time.time() - t0:4.0f}s magic={b[0]:02X} "
          f"slots={' '.join(f'{x:02X}' for x in b[1:19])} "
          f"hand={hand:02X} status={status:02X}", flush=True)
    if hand == 0xD1 and mounted != 1:
        print(">> mounting disk 1")
        t.call("mount_disk", {"path": disk1})
        mounted = 1
        t.press()
    elif hand == 0xD3 and mounted != 0:
        print(">> mounting disk 0")
        t.call("mount_disk", {"path": disk0})
        mounted = 0
        t.press()
    if status != 0:
        if status == 0x0D:
            # T18 fires AFTER the status : it provokes the overlap trap on
            # purpose and wedges the machine. Let it run, then check the log.
            t.call("run_frames", {"n": 200, "timeout_ms": 10000})
            lb = t.read("9EF0", 3)
            code = (lb[0] << 8) | lb[1]
            if code == 0x8301:
                print("LOADER-UT PASS (status $0D, T18 trap log $8301)")
                verdict = 0
            else:
                print(f"LOADER-UT FAIL (status $0D but T18 log.code={code:04X},"
                      " expected $8301)")
                # the whole log block : page, site, and D/X/Y/U as photographed
                # (a tlsf trap, $8101, carries the tlsf.err code in A)
                lb = t.read("9EF0", 13)
                print("  log.block : page %02X pc %04X D %04X X %04X Y %04X U %04X"
                      % (lb[2], (lb[3] << 8) | lb[4], (lb[5] << 8) | lb[6],
                         (lb[7] << 8) | lb[8], (lb[9] << 8) | lb[10], (lb[11] << 8) | lb[12]))
                # the TLSF pool, block by block (size word : bit 15 = free,
                # 15 bits = size-1 ; then prev.phys), from the loader's map
                try:
                    import re as _re
                    lm = os.path.join(os.path.dirname(os.path.dirname(disk0)), "gen", "bootloader", "build", "loader.lwmap")
                    sy = {}
                    for l in open(lm):
                        m = _re.match(r"Symbol: (\S+) .*= ([0-9A-F]{4})", l)
                        if m: sy[m.group(1)] = int(m.group(2), 16)
                    pool = t.read("%04X" % sy["tlsf.memoryPool"], 2); pool = (pool[0] << 8) | pool[1]
                    end = t.read("%04X" % sy["tlsf.memoryPool.end"], 2); end = (end[0] << 8) | end[1]
                    p, rows, free_total, biggest = pool, [], 0, 0
                    while p + 4 <= end and len(rows) < 80:
                        h = t.read("%04X" % p, 4); size = ((h[0] & 0x7F) << 8 | h[1]) + 1; free = bool(h[0] & 0x80)
                        rows.append("%04X:%s%d" % (p + 4, "free" if free else "used", size))
                        if free: free_total += size; biggest = max(biggest, size)
                        p += 4 + size
                    print("  pool $%04X-$%04X : %s" % (pool, end, " ".join(rows)))
                    print("  free %d bytes, biggest free block %d" % (free_total, biggest))
                except Exception as e:
                    print("  (pool walk failed :", e, ")")
                verdict = 1
        else:
            print(f"LOADER-UT FAIL (status ${status:02X})")
            verdict = 1
        break
else:
    print("LOADER-UT NO VERDICT")
    t.dump()

t.close()
sys.exit(verdict)
