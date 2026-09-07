"""L'evenement de 440-880 ms par piste : que fait la machine pendant ?"""
import sys, os, re
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "ci", "toje-bench"))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from mcp import Toje, bench_block
def equ(n):
    for l in open("gen/bootloader/build/loader.lwmap"):
        m=re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)'%re.escape(n),l)
        if m: return int(m.group(1),16)
TRACK=equ("track"); NSECT=equ("nsect")
img=os.path.abspath("dist/to8.fd"); BLOCK=bench_block(img)
t=Toje(); t.call('boot_disk',{'path':img,'settle_frames':1})
def W(): b=t.read("%04X"%BLOCK,2); return b[0],b[1]
def lstate():
    pm=t.call('read_page_map'); dp=pm.get('data_page'); t.call('write_memory',{'addr':'E7E5','bytes':['04']})
    b=t.read("%04X"%TRACK,2); n=t.read("%04X"%NSECT,1)[0]
    t.call('write_memory',{'addr':'E7E5','bytes':['%02X'%dp]})
    return (b[0]>>1, b[0]&1, b[1], n)
rows=[]
for f in range(1100):
    t.call('run_frames',{'n':1,'fast':False,'timeout_ms':600000})
    d=t.call('disk_state'); dr=d.get('drive',d)
    pc=t.call('read_registers')['pc']
    rows.append((f, lstate(), pc, dr.get('reads'), dr.get('seeks'), dr.get('track'), dr.get('requested_track'), dr.get('requested_sector'), dr.get('stat0'), dr.get('stat1'), dr.get('motor_on')))
    if W()==(0xCA,0): break
# les trous : etat loader inchange >= 12 trames
prev=rows[0]; start=0
for i,r in enumerate(rows[1:],1):
    if r[1][:3]!=prev[1][:3]:
        if i-start>=12 and rows[start][1][3]!=0:
            print("--- trou de %d trames avant la lecture de %s (piste,face,index,nsect)"%(i-start, r[1]))
            for k in range(max(0,start-1), i+1):
                x=rows[k]; print("   f=%4d loader=%s pc=%s reads=%s seeks=%s head=%s req=%s/%s stat0=%s stat1=%s motor=%s"%(x[0],x[1],x[2],x[3],x[4],x[5],x[6],x[7],x[8],x[9],x[10]))
        start=i
    prev=r
t.close()
