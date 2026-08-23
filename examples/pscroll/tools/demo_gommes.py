#!/usr/bin/env python3
"""Le banc de demonstration du champ de gommes — video + validation par trame.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/demo_gommes.py dist/to8.fd \
        [--video /tmp/claude-501/gommes-demo.mp4] [--rapide]

Ce que c'est : le VRAI champ du stage 4 (level4_ball.bin) qui defile a la
vitesse du jeu ($0030 en 8.8, soit 0,5 px arcade par trame), traverse par
CHAQUE arme qui efface, une a la fois, aux vitesses et empreintes relevees
dans la rom arcade (tools/gen_gum_cases.py porte les sources). Le scenario
alterne des phases de scroll et des phases a l'arret ; pendant les arrets,
CHAQUE trame rendue est comparee au modele — l'ecran doit etre exactement ce
que le champ, la camera et le motif de gomme predisent. Pendant le scroll, la
comparaison se fait a l'entree et a la sortie de la phase (decision assumee :
valider l'ecran a la trame pendant un defilement demanderait de re-deriver la
gravure sous-pixel, ce que check_gum prouve deja cellule par cellule).

Chemins du moteur exerces, tous : clearCell (via run de 1), les runs 2, 4, 5,
les decompositions 3 = 1+2, 6 = 4+2, 7 = 5+2, la bande deroulee zrow (runs 8
et plus), le rejet hors carte, et la REPOUSSE (setCell par la sonde).

La video est assemblee depuis les screenshots des trames jouees — elle montre
exactement ce qui a ete valide, pas un enregistrement parallele.
"""
import argparse
import os
import re
import subprocess
import sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/games/r-type/tools")
from mcp import Toje                                            # noqa: E402
from gen_pellet_tables import BALL, BG, CELL_H, VP_Y            # noqa: E402
from PIL import Image                                           # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("image")
ap.add_argument("--video", default="/tmp/claude-501/gommes-demo.mp4")
ap.add_argument("--rapide", action="store_true",
                help="phases de scroll raccourcies (mise au point)")
args = ap.parse_args()

