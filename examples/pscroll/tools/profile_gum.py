#!/usr/bin/env python3
"""Ce que coute UNE mutation de gomme, en cycles emules.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/profile_gum.py dist/to8.fd

La mire du banc est le compteur : elle pose 640 gommes puis les efface, une
rangee par trame. On profile chaque phase separement et on divise par le
nombre de mutations REELLEMENT faites (temoin $9C06), pas par le nombre de
cellules — une cellule deja pleine ne coute que son test.

Les cycles sont attribues par ROUTINE, bornes lues dans le .lwmap du build :
elles suivent le code au lieu d'etre recopiees a la main.
"""
import os, re, sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
from mcp import Toje

image = os.path.abspath(sys.argv[1])
LWMAP = os.path.join(os.path.dirname(image),
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")
BASE = 0x6100

sym = {}
for line in open(LWMAP):
    m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
    if m:
        sym[m.group(1)] = int(m.group(2), 16) + BASE

# les postes, dans l'ordre du binaire ; le libelle est ce qu'on veut lire
POSTES = [
    ("pscroll.setCell",   "aiguillage (setCell/clearCell/mutate)"),
    ("pscroll.wr.00",     "LES 16 ROUTINES D'ECRITURE"),
    ("pscroll.wr.tbl",    "tables"),
    ("pscroll.er.00",     "LES 16 ROUTINES D'EFFACEMENT"),
    ("pscroll.er.tbl",    "tables"),
    ("pscroll.col.tbl",   "tables"),
]
bornes = sorted((sym[n], lbl) for n, lbl in POSTES if n in sym)

# le nombre de gommes par rangee, relu du motif genere : c'est le diviseur
MOTIF = []
for _l in open(os.path.join(os.path.dirname(image),
                            "../src/assets/game-modes/to8/main/smiley.asm")):
    _l = _l.strip()
    if _l.startswith("fcb"):
        MOTIF.append(sum(bin(int(v.strip().lstrip("$"), 16)).count("1")
                         for v in _l[3:].split(",")))

t = Toje()
t.boot_floppy(image)


def rd(name, n=1):
    return t.read("%04X" % sym[name], n)


def wr(name, *b):
    t.call("write_memory", {"addr": "%04X" % sym[name],
                            "bytes": ["%02X" % v for v in b]})


def mutations():
    return t.read("9D06", 1)[0]


def attendre(cible, maxi=4000, pas=2):
    """le pas compte : une rangee de mire tient en ~9 trames, donc sonder par
    10 fait rater la fenetre a mesurer."""
    for _ in range(maxi):
        if rd("smiley.row")[0] >= cible:
            return True
        t.call("run_frames", {"n": pas})
    return False


def mesure_rendu(titre, n):
    """le depouillement seul : le profil est deja arrete"""
    top = t.call("profile_top", {"n": 1000, "by": "cycles"})
    total = top.get("total_cycles", 0)
    acc = {}
    for r in top.get("rows", []):
        pc, c = int(r["pc"], 16), r["cycles"]
        if pc < 0x4000:
            lbl = "le blast (buffer, fenetre cartouche)"
        elif pc >= 0xE000:
            lbl = "moniteur"
        elif pc < bornes[0][0]:
            lbl = "main / engine / irq / pscroll.do / feed"
        else:
            lbl = bornes[0][1]
            for a, l in bornes:
                if pc >= a:
                    lbl = l
                else:
                    break
        acc[lbl] = acc.get(lbl, 0) + c
    print("\n=== %s : %d mutations (%d cycles au total, %d PC)"
          % (titre, n, total, len(top.get("rows", []))))
    print("%-42s %10s %8s %12s" % ("poste", "cycles", "%", "cy/mutation"))
    for lbl, c in sorted(acc.items(), key=lambda kv: -kv[1]):
        print("%-42s %10d %7.2f%% %12.0f"
              % (lbl, c, 100.0 * c / total if total else 0, c / n if n else 0))
    return acc


def mesure(titre, cible, n_mut):
    n0 = mutations()
    t.call("profile_reset")
    t.call("profile_start")
    ok = attendre(cible, pas=1)
    t.call("profile_stop")
    n = n_mut
    top = t.call("profile_top", {"n": 1000, "by": "cycles"})
    total = top.get("total_cycles", 0)
    acc = {}
    for r in top.get("rows", []):
        pc, c = int(r["pc"], 16), r["cycles"]
        if pc < 0x4000:
            lbl = "le blast (buffer, fenetre cartouche)"
        elif pc >= 0xE000:
            lbl = "moniteur"
        elif pc < bornes[0][0]:
            lbl = "main / engine / irq / pscroll.do / feed"
        else:
            lbl = bornes[0][1]
            for a, l in bornes:
                if pc >= a:
                    lbl = l
                else:
                    break
        acc[lbl] = acc.get(lbl, 0) + c
    print("\n=== %s : %d mutations%s" % (titre, n, "" if ok else " (INCOMPLET)"))
    print("%-42s %10s %8s %12s" % ("poste", "cycles", "%", "cy/mutation"))
    for lbl, c in sorted(acc.items(), key=lambda kv: -kv[1]):
        print("%-42s %10d %7.2f%% %12.0f"
              % (lbl, c, 100.0 * c / total if total else 0, c / n if n else 0))
    print("%-42s %10d %7s %12.0f" % ("TOTAL", total, "", total / n if n else 0))
    return acc, n


# UNE RANGEE A LA FOIS. Le profileur ne rend que ses ~1000 PC les plus chauds ;
# sur les 640 gommes de la mire, le code des 32 routines s'y noie. Une seule
# rangee tient largement dedans, et elle suffit : le cout est par gomme.
DENSE = max(range(30), key=lambda r: MOTIF[r])
print("rangee de mesure : %d (%d gommes)" % (DENSE, MOTIF[DENSE]))

def attendre_sous(v, maxi=4000):
    """le cycle de la mire reboucle : on attend la bascule vers le dessin"""
    for _ in range(maxi):
        if rd("smiley.row")[0] < v:
            return True
        t.call("run_frames", {"n": 2})
    return False


attendre(30)                       # la mire est posee
wr("smiley.pause", 0)
attendre(30 + DENSE)               # on efface jusqu'a la rangee choisie
mesure("EFFACEMENT, rangee %d" % DENSE, 30 + DENSE + 1, MOTIF[DENSE])

attendre_sous(5)                   # le cycle recommence : la mire se redessine
wr("smiley.pause", 0)
attendre(DENSE)
mesure("ECRITURE, rangee %d" % DENSE, DENSE + 1, MOTIF[DENSE])

# --- AU FOND DU NIVEAU -------------------------------------------------------
# La mire vit aux bandes 0 a 3, ou une division par 10 sort tout de suite. Au
# fond du niveau la bande vaut 60 et plus : c'est la que se juge le cout d'une
# mutation en conditions de jeu.
wr("smiley.loop", 0)
wr("smiley.row", 60)
wr("cytron.enable", 0)
wr("ctrlspeedx", 1, 0)
wr("pscroll.camera.speedx", 1, 0)
for _ in range(600):
    b = rd("pscroll.camera.x", 2)
    if (b[0] << 8) | b[1] >= 600:
        break
    t.call("run_frames", {"n": 10})
wr("pscroll.camera.speedx", 0, 0)
wr("ctrlspeedx", 0, 0)
b = rd("pscroll.camera.x", 2)
cam = (b[0] << 8) | b[1]
c0 = (cam + 2) // 3 + 2
print("\ncamera %d -> cellules %d.., bande %d" % (cam, c0, (3 * c0) >> 4))

# la mire se rejoue LA, sur les grandes bandes : meme mesure, autre geometrie
wr("smiley.col0", c0 >> 8, c0 & 0xFF)
wr("smiley.loop", 1)
wr("smiley.pause", 0)
wr("smiley.row", 0)
attendre(DENSE)
mesure("AU FOND DU NIVEAU, bande %d" % ((3 * c0) >> 4), DENSE + 1, MOTIF[DENSE])
t.close()
