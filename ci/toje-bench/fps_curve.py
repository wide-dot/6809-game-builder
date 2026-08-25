#!/usr/bin/env python3
"""Releve la cadence de rendu d'un stage, TRAME PAR TRAME, sans toucher au jeu.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 ci/toje-bench/fps_curve.py dist/to8.fd releve.csv [options]

Le jeu ne porte aucune sonde : `bench.frames` s'incremente deja une fois par
tour de `stage.loop` (src/common/bench.const.asm), et l'emulateur le lit sans
couter un cycle au programme mesure. C'est ce qui rend la mesure honnete — une
sonde en RAM ecrite par le jeu fausserait precisement ce qu'on compare.

L'echantillonnage est a la trame machine (50 Hz), c'est-a-dire la resolution
maximale : `run_frames(1)` coute 4,1 ms, soit la vitesse d'emulation elle-meme
(~245 trames/s). Aller-retour MCP negligeable, donc aucun outil a ajouter a
toje — un niveau 1 complet se releve en une minute environ.

CE QUE LE RELEVE SUPPOSE, et qui doit etre identique des deux cotes d'une
comparaison :
  - L'INVINCIBILITE. Sans elle le vaisseau finit par mourir faute d'entree
    manette, la boucle passe en DEAD/CHECKPOINT et le releve s'arrete la
    (constate a la trame 3835 sur le build du 19/08). Elle vient du cheat du
    title depuis que le define `invincible` a ete retire : --cheat l'arme
    toujours, et c'est aussi la seule facon d'entrer ailleurs qu'au stage 1 ;
  - aucune entree manette pendant le releve ;
  - `bench.SCROLL_VEL` inchange : les horodatages des vagues sont des trames
    d'arcade calees sur CETTE vitesse.

Sortie CSV, une ligne par trame machine :
  machine_frame,rendered,delta,camera,stage,lives
    rendered  compteur de trames rendues, deroule (l'octet du jeu boucle a 256)
    delta     rendus sur cette trame machine : 0 ou 1 (2 si double rendu)
    camera    position camera du stage (mot) — l'axe commun de deux releves
Les images/s ne sont PAS ecrites ici : elles se derivent par fenetre glissante
(fps_plot.py), la valeur instantanee n'ayant que deux etats.

Codes de sortie : 0 releve complet, 1 blocage, 2 pas entre dans le stage.
"""
import argparse, os, re, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp import Toje


def bench_address(layout, fallback=0x87DB):
    """L'adresse du bloc temoin, lue dans gen/layout.asm quand il est la.

    Le bloc a deja demenage deux fois ($8766 -> $87DB le 19/08, le title ayant
    grossi jusqu'a poser son dernier octet dessus) : le coder en dur, c'est
    relever du bruit de pile un jour sans s'en apercevoir."""
    try:
        for line in open(layout):
            m = re.match(r'\s*bench\.address\s+equ\s+\$([0-9A-Fa-f]+)', line)
            if m:
                return int(m.group(1), 16)
    except OSError:
        pass
    return fallback


def globals_address(layout, fallback=0x9DCB):
    try:
        for line in open(layout):
            m = re.match(r'\s*globals\.address\s+equ\s+\$([0-9A-Fa-f]+)', line)
            if m:
                return int(m.group(1), 16)
    except OSError:
        pass
    return fallback


p = argparse.ArgumentParser()
p.add_argument("image")
p.add_argument("out")
p.add_argument("--layout", default="gen/layout.asm",
               help="d'ou sont lues bench.address et globals.address")
p.add_argument("--stage", type=int, default=1,
               help="le stage a relever ; le releve s'arrete quand on en sort")
p.add_argument("--max-frames", type=int, default=30000,
               help="garde-fou en trames machine (~10 min emulees)")
p.add_argument("--wedge", type=int, default=1200,
               help="trames machine sans un seul rendu avant de crier au blocage")
p.add_argument("--enter-budget", type=int, default=80,
               help="rafales de touche start avant d'abandonner l'entree en jeu")
p.add_argument("--cheat", action="store_true",
               help="entrer par le cheat du title (manette) : invincible + le "
                    "stage demande. Obligatoire au-dela du stage 1, et c'est "
                    "aussi ce qui arme l'invincibilite depuis que le define a "
                    "disparu")
