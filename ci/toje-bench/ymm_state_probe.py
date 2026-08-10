"""Boot an r-type image, run to the stage-2 crawl, and dump the YMM player's
state the moment the CPU is inside its page : variables, ring content, and
compressed source. Addresses come from gen/sound/build/ymm.lwmap (unit base
$1C9B, the ymm.player region). This is the two-minute replay of the
consumer-phase desync diagnosis — see the readme's open item.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/ymm_state_probe.py games/r-type/dist/to8.fd
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mcp import Toje

t = Toje()
t.boot_floppy(sys.argv[1])
done = 0
while done < 16200:
    r = t.call("run_frames", {"n": 500, "timeout_ms": 15000})
    done += r.get("frames", 0) or 500
    if r.get("timed_out"):
        print(f"crawl at ~{done}")
        break
for i in range(8):
    t.call("run_frames", {"n": 10, "timeout_ms": 6000})
    regs = t.call("read_registers")
    pc = int(regs["pc"], 16)
    if 0x1C9B <= pc <= 0x20BC:      # inside the ymm player page window
        v = t.read("1CBC", 8)
        print(f"pc={regs['pc']} x={regs['x']} data={v[0]:02X}{v[1]:02X} "
              f"page={v[2]:02X} pos={v[3]:02X}{v[4]:02X} status={v[5]:02X} "
              f"waits={v[6]:02X} loop={v[7]:02X}")
        print("ring[1EBC]:", " ".join(f"{b:02X}" for b in t.read("1EBC", 48)))
        print("ring[2040]:", " ".join(f"{b:02X}" for b in t.read("2040", 48)))
        print("src [20BC]:", " ".join(f"{b:02X}" for b in t.read("20BC", 16)))
        break
    else:
        print(f"pc={regs['pc']} (elsewhere)")
t.close()
