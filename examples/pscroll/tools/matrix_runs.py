#!/usr/bin/env python3
"""LA MATRICE DES EFFACEMENTS — champ plein, camera fixe, un cas a la fois.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/matrix_runs.py dist/to8.fd \
        [--longueurs 1,2,3,4,5,6,7,8,12] [--rangees 4,12,20] [-v]

Le principe, et pourquoi il vaut mieux que la mire : le champ est REMPLI
(bench.fill met la carte a $FF et rappelle pscroll.init, qui regrave les dix
bandes). Sur un champ plein, tout pixel eteint est un effacement et rien
d'autre — plus de motif a modeliser, plus de cellule « deja vide » qui masque
un defaut. Entre deux essais on remplit a nouveau : chaque cas part du meme
etat, et un residu ne peut pas se propager d'un cas au suivant.

Ce qui est balaye : chaque longueur de run, a CHAQUE decalage de phase. Le cas
d'une routine vaut (3*colonne - phase) mod 16 ; a camera paire, 3*colonne mod
16 prend ses seize valeurs sur seize colonnes consecutives (3 est inversible
mod 16), donc seize colonnes suffisent a couvrir tous les cas.

Le controle est un ET de deux choses, a chaque etape :
  - la CARTE machine dit exactement ce que le modele dit ;
  - l'ECRAN dit exactement ce que la carte machine dit.
Le second est le plus dur : c'est lui qui attrape les residus de buffer, ces
cellules dont le bit est efface mais dont les pixels restent.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/games/r-type/tools")
from mcp import Toje                                            # noqa: E402
from gen_pellet_tables import BALL, BG, CELL_H, VP_Y            # noqa: E402
from PIL import Image                                           # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("image")
ap.add_argument("--longueurs", default="1,2,3,4,5,6,7,8,12")
ap.add_argument("--rangees", default="12")
ap.add_argument("--colonnes", default="16", help="decalages de phase balayes")
ap.add_argument("--hauteur", default="1", help="rangees par rectangle")
ap.add_argument("--scroll", default="0",
                help="trames de scroll APRES l'effacement (la demo en fait)")
ap.add_argument("-v", "--verbeux", action="store_true")
args = ap.parse_args()

image = os.path.abspath(args.image)
LWMAP = os.path.join(os.path.dirname(image),
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")
MAP_STRIDE, ROWS, CELLS = 48, 30, 384
ORG_X, ORG_Y, PX_W, PX_H = 32, 112, 4, 2
GARDE = 12

sym = {}
for line in open(LWMAP):
    m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
    if m:
        sym[m.group(1)] = int(m.group(2), 16) + 0x6100

t = Toje()
wr = lambda n, *b: t.call("write_memory", {"addr": "%04X" % sym[n],
                                           "bytes": ["%02X" % v for v in b]})
rb = lambda n: t.read("%04X" % sym[n], 1)[0]


def w16(n):
    b = t.read("%04X" % sym[n], 2)
    return (b[0] << 8) | b[1]


def carte():
    d = bytearray()
    for off in range(0, MAP_STRIDE * ROWS, 240):
        d += bytes(t.read("%04X" % (sym["field.map"] + off),
                          min(240, MAP_STRIDE * ROWS - off)))
    return d


def ecran():
    q = Image.open(t.call("screenshot")["path"]).convert("RGB").load()
    return {(x, y) for y in range(VP_Y, VP_Y + 180)
            for x in range(GARDE, 160 - GARDE)
            if sum(q[ORG_X + PX_W * x + 1, ORG_Y + PX_H * y]) > 60}


def attendu_de(c, cam, bornes=None):
    """les pixels que la carte `c` impose a l'ecran, camera `cam`.

    LES DEUX CELLULES DE BORD DU RUBAN SONT EXCLUES. Elles chevauchent une
    bande qui n'est pas dans le ruban : setCell n'en peint que la moitie, et le
    feed grave l'autre depuis les donnees du niveau. Ce n'est pas un defaut du
    moteur — c'est la definition du ruban — mais ca fait diverger un modele qui
    les compte pleines (vu le 23/08 : la cellule 53 « disparaissait » des que
    la camera bougeait)."""
    bit = lambda cc, rr: (c[rr * MAP_STRIDE + (cc >> 3)] >> (7 - (cc & 7))) & 1
    out = set()
    for X in range(GARDE, 160 - GARDE):
        cc, d = divmod(cam + X, 3)
        if not (0 <= cc < CELLS):
            continue
        if bornes and not (bornes[0] < cc < bornes[1]):
            continue
        for r in range(ROWS):
            if bit(cc, r):
                for l in range(CELL_H):
                    if BALL[l][d] != BG:
                        out.add((X, VP_Y + CELL_H * r + l))
    return out


def chunkfirst(m):
    return -(-16 * m // 3)


def remplir():
    wr("bench.fill.row", 0)            # le banc pose UNE rangee par tour
    wr("bench.fill", 1)
    for i in range(400):               # ~11 500 setCell : deux bonnes secondes
        t.call("run_frames", {"n": 4})
        if rb("bench.fill") == 0:
            break
    else:
        print("!! remplissage JAMAIS fini (row=%d) — la suite est fausse"
              % rb("bench.fill.row"))
    for _ in range(3):                 # le pipeline : la gravure est a l'ecran
        t.call("run_frames", {"n": 1}) # deux trames plus tard
    return carte()


def effacer(c0, r0, n, h=1):
    wr("pscroll.rect.c0", (c0 >> 8) & 255, c0 & 255)
    wr("pscroll.rect.r0", r0)
    wr("pscroll.rect.c1", (c0 >> 8) & 255, c0 & 255)
    wr("pscroll.rect.r1", r0)
    wr("pscroll.rect.w", n)
    wr("pscroll.rect.h", h)
    wr("bench.rect", 1)
    # APRES UN REMPLISSAGE, gfxlock se resynchronise : le tour qui a porte les
    # ~11 500 setCell a deborde de plus de cent trames, et la boucle ne
    # reprend pas au tour suivant. Quarante trames ne suffisaient pas — le
    # pilote croyait l'effacement jamais consomme (23/08).
    # SONDER PAR GROS PAQUETS. Apres un remplissage, un tour de boucle deborde
    # largement de la trame ; interroger le temoin toutes les une ou deux
    # trames faisait conclure a tort « jamais consomme » alors que l'effacement
    # se faisait tres bien (23/08).
    for _ in range(40):
        t.call("run_frames", {"n": 10})
        if rb("bench.rect") == 0:
            break
    else:
        st = t.call("machine_state", {})["registers"]
        print("   !! rect bloque : fill=%d rect=%d pc=%s tour=%d | a=%d b=%d "
              "n=%d row=%d left=%d"
              % (rb("bench.fill"), rb("bench.rect"), st["pc"],
                 t.read("9D00", 1)[0], w16("pscroll.rect.a"),
                 w16("pscroll.rect.b"), w16("pscroll.rect.n"),
                 rb("pscroll.rect.row"), rb("pscroll.rect.left")))
        return False
    for _ in range(3):
        t.call("run_frames", {"n": 1})
    return True


# =============================================================================
t.boot_floppy(image)
wr("smiley.loop", 0)                   # pas de mire : le champ plein la remplace
wr("smiley.row", 60)
wr("cytron.enable", 0)
wr("ctrlspeedx", 0, 0)                 # PAS DE SCROLL : camera figee
# pscroll n'a plus de vitesse a lui (24/08/2026) : le banc integre ctrlspeedx
# dans SA camera et la donne au module. Une seule manette a tourner.
t.call("run_frames", {"n": 30})
cam = w16("pscroll.camera.x")
edge = rb("pscroll.edge16")
lo, hi = chunkfirst(edge), chunkfirst(edge + 10) - 1
print("camera %d (figee), ruban cellules %d..%d" % (cam, lo, hi))

# --- etape 1 : le champ plein -----------------------------------------------
ref = remplir()
plein = sum(bin(x).count("1") for x in ref)
vu, att = ecran(), attendu_de(ref, cam, (lo, hi))
print("champ plein : %d bits poses, ecran %d px | %d manquants, %d en trop"
      % (plein, len(vu), len(att - vu), len(vu - att)))
if att != vu:
    print("!! le champ plein lui-meme ne s'affiche pas exactement — "
          "rien de ce qui suit ne voudra dire grand-chose")
    for p in sorted(att - vu)[:5]:
        print("   manquant", p)
    for p in sorted(vu - att)[:5]:
        print("   en trop ", p)

# --- etape 2 : la matrice, un cas a la fois ---------------------------------
LONGUEURS = [int(x) for x in args.longueurs.split(",")]
RANGEES = [int(x) for x in args.rangees.split(",")]
NCOL = int(args.colonnes)
H = int(args.hauteur)
SCROLL = int(args.scroll)
base = lo + 4                          # a l'aise dans le ruban
fautes = []
essais = 0

for n in LONGUEURS:
    ligne = []
    for r0 in RANGEES:
        for k in range(NCOL):
            c0 = base + k
            if c0 + n - 1 > hi:
                continue
            essais += 1
            avant = remplir()
            if not effacer(c0, r0, n, H):
                fautes.append((n, c0, r0, "bench.rect jamais consomme"))
                ligne.append("!")
                continue
            if SCROLL:
                # LE SCROLL D'APRES. La demo en fait, la matrice n'en faisait
                # pas : si un residu n'apparait qu'une fois la camera bougee,
                # c'est le feed qui regrave par-dessus l'effacement.
                wr("ctrlspeedx", 0, 0x30)
                for _ in range(SCROLL):
                    t.call("run_frames", {"n": 1})
                wr("ctrlspeedx", 0, 0)
                for _ in range(4):
                    t.call("run_frames", {"n": 1})
            apres = carte()
            # le modele : les n cellules, bornees comme prep le fait
            mod = bytearray(avant)
            a = max(c0, lo)
            b = min(c0 + n - 1, hi)
            for r in range(r0, min(r0 + H, ROWS)):
                for c in range(a, b + 1):
                    mod[r * MAP_STRIDE + (c >> 3)] &= ~(1 << (7 - (c & 7))) & 0xFF
            dcarte = [i for i in range(len(mod)) if mod[i] != apres[i]]
            vu = ecran()
            att = attendu_de(apres, w16("pscroll.camera.x"), (lo, hi))
            mq, tr = att - vu, vu - att
            cas = (3 * c0 - (cam & 1)) % 16
            if dcarte or mq or tr:
                fautes.append((n, c0, r0, "carte %d octets, ecran %d manquants "
                               "%d en trop (cas %d)"
                               % (len(dcarte), len(mq), len(tr), cas)))
                ligne.append("X")
                if args.verbeux:
                    print("   n=%-2d c=%-3d r=%-2d cas=%-2d : carte %d octets, "
                          "ecran %d/%d" % (n, c0, r0, cas, len(dcarte),
                                           len(mq), len(tr)))
                    print("      prep : a=%d b=%d n=%d m0=%d m1=%d done=%d"
                          % (w16("pscroll.rect.a"), w16("pscroll.rect.b"),
                             w16("pscroll.rect.n"), rb("pscroll.rect.m0"),
                             rb("pscroll.rect.m1"), rb("pscroll.rect.done")))
                    for i in dcarte[:3]:
                        r, o = divmod(i, MAP_STRIDE)
                        att_b, vu_b = mod[i], apres[i]
                        diff = att_b ^ vu_b
                        cells = [o * 8 + k for k in range(8)
                                 if (diff >> (7 - k)) & 1]
                        print("      rangee %d octet %d : modele %02X machine "
                              "%02X -> cellules %s %s" % (
                                  r, o, att_b, vu_b, cells,
                                  "que la machine a GARDEES"
                                  if (vu_b & diff) else "que la machine a EFFACEES"))
                    for nom, ens in (("manquants", mq), ("en trop", tr)):
                        if ens:
                            print("      %-9s : cellules %s | rangees %s | "
                                  "lignes-dans-rangee %s"
                                  % (nom,
                                     sorted({(cam + x) // 3 for x, y in ens}),
                                     sorted({(y - VP_Y) // CELL_H for x, y in ens}),
                                     sorted({(y - VP_Y) % CELL_H for x, y in ens})))
            else:
                ligne.append(".")
    print("longueur %-2d (h=%d) : %s" % (n, H, "".join(ligne)))

print("\n%d essais, %d fautifs" % (essais, len(fautes)))
for n, c0, r0, quoi in fautes[:25]:
    print("  n=%-2d colonne %-3d rangee %-2d : %s" % (n, c0, r0, quoi))
t.close()
sys.exit(0 if not fautes else 1)
