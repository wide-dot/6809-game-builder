#!/usr/bin/env python3
"""Les cas d'effacement du champ de gommes, DERIVES et non inventes.

    python3 tools/gen_gum_cases.py [--planches <dir>]

Jusqu'ici les cas du banc etaient choisis a la main — « un bloc 4x4 », « balaye
de six » — et l'un d'eux (le balaye de six) ne correspondait a rien de ce que le
jeu produit. Ce script part des CARACTERISTIQUES des objets qui effacent :
leur empreinte, leur vitesse, leur cadence. Le reste se calcule.

    longueur du run = empreinte + deplacement pendant la trame
    deplacement     = (vitesse propre + vitesse de scroll) x (1 + frame drop)

Sources, toutes relevees dans la base Ghidra arcade (voir l'etude, section
« cartographie ») :

  0x40:2702  erase_green_ball_block4x4_stage4 — quatre grappes 2x2 aux
             decalages (+-8, +-8) px arcade : un bloc de 4x4 CELLULES.
  0x40:2C94  force_pod_horizontal_tracking — velocite +-0x180, soit 1,5 px
             arcade par trame en POURSUITE.
  0x40:2581  run_force_pod_attached — l'EJECTION part a +-0x900, soit 9 px
             arcade par trame, jusqu'au mur ou aux bandes de garde. C'est la
             vitesse qui dimensionne le run du pod, pas la poursuite.
  0x40:31D9  run_fire_beam — pos_x += 0x0008.00 par trame, soit EXACTEMENT une
             cellule ; CX balayages de +8 px, CX venant de la table 0x1000:183E.
  0x40:2D50  run_bit_devices — grappe 2x2, orbite autour du joueur, velocite
             8.8 lue dans la table 0x1000:16DE : de 4.0 a 15.0 px arcade par
             trame selon l'amplitude du swing (releve du 23/08).
  0x40:49CF  counter-air laser — onze blocs 4x4, mais une trame sur seize.
  0x40:4FB9  erase_green_ball_cell_stage4 — une cellule (missiles, tir simple),
             qui meurent sur la premiere gomme.

UNITES — le ratio de resolution. Tout ce script travaille en px ARCADE et en
CELLULES : 8 px arcade = 1 cellule, et c'est la seule division. La conversion
vers les px larges v2 (x0,375 : 384 colonnes arcade -> 144 px larges) et vers
les lignes (x0,75) n'intervient QUE dans pellet.grow et les planches — jamais
dans le calcul des runs, qui resterait faux si on melangait les deux echelles.

Et cote v2 :
  games/r-type/src/stages/04/stage.asm — vitesse de scroll $0030 en 8.8, soit
  0,1875 px large par trame, c'est-a-dire 0,5 px ARCADE : une cellule toutes
  les seize trames. C'est lent, et ca compte : le banc scrollait a 1 px large
  par trame, cinq fois trop vite, ce qui gonflait artificiellement les unions.
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw

# --- l'echelle, celle du portage ---------------------------------------------
ARCADE_PX_PER_CELL = 8                 # une tuile arcade = une cellule de gomme
CELL_W = 3                             # px larges
CELL_H = 6                             # lignes
SCROLL_ARCADE = 0.5                    # px arcade par trame, stage 4 ($0030)
FRAME_DROPS = (0, 1, 2, 3)             # ce que la compensation peut avaler


class Arme:
    def __init__(self, nom, w, h, vitesse, cadence, source, note="", perce=True):
        self.nom = nom
        self.w = w                     # empreinte, en cellules
        self.h = h
        self.vitesse = vitesse         # px arcade par trame, RELATIVE a l'ecran
        self.cadence = cadence         # trames entre deux effacements
        self.source = source
        self.note = note
        # PERCE : l'arme survit-elle a la gomme qu'elle efface ? Le tir simple
        # et les missiles meurent sur la PREMIERE (l'effaceur rend 0, que
        # l'appelant relit comme un mur) : ils n'ont pas d'union balayee, quelle
        # que soit leur vitesse.
        self.perce = perce

    def deplacement(self, drop):
        """en cellules, pendant UNE trame rendue, relativement a la CARTE"""
        ticks = 1 + drop
        return (abs(self.vitesse) + SCROLL_ARCADE) * ticks / ARCADE_PX_PER_CELL

    def runs(self):
        """les longueurs de run que cette arme produit reellement.

        La longueur depend de l'alignement sous-cellule : un deplacement d
        donne w + floor(d) ou w + ceil(d) suivant la phase, et une vitesse
        variable (le bit va de 4 a 15) produit TOUT l'intervalle. On rend donc
        la plage continue [w .. w + ceil(d_max)] — pas d'echantillonnage qui
        raterait une longueur intermediaire."""
        if not self.perce:
            return [self.w]
        d_max = self.deplacement(FRAME_DROPS[-1])
        return list(range(self.w, self.w + int(d_max + 0.999) + 1))


ARMES = [
    Arme("Force Pod (poursuite)", 4, 4, 1.5, 1, "0x40:2702 + 0x40:2C94",
         "ses trois etats, a chaque trame ; jamais detruit, portee infinie"),
    Arme("Force Pod (ejection)", 4, 4, 9.0, 1, "0x40:2581 (+-0x900)",
         "9 px arcade/trame jusqu'au mur : la vitesse qui dimensionne son run"),
    Arme("Bit Device", 2, 2, 15.0, 1, "0x40:2D50 + 0x1000:16DE",
         "orbite ; la table de rattrapage monte a 15 px arcade/trame"),
    Arme("Wave Cannon (palier bas)", 6, 2, 8.0, 1, "0x40:31D9 + 0x1000:183E",
         "CX+1 colonnes, CX = 5 au palier bas"),
    Arme("Wave Cannon (palier max)", 11, 2, 8.0, 1, "0x40:31D9 + 0x1000:183E",
         "CX = 10 ; le palier decroit d'une trame a l'autre, le tunnel se ferme"),
    Arme("Counter-Air Laser", 4, 4, 0.0, 16, "0x40:49CF",
         "onze blocs disperses, mais une seule trame sur seize"),
    Arme("Tir simple / missile", 1, 1, 6.0, 1, "0x40:4FB9",
         "meurt sur la PREMIERE gomme : jamais plus d'une cellule", False),
]

# ce que le moteur sait faire, et a quel prix (mesures du 23/08, cy par case)
ROUTINES = {
    1: ("clearCell", 610),
    4: ("run de 4", 610),
    5: ("run de 5", 526),
}
SEUIL_BANDE = 8                        # pscroll.CLEAR_UNROLL


def regime(n):
    if n in ROUTINES:
        return "routine dediee", ROUTINES[n][0]
    if n >= SEUIL_BANDE:
        return "bande deroulee", "zrow"
    return "PAR CELLULE", "-"


# --- les planches ------------------------------------------------------------
PX = 14                                # un cote de cellule, en pixels d'image
MARGE = 40
FOND = (24, 26, 32)
GRILLE = (56, 60, 72)
GOMME = (120, 200, 130)
EMPREINTE = (230, 180, 60)
BALAYE = (200, 90, 70)
TEXTE = (230, 232, 238)


def planche_arme(a, dest):
    """l'empreinte de l'arme, et ce que son deplacement en fait sur une trame"""
    cols = a.w + 6
    lignes = a.h + 2
    larg = MARGE * 2 + cols * PX
    haut = MARGE + 30 + len(FRAME_DROPS) * (lignes * PX + 34)
    im = Image.new("RGB", (larg, haut), FOND)
    d = ImageDraw.Draw(im)
    d.text((MARGE, 10), "%s — empreinte %dx%d cellules, %.1f px arcade/trame"
           % (a.nom, a.w, a.h, a.vitesse), fill=TEXTE)
    d.text((MARGE, 24), "source : %s" % a.source, fill=(150, 155, 168))

    y0 = MARGE + 26
    for drop in FRAME_DROPS:
        dep = a.deplacement(drop)
        n = a.w + int(dep + 0.999)
        reg, nom = regime(n)
        d.text((MARGE, y0 - 2), "frame drop %d : deplacement %.2f cellule -> "
               "run de %d a %d  (%s : %s)" % (drop, dep, a.w, n, reg, nom),
               fill=TEXTE if reg != "PAR CELLULE" else BALAYE)
        yg = y0 + 14
        for r in range(lignes):
            for c in range(cols):
                x = MARGE + c * PX
                y = yg + r * PX
                dedans_h = 1 <= r <= a.h
                if dedans_h and 1 <= c <= a.w:
                    coul = EMPREINTE
                elif dedans_h and a.w < c <= n:
                    coul = BALAYE
                else:
                    coul = None
                if coul:
                    d.rectangle([x, y, x + PX - 2, y + PX - 2], fill=coul)
                d.rectangle([x, y, x + PX - 2, y + PX - 2], outline=GRILLE)
        y0 = yg + lignes * PX + 20
    im.save(dest)
    return dest


def planche_couverture(dest, runs_reels):
    """quelles longueurs le jeu produit, et par quel chemin le moteur les traite"""
    nmax = max(max(runs_reels), SEUIL_BANDE + 2)
    larg = MARGE * 2 + nmax * (PX + 12)
    im = Image.new("RGB", (larg, 210), FOND)
    d = ImageDraw.Draw(im)
    d.text((MARGE, 10), "Longueurs de run que le stage 4 produit, "
                        "et le chemin qui les traite", fill=TEXTE)
    d.text((MARGE, 26), "jaune = routine dediee   bleu = bande deroulee   "
                        "rouge = repli par cellule", fill=(150, 155, 168))
    for i in range(1, nmax + 1):
        x = MARGE + (i - 1) * (PX + 12)
        reel = i in runs_reels
        reg, _ = regime(i)
        coul = {"routine dediee": EMPREINTE, "bande deroulee": (90, 140, 210),
                "PAR CELLULE": BALAYE}[reg]
        h = 60 if reel else 20
        d.rectangle([x, 150 - h, x + PX + 6, 150], fill=coul if reel else GRILLE)
        d.text((x + 2, 156), str(i), fill=TEXTE)
        if reel:
            d.text((x + 2, 172), "x", fill=TEXTE)
    d.text((MARGE, 190), "« x » = longueur effectivement produite par une arme",
           fill=(150, 155, 168))
    im.save(dest)
    return dest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--planches", default="doc/gommes-cas")
    a = ap.parse_args()
    os.makedirs(a.planches, exist_ok=True)

    print("Vitesse de scroll du stage 4 : %.2f px arcade/trame "
          "(%.3f cellule)" % (SCROLL_ARCADE, SCROLL_ARCADE / ARCADE_PX_PER_CELL))
    print()
    print("%-26s %-9s %-7s %-16s %s" % ("arme", "empreinte", "px/tr",
                                        "runs produits", "chemin"))
    print("-" * 86)
    tous = set()
    for arme in ARMES:
        r = arme.runs()
        tous |= set(r)
        chemins = sorted({regime(n)[0] for n in r})
        print("%-26s %-9s %-7.1f %-16s %s"
              % (arme.nom, "%dx%d" % (arme.w, arme.h), arme.vitesse,
                 ",".join(str(x) for x in r), " + ".join(chemins)))
        planche_arme(arme, os.path.join(
            a.planches, "arme-%s.png" % arme.nom.split()[0].lower()))
    print()
    manquants = sorted(n for n in tous
                       if regime(n)[0] == "PAR CELLULE")
    print("longueurs produites :", ",".join(str(n) for n in sorted(tous)))
    if manquants:
        print("SANS ROUTINE DEDIEE  :", ",".join(str(n) for n in manquants),
              "-> repli par cellule, le chemin le plus cher")
    else:
        print("toutes ont leur chemin rapide.")
    planche_couverture(os.path.join(a.planches, "couverture.png"), tous)
    print("\nplanches ecrites dans", a.planches)
    return 0


if __name__ == "__main__":
    sys.exit(main())
