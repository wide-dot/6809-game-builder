#!/usr/bin/env python3
"""Sauter au stage 4 par le cheat du title et regarder.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/shot_stage4.py dist/to8.fd [trames]

Le cheat stage-select est au joypad, au title : h,b,g,d puis N x haut = stage N,
et h,b,g,d puis bas = invincible (indispensable pour traverser sans jouer). Le
bouton A lance. La manette 0 est muette tant que la souris emulee occupe le
port : set_pointer_device none, APRES le boot.
"""
import os, shutil, sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
from mcp import Toje

image = os.path.abspath(sys.argv[1])
trames = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
dest = sys.argv[3] if len(sys.argv) > 3 else "/tmp/claude-501/stage4.png"

t = Toje()
t.boot_floppy(image)
# set_pointer_device n'existe pas sur tous les serveurs toje ; s'il manque, la
# manette 0 peut rester muette (la souris emulee occupe le port) et le cheat ne
# passe pas — le script le dit alors au lieu de mentir sur le resultat.
try:
    t.call("set_pointer_device", {"device": "none"})
except Exception as e:
    print("!! set_pointer_device indisponible :", e)
t.call("run_frames", {"n": 400})               # que le title tourne


def dpad(d, hold=6):
    t.call("press_joystick", {"port": 0, "direction": d, "hold_frames": hold})
    t.call("run_frames", {"n": 6})


def cheat(seq):
    for d in ("up", "down", "left", "right"):
        dpad(d)
    for d in seq:
        dpad(d)


cheat(["down"])                                # invincible
cheat(["up"] * 4)                              # stage 4
t.call("press_joystick", {"port": 0, "button": "a", "hold_frames": 6})
t.call("run_frames", {"n": 120})

b = t.read("87DB", 8)
print("temoins : magic=%02X stage=%02X tour=%02X camera=%d"
      % (b[0], b[1], b[2], (b[3] << 8) | b[4]))
t.call("run_frames", {"n": trames})
b = t.read("87DB", 8)
print("apres %d trames : stage=%02X camera=%d spawns=%d"
      % (trames, b[1], (b[3] << 8) | b[4], (b[5] << 8) | b[6]))
shutil.copy(t.call("screenshot")["path"], dest)
print("capture ->", dest)
t.close()
