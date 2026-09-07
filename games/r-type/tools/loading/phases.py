"""Ou passe le temps de chargement : PC echantillonne toutes les 5 trames pendant
l'amorcage (jusqu'au title) puis pendant title -> stage 1, classe par phase."""
import sys, os, re, collections
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "ci", "toje-bench"))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from mcp import Toje, bench_block
def syms(mf):
    out=[]
    for l in open(mf):
        m=re.match(r"Symbol: (\S+) .*= ([0-9A-F]{4})", l)
        if m and not m.group(1).startswith("@") and not m.group(1).startswith("builder."): out.append((int(m.group(2),16),m.group(1)))
    return sorted(out)
LS=syms("gen/bootloader/build/loader.lwmap")
def unit(n):
    o=open('dist/occupancy-fd.html').read()
    m=re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'%re.escape(n),o)
    return int(m.group(1)),int(m.group(2))
def equ(mf,n):
    for l in open(mf):
        m=re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)'%re.escape(n),l)
        if m: return int(m.group(1),16)
def where(pc):
    if pc>=0xE000: return "moniteur ROM (DKCONT : attente disque + lecture)"
    if 0xC000<=pc<0xE000:
        n="?"
        for a,s in LS:
            if a<=pc: n=s
        for key,lab in (("decompress","zx0 : decompression"),("zx0","zx0 : decompression"),("symbol.search","lien : recherche de symboles"),("link","lien : relocations"),("linkData","lien : relocations"),("dir.","repertoire"),("ldsec","lecture : boucle secteurs"),("file.load","lecture : boucle secteurs"),("tfrxua","lecture : copie partielle"),("tlsf","tlsf"),("scene","scene : table"),("composition","scene : table")):
            if key in n: return lab
        return "loader : autre (%s)"%n
    if 0x6000<=pc<0xA000: return "code jeu (resident)"
    if pc<0x4000: return "code jeu (cartouche)"
    return "autre %04X"%pc
img=os.path.abspath("dist/to8.fd"); BLOCK=bench_block(img)
_,ENG=unit('common.engine'); WAIT=ENG+equ('gen/common/build/engine.lwmap','gfxlock.bufferSwap.wait')
page,base=unit('title.cheat'); pstage=equ('gen/title/build/cheat.lwmap','tct.pstage'); launch=equ('gen/title/build/cheat.lwmap','title.cheat.launch')
t=Toje(); t.boot_floppy(img)
def W(): b=t.read("%04X"%BLOCK,2); return b[0],b[1]
def sample(stop, label, maxf=6000):
    h=collections.Counter(); f=0
    while f<maxf:
        t.call('run_frames',{'n':5,'fast':False,'timeout_ms':600000}); f+=5
        h[where(int(t.call('read_registers')['pc'],16))]+=5
        if stop(): break
    tot=sum(h.values()); print("== %s : %d trames (%.1f s)"%(label,tot,tot/50))
    for k,v in h.most_common(): print("   %5.1f s  %4.0f%%  %s"%(v/50,100*v/tot,k))
sample(lambda: W()==(0xCA,0), "amorcage -> title (fondu, splash, scenes.boot + title)")
t.call('run_frames',{'n':300,'fast':False,'timeout_ms':600000})
b1=t.call('set_breakpoint',{'pc':'%04X'%WAIT}); t.call('run_to_breakpoint',{'timeout_ms':120000}); t.call('clear_breakpoint',{'id':b1['id']})
t.call('write_memory',{'addr':'E7E6','bytes':['%02X'%(0x60+page)]})
t.call('write_memory',{'addr':hex(base+pstage),'bytes':['01','01']})
t.call('set_register',{'reg':'dp','value':'9F'}); t.call('set_register',{'reg':'pc','value':'%04X'%(base+launch)})
sample(lambda: W()[1]==1, "title -> stage 1")
t.close()