a = p.parse_args()

BENCH = bench_address(a.layout)
LIVES = globals_address(a.layout) + 4
print(f"temoins : bench=${BENCH:04X} lives=${LIVES:04X} (source {a.layout})", flush=True)

t = Toje()
t.boot_floppy(os.path.abspath(a.image))


def wit():
    b = t.read(f"0x{BENCH:04X}", 8)
    return {"magic": b[0], "stage": b[1], "frames": b[2],
            "camera": (b[3] << 8) | b[4]}


def lives():
    return t.read(f"0x{LIVES:04X}", 1)[0]


# --- entrer dans le stage -----------------------------------------------------
def cheat_entry(stage):
    """Le cheat du title, a la manette (src/title/cheat.unit.asm).

    Prefixe haut,bas,gauche,droite puis : bas = invincible, N fois haut =
    stage N. Les cheats se cumulent en re-entrant le prefixe, bouton A lance.
    La souris emulee occupe la manette 0 : la debrancher est le prealable."""
    t.call("set_pointer_device", {"device": "none"})
    prefix = ["up", "down", "left", "right"]
    for d in prefix + ["down"]:                    # invincible
        t.call("press_joystick", {"joystick": 0, "direction": d,
                                  "hold_frames": 6})
    for d in prefix + ["up"] * stage:              # stage N
        t.call("press_joystick", {"joystick": 0, "direction": d,
                                  "hold_frames": 6})
    t.call("press_joystick", {"joystick": 0, "button_a": True,
                              "hold_frames": 6})
    return 6 * 2 * (len(prefix) * 2 + 1 + stage + 1)


machine = 0
armed = not a.cheat
for _ in range(a.enter_budget):
    w = wit()
    if w["magic"] == 0xCA and w["stage"] == a.stage:
        break
    if a.cheat:
        # le cheat ne se saisit qu'AU title : hors de lui, on attend
        if w["magic"] == 0xCA and w["stage"] == 0x00 and not armed:
            machine += cheat_entry(a.stage)
            armed = True
    else:
        t.press("0F")
    t.call("run_frames", {"n": 60})
    machine += 65
else:
    print(f"jamais entre dans le stage {a.stage} : {wit()}", flush=True)
    t.dump("abort ")
    t.close()
    sys.exit(2)

start = machine
print(f"stage {a.stage} atteint a la trame {machine}", flush=True)

# --- le releve ----------------------------------------------------------------
rows = []
prev = wit()["frames"]
rendered = 0
dry = 0
t0 = time.time()
status = "complet"

while machine - start < a.max_frames:
    t.call("run_frames", {"n": 1})
    machine += 1
    w = wit()
    d = (w["frames"] - prev) & 0xFF
    prev = w["frames"]
    rendered += d
    rows.append((machine - start, rendered, d, w["camera"], w["stage"]))

    if w["stage"] != a.stage:
        status = f"sortie du stage (stage={w['stage']})"
        break

    dry = 0 if d else dry + 1
    if dry >= a.wedge:
        status = f"BLOCAGE : {dry} trames sans un rendu"
        break

    if len(rows) % 2000 == 0:
        el = time.time() - t0
        print(f"  trame {machine - start:6d}  camera {w['camera']:5d}  "
              f"rendus {rendered:6d}  ({(machine-start)/el:.0f} trames/s reelles)",
              flush=True)
else:
    status = "garde-fou max-frames atteint"

with open(a.out, "w") as f:
    f.write("machine_frame,rendered,delta,camera,stage,lives\n")
    lv = lives()
    for r in rows:
        f.write(",".join(str(x) for x in r) + f",{lv}\n")

span = rows[-1][0] if rows else 0
fps = 50.0 * rendered / span if span else 0
print(f"{status} — {span} trames machine, {rendered} rendus, "
      f"moyenne {fps:.1f} img/s, camera {rows[-1][3] if rows else 0}", flush=True)
print(f"ecrit {a.out}", flush=True)

if status.startswith("BLOCAGE"):
    t.dump("wedge ")
    shot = os.path.splitext(a.out)[0] + "-wedge.png"
    print("capture :", t.call("screenshot", {"path": os.path.abspath(shot)}), flush=True)
    t.close()
    sys.exit(1)

t.close()
