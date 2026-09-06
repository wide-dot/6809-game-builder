# python3 tools/symbolize.py <prefixe> : symbolise les profils de profile.py avec les listings .lst
# (toje ne connait pas les bases de placement ; les unites en page partagent la fenetre
# cartouche, un nom peut donc venir d une autre page : verifier avec le contexte).
import re, json, glob, sys, bisect, os
B="/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder/games/r-type/bench/ranking"; os.chdir(B)
occ=open("dist/occupancy-fd.html").read()
place={m.group(1):int(m.group(3)) for m in re.finditer(r'"name":"([^"]+)","container":"([^"]*)","page":\d+,"address":(\d+)', occ)}
lay={m.group(1):int(m.group(2),16) for m in re.finditer(r"^(\S+)\.address equ \$([0-9A-F]+)", open("gen/layout.asm").read(), re.M)}
bases={"gen/common/build/engine.lst":lay["engine"],"gen/ranking/build/ranking.lst":lay["ranking"],"gen/bench/build/main.lst":lay["stage"]}
for f in glob.glob("gen/**/build/*.lst", recursive=True):
    if f in bases: continue
    nm=os.path.basename(f)[:-4]; cand=[k for k in place if k.endswith("."+nm)]
    if len(cand)==1: bases[f]=place[cand[0]]
syms=[]
for f,base in bases.items():
    unit=os.path.basename(f)[:-4]
    for l in open(f, errors="replace"):
        m=re.match(r"^([0-9A-F]{4})\s+(?:[0-9A-F]{2}\s)*\s*\(([^)]*)\):\d+\s+([A-Za-z_][\w.]*)(\s.*)?$", l)
        if not m: continue
        rest=(m.group(4) or "").strip().lower()
        if rest.startswith(("equ","set")) or m.group(3).startswith("@"): continue
        syms.append((base+int(m.group(1),16), m.group(3), unit))
syms.sort(); addrs=[a for a,_,_ in syms]
def name(pc):
    i=bisect.bisect_right(addrs,pc)-1
    if i<0: return f"${pc:04X}"
    a,n,u=syms[i]
    return n if pc-a<0x300 else f"${pc:04X}"
def walk(node, depth, total, out, prefix=""):
    for c in sorted(node.get("children",[]), key=lambda c:-c["cycles"]):
        if c["cycles"]<total*0.01: continue
        out.append(f"{prefix}{100*c['cycles']/total:5.1f}%  {name(int(c['pc'],16))}")
        if depth>1: walk(c, depth-1, total, out, prefix+"    ")
for what in ("saisie","tableau"):
    d=json.load(open(f"{sys.argv[1]}-{what}.json")); tot=d["top"]["total_cycles"]
    print(f"=== {what} : {tot} cycles / 200 trames ; par PC (exclusif, top 30 regroupes) :")
    agg={}
    for r in d["top"]["rows"]:
        n=name(int(r["pc"],16)); agg[n]=agg.get(n,0)+r["cycles"]
    for n,c in sorted(agg.items(), key=lambda kv:-kv[1])[:8]: print(f"  {100*c/tot:5.1f}%  {n}")
    out=[]; walk(d["tree"]["tree"], 3, tot, out); print("--- arbre inclusif (>= 1 %) :"); print("\n".join(out))
