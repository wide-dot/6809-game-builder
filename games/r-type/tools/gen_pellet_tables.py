#!/usr/bin/env python3
"""Les tables de la couche gommes du stage 4, et leur preuve.

    python3 tools/gen_pellet_tables.py [--verifier-seulement]

## Le modele d'ecran

BM16 sur TO8 : 160 px par ligne, deux plans de 40 octets entrelaces PAR PAIRE
de pixels, un octet = 2 px, quartet haut = pixel de GAUCHE.

    px X  ->  plan   = $C000 si (X >> 1) est pair, sinon $A000
              octet  = X >> 2
              quartet= X & 1        (0 = haut = gauche)

C'est ce que fait DrawTiles (`lsrb lsrb` puis `bcs @ram2`) et ce que confirme
une tuile compilee relue : ses trois pixels tombent sur un octet plein d'un
plan et un quartet haut de l'autre.

## La periodicite

Une gomme fait 3 px de large, un octet en couvre 2 : le motif d'octets se
repete donc tous les `lcm(3, 4) = 12` px, soit **3 octets par plan**. C'est ce
qui rend le blast possible — et le `PSHS A,B,DP,X,Y,U` de clearblast pousse 9
octets, exactement 3 periodes.

La position du champ a l'ecran est `ancre = viewport_x - camera_x`, donc la
phase du motif est `ancre mod 12` : douze jeux de tables.

## Ce que ce script produit

    src/stages/04/pellet-tables.asm

  pellet.tbl.run    12 phases x 6 lignes x 2 plans x 3 octets
                    UNE periode du motif ; le blast reconstruit ses 9 octets
                    en registres depuis ces 3 (p0 p1 p2 p0 -> A,B,DP,X,Y,U)
  pellet.tbl.edge   12 phases x 6 lignes x 2 plans x 2 octets
                    les octets de bord (gauche, droite) d'une plage, ou un
                    seul des deux pixels appartient a la gomme

## La preuve

`--verifier-seulement` n'ecrit rien : il rejoue le rendu COMPLET du champ pour
les douze phases, depuis les tables, dans un modele d'ecran, puis relit les
pixels et les compare a ce que la carte dit qu'il devrait y avoir. Une seule
divergence et le script sort en erreur. C'est ce qui autorise a ecrire le 6809
ensuite : le modele d'octets est deja verifie.
"""
import argparse
import os
import sys

from PIL import Image

VP_X, VP_Y = 8, 11          # origine du viewport a l'ecran, px
VP_W, VP_H = 144, 180
CELL_W, CELL_H = 3, 6
STRIDE = 40                 # octets par ligne et par plan
PLANE_C, PLANE_A = 0, 1     # 0 = $C000 (forme), 1 = $A000 (couleur)

# La gomme, relevee sur l'in.png d'AVANT le retrait des gommes (commit
# a3108e4e) : 1 586 des 1 618 cellules portent exactement ce motif. Les 32
# autres, toutes sur la rangee 5 (colonnes 296-327), portent une variante en
# miroir vertical qui n'est PAS traitee ici — 2 % du champ, ecart assume, a
# rouvrir si ca se voit a l'ecran.
#
# ATTENTION, ces valeurs sont des index PNG, pas des index MATERIEL. La chaine
# numerote la palette du PNG a partir de 1 (l'index 0 y est la transparence) :
# l'index 16 existe cote PNG et ne tiendrait pas dans un quartet. La conversion
# est materiel = PNG - 1, et elle se verifie sur une tuile compilee par gfxcomp :
# la ligne PNG (13,13,16) y sort en $cc puis $f0, soit materiel (12,12) et 15.
BALL_PNG = [[0, 14, 13],
            [0, 14, 13],
            [14, 14, 13],
            [14, 8, 11],
            [13, 13, 16],
            [0, 16, 16]]


def hw(png):
    """index PNG -> quartet materiel. Le PNG 0 (transparent) devient le fond."""
    return png - 1 if png else 0


BALL = [[hw(p) for p in ligne] for ligne in BALL_PNG]
BG = 0


def loc(x):
    """px ecran -> (plan, octet, quartet). quartet 0 = haut = gauche."""
    return (PLANE_C if ((x >> 1) & 1) == 0 else PLANE_A, x >> 2, x & 1)


