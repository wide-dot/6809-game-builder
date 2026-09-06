#!/usr/bin/env python3
"""Combien de Pata-Pata vivent a la fois pendant la saisie ? Sonde le pool
d'objets toutes les 10 trames pendant 600 trames (banc construit, toje)."""
import sys, os, re
HERE=os.path.dirname(os.path.abspath(__file__)); B=os.path.dirname(HERE)
sys.path.insert(0, os.path.join(B,"..","..","..","..","ci","toje-bench")); os.chdir(B)
from mcp import Toje, bench_block, layout_symbol
IMG=os.path.abspath("dist/to8.fd"); LAYOUT=B+"/gen/layout.asm"
POOL=layout_symbol("objects.pool", IMG, layout=LAYOUT)
SIZE=int(sys.argv[1]) if len(sys.argv)>1 else 63; N=60; ID_PATA=32
BLOCK=bench_block(IMG, layout=LAYOUT)
def h(a): return format(a,"04X")
tj=Toje(); tj.boot_floppy(IMG); tj.call("set_pointer_device",{"device":"none"})
for i in range(120):
    tj.call("run_frames",{"n":20,"fast":True,"timeout_ms":600000})
    if tj.read(h(BLOCK),1)[0]==0xCA: break
tj.call("run_frames",{"n":150,"fast":True,"timeout_ms":600000})   # la revelation passee
counts=[]; ids={}
for k in range(int(sys.argv[2]) if len(sys.argv)>2 else 60):
    tj.call("run_frames",{"n":10,"fast":True,"timeout_ms":600000})
    raw=tj.read(h(POOL), N*SIZE)
    alive=[raw[i*SIZE] for i in range(N) if raw[i*SIZE]]
    counts.append(sum(1 for v in alive if v==ID_PATA))
    for v in alive: ids[v]=ids.get(v,0)+1
print("pata vivants, toutes les 10 trames :", counts)
print(f"moyenne {sum(counts)/len(counts):.1f}, max {max(counts)}, ids vus : {ids}")
tj.close()
