"""Combien de temps coute UN secteur (argument `boot` : depuis la touche B) : on lit nsect/track/sector du loader a
chaque trame pendant l'amorcage, et on mesure l'ecart (en trames de 20 ms)
entre deux lectures de secteur. 1-2 trames = l'entrelacement tient ;
~10 trames = un tour de disque perdu par secteur."""
import sys, os, re, collections
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "ci", "toje-bench"))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from mcp import Toje, bench_block
def equ(n):
    for l in open("gen/bootloader/build/loader.lwmap"):
        m=re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)'%re.escape(n),l)
        if m: return int(m.group(1),16)
TRACK=equ("track"); NSECT=equ("nsect")
img=os.path.abspath("dist/to8.fd"); BLOCK=bench_block(img)
t=Toje()
if "boot" in sys.argv[1:]:                  # depuis la touche B (boot_disk, settle 1) : la sequence entiere
    t.call('boot_disk',{'path':img,'settle_frames':1})
else:                                       # apres boot_floppy (1200 trames de settle) : la fin seulement
    t.boot_floppy(img)
def W(): b=t.read("%04X"%BLOCK,2); return b[0],b[1]
def state():
    pm=t.call('read_page_map'); dp=pm.get('data_page'); t.call('write_memory',{'addr':'E7E5','bytes':['04']})
    b=t.read("%04X"%TRACK,2); n=t.read("%04X"%NSECT,1)[0]
    t.call('write_memory',{'addr':'E7E5','bytes':['%02X'%dp]})
    return (b[0]>>1, b[0]&1, b[1], n)
gaps=collections.Counter(); prev=None; last_change=0; f=0; changes=0; timeline=[]
while f<3000:
    t.call('run_frames',{'n':1,'fast':False,'timeout_ms':600000}); f+=1
    s=state()
    if s!=prev:
        if prev is not None and s[:3]!=prev[:3]:
            gaps[f-last_change]+=1; changes+=1; timeline.append((f, f-last_change, prev, s))
        last_change=f; prev=s
    if W()==(0xCA,0): break
print("secteurs lus :", changes, "sur", f, "trames")
for g,c in sorted(gaps.items()): print("  ecart %2d trames (%3d ms) : %4d secteurs"%(g,g*20,c))
print("--- chronologie des ecarts >= 5 trames : trame, ecart, (piste,face,index,nsect restant) avant -> apres")
for f_,g,a,b in timeline:
    if g>=5: print("  t=%4d  %3d trames  %s -> %s"%(f_,g,a,b))
print("--- lectures rapides par tranche de 100 trames")
import itertools
for k in range(0, 1900, 100):
    n=sum(1 for f_,g,a,b in timeline if k<=f_<k+100 and g<=2); m=sum(1 for f_,g,a,b in timeline if k<=f_<k+100 and g>=9)
    print("  t=%4d..%4d : %3d lectures a 20-40 ms, %2d a >=180 ms"%(k,k+99,n,m))
t.close()
