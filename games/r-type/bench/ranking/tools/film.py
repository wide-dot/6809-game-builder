#!/usr/bin/env python3
"""Filme un tour du banc : revelation, saisie avec les Pata-Pata (D, C, RUB, END),
tableau. Sortie : dist/<nom>.avi (sans perte) et dist/<nom>.mp4 (H.264).
    python3 tools/film.py [nom]"""
import sys, os, re
HERE=os.path.dirname(os.path.abspath(__file__)); B=os.path.dirname(HERE)
sys.path.insert(0, os.path.join(B,"..","..","..","..","ci","toje-bench")); os.chdir(B)
from mcp import Toje, bench_block, layout_symbol
NAME=sys.argv[1] if len(sys.argv)>1 else "ranking-patapata"
IMG=os.path.abspath("dist/to8.fd"); LAYOUT=B+"/gen/layout.asm"
BLOCK=bench_block(IMG, layout=LAYOUT)
def h(a): return format(a,"04X")
def say(*a): print(*a, flush=True)
tj=Toje(); say("boot =", tj.boot_floppy(IMG).get("booted"))
tj.call("set_pointer_device",{"device":"none"})
# LE DEPART EST UN NUMERO DE TRAME, pas une adresse : un declencheur par PC a
# donne un film de 46 trames (05/09/2026), un declencheur par trame filme tout.
# Il coupe le turbo des l'armement : le boot (~1 400 trames) tourne en temps
# reel, une trentaine de secondes.
AVI=os.path.abspath(f"dist/{NAME}.avi")
say("armement :", tj.call("arm_video_capture",{"start":{"frame":1240},"path":AVI}))
for i in range(120):
    tj.call("run_frames",{"n":20,"fast":False,"timeout_ms":600000})
    if tj.read(h(BLOCK),1)[0]==0xCA: break
say("temoin apres", (i+1)*20, "trames")
def run(n): tj.call("run_frames",{"n":n,"fast":False,"timeout_ms":600000})   # le film exige le rendu
def joy(d=None,a=False,hold=4):
    arg={"joystick":0,"hold_frames":hold}
    if d: arg["direction"]=d
    if a: arg["button_a"]=True
    tj.call("press_joystick",arg)
run(300)                                    # la revelation, puis les Pata-Pata
for _ in range(3): joy("right"); run(25)    # D
run(60); joy(a=True); run(60)
for _ in range(2): joy("right"); run(25)    # C
run(60); joy(a=True); run(60)
for _ in range(2): joy("left"); run(25)     # RUB
run(60); joy(a=True); run(60)
joy("left"); run(60); joy(a=True)           # END
run(160)                                    # la tenue (64 trames de jeu)
run(320)                                    # le tableau
say("statut :", tj.call("video_capture_status"))
say("arret :", tj.call("stop_video_capture"))
say("encodage :", tj.call("encode_capture",{"path":AVI,"codec":"h264","output":AVI[:-4]+".mp4"}))
tj.close()
