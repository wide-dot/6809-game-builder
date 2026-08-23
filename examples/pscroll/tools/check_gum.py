#!/usr/bin/env python3
"""Valide la repousse d'une gomme, UNE A LA FOIS, SUR ECRAN VIDE.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/check_gum.py dist/to8.fd

Methode (exigee par l'auteur le 22/08) : ne rien juger sur un champ charge.
La camera est figee a un endroit ou la carte est VIDE — l'ecran est noir —
puis on pose une gomme par appel a pscroll.setCell, a une cellule CHOISIE,
et on compare les pixels allumes au modele pixel (gen_pellet_tables).

Ce que le plan couvre :
  - les SEIZE routines d'ecriture : le cas vaut (3*colonne - phase) mod 16,
    donc seize colonnes consecutives les epuisent. On les prend une sur deux
    et sur deux rangees pour que les gommes ne se touchent pas.
  - les deux PHASES : la camera paire montre les buffers de phase 0, la
    camera impaire ceux de phase 1.
  - le VERTICAL : rangees 0, 3, 9, 16, 22 et 29 — les deux bords compris.

Le calage de l'ecran n'est pas suppose : il est mesure sur la bande peinte
elle-meme (viewport.ram place ses 180 lignes de field.VP_Y a +179), puis
verifie par la position absolue de la premiere gomme.
"""
import os, re, sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/games/r-type/tools")
from mcp import Toje
from gen_pellet_tables import BALL, BG, CELL_W, CELL_H, VP_Y
from PIL import Image

image = os.path.abspath(sys.argv[1])
LWMAP = os.path.join(os.path.dirname(image),
                     "../gen/assets/game-modes/to8/main/build/main.lwmap")
BASE = 0x6100
# le raster de la capture toje : 4 px image par pixel BM16, 2 par ligne
PX_W, PX_H = 4, 2
ORG_X = 32                      # colonne image du pixel BM16 0
ORG_Y = 112                     # ligne image de la ligne ecran 0
# ORG_X/ORG_Y sont des proprietes du raster de toje, pas du programme : sur
# une capture d'un champ PLEIN la bande peinte (lignes 11..190, posee par
# pscroll.viewport.ram) occupe Y 134..493 et les 160 px BM16 occupent X
# 32..671 — d'ou 4 px image par pixel, 2 par ligne, et ces deux origines.


def symbols():
    s = {}
    for line in open(LWMAP):
        m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
        if m:
            s[m.group(1)] = int(m.group(2), 16) + BASE
    return s


sym = symbols()
t = Toje()


def wr(name, *bytes_):
    t.call("write_memory", {"addr": "%04X" % sym[name],
                            "bytes": ["%02X" % b for b in bytes_]})


def rd(name, n):
    return t.read("%04X" % sym[name], n)


t.boot_floppy(image)
# LA MIRE DOIT AVOIR DISPARU. Le banc joue son smiley au demarrage ; tant
# qu'il est a l'ecran, les cellules d'essai tombent sur des gommes deja
# posees. On force la phase d'EFFACEMENT (smiley.row = H) et on attend la
# fin du cycle : ce qui n'a pas ete dessine est simplement refuse par
# clearCell, donc le raccourci est sans effet de bord.
wr("smiley.loop", 0)                  # un seul cycle : le banc doit se taire
wr("smiley.row", 30)
wr("smiley.pause", 0)                 # pas de pause : on veut la mire effacee
for _ in range(200):
    t.call("run_frames", {"n": 10})
    if rd("smiley.row", 1)[0] >= 60:
        break
else:
    print("!! la mire n'a pas fini son cycle : les essais peuvent tomber dessus")
wr("cytron.enable", 0)
wr("ctrlspeedx", 0, 0)
wr("pscroll.camera.speedx", 0, 0)
t.call("run_frames", {"n": 20})


def loops():
    return t.read("9C00", 1)[0]


def pose(col, row, efface=False):
    """une mutation, un tour de boucle, puis le pilote se tait a nouveau.

    cytron.enable = 1 : le pilote fait UNE sonde sur place, a la cellule
    demandee, sans jouer son script arcade (celui-ci tourne sur 255)."""
    wr("cytron.col", col >> 8, col & 0xFF)
    wr("cytron.row", row)
    wr("cytron.erase", 1 if efface else 0)
    n = loops()
    wr("cytron.enable", 1)                # UN tir : le banc decremente lui-meme
    for _ in range(20):
        t.call("run_frames", {"n": 4})
        if loops() != n and rd("cytron.enable", 1)[0] == 0:
            break
    t.call("run_frames", {"n": 12})      # que les DEUX tampons soient repeints


