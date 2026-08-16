#!/usr/bin/env python3
"""Deriver les palettes CHARGEES par le stage 1 depuis `pal-next.png` (groupe E).

    tools/palette_stage.py            mesure et dit ce qu'il ferait
    tools/palette_stage.py --ecrire   ecrit les deux fichiers

Le stage 1 ne charge pas une palette mais DEUX, et le config les nomme
separement : `Pal_stage` (le jeu) et `Pal_tunnel` (l'interieur, ou le fondu
`fadetotunnel` emmene la palette a l'entree du tunnel). Elles doivent etre dans
la MEME numerotation, sinon le fondu melange deux mondes.

MESURE QUI FONDE CE FICHIER (16/08/2026, et qui a fait tomber la version
initiale du groupe E) : sur le stage 1, l'index materiel 15 n'est pas une
couleur, c'est un ROLE — le ciel. Deux preuves independantes :

  * `pal.png` et `pal-inside.png` ne different que d'UNE entree, la 15 :
    `#000000` (le ciel du niveau) devient `#617A7A` (l'interieur du tunnel).
    Le fondu vers le tunnel EST le recoloriage de cette seule case ;
  * l'image du niveau (`src/stages/01/map/in.png`) pose 234 652 px sur cet
    index — tout le ciel — contre 9 061 px de vrai noir sur l'index 0, qui est
    le noir du DECOR (structures haut et bas).

Le champ d'etoiles repose sur cette distinction : il ne dessine que sur le
« ciel vierge » (nibble $F) et laisse le noir du decor tranquille, et
`checkpoint` efface les deux tampons a `$FFFF` pour que le ciel jamais dessine
soit du ciel. Verser le ciel dans l'index 0 aurait donc coute trois choses a la
fois : des etoiles dans la silhouette de la ville et dans le noir des sprites,
un fondu de tunnel qui recolore aussi tout ce noir-la, et une palette de tunnel
sans objet. C'est pourquoi ce script ne touche NI au starfield, NI aux
effacements, NI a l'effaceur de shells : ils sont deja justes.

Ce que ce script fait, donc : `pal-next.png` porte `#9ECC00` en case 15 — une
couleur que le stage 1 ne peut pas heberger, sa quatrieme case propre etant
prise par le ciel. Les deux palettes du stage sont derivees en reposant le
ciel :

    pal-next-stage.png   = pal-next.png avec 15 = le ciel de pal.png        (#000000)
    pal-next-inside.png  = pal-next.png avec 15 = le tunnel de pal-inside   (#617A7A)

Rien n'est saisi a la main : les deux valeurs sont LUES dans les anciennes
palettes, la case a remplacer est CALCULEE (la seule qui differe entre les
deux), et un garde-fou verifie que cette case est bien celle que l'image du
niveau emploie le plus. Si l'une de ces trois choses cesse d'etre vraie,
l'outil ARRETE au lieu de deviner.

`pal-next.png` n'est jamais reecrit : c'est la palette de reference de la
campagne, elle appartient a l'auteur. Les trois autres cases propres au stage
(12, 13, 14 : les deux beiges et l'olive) y sont deja justes, l'outil le
verifie.
"""
import argparse
import os
import sys

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
PROJET = os.path.dirname(ICI)
PAL = os.path.join(PROJET, 'src/stages/01/palette')

ANCIENNE = os.path.join(PAL, 'pal.png')
ANCIENNE_TUNNEL = os.path.join(PAL, 'pal-inside.png')
NOUVELLE = os.path.join(PAL, 'pal-next.png')
SORTIE_JEU = os.path.join(PAL, 'pal-next-stage.png')
SORTIE_TUNNEL = os.path.join(PAL, 'pal-next-inside.png')
NIVEAU = os.path.join(PROJET, 'src/stages/01/map/in.png')