image = os.path.abspath(args.image)
LWMAP = os.path.join(os.path.dirname(image),
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")
MAPBIN = os.path.join(os.path.dirname(image),
                      "../../../games/r-type/src/stages/04/terrain/level4_ball.bin")
ORG_X, ORG_Y, PX_W, PX_H = 32, 112, 4, 2
MAP_STRIDE, ROWS, CELLS = 48, 30, 384
GARDE = 12                             # px de bord exclus de la comparaison :
                                       # la couture d'entree de bande y vit

sym = {}
for line in open(LWMAP):
    m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
    if m:
        sym[m.group(1)] = int(m.group(2), 16) + 0x6100

t = Toje()


def wr(name, *b):
    t.call("write_memory", {"addr": "%04X" % sym[name],
                            "bytes": ["%02X" % v for v in b]})


def rd(name, n=1):
    return t.read("%04X" % sym[name], n)


def w16(name):
    b = rd(name, 2)
    return (b[0] << 8) | b[1]


# --- le modele : le champ reel, mute en parallele de la machine --------------
# L'etat INITIAL est LU depuis la machine apres le boot : la mire du banc a pu
# s'ecrire pendant boot_floppy, et supposer le .bin brut ferait diverger le
# modele des la premiere trame (vecu : 8 592 pixels « en trop »).
champ = bytearray(MAP_STRIDE * ROWS)


def lire_champ_machine():
    for off in range(0, MAP_STRIDE * ROWS, 240):
        n = min(240, MAP_STRIDE * ROWS - off)
        champ[off:off + n] = bytes(
            t.read("%04X" % (sym["field.map"] + off), n))


def bit(c, r):
    return (champ[r * MAP_STRIDE + (c >> 3)] >> (7 - (c & 7))) & 1


def model_clear(c0, r0, c1, r1, w, h):
    """l'union du balayage, avec LES MEMES bornes que pscroll.clearRect :
    la carte, ET le ruban — une cellule hors des dix bandes n'est pas dans
    les buffers, le moteur refuse de l'y effacer (le modele qui ne bornait
    qu'a la carte voyait des effacements que la machine n'avait pas faits,
    des que le counter-air tombait pres du bord : 288 px « en trop »)."""
    edge = rd("pscroll.edge16")[0]     # UN octet — lu en mot, la borne
                                       # devenait infranchissable (23/08)
    for r in range(min(r0, r1), max(r0, r1) + h):
        for c in range(min(c0, c1), max(c0, c1) + w):
            if not (0 <= c < CELLS and 0 <= r < ROWS):
                continue
            if not (edge <= (3 * c) // 16 < edge + 10):
                continue               # hors ruban : le moteur n'y touche pas
            champ[r * MAP_STRIDE + (c >> 3)] &= ~(1 << (7 - (c & 7))) & 0xFF


def model_grow(c, r):
    if 0 <= c < CELLS and 0 <= r < ROWS:
        champ[r * MAP_STRIDE + (c >> 3)] |= 1 << (7 - (c & 7))


def attendus(cam):
    """les pixels de gomme que l'ecran DOIT montrer, camera connue"""
    out = set()
    c_min = (cam + 2) // 3
    c_max = (cam + 159) // 3
    for c in range(max(0, c_min), min(CELLS, c_max + 1)):
        for r in range(ROWS):
            if not bit(c, r):
                continue
            for l in range(CELL_H):
                for d in range(3):
                    if BALL[l][d] != BG:
                        x = 3 * c - cam + d
                        if GARDE <= x < 160 - GARDE:
                            out.add((x, VP_Y + CELL_H * r + l))
    return out


frames = []                            # les chemins de screenshot, dans l'ordre
verdicts = []


def snap():
    p = t.call("screenshot")["path"]
    dest = "/tmp/claude-501/demo-f%05d.png" % len(frames)
    Image.open(p).save(dest)
    frames.append(dest)
    return dest


def ecran():
    q = Image.open(frames[-1]).convert("RGB").load()
    return {(x, y) for y in range(VP_Y, VP_Y + 180)
            for x in range(GARDE, 160 - GARDE)
            if sum(q[ORG_X + PX_W * x + 1, ORG_Y + PX_H * y]) > 60}


def valider(tag):
    cam = w16("pscroll.camera.x")
    att = attendus(cam)
    vu = ecran()
    manque = att - vu
    trop = vu - att
    ok = not manque and not trop
    verdicts.append((tag, ok, len(att), len(manque), len(trop)))
    if not ok:
        print("  !! %-34s camera %4d : %d attendus, %d manquants, %d en trop"
              % (tag, cam, len(att), len(manque), len(trop)))
        for p in sorted(manque)[:4]:
            print("        manquant", p)
        for p in sorted(trop)[:4]:
            print("        en trop ", p)
        # DIAGNOSTIC : le modele a-t-il derive du champ machine, ou le rendu
        # du champ ? On relit field.map et on refait la diff contre LUI.
        copie = bytes(champ)
        lire_champ_machine()
        delta = [(i, a, b) for i, (a, b) in enumerate(zip(copie, champ))
                 if a != b]
        att2 = attendus(cam)
        m2, t2 = att2 - vu, vu - att2
        print("        modele vs machine : %d octets de champ different ; "
              "ecran vs champ machine : %d manquants, %d en trop"
              % (len(delta), len(m2), len(t2)))
        for i, a, b in delta[:4]:
            print("        champ[%d] (cellules %d.., rangee %d) : modele "
                  "%02X machine %02X" % (i, (i % MAP_STRIDE) * 8,
                                         i // MAP_STRIDE, a, b))
        champ[:] = copie               # la demo continue sur SON modele
    return ok


def frame(valide=None):
    """UNE trame rendue, capturee ; validee si un tag est donne.

    LA LATENCE DU DOUBLE-BUFFER : la mutation decidee au tour T est dessinee
    par le `do` de T+1 dans le tampon ARRIERE, flippe en fin de T+1 — l'ecran
    la montre a T+2. Une validation qui suit une mutation doit donc laisser
    passer DEUX trames ; frame() n'en joue qu'une, l'appelant en enchaine
    deux avant de valider (mesure sur la sonde : la gomme etait dans le champ
    machine, a l'ecran une validation plus tard, 23/08)."""
    t.call("run_frames", {"n": 1})
    snap()
    if valide:
        valider(valide)


def rect(c0, r0, c1, r1, w, h):
    """un effacement par le moteur + la meme chose dans le modele"""
    wr("pscroll.rect.c0", (c0 >> 8) & 255, c0 & 255)
    wr("pscroll.rect.r0", r0 & 255)
    wr("pscroll.rect.c1", (c1 >> 8) & 255, c1 & 255)
    wr("pscroll.rect.r1", r1 & 255)
    wr("pscroll.rect.w", w)
    wr("pscroll.rect.h", h)
    wr("bench.rect", 1)
    model_clear(c0, r0, c1, r1, w, h)
    # ATTENDRE LA CONSOMMATION, pas compter des trames : un tour de boucle qui
    # porte un gros effacement DEPASSE la trame (frame drop) — enchainer les
    # rect a une trame d'ecart ecrasait bench.rect avant que le banc ne l'ait
    # lu, et des blocs entiers se perdaient (vecu : 4 des 11 blocs du
    # counter-air, 23/08).
    for _ in range(12):
        frame()
        if rd("bench.rect")[0] == 0:
            break
    else:
        print("  !! bench.rect jamais consomme")


def sonde(c, r, efface=False):
    """une mutation unitaire par la sonde (le chemin setCell/clearCell).

    Le tour de boucle du banc DESSINE avant de muter (do, move, puis la
    sonde) : la mutation d'une trame n'est a l'ecran qu'a la suivante —
    l'appelant doit jouer une frame() de plus avant de valider."""
    wr("cytron.col", (c >> 8) & 255, c & 255)
    wr("cytron.row", r & 255)
    wr("cytron.erase", 1 if efface else 0)
    wr("cytron.enable", 1)
    if efface:
        pass
    for _ in range(12):                # meme regle que rect : la consommation
        frame()
        if rd("cytron.enable")[0] == 0:
            break
    else:
        print("  !! sonde jamais consommee")
    if efface:
        model_clear(c, r, c, r, 1, 1)
    else:
        # la sonde refuse le terrain dur et l'exterieur — le champ du banc
        # n'a pas de terrain dur, le modele pose sans condition
        model_grow(c, r)


def scroll(vitesse_88, trames, tag):
    """la camera avance a cette vitesse ; validation entree/sortie"""
    n = max(6, trames // 8) if args.rapide else trames
    print("  %s (%d trames a $%04X)" % (tag, n, vitesse_88))
    wr("pscroll.camera.speedx", (vitesse_88 >> 8) & 255, vitesse_88 & 255)
    wr("ctrlspeedx", (vitesse_88 >> 8) & 255, vitesse_88 & 255)
    for _ in range(n):
        frame()
    wr("pscroll.camera.speedx", 0, 0)
    wr("ctrlspeedx", 0, 0)
    frame()
    frame()
    frame(valide=tag + " (arret)")


V_STAGE = 0x0030                       # 0,5 px arcade/trame : le stage 4


def cellule_gauche():
    return (w16("pscroll.camera.x") + 2) // 3


# =============================================================================
os.makedirs("/tmp/claude-501", exist_ok=True)
print("boot...")
t.boot_floppy(image)
wr("smiley.loop", 0)                   # PAS de mire : le champ reel du niveau
wr("smiley.row", 60)
wr("cytron.enable", 0)
wr("ctrlspeedx", 0, 0)
wr("pscroll.camera.speedx", 0, 0)
t.call("run_frames", {"n": 30})
lire_champ_machine()
frame(valide="champ initial")

# --- 0. l'approche : le champ dense vit aux cellules 240..335 ----------------
# (0..239 est presque vide sur la carte reelle). On s'y rend a 3 px/trame —
# assumee plus rapide que le jeu, c'est le trajet, pas la demonstration — puis
# tout le reste se joue a la vitesse reelle.
print("PHASE approche du champ")
wr("pscroll.camera.speedx", 3, 0)
wr("ctrlspeedx", 3, 0)
for _ in range(300):
    t.call("run_frames", {"n": 4})
    snap()
    if w16("pscroll.camera.x") >= 700:
        break
wr("pscroll.camera.speedx", 0, 0)
wr("ctrlspeedx", 0, 0)
for _ in range(8):                     # 3 px/trame est HORS des vitesses du
    frame()                            # jeu : le feed etale sa gravure, on le
frame(valide="arrivee au champ")       # laisse rattraper avant de juger

# --- 1. le niveau defile, vitesse reelle -------------------------------------
print("PHASE scroll d'ouverture")
scroll(V_STAGE, 200, "scroll d'ouverture")

# --- 2. tir simple / missile : UNE cellule, il meurt dessus ------------------
print("PHASE tir simple (1 cellule, run de 1)")
g = cellule_gauche()
for i, (c, r) in enumerate([(g + 8, 6), (g + 14, 12), (g + 20, 22)]):
    sonde(c, r, efface=True)
    frame()
    frame(valide="tir simple %d" % (i + 1))

# --- 3. bit device : grappe 2x2, a l'arret puis balayee ----------------------
print("PHASE bit device (2x2 : runs 2 et 3)")
g = cellule_gauche()
rect(g + 10, 8, g + 10, 8, 2, 2)       # a l'arret : run de 2
frame()
frame(valide="bit 2x2 a l'arret")
# l'orbite balaye d'une cellule par trame rendue (4..15 px arcade/trame)
c = g + 16
for i in range(5):
    rect(c, 16, c + 1, 16, 2, 2)       # balaye de 1 : run de 3 = 1+2
    frame()
    frame(valide="bit balaye %d" % (i + 1))
    c += 1

# --- 4. un peu de scroll entre deux armes ------------------------------------
scroll(V_STAGE, 120, "scroll inter-armes")

# --- 5. force pod, poursuite : 4x4 a 1,5 px arcade/trame ---------------------
print("PHASE force pod poursuite (4x4 : runs 4 et 5)")
g = cellule_gauche()
rect(g + 12, 10, g + 12, 10, 4, 4)     # a l'arret : run de 4
frame()
frame(valide="pod a l'arret")
c = g + 18
for i in range(4):                     # 1,5+0,5 px/trame -> balaye de 0 ou 1
    dc = 1 if i % 2 == 0 else 0        # l'alternance du sous-pixel
    rect(c, 18, c + dc, 18, 4, 4)      # runs 4 et 5
    frame()
    frame(valide="pod poursuite %d" % (i + 1))
    c += dc

# --- 6. force pod, EJECTION : 9 px arcade/trame ------------------------------
print("PHASE force pod ejection (4x4 balaye de 2-3 : runs 6 et 7 decomposes)")
g = cellule_gauche()
c = g + 6
for i in range(5):
    dc = 2 if i % 2 == 0 else 3        # 9,5 px/trame = 1,19 cellule + drop
    rect(c, 24, c + dc, 24, 4, 4)      # runs 6 (4+2) et 7 (5+2)
    frame()
    frame(valide="pod ejecte %d" % (i + 1))
    c += dc

# --- 7. la repousse : cytron seme derriere lui -------------------------------
print("PHASE repousse (setCell par la sonde)")
g = cellule_gauche()
for i in range(6):
    sonde(g + 10 + i, 8 + i)
    frame()
    frame()
    frame(valide="repousse %d" % (i + 1))

# --- 8. wave cannon, palier bas : bande 2x6 a une cellule par trame ----------
print("PHASE wave cannon palier bas (2x7 par trame : run 7 = 5+2)")
scroll(V_STAGE, 80, "scroll avant le beam")
g = cellule_gauche()
c = g + 4
for i in range(6):
    rect(c, 14, c + 1, 14, 6, 2)       # 6 de large balaye de 1 : run de 7
    frame()
    frame(valide="beam bas %d" % (i + 1))
    c += 1

# --- 9. wave cannon, palier max : bande 2x11, la bande deroulee --------------
print("PHASE wave cannon palier max (2x12 par trame : zrow)")
g = cellule_gauche()
c = g + 4
for i in range(4):
    rect(c, 20, c + 1, 20, 11, 2)      # 11 balaye de 1 : run de 12 -> zrow
    frame()
    frame(valide="beam max %d" % (i + 1))
    c += 1

# --- 10. counter-air laser : onze blocs 4x4, une seule trame -----------------
# La grille du releve (0x40:49CF) : une colonne de 3 blocs, trois lateraux,
# une queue de 4 — approchee ici en gardant le compte et la dispersion.
print("PHASE counter-air laser (11 blocs 4x4 d'un coup)")
g = cellule_gauche()
blocs = [(g + 8, 2), (g + 8, 8), (g + 8, 14),
         (g + 14, 5), (g + 14, 11), (g + 14, 17),
         (g + 20, 2), (g + 20, 8), (g + 20, 14), (g + 20, 20), (g + 26, 8)]
for (c, r) in blocs:
    rect(c, r, c, r, 4, 4)             # chaque bloc : run de 4
    frame()
frame(valide="counter-air, apres les 11 blocs")

# --- 11. le bord : un balayage qui deborde de la carte -----------------------
print("PHASE debordement (rejet hors carte)")
rect(-3, 25, cellule_gauche() + 2, 25, 4, 2)
frame()
frame(valide="debordement a gauche")

# --- 12. scroll final --------------------------------------------------------
scroll(V_STAGE, 200, "scroll final")

# =============================================================================
ok = sum(1 for _, v, *_ in verdicts if v)
print("\nVERDICTS : %d/%d trames validees conformes" % (ok, len(verdicts)))
for tag, v, natt, nm, nt in verdicts:
    if not v:
        print("  FAUX : %s (%d attendus, %d manquants, %d en trop)"
              % (tag, natt, nm, nt))

print("\nassemblage video (%d trames)..." % len(frames))
liste = "/tmp/claude-501/demo-frames.txt"
with open(liste, "w") as f:
    for p in frames:
        f.write("file '%s'\nduration 0.04\n" % p)   # 25 i/s : 2x le temps reel
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat",
                "-safe", "0", "-i", liste, "-vf", "scale=768:-2:flags=neighbor",
                "-pix_fmt", "yuv420p", args.video], check=True)
print("video ->", args.video)
t.close()
sys.exit(0 if ok == len(verdicts) else 1)