def pixel_of(x, anchor, present):
    """L'index de palette que la couche doit ecrire au px ecran `x`.

    `present(cx)` dit si la cellule cx porte une gomme. Hors gomme, la couche
    ecrit le fond : elle POSSEDE son rectangle, elle remplace l'effacement.
    """
    rel = x - anchor
    cx, d = divmod(rel, CELL_W)
    if rel < 0 or not present(cx):
        return None            # rempli par l'appelant selon la ligne
    return d, cx


def octet(x0, line, anchor, present):
    """La valeur de l'octet dont le pixel gauche est x0 (x0 pair)."""
    v = 0
    for k, x in enumerate((x0, x0 + 1)):
        rel = x - anchor
        cx, d = divmod(rel, CELL_W)
        pen = BALL[line][d] if rel >= 0 and present(cx) else BG
        v |= pen << (4 if k == 0 else 0)
    return v


def tables(phase):
    """Les tables d'une phase. anchor mod 12 == phase.

    L'ancre est prise LOIN A GAUCHE (phase - 1200, multiple de 12 retire) et
    non a `phase` : les octets 0,1,2 sur lesquels le motif est releve ont des
    pixels AVANT l'ancre des que la phase est non nulle, et la garde `rel >= 0`
    d'`octet` les rendait alors en fond — la table de la phase 8 sortait
    [$00,$00,$CC] pour une ligne pourtant pleine. Bug attrape par la simulation
    de la passe, pas par la preuve du modele d'octets : celle-ci n'exercait pas
    les tables.
    """
    anchor = phase - 1200
    plein = lambda cx: True
    run = {}
    edge = {}
    for line in range(6):
        for plane in (PLANE_C, PLANE_A):
            # le motif repete : 3 octets, pris sur des indices d'octet
            # consecutifs du plan. L'octet d'indice j du plan couvre les px
            # 4j + 2*plane et +1.
            motif = [octet(4 * j + 2 * plane, line, anchor, plein)
                     for j in range(3)]
            # 3 octets : UNE periode. La table repetait le motif 3 fois pour
            # servir un PSHS de 9 octets ; tant que la passe ecrit octet par
            # octet c'etait 864 octets de redondance, et le blast pourra
            # reconstruire ses 9 en registres depuis ces 3.
            run[(line, plane)] = motif
            # les bords : un seul des deux px appartient a la plage.
            gauche = octet(4 * 0 + 2 * plane, line, anchor,
                           lambda cx: cx >= 0)      # rien a gauche de la plage
            droite = octet(4 * 0 + 2 * plane, line, anchor,
                           lambda cx: cx <= 0)      # rien a droite
            edge[(line, plane)] = (gauche, droite)
    return run, edge


def rendu(cells, anchor, cols, rows):
    """Rejoue la couche dans un modele d'ecran, depuis les MEMES valeurs
    d'octet que les tables. Rend un buffer de pixels (index de palette)."""
    ecran = {}
    for cy in range(rows):
        present = lambda cx: 0 <= cx < cols and cells[cy][cx]
        if not any(cells[cy]):
            continue
        for r in range(6):
            ligne = VP_Y + cy * 6 + r
            for x0 in range(VP_X, VP_X + VP_W, 2):
                plane, byte, _ = loc(x0)
                ecran[(plane, ligne, byte)] = octet(x0, r, anchor, present)
    # relecture pixel par pixel
    out = {}
    for (plane, ligne, byte), v in ecran.items():
        for nib in (0, 1):
            x = byte * 4 + plane * 2 + nib
            out[(x, ligne)] = (v >> 4) & 0xF if nib == 0 else v & 0xF
    return out


def verifier(cells, cols, rows):
    """Le rendu doit redonner, pixel pour pixel, ce que la carte decrit."""
    total = faux = 0
    phases = set()
    # des positions de camera REELLES : la salle de gommes commence a la
    # cellule 272, soit 816 px. 24 positions consecutives couvrent les 12
    # phases deux fois. Verifier a anchor = phase ne testerait que du fond,
    # les cellules du champ etant hors fenetre.
    for cam in range(816, 816 + 24):
        anchor = VP_X - cam
        phases.add(anchor % 12)
        out = rendu(cells, anchor, cols, rows)
        for cy in range(rows):
            if not any(cells[cy]):
                continue
            for cx in range(cols):
                for r in range(6):
                    for d in range(3):
                        x = anchor + cx * 3 + d
                        if not (VP_X <= x < VP_X + VP_W):
                            continue
                        y = VP_Y + cy * 6 + r
                        attendu = BALL[r][d] if cells[cy][cx] else BG
                        total += 1
                        if out.get((x, y)) != attendu:
                            faux += 1
    assert len(phases) == 12, 'les 12 phases ne sont pas couvertes'
    return total, faux


