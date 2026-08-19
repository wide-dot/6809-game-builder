#!/usr/bin/env python3
"""Drive the r-type tour and, at each first entry into a stage, compare the
YMM bytes resident at page $1A offset $20BC (the music slot) with the file
the stage is supposed to play. Proves the per-stage music wiring: the right
track is in RAM, at the right place, after every scene swap.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 ci/toje-bench/music_probe.py games/r-type/dist/to8.fd

Reads use the DATA window ($A000-$DFFF, register $E7E5): the machine is
paused between MCP calls, so mount page $1A, read, restore. Register $E7E5
reads back on the TO8 (toje implements it), which gives the restore value.

Exit code: 0 all stages verified, 1 mismatch or wedge.
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp import Toje

image = sys.argv[1]
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                    "games", "r-type", "src")

MUSIC = {
    1: "stages/01/music/adnz/ymm/music.ymm",
    2: "stages/02/music/adnz/ymm/music.ymm",
    3: "stages/03/music/adnz/ymm/music.ymm",
    4: "stages/04/music/adnz/ymm/theme.ymm",
    5: "stages/05/music/adnz/ymm/music.ymm",
    6: "stages/01/music/adnz/ymm/music.ymm",   # no level-6 asset: replays 1
    7: "stages/07/music/adnz/ymm/rtype-stage4.ymm",
    8: "stages/08/music/adnz/ymm/theme.ymm",
}
BOSS = "common/flow/bossmusic/music/ymm/music.ymm"
# Every stage block up to 7 carries boss+clearstage (the shared names make
# each block an indexed pool file — affordable since the directory buffer
# went static). Stage 8 has no room for them, and its v1 index had neither.
HAS_BOSS = {1, 2, 3, 4, 5, 6, 7}

t = Toje()
t.boot_floppy(image)
t0 = time.time()
frames = 215


def witnesses():
    b = t.read("87DB", 8)
    return {"magic": b[0], "stage": b[1]}


def run(n):
    global frames
    r = t.call("run_frames", {"n": n, "timeout_ms": 20000})
    ran = r.get("frames", n)
    frames += ran if isinstance(ran, int) else n
    return r


def read_page_1a(offset, length):
    """Mount page $1A in the DATA window ($E7E7 bit4 + $E7E5, the engine's
    _ram.data.set gesture), read, then restore the page from read_page_map
    and the SYS1 register from its RAM shadow $6081 (reading $E7E5 back is
    the light pen, not the page)."""
    old_data = t.call("read_page_map")["data_page"]
    sys1 = t.read("6081", 1)[0]
    t.call("write_memory", {"addr": "E7E7", "bytes": [f"{sys1 | 0x10:02X}"]})
    t.call("write_memory", {"addr": "E7E5", "bytes": ["1A"]})
    # TO8 : la fenetre DATA presente la page avec ses moities de 8 Ko
    # croisees — l'offset de page $20BC se lit en $A0BC (mesure ici meme,
    # scan de la page 26 : la musique du stage 1 apparait a $A0BC).
    data = []
    for i in range(length):
        cpu = 0xA000 + ((offset + i + 0x2000) & 0x3FFF)
        data.append(t.read(f"{cpu:04X}", 1)[0])
    t.call("write_memory", {"addr": "E7E5", "bytes": [f"{old_data:02X}"]})
    t.call("write_memory", {"addr": "E7E7", "bytes": [f"{sys1:02X}"]})
    return data


def head(path, n=16):
    with open(os.path.join(root, path), "rb") as f:
        return list(f.read(n))


def check(stage):
    want = head(MUSIC[stage])
    got = read_page_1a(0x20BC, 16)
    ok = got == want
    verdicts = [f"theme {'OK' if ok else 'MISMATCH'}"]
    if stage in HAS_BOSS:
        size = os.path.getsize(os.path.join(root, MUSIC[stage]))
        want_b = head(BOSS, 8)
        got_b = read_page_1a(0x20BC + size, 8)
        okb = got_b == want_b
        ok = ok and okb
        verdicts.append(f"boss {'OK' if okb else 'MISMATCH'}")
    print(f"stage {stage}: {MUSIC[stage].split('/')[-1]:20s} "
          f"{' + '.join(verdicts)}"
          + ("" if ok else f"\n   want {bytes(want).hex()}\n   got  {bytes(got).hex()}"),
          flush=True)
    return ok


# press start until stage 1
deadline = frames + 6000
while frames < deadline:
    w = witnesses()
    if w["magic"] == 0xCA and w["stage"] == 0x01:
        break
    t.press()
    run(200)
else:
    print("FAIL — never reached stage 1")
    t.close(); sys.exit(1)

seen = set()
all_ok = True
last_stage, stuck = None, 0
while frames < 140000 and len(seen) < 8:
    w = witnesses()
    s = w["stage"]
    if w["magic"] == 0xCA and 1 <= s <= 8 and s not in seen:
        seen.add(s)
        if not check(s):
            all_ok = False
    r = run(500)
    stuck = stuck + 1 if (s == last_stage and r.get("timed_out")) else 0
    last_stage = s
    if stuck >= 4:
        print("MACHINE WEDGED"); t.dump("wedge "); all_ok = False
        break

missing = set(MUSIC) - seen
if missing:
    print(f"stages never entered: {sorted(missing)}")
    all_ok = False
print(f"MUSIC PROBE {'8/8 PASS' if all_ok and not missing else 'FAIL'} "
      f"(wall {time.time()-t0:.0f}s)")
t.close()
sys.exit(0 if all_ok and not missing else 1)