# Les trois cases propres au stage deja posees dans pal-next : les deux beiges
# et l'olive. Elles viennent de l'ancienne palette, l'outil verifie qu'elles y
# sont bien — sinon la 4e case (le ciel) n'est pas celle qu'on croit.
SPECIFIQUES_ATTENDUES = {12: (0x9E, 0x8F, 0x7A), 13: (0xCC, 0xC2, 0xAB), 14: (0x61, 0x7A, 0x00)}


def couleurs(chemin):
    """Les 16 couleurs MATERIELLES d'un fichier palette (PNG index i+1)."""
    p = Image.open(chemin).getpalette()
    return [tuple(p[(i + 1) * 3:(i + 1) * 3 + 3]) for i in range(16)]


def h(t):
    return '#%02X%02X%02X' % t


def ecrire(source, materiel, couleur, destination):
    im = Image.open(source)
    pal = list(im.getpalette())
    pal[(materiel + 1) * 3:(materiel + 1) * 3 + 3] = list(couleur)
    im.putpalette(pal)
    im.save(destination)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ecrire', action='store_true')
    args = ap.parse_args()

    A, T, B = couleurs(ANCIENNE), couleurs(ANCIENNE_TUNNEL), couleurs(NOUVELLE)

    # 1. La case du ciel = la seule que le fondu vers le tunnel recolore.
    ecarts = [i for i in range(16) if A[i] != T[i]]
    if len(ecarts) != 1:
        print("ARRET — pal.png et pal-inside.png different sur %d cases (%s)."
              % (len(ecarts), ecarts))
        print("  Le fondu vers le tunnel n'est donc plus le recoloriage d'UNE case :")
        print("  la derivation ci-dessous ne tient plus, il faut la refaire a la main.")
        return 1
    ciel = ecarts[0]

    # 2. Garde-fou independant : cette case doit etre celle que l'image du
    #    niveau emploie le plus — le ciel couvre l'ecran, rien d'autre n'approche.
    hist = Image.open(NIVEAU).histogram()[:17]
    domine = max(range(1, 17), key=lambda i: hist[i]) - 1
    if domine != ciel:
        print("ARRET — l'image du niveau emploie surtout l'index materiel %d,"
              " pas %d." % (domine, ciel))
        print("  Les deux mesures du ciel se contredisent : ne rien ecrire.")
        return 1

    # 3. Les trois autres cases propres au stage doivent deja etre posees.
    faux = {i: B[i] for i, c in SPECIFIQUES_ATTENDUES.items() if B[i] != c}
    if faux:
        print("ARRET — pal-next.png ne porte pas les cases propres attendues :")
        for i, c in sorted(faux.items()):
            print("    %2d : %s au lieu de %s" % (i, h(c), h(SPECIFIQUES_ATTENDUES[i])))
        return 1

    print("Ciel du stage 1 = index materiel %d (%d px de l'image du niveau, %.0f %%)."
          % (ciel, hist[ciel + 1], 100.0 * hist[ciel + 1] / sum(hist)))
    print("  jeu    : %s -> %s   (%s)" % (h(B[ciel]), h(A[ciel]), os.path.basename(SORTIE_JEU)))
    print("  tunnel : %s -> %s   (%s)" % (h(B[ciel]), h(T[ciel]), os.path.basename(SORTIE_TUNNEL)))
    print("  les 15 autres cases sont celles de pal-next.png, inchangees.")

    if args.ecrire:
        ecrire(NOUVELLE, ciel, A[ciel], SORTIE_JEU)
        ecrire(NOUVELLE, ciel, T[ciel], SORTIE_TUNNEL)
        # relecture : les deux fichiers doivent valoir pal-next partout sauf au ciel
        for chemin, attendu in ((SORTIE_JEU, A[ciel]), (SORTIE_TUNNEL, T[ciel])):
            relu = couleurs(chemin)
            if relu[ciel] != attendu or any(relu[i] != B[i] for i in range(16) if i != ciel):
                print("  ECRITURE VERIFIEE : ECART sur %s" % chemin)
                return 1
        print("  ecrit et relu : conforme.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