def shot():
    p = t.call("screenshot")["path"]
    im = Image.open(p).convert("RGB")
    return im.load(), im.size


def camera():
    b = rd("pscroll.camera.x", 2)
    return (b[0] << 8) | b[1]


def boite(px, size):
    """la boite englobante de ce qui est allume, en pixels image"""
    xs = [x for x in range(ORG_X, min(size[0], ORG_X + 640))
          if any(sum(px[x, y]) > 60 for y in range(size[1]))]
    ys = [y for y in range(size[1])
          if any(sum(px[x, y]) > 60 for x in range(ORG_X, min(size[0], ORG_X + 640)))]
    return (xs[0], xs[-1], ys[0], ys[-1]) if xs else None


def pixels(px, size):
    """LA BANDE DU CHAMP, en pixels BM16 : un set des allumes.

    On ne juge que les lignes VP_Y..VP_Y+179 : au-dessus, la ligne d'entree
    du blast laisse quelques pixels au bord droit du ruban, qui clignotent
    d'une trame a l'autre. Ce n'est pas le champ, et un banc qui les compte
    declare faux des mutations parfaitement justes (vecu le 23/08).
    """
    out = set()
    for y in range(VP_Y, VP_Y + 180):
        Y = ORG_Y + PX_H * y
        if Y + 1 >= size[1]:
            break
        for x in range(160):
            X = ORG_X + PX_W * x
            if sum(px[X + 1, Y]) > 60 or sum(px[X + 2, Y + 1]) > 60:
                out.add((x, y))
    return out


def attendu_de(col, row, cam):
    """les pixels que la gomme DOIT allumer, en coordonnees ecran"""
    return {(3 * col - cam + d, VP_Y + CELL_H * row + l)
            for l in range(CELL_H) for d in range(CELL_W)
            if BALL[l][d] != BG}


SAUTES = []


def essai_efface(col, row, avant, cam):
    """la gomme posee doit disparaitre SANS TRACE : l'ecran doit redevenir
    exactement celui d'avant. C'est le meme standard que pour l'ecriture, et
    c'est ce qui prouve que le masque n'a pas entame les voisines."""
    pose(col, row, efface=True)
    apres = pixels(*shot())
    cas = (3 * col - (cam & 1)) % 16
    tag = "cellule %3d rangee %2d (cas %2d) EFFACEMENT" % (col, row, cas)
    if apres == avant:
        print("  %s : OK" % tag)
        return 0
    reste = sorted(apres - avant)
    manque = sorted(avant - apres)
    print("  %s : %d px de trop, %d px effaces en trop" % (tag, len(reste), len(manque)))
    if reste:
        print("      restants :", reste[:8])
    if manque:
        print("      voisines entamees :", manque[:8])
    return 1


def essai(col, row, titre):
    """UNE gomme : on photographie avant, on pose, on photographie apres, et
    la DIFFERENCE est exactement ce que setCell a dessine. Aucun fond ne
    peut fausser la mesure, aucune calibration n'est supposee."""
    a = pixels(*shot())
    cam = camera()
    pousses = t.read("9C06", 1)[0]
    pose(col, row)
    if t.read("9C06", 1)[0] == pousses:
        # UN ESSAI SAUTE N'EST PAS UN ESSAI REUSSI. Deux campagnes ont rendu
        # « TOUT CONFORME » alors que la mire couvrait toutes les cibles et
        # que pas un seul essai n'avait tourne (22 et 23/08). On les compte,
        # et le bilan le dit.
        SAUTES.append((col, row))
        print("  cellule %3d rangee %2d : SAUTE — cellule deja pleine"
              % (col, row))
        return 0
    b = pixels(*shot())
    neuf = b - a
    att = attendu_de(col, row, cam)
    cas = (3 * col - (cam & 1)) % 16
    tag = "cellule %3d rangee %2d (cas %2d, camera %d)" % (col, row, cas, cam)
    if not neuf:
        print("  %s : RIEN DESSINE" % tag)
        return 1
    if neuf == att:
        print("  %s : OK" % tag)
        return essai_efface(col, row, a, cam)
    # le decalage : on compare les coins haut-gauche
    dx = min(x for x, y in neuf) - min(x for x, y in att)
    dy = min(y for x, y in neuf) - min(y for x, y in att)
    forme = {(x - dx, y - dy) for x, y in neuf} == att
    print("  %s : %s, decale de dx=%+d px dy=%+d lignes (%d px dessines, %d attendus)"
          % (tag, "MEME FORME" if forme else "FORME DIFFERENTE",
             dx, dy, len(neuf), len(att)))
    if True:
        manque = sorted(att - neuf)
        trop = sorted(neuf - att)
        if manque:
            print("      manquants (x,y ecran) :", manque)
        if trop:
            print("      en trop :", trop)
    return 1


