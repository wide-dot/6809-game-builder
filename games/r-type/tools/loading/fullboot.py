"""Du reset au title, toutes les 4 trames : ou est le CPU."""
import sys, os, re, collections
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "ci", "toje-bench"))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from mcp import Toje, bench_block
LS=[]
for l in open("gen/bootloader/build/loader.lwmap"):
    m=re.match(r"Symbol: (\S+) .*= ([0-9A-F]{4})", l)
    if m and not m.group(1).startswith("@") and not m.group(1).startswith("builder."): LS.append((int(m.group(2),16),m.group(1)))
LS.sort()
def lsym(pc):
    n="?"
    for a,s in LS:
        if a<=pc: n=s
    return n
img=os.path.abspath("dist/to8.fd"); BLOCK=bench_block(img)
t=Toje(); r=t.call('boot_disk',{'path':img,'settle_frames':1}); print('boot_disk :', r)
def W(): b=t.read("%04X"%BLOCK,2); return b[0],b[1]
h=collections.Counter(); order=[]; f=0; loader_seen=False; game_seen=False; first_loader=None; first_game=None
while f<2600:
    t.call('run_frames',{'n':4,'fast':False,'timeout_ms':600000}); f+=4
    pc=int(t.call('read_registers')['pc'],16)
    if 0xC000<=pc<0xE000 and not loader_seen: loader_seen=True; first_loader=f
    if 0x6100<=pc<0x6300 and not game_seen and loader_seen: game_seen=True; first_game=f
    if pc>=0xE000:
        k="ROM avant le loader (menu TO8, secteur de boot, lecture du loader)" if not loader_seen else "ROM : DKCONT (attente + lecture)"
    elif 0xC000<=pc<0xE000:
        n=lsym(pc)
        if "zx0" in n or n.startswith(("loop@","done@","skip@")): k="zx0 : decompression"
        elif "symbol" in n or "link" in n or "linkData" in n: k="lien"
        elif "tlsf" in n: k="tlsf"
        elif "ldsec" in n or "tfrxua" in n or "ld" in n[:3]: k="loader : lecture (hors DKCONT)"
        else: k="loader : autre (%s)"%n
    elif 0x6100<=pc<0x6300: k="fondu / splash (attente VBL)"
    elif 0x6000<=pc<0xA000: k="code jeu resident"
    elif pc<0x4000: k="code jeu cartouche"
    else: k="autre %04X"%pc
    h[k]+=4; order.append((f,k))
    if W()==(0xCA,0): break
print("title a la trame", f, "(%.1f s) ; premier PC loader trame %s ; premier PC fondu trame %s"%(f/50, first_loader, first_game))
for k,v in h.most_common(): print("   %5.1f s  %3.0f%%  %s"%(v/50,100*v/f,k))
# chronologie condensee
cur=None; start=0
for fr,k in order:
    if k!=cur:
        if cur is not None and fr-start>=40: print("  t=%4d..%4d  %-60s"%(start,fr,cur))
        cur=k; start=fr
t.close()
