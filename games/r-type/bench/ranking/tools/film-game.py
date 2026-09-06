#!/usr/bin/env python3
"""Filme, dans le JEU : title avec le cheat de score, mort au stage 1, la
sequence de classement avec la saisie d'un nom, le tableau, le continue
accepte, READY et la reprise. Sortie : games/r-type/dist/<nom>.mp4 (H.264).
    python3 bench/ranking/tools/film-game.py [nom] [NOM-A-SAISIR]"""
import sys, os
HERE=os.path.dirname(os.path.abspath(__file__)); G=os.path.abspath(os.path.join(HERE,"..","..",".."))
sys.path.insert(0, os.path.join(G,"..","..","ci","toje-bench")); os.chdir(G)
from mcp import Toje, bench_block, globals_block
from PIL import Image
NAME=sys.argv[1] if len(sys.argv)>1 else "game-ranking"; WORD=(sys.argv[2] if len(sys.argv)>2 else "BENTOC").upper()
IMG=os.path.abspath("dist/to8.fd"); BLOCK=bench_block(IMG); REQUEST=BLOCK+8; GLB=globals_block(IMG); LIVES=GLB+4
def h(a): return format(a,"04X")
def say(*a): print(*a, flush=True)
tj=Toje(); say("boot =", tj.boot_floppy(IMG).get("booted"))
tj.call("set_pointer_device",{"device":"none"})
for i in range(10):
    tj.call("run_frames",{"n":500,"fast":True,"timeout_ms":600000})
    if tj.read(h(BLOCK),1)[0]==0xCA: break
for d in ["up","down","left","right","right"]:                 # le cheat de score
    tj.call("press_joystick",{"joystick":0,"direction":d,"hold_frames":4}); tj.call("run_frames",{"n":8,"fast":True})
for i in range(150):
    tj.press(); tj.call("run_frames",{"n":15,"fast":True,"timeout_ms":600000})
    if tj.read(h(BLOCK+1),1)[0]!=0: break
tj.call("run_frames",{"n":200,"fast":True,"timeout_ms":600000})
AVI=os.path.abspath(f"dist/{NAME}.avi")
say("armement :", tj.call("arm_video_capture",{"start":{"frame":1},"path":AVI})["state"])
def run(n): tj.call("run_frames",{"n":n,"fast":False,"timeout_ms":600000})
def lit():
    p="/tmp/film-probe.png"; tj.call("screenshot",{"path":p})
    return sum(1 for q in Image.open(p).convert('L').get_flattened_data() if q>40)
def wait(pred, what, step=10, limit=3000):
    for i in range(limit//step):
        run(step); v=lit()
        if pred(v): say(f"  {what} : {v} px apres {(i+1)*step} tr"); return
    raise SystemExit(what+" jamais atteint")
def joy(d=None,a=False,hold=8):
    arg={"joystick":0,"hold_frames":hold}
    if d: arg["direction"]=d
    if a: arg["button_a"]=True
    tj.call("press_joystick",arg); run(6)
run(30)
tj.call("write_memory",{"addr":h(LIVES),"bytes":["00"]}); tj.call("write_memory",{"addr":h(REQUEST),"bytes":["01"]})
wait(lambda v: v<200, "le noir apres GAME OVER")
wait(lambda v: v>=5300, "l'ecran de saisie")
run(120)                                                          # les Pata-Pata arrivent
ALPHA="ABCDEFGHIJKLMNOPQRSTUVWXYZ!?>.,-"
for ch in WORD[:7]:
    for _ in range(ALPHA.index(ch)): joy("right")
    run(20); joy(a=True); run(20)
if len(WORD)<7: joy("left"); run(20); joy(a=True)                 # END
wait(lambda v: v>=13000, "le tableau"); run(120)
joy(a=True)                                                       # le tableau ecourte
wait(lambda v: 3000<=v<=6000, "le continue"); run(60)
joy(a=True)                                                       # continue accepte
run(60); wait(lambda v: v>=12000, "la reprise", limit=1200); run(200)
say("statut :", {k:v for k,v in tj.call("video_capture_status").items() if k in ("frames","seconds")})
tj.call("stop_video_capture")
say("encodage :", {k:v for k,v in tj.call("encode_capture",{"path":AVI,"codec":"h264","output":AVI[:-4]+".mp4"}).items() if k in ("bytes","codec")})
tj.close()
