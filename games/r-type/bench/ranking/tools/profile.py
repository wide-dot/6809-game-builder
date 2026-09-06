# python3 tools/profile.py <prefixe> : profile la saisie puis le tableau sous toje, 200 trames chacun,
# et ecrit <prefixe>-saisie.json et <prefixe>-tableau.json (top, arbre, boucles).
# profile la saisie puis le tableau, sur le banc
import sys, os, re, json
sys.path.insert(0,"/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder/ci/toje-bench")
B="/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder/games/r-type/bench/ranking"
os.chdir(B)
from mcp import Toje, bench_block, layout_symbol
IMG=os.path.abspath("dist/to8.fd"); LAYOUT=B+"/gen/layout.asm"; OUT=sys.argv[1]
def sym(lwmap, base, name):
    for l in open(lwmap):
        m=re.match(r"Symbol: %s \(.*\) = ([0-9A-F]+)"%re.escape(name), l)
        if m: return base+int(m.group(1),16)
RNK=layout_symbol("ranking", IMG, layout=LAYOUT)
PAINTER=sym("gen/ranking/build/ranking.lwmap", RNK, "ranking.painter")
IN=sym("gen/ranking/build/ranking.lwmap", RNK, "ranking.in.paint"); TBL=sym("gen/ranking/build/ranking.lwmap", RNK, "ranking.tbl.paint")
BLOCK=bench_block(IMG, layout=LAYOUT)
def h(a): return format(a,"04X")
def say(*a): print(*a,flush=True)
tj=Toje(); say("boot =", tj.boot_floppy(IMG).get("booted"))
tj.call("set_pointer_device",{"device":"none"})
say("symboles :", str(tj.call("load_symbols",{"path":B}))[:300])
for i in range(120):
    tj.call("run_frames",{"n":20,"fast":True,"timeout_ms":600000})
    if tj.read(h(BLOCK),1)[0]==0xCA: break
def painter(): b=tj.read(h(PAINTER),2); return (b[0]<<8)|b[1]
def wait_painter(v, what):
    for i in range(400):
        tj.call("run_frames",{"n":10,"fast":True,"timeout_ms":600000})
        if painter()==v: say(f"{what} atteint apres {(i+1)*10} tr"); return
    raise SystemExit(what+" jamais atteint")
def profile(what, frames):
    tj.call("run_frames",{"n":20,"fast":True,"timeout_ms":600000})   # l'ecran est stable
    tj.call("profile_reset"); tj.call("profile_start")
    tj.call("run_frames",{"n":frames,"fast":True,"timeout_ms":600000})
    tj.call("profile_stop")
    top=tj.call("profile_top",{"n":30,"by":"cycles"})
    tree=tj.call("profile_flamegraph",{"format":"tree","max_depth":5})
    loops=tj.call("profile_loops",{})
    json.dump({"top":top,"tree":tree,"loops":loops}, open(f"{OUT}-{what}.json","w"), indent=1)
    say(f"=== {what} : top ({frames} trames)"); say(json.dumps(top, ensure_ascii=False)[:3000])
wait_painter(IN,"saisie"); profile("saisie", 200)
wait_painter(TBL,"tableau"); profile("tableau", 200)
tj.close()
