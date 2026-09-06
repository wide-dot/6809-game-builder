import re, json, glob, sys, bisect, os
G="/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder/games/r-type"; os.chdir(G)
h=open("dist/occupancy-fd.html").read(); best=None
for mm in re.finditer(r'\{"', h):
    i=mm.start()
    try:
        obj,end=json.JSONDecoder().raw_decode(h[i:])
        if best is None or end>best[1]: best=(obj,end)
    except Exception: pass
loads={}
for sc in best[0]['ram']['scenes']:
    for l in sc['loads']:
        if l.get('size') and 'page' in l: loads[l['name']]=(l['page'],l['address'])
cfg=open("to8.config.xml").read()
units={}
for m in re.finditer(r'<file name="([^"]+)"[^>]*>\s*(?:<!--.*?-->\s*)*<lwasm[^>]*gensource="([^"]+)"', cfg, re.S):
    units[m.group(2)]=m.group(1)
syms=[]
for gs,unit in units.items():
    lst=os.path.join(os.path.dirname(gs),"build",os.path.basename(gs)[:-4]+".lst")
    if not os.path.exists(lst) or unit not in loads: continue
    page,base=loads[unit]
    for l in open(lst, errors="replace"):
        m=re.match(r"^([0-9A-F]{4})\s+(?:[0-9A-F]{2}\s)*\s*\(([^)]*)\):\d+\s+([A-Za-z_][\w.]*)(\s.*)?$", l)
        if not m: continue
        rest=(m.group(4) or "").strip().lower()
        if rest.startswith(("equ","set")) or m.group(3).startswith("@"): continue
        syms.append((base+int(m.group(1),16), m.group(3), unit, page))
syms.sort(); addrs=[a for a,_,_,_ in syms]
def name(pc):
    i=bisect.bisect_right(addrs,pc)-1
    if i<0: return f"${pc:04X}"
    a,n,u,p=syms[i]
    return f"{n}" if pc-a<0x400 else f"${pc:04X}"
def walk(node, depth, total, out, prefix=""):
    for c in sorted(node.get("children",[]), key=lambda c:-c["cycles"]):
        if c["cycles"]<total*0.01: continue
        out.append(f"{prefix}{100*c['cycles']/total:5.1f}%  {name(int(c['pc'],16))}")
        if depth>1: walk(c, depth-1, total, out, prefix+"    ")
for what in sys.argv[2:]:
    d=json.load(open(f"{sys.argv[1]}-{what}.json")); tot=d["top"]["total_cycles"]
    print(f"=== {what} : {tot} cycles / 100 trames = {tot/100:.0f} par trame ; exclusif (top regroupes) :")
    agg={}
    for r in d["top"]["rows"]:
        n=name(int(r["pc"],16)); agg[n]=agg.get(n,0)+r["cycles"]
    for n,c in sorted(agg.items(), key=lambda kv:-kv[1])[:10]: print(f"  {100*c/tot:5.1f}%  {n}")
    out=[]; walk(d["tree"]["tree"], 3, tot, out); print("--- arbre inclusif (>= 1 %) :"); print("\n".join(out))
    print("--- boucles chaudes :", str(d["loops"])[:600])
