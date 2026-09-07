"""Qui ecrit CMD2 ($E7D2) avec le moteur coupe (bits de drive a 0) pendant une lecture ?"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "ci", "toje-bench"))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from mcp import Toje
img=os.path.abspath("dist/to8.fd")
t=Toje(); t.call('boot_disk',{'path':img,'settle_frames':1})
t.call('run_frames',{'n':90,'fast':False,'timeout_ms':600000})      # en pleine lecture de scenes.boot
print("etat :", {k:v for k,v in t.call('disk_state').get('drive',{}).items() if k in ('motor_on','reads','track')})
w=t.call('set_watchpoint',{'addr':'E7D2','len':1,'label':'cmd2'}); print("watch", w)
hits=0; writers={}; events=0
for i in range(2000):
    r=t.call('run_to_breakpoint',{'max_instructions':3000000})
    rg=t.call('read_registers'); pc=int(rg['pc'],16)
    hits+=1
    writers[rg['pc']]=writers.get(rg['pc'],0)+1
    ds=t.call('disk_state').get('drive',{})
    if not ds.get('motor_on'):
        events+=1
        sp=int(rg['s'],16); st=t.read("%04X"%sp,16)
        ms=t.call('machine_state')
        print("=== moteur coupe #%d depuis pc=%s cc=%s  reads=%s  pile[S]=%s  cycles=%s"%(events,rg['pc'],rg['cc'],ds.get('reads')," ".join("%02X"%x for x in st), ms.get('total_cycles') if isinstance(ms,dict) else ms))
        ret=(st[0]<<8)|st[1]
        print("    appelant (retour) : %04X ->"%ret, [ (l['addr'],l['mnemonic']) for l in t.call('disassemble',{'addr':'%04X'%(ret-8),'lines':6}).get('lines',[])])
        if events>=4: break
    t.call('step',{})
print("ecritures vues :", hits, "par pc :", writers)
t.close()