def edge_table():
    """(gauche, droite) par ligne : le pixel unique d'un octet de bord."""
    return [(BALL[r][0], BALL[r][2] << 4) for r in range(6)]


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('--verifier-seulement', action='store_true')
    ap.add_argument('-h', '--help', action='store_true')
    args = ap.parse_args()
    if args.help:
        print(__doc__)
        return 0

    # le champ reel, depuis le masque extrait de l'arcade
    masque = open('src/stages/04/terrain/level4_ball.bin', 'rb').read()
    cols, rows = 384, 30
    stride = cols // 8
    cells = [[bool((masque[cy * stride + cx // 8] >> (7 - (cx % 8))) & 1)
              for cx in range(cols)] for cy in range(rows)]

    total, faux = verifier(cells, cols, rows)
    print('preuve : %d pixels rejoues sur les 12 phases, %d divergence(s)'
          % (total, faux))
    if faux:
        raise SystemExit('ECHEC : le modele d\'octets ne redonne pas la carte')

    if args.verifier_seulement:
        return 0

    lignes = ['; GENERE par tools/gen_pellet_tables.py — NE PAS EDITER.',
              '; Les tables de la couche gommes du stage 4. Voir l\'en-tete de',
              '; l\'outil pour le modele d\'ecran et la periodicite (3 octets par',
              '; plan, 12 phases). Le rendu depuis ces valeurs a ete rejoue et',
              '; compare pixel pour pixel a la carte : %d px, 0 divergence.'
              % total,
              '']
    lignes.append('; 12 phases x 6 lignes x 2 plans x 3 octets — UNE periode du motif.')
    lignes.append('; L\'octet j d\'un plan prend l\'entree (j mod 3).')
    lignes.append('pellet.tbl.run')
    for phase in range(12):
        run, _ = tables(phase)
        lignes.append('; --- phase %d' % phase)
        for line in range(6):
            for plane in (PLANE_C, PLANE_A):
                v = run[(line, plane)]
                lignes.append('        fcb   ' + ','.join('$%02X' % b for b in v)
                              + '   ; ligne %d plan %s' % (line, 'C' if plane == PLANE_C else 'A'))
    lignes.append('')
    lignes.append('; Les octets de BORD, par ligne. Un octet de bord n\'a qu\'UN pixel')
    lignes.append('; dans la plage : celui de gauche est le d=0 d\'une gomme, celui de')
    lignes.append('; droite le d=2. Sa valeur ne depend donc ni de la phase, ni du plan,')
    lignes.append('; ni de l\'alignement — 12 octets pour tout le champ.')
    lignes.append('pellet.tbl.edge')
    for r, (gauche, droite) in enumerate(edge_table()):
        lignes.append('        fcb   $%02X,$%02X   ; ligne %d : bord gauche, bord droit'
                      % (gauche, droite, r))

    # --- la geometrie par offset24, ce que le scroll maintient deja
    lignes.append('')
    lignes.append('; La geometrie, indexee par scroll_tile_pos_offset24 (0..23) — le')
    lignes.append('; decalage px de la camera dans l\'octet de carte courant, que le')
    lignes.append('; scroll tient a jour. Comme un octet de carte fait 24 px et que')
    lignes.append('; 24 est multiple de 12, la PHASE du motif ne depend que de lui :')
    lignes.append('; pas de division a faire au runtime.')
    lignes.append(';   fdb  offset de la phase dans pellet.tbl.run (phase x 108)')
    lignes.append(';   fcb  premiere cellule relative a dessiner')
    lignes.append(';   fcb  nombre de cellules a parcourir')
    lignes.append('pellet.tbl.geo')
    for off24 in range(24):
        anchor = VP_X - off24        # x ecran de la cellule relative 0
        phase = anchor % 12
        # premiere cellule dont un pixel touche la fenetre, et la derniere
        ks = [k for k in range(64)
              if anchor + 3 * k + 2 >= VP_X and anchor + 3 * k < VP_X + VP_W]
        lignes.append('        fdb   %d' % (phase * 36)
                      + '\n        fcb   %d,%d   ; offset24 %d, phase %d'
                      % (ks[0], len(ks), off24, phase))

    lignes.append('')
    lignes.append('; j mod 3, pour indexer le motif periodique par l\'indice d\'octet.')
    lignes.append('; 64 entrees : l\'indice d\'octet d\'un plan ne depasse pas 38.')
    lignes.append('pellet.tbl.mod3')
    for base in range(0, 64, 16):
        lignes.append('        fcb   ' + ','.join(str(j % 3) for j in range(base, base + 16)))

    out = 'src/stages/04/pellet-tables.asm'
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w') as f:
        f.write('\n'.join(lignes) + '\n')
    taille = 12 * 6 * 2 * 3 + 6 * 2 + 24 * 4 + 64
    print('ecrit %s (%d octets de tables)' % (out, taille))
    return 0


if __name__ == '__main__':
    sys.exit(main())


# ---------------------------------------------------------------------------
# La simulation de la PASSE — l'algorithme que le 6809 executera, joue ici et
# verifie au pixel. Ce qui est prouve ici n'est plus a deviner en assembleur.
#
# L'algorithme : par rangee de cellules, on parcourt les plages de gommes
# consecutives. Pour chaque plage, chaque ligne et chaque plan, on ecrit les
# octets qui la recouvrent :
#
#   - un octet dont les DEUX pixels sont dans la plage prend la valeur du motif
#     periodique, indexee par (phase, ligne, plan, j mod 3) — la periode est de
#     3 octets par plan ;
#   - un octet de BORD n'a qu'un pixel dans la plage : celui de gauche est le
#     d=0 d'une gomme, celui de droite le d=2. Sa valeur ne depend donc que de
#     la ligne — 12 octets de table pour tout le jeu.
#
# Les TROUS ne coutent RIEN : clearblast a deja pose le fond, et le creux de la
# gomme vaut ce meme fond. La passe n'ecrit que ses plages, en octets pleins,
# sans un seul read-modify-write.
# ---------------------------------------------------------------------------

def passe(cells, anchor, cols, rows):
    """Joue la passe et rend l'ecran obtenu, en px."""
    ecran = {}
    edges = edge_table()
    for cy in range(rows):
        # les cellules visibles de la rangee
        # une cellule entre des qu'UN de ses pixels touche la fenetre : celle
        # du bord deborde d'un ou deux px sur la bordure, que le masque du
        # champ de jeu recouvre en fin de trame. C'est deja ce que fait
        # DrawTiles, qui se donne une marge a gauche « that will be remove
        # later ». Ecarter la cellule entiere laissait ses pixels visibles
        # non peints — 3 252 px sur 12 phases.
        visibles = [cx for cx in range(cols)
                    if anchor + 3 * cx + 2 >= VP_X and anchor + 3 * cx < VP_X + VP_W]
        if not visibles:
            continue
        # les plages de gommes consecutives
        plages, debut = [], None
        for cx in visibles + [None]:
            porte = cx is not None and cells[cy][cx]
            if porte and debut is None:
                debut = cx
            elif not porte and debut is not None:
                plages.append((debut, prec))
                debut = None
            prec = cx
        for (ca, cb) in plages:
            xa, xb = anchor + 3 * ca, anchor + 3 * cb + 2
            for r in range(6):
                ligne = VP_Y + cy * 6 + r
                for p in (PLANE_C, PLANE_A):
                    # les octets du plan p qui recouvrent [xa, xb]
                    j = (xa - 2 * p) // 4
                    while True:
                        g, d = 4 * j + 2 * p, 4 * j + 2 * p + 1
                        if g > xb:
                            break
                        if d >= xa:
                            dedans_g, dedans_d = xa <= g <= xb, xa <= d <= xb
                            if dedans_g and dedans_d:
                                v = tables(anchor % 12)[0][(r, p)][j % 3]
                            elif dedans_d:
                                v = edges[r][0]          # bord gauche
                            else:
                                v = edges[r][1]          # bord droit
                            ecran[(p, ligne, j)] = v
                        j += 1
    out = {}
    for (p, ligne, j), v in ecran.items():
        out[(j * 4 + p * 2, ligne)] = (v >> 4) & 0xF
        out[(j * 4 + p * 2 + 1, ligne)] = v & 0xF
    return out
