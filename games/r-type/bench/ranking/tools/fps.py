#!/usr/bin/env python3
"""Le releve de fps des ecrans de classement, sur le banc.

    python3 tools/fps.py [sortie]      # depuis bench/ranking, banc construit

Boote dist/to8.fd sous toje, attend le temoin, puis echantillonne toutes les
STEP trames : gfxlock.frame.count (trames 50 Hz), gfxlock.bufferSwap.count
(echanges de tampons = iterations de la boucle), ranking.painter (l'ecran
en cours) et bench.frames (le tour). fps = echanges / trames x 50 sur une
fenetre glissante. Sortie : <sortie>.csv et <sortie>.png (PIL, sans
matplotlib). Les adresses viennent des cartes lwasm et de gen/layout.asm.
"""
import sys, os, re
HERE=os.path.dirname(os.path.abspath(__file__)); B=os.path.dirname(HERE)
sys.path.insert(0, os.path.join(B, "..", "..", "..", "..", "ci", "toje-bench"))
os.chdir(B)
from mcp import Toje, bench_block, layout_symbol
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv)>1 else "fps-reference"
STEP, TOTAL, WINDOW = 5, 3000, 25          # trames entre deux mesures, duree, fenetre fps
IMG=os.path.abspath("dist/to8.fd"); LAYOUT=os.path.join(B,"gen/layout.asm")

def sym(lwmap, base, name):
    with open(lwmap) as f:
        for l in f:
            m=re.match(r"Symbol: %s \(.*\) = ([0-9A-F]+)"%re.escape(name), l)
            if m: return base+int(m.group(1),16)
    raise SystemExit("symbole absent : "+name)
ENG=layout_symbol("engine", IMG, layout=LAYOUT); RNK=layout_symbol("ranking", IMG, layout=LAYOUT)
FRAME=sym("gen/common/build/engine.lwmap", ENG, "gfxlock.frame.count")
SWAP =sym("gen/common/build/engine.lwmap", ENG, "gfxlock.bufferSwap.count")
PAINTER=sym("gen/ranking/build/ranking.lwmap", RNK, "ranking.painter")
PHASES={sym("gen/ranking/build/ranking.lwmap", RNK, n): lab for n,lab in
        [("ranking.loop.black","noir"),("ranking.scr.paint","revelation"),
         ("ranking.in.paint","saisie"),("ranking.tbl.paint","tableau")]}
STG=layout_symbol("stage", IMG, layout=LAYOUT)
WAIT=sym("gen/bench/build/main.lwmap", STG, "bench.wait")   # != 0 : le noir entre deux tours
BLOCK=bench_block(IMG, layout=LAYOUT)
def h(a): return format(a,"04X")
def w16(b): return (b[0]<<8)|b[1]

tj=Toje(); print("boot =", tj.boot_floppy(IMG).get("booted"), flush=True)
tj.call("set_pointer_device",{"device":"none"})
for i in range(120):                       # le temoin, au pas de 20 trames : la
    tj.call("run_frames",{"n":20,"fast":True,"timeout_ms":600000}) # premiere revelation
    if tj.read(h(BLOCK),1)[0]==0xCA: break # est dans le releve
rows=[]; tours=None
for i in range(TOTAL//STEP):
    tj.call("run_frames",{"n":STEP,"fast":True,"timeout_ms":600000})
    fr=w16(tj.read(h(FRAME),2)); sw=w16(tj.read(h(SWAP),2))
    pt=w16(tj.read(h(PAINTER),2)); tr=tj.read(h(BLOCK+2),1)[0]
    phase=PHASES.get(pt,"?")
    if tj.read(h(WAIT),1)[0]: phase="entre-tours"
    rows.append((fr,sw,phase,tr)); tours=tr
    if i==60:                               # l'ecran de saisie : la case 0 vide ?
        p=OUT+"-saisie.png"; tj.call("screenshot",{"path":p})
        lit=sum(1 for q in Image.open(p).convert('L').get_flattened_data() if q>40)
        print("ecran de saisie :", lit, "px (5456 = case 0 vide, 5544 = un A commis)", flush=True)
tj.close()

# fps sur fenetre glissante
f0=rows[0][0]; pts=[]
n=max(1,WINDOW//STEP)
for k in range(n,len(rows)):
    df=(rows[k][0]-rows[k-n][0])&0xFFFF; ds=(rows[k][1]-rows[k-n][1])&0xFFFF
    fps=50.0*ds/df if df else 0.0
    pts.append(((rows[k][0]-f0)&0xFFFF, fps, rows[k][2]))
with open(OUT+".csv","w") as f:
    f.write("trame,fps,phase\n")
    for t,fps,ph in pts: f.write(f"{t},{fps:.2f},{ph}\n")
# par phase
stats={}
for t,fps,ph in pts: stats.setdefault(ph,[]).append(fps)
for ph,v in stats.items(): print(f"  {ph:12s} {len(v):4d} mesures  fps min/moy/max = {min(v):.1f} / {sum(v)/len(v):.1f} / {max(v):.1f}")
# le graphe
W,H=1200,420; L,R,T,Bm=60,20,30,50
im=Image.new("RGB",(W,H),(255,255,255)); d=ImageDraw.Draw(im)
COL={"noir":(60,60,60),"revelation":(90,150,230),"saisie":(120,200,120),"tableau":(230,170,80),"entre-tours":(200,200,200),"?":(255,0,0)}
tmax=max(t for t,_,_ in pts) or 1
def X(t): return L+(W-L-R)*t/tmax
def Y(v): return T+(H-T-Bm)*(1-min(v,50)/50)
prev=None
for t,fps,ph in pts:                       # les bandes de phase
    if prev: d.rectangle([X(prev[0]),T,X(t),H-Bm], fill=tuple(min(255,c+40) for c in COL[ph]))
    prev=(t,fps,ph)
for v in (10,20,25,30,40,50):
    d.line([L,Y(v),W-R,Y(v)], fill=(120,120,120)); d.text((8,Y(v)-6),f"{v} fps",fill=(0,0,0))
for s in range(0,int(tmax/50)+1,5):
    d.line([X(s*50),H-Bm,X(s*50),H-Bm+5], fill=(0,0,0)); d.text((X(s*50)-6,H-Bm+8),f"{s}s",fill=(0,0,0))
d.line([(X(t),Y(fps)) for t,fps,_ in pts], fill=(0,0,0), width=2)
x=L
for ph,c in COL.items():
    if ph in stats:
        d.rectangle([x,H-22,x+12,H-10], fill=c); d.text((x+16,H-24),f"{ph} ({sum(stats[ph])/len(stats[ph]):.1f})",fill=(0,0,0)); x+=170
d.text((L,8),"ecrans de classement — fps (echanges de tampons / trames 50 Hz), fenetre %d trames" % WINDOW, fill=(0,0,0))
im.save(OUT+".png"); print("->", OUT+".png", OUT+".csv")
