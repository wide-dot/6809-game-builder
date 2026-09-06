# python3 tools/profile-stage.py <prefixe> : profile le stage 1 en jeu (100 trames a deux moments)
# puis python3 tools/symbolize-profile.py <prefixe> s1-debut s1-milieu
# profile le stage 1 en jeu : 100 trames a deux moments (ouverture, puis plus loin)
import sys, os, json
sys.path.insert(0,"/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder/ci/toje-bench")
G="/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder/games/r-type"; os.chdir(G)
from mcp import Toje, bench_block
IMG=os.path.abspath("dist/to8.fd"); BLOCK=bench_block(IMG); OUT=sys.argv[1]
def h(a): return format(a,"04X")
tj=Toje(); tj.boot_floppy(IMG); tj.call("set_pointer_device",{"device":"none"})
for i in range(10):
    tj.call("run_frames",{"n":500,"fast":True,"timeout_ms":600000})
    if tj.read(h(BLOCK),1)[0]==0xCA: break
for i in range(150):
    tj.press(); tj.call("run_frames",{"n":15,"fast":True,"timeout_ms":600000})
    if tj.read(h(BLOCK+1),1)[0]!=0: break
tj.call("write_memory",{"addr":h(BLOCK+8),"bytes":["00"]})
def prof(what, frames):
    tj.call("profile_reset"); tj.call("profile_start")
    tj.call("run_frames",{"n":frames,"fast":True,"timeout_ms":600000})
    tj.call("profile_stop")
    d={"top":tj.call("profile_top",{"n":60,"by":"cycles"}),"tree":tj.call("profile_flamegraph",{"format":"tree","max_depth":6}),"loops":tj.call("profile_loops",{})}
    json.dump(d, open(f"{OUT}-{what}.json","w"), indent=1)
    cam=tj.read(h(BLOCK+3),2); print(what, ": camera", (cam[0]<<8)|cam[1], "total cycles", d["top"]["total_cycles"], flush=True)
tj.call("run_frames",{"n":300,"fast":True,"timeout_ms":600000})
prof("s1-debut", 100)
tj.call("run_frames",{"n":1500,"fast":True,"timeout_ms":600000})
prof("s1-milieu", 100)
tj.close()