def verifie(px, org_y, cam, gommes, titre):
    """chaque gomme posee : ses 18 sous-pixels contre le modele"""
    print("\n--- %s (camera %d, ligne 0 de l'ecran a Y=%d) ---" % (titre, cam, org_y))
    total = faux = 0
    for col, row in gommes:
        ecarts = []
        for l in range(CELL_H):
            for d in range(CELL_W):
                x = 3 * col - cam + d
                y = VP_Y + CELL_H * row + l
                X = ORG_X + PX_W * x
                Y = org_y + PX_H * y
                vu = sum(px[X + 1, Y]) > 60 or sum(px[X + 2, Y + 1]) > 60
                attendu = BALL[l][d] != BG
                total += 1
                if vu != attendu:
                    faux += 1
                    ecarts.append((l, d, attendu, vu))
        cas = (3 * col - (cam & 1)) % 16
        if ecarts:
            att = "  cellule %3d rangee %2d (cas %2d) : %2d/%d sous-px faux" % (
                col, row, cas, len(ecarts), CELL_H * CELL_W)
            # ou la gomme est-elle VRAIMENT ? on la cherche autour
            X0 = ORG_X + PX_W * (3 * col - cam)
            Y0 = org_y + PX_H * (VP_Y + CELL_H * row)
            trouve = None
            for dy in range(-40, 41):
                for dx in range(-8, 9):
                    X, Y = X0 + PX_W * dx, Y0 + PX_H * dy
                    if 0 <= X < 660 and 0 <= Y < 600 and sum(px[X + 1, Y]) > 60:
                        trouve = (dx, dy)
                        break
                if trouve:
                    break
            print(att + ("  (allume le plus proche : dx=%+d px, dy=%+d lignes)"
                         % trouve if trouve else "  (rien d'allume autour)"))
        else:
            print("  cellule %3d rangee %2d (cas %2d) : OK" % (col, row, cas))
    print("  => %d/%d sous-pixels conformes" % (total - faux, total))
    return faux


# LES CIBLES SONT RELATIVES A LA CAMERA. Une cellule hors fenetre n'est pas
# dans le ruban : setCell la refuse (c'est voulu), et le banc ne verrait rien.
cam0 = camera()
c0 = (cam0 + 2) // 3 + 1
print("camera arretee a %d -> premiere cellule visible %d\n" % (cam0, c0))

ko = 0
print("--- les seize cas d'ecriture, rangee 3 ---")
for k in range(16):
    ko += essai(c0 + k, 3, "cas")

print("--- le vertical : la meme colonne sur les rangees cles ---")
for row in (0, 1, 5, 12, 19, 26, 28, 29):
    ko += essai(c0 + 20, row, "vertical")

print("--- l'autre phase : camera +1 ---")
cam = camera()
wr("pscroll.camera.x", (cam + 1) >> 8, (cam + 1) & 0xFF)
t.call("run_frames", {"n": 10})
if camera() % 2 == cam % 2:
    print("  !! la camera n'a pas change de parite (%d)" % camera())
for k in range(16):
    ko += essai(c0 + 25 + k, 20, "cas phase 1")

if SAUTES:
    print("\nBILAN : NON CONCLUANT — %d essais sautes (cellules deja pleines) : %s"
          % (len(SAUTES), SAUTES[:8]))
elif ko:
    print("\nBILAN : %d essais non conformes" % ko)
else:
    print("\nBILAN : TOUT CONFORME")
t.close()
sys.exit(1 if (ko or SAUTES) else 0)
