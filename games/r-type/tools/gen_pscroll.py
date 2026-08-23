#!/usr/bin/env python3
"""Le buffer de code de la couche gommes (pscroll) : gravure et PREUVE.

    python3 tools/gen_pscroll.py [--verifier-seulement]

## Le principe (contrat auteur)

Les gfx sont GRAVES dans un buffer de code persistant — le mega-sprite du
mscroll — et on ne met a jour que le delta. Ici : le SCROLL. Une colonne qui
entre par la borne droite n'a jamais ete a l'ecran, donc jamais creusee ni
semee : son contenu est celui de la carte de build, connu ici.

## Le buffer

Un chunk mscroll est `ldd #imm / ldx #imm / pshs d,x` : 8 octets de code pour
4 octets de donnees = 16 px d'ecran pour UN plan. L'ordre memoire d'un
`pshs d,x` en montant depuis S est A, B, Xh, Xl : les 4 octets sont donc, de
gauche a droite a l'ecran, [D haut][D bas][X haut][X bas], et les immediats
vivent aux offsets +1 et +4 du chunk.

Le buffer est ANCRE A LA CARTE : le chunk `m` porte le rendu des px de carte
[16m + phase, +15]. Il ne depend donc PAS de la position fine de la camera —
seule la PARITE compte (un decalage d'1 px change de quartet ET de plan), d'ou
deux jeux de buffers, phase 0 et phase 1.

## Les routines

L'unite de gravure est UNE RANGEE de cellules (6 lignes) x les 4 octets d'un
plan. La vue d'un plan sur la bande de 16 px est un peigne — 2 px, saut de
2 px — et cette combinaison NE MENTIONNE PAS LE PLAN : le meme peigne se
retrouve dans les deux, ce qui partage les routines. Compte sur la carte
reelle : 22 combinaisons distinctes, contre 28 si l'on separait les plans.

## La preuve

`--verifier-seulement` n'ecrit rien : il regrave le buffer, rejoue le
placement du blast pour TOUTES les positions de camera du niveau et les deux
parites, et compare l'ecran obtenu, pixel par pixel, a ce que la carte dit
qu'il devrait y avoir. Une divergence et le script sort en erreur.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_pellet_tables import BALL, BG, CELL_W, CELL_H, VP_Y  # le modele pixel

MAP = "src/stages/04/terrain/level4_ball.bin"
OUT = "src/stages/04/pscroll-rows.asm"

W_BYTES, ROWS = 48, 30           # la carte : 48 o x 30 rangees = 384 cellules
CELLS = W_BYTES * 8
MAP_W = CELLS * CELL_W           # 1152 px
SCREEN_W = 160                   # px visibles
CHUNK_PX = 16                    # un chunk = 16 px d'ecran pour un plan
CHUNKS = MAP_W // CHUNK_PX       # 72 bandes dans le niveau
LINE_SIZE = 80                   # 10 chunks x 8 o : le pas de ligne du buffer
CHUNK_SIZE = 8                   # ldd# ldx# pshs : les 8 octets d'un chunk
CHUNKS_PER_LINE = LINE_SIZE // CHUNK_SIZE


# --- la carte -----------------------------------------------------------------
def charger(path=MAP):
    d = open(path, "rb").read()
    assert len(d) == W_BYTES * ROWS, f"{path}: {len(d)} o, attendu {W_BYTES*ROWS}"
    return d


def present(dat, cx, r):
    """la cellule cx de la rangee r porte-t-elle une gomme ?"""
    if cx < 0 or cx >= CELLS or r < 0 or r >= ROWS:
        return False
    return bool((dat[r * W_BYTES + (cx >> 3)] >> (7 - (cx & 7))) & 1)


# --- le modele d'octet, en coordonnees CARTE ----------------------------------
def octet_carte(dat, x, r, line):
    """l'octet dont le pixel gauche est le px de carte `x`, rangee r, ligne l.

    Reprend le modele pixel de gen_pellet_tables, ancre a 0 : la cellule cx
    occupe les px [3cx, 3cx+2] et le creux vaut le fond (la couche possede son
    rectangle, elle remplace l'effacement).
    """
    v = 0
    for k, xx in enumerate((x, x + 1)):
        cx, d = divmod(xx, CELL_W)
        pen = BALL[line][d] if present(dat, cx, r) else BG
        v |= pen << (4 if k == 0 else 0)
    return v


def chunk_bytes(dat, m, plane, phase, r, line):
    """les 4 octets du chunk m, pour un plan, une phase, une rangee, une ligne.

    L'octet k porte les px de carte 16m + phase + 4k + 2*plane (et +1).
    """
    base = CHUNK_PX * m + phase + 2 * plane
    return tuple(octet_carte(dat, base + 4 * k, r, line) for k in range(4))


def row_combo(dat, m, plane, phase, r):
    """le contenu d'une rangee : 6 lignes x 4 octets. C'est l'unite de routine."""
    return tuple(chunk_bytes(dat, m, plane, phase, r, l) for l in range(CELL_H))


# --- le recensement des combinaisons ------------------------------------------
def recenser(dat):
    combos = {}                    # contenu -> index de routine
    ordre = []
    colonnes = {}                  # (m, plane, phase) -> [30 index]
    for m in range(CHUNKS):
        for plane in (0, 1):
            for phase in (0, 1):
                seq = []
                for r in range(ROWS):
                    c = row_combo(dat, m, plane, phase, r)
                    if c not in combos:
                        combos[c] = len(ordre)
                        ordre.append(c)
                    seq.append(combos[c])
                colonnes[(m, plane, phase)] = seq
    return ordre, colonnes


def vide(combo):
    return all(b == 0 for ligne in combo for b in ligne)


# --- LA PREUVE : rejouer le placement du blast ---------------------------------
def verifier(dat, ordre, colonnes):
    """Pour chaque camera et chaque parite, reconstruire l'ecran depuis le
    buffer et le comparer au rendu direct de la carte.

    Le placement : le chunk m, grave pour la phase p, porte les px de carte
    [16m + p, +15] ; a la camera x (de meme parite que p) son octet (plan, k)
    tombe au px ecran X = 16m + p + 4k + 2*plane - x. On ne controle que les px
    ENTIEREMENT couverts : le ruban deborde d'au plus 8 px de chaque cote, que
    le masque du champ recouvre — c'est ce que fait deja la passe actuelle.
    """
    divergences = 0
    controles = 0
    for x in range(0, MAP_W - SCREEN_W + 1):
        phase = x & 1
        for r in range(ROWS):
            for line in range(CELL_H):
                # l'ecran attendu, directement depuis la carte
                attendu = [None] * SCREEN_W
                for X in range(SCREEN_W):
                    M = x + X
                    cx, d = divmod(M, CELL_W)
                    attendu[X] = BALL[line][d] if present(dat, cx, r) else BG
                # l'ecran obtenu depuis le buffer
                obtenu = [None] * SCREEN_W
                for m in range(CHUNKS):
                    for plane in (0, 1):
                        octets = ordre[colonnes[(m, plane, phase)][r]][line]
                        for k, val in enumerate(octets):
                            X = CHUNK_PX * m + phase + 4 * k + 2 * plane - x
                            if 0 <= X < SCREEN_W:
                                obtenu[X] = (val >> 4) & 0xF
                            if 0 <= X + 1 < SCREEN_W:
                                obtenu[X + 1] = val & 0xF
                for X in range(SCREEN_W):
                    if obtenu[X] is None:      # bord non couvert : masque
                        continue
                    controles += 1
                    if obtenu[X] != attendu[X]:
                        divergences += 1
                        if divergences <= 5:
                            print(f"  DIVERGENCE camera {x} rangee {r} ligne "
                                  f"{line} px {X} : buffer {obtenu[X]} != "
                                  f"carte {attendu[X]}")
    return controles, divergences


# --- l'emission ASM ------------------------------------------------------------
def emettre(ordre, colonnes, path=OUT):
    L = []
    A = L.append
    A(";" + "*" * 78)
    A("; pscroll — les routines de gravure d'une rangee, GENEREES")
    A(";")
    A("; tools/gen_pscroll.py — ne pas editer a la main.")
    A(";")
    A("; Une routine grave UNE RANGEE de cellules (6 lignes) x les 4 octets")
    A("; d'un plan sur une bande de 16 px. U pointe le chunk de la premiere")
    A("; ligne ; les immediats sont CUITS (ldd #, 3 cy) et la destination est")
    A("; fixe — c'est le chemin du FEED, pas celui de la mutation (voir")
    A("; etude-pscroll-gommes-stage4.md, §6.4).")
    A(";")
    A("; La combinaison ne mentionne pas le plan : le meme peigne (2 px, saut")
    A(f"; de 2 px) se retrouve dans les deux. {len(ordre)} routines au lieu de 28.")
    A(";" + "*" * 78)
    A("")
    A("; pscroll.LINE_SIZE vient du module engine (pscroll.asm) : le pas de")
    A(f"; ligne du buffer, {LINE_SIZE} o. Le generateur le SUPPOSE — si le module")
    A("; change de geometrie, cette valeur doit suivre ici aussi.")
    A("")
    # LA COUPE EN PARTS (cf. pscroll.asm, « DECOUPAGE EN TROIS MORCEAUX »).
    # Tout ce fichier est du contenu VISIBLE BUFFER MONTE — routines qui
    # ecrivent les buffers et tables lues pendant ce temps — SAUF les
    # sequences de colonnes et leur index, que feedBand copie dans son
    # staging AVANT de monter : elles restent cote cartouche, avec la carte.
    # Les tables fixes ($4000) sont lisibles de partout : les dispatchers
    # cartouche les lisent sans lien. Seuls les SYMBOLES qui franchissent la
    # frontiere d'unite sont declares, et uniquement dans les builds coupes.
    A(" IFEQ PSCROLL_PART-1              ; CART seul : les tables fixes sont")
    for t in ("rowbase", "bandoff", "chunkfirst", "bandlast",
              "seamof", "seamlast", "run", "wr"):
        A(f"pscroll.{t}.tbl EXTERNAL         ; dans l'unite $4000")
    A("pscroll.col.tbl EXPORT")
    A("pscroll.r1.tbl EXTERNAL          ; clearCell : la table du run de UN")
    A("pscroll.zrow.entry EXTERNAL      ; zone : l'entree de la bande deroulee")
    A(" ENDC")
    A(" IFEQ PSCROLL_PART-2              ; VID seul")
    for t in ("rowbase", "bandoff", "chunkfirst", "bandlast",
              "seamof", "seamlast", "run", "wr"):
        A(f"pscroll.{t}.tbl EXPORT")
    A("pscroll.col.tbl EXTERNAL         ; cote cartouche, lu avant montage")
    A("pscroll.r1.tbl EXPORT")
    A("pscroll.zrow.entry EXPORT")
    A(" ENDC")
    A("")
    A(" IFNE PSCROLL_VID                 ; --- ecrit les buffers, ou lu pendant")
    A("; --- la table des routines ---------------------------------------------")
    A("pscroll.row.tbl")
    for i in range(len(ordre)):
        A(f"        fdb   pscroll.row.{i:02d}")
    A("")
    # LE SCHEMA (proposition auteur, 22/08). D est le SEUL registre de
    # donnee : X passe en base, et les ecritures sont ORDONNEES PAR VALEUR,
    # donc un `ldd #` par valeur distincte au lieu d'un par ligne. Deux bases
    # a 240 octets d'ecart couvrent les six lignes sans qu'un seul offset ne
    # depasse 80 — donc aucun offset 16 bits, et plus aucun `leau` interne.
    #   u = l'operande de la ligne 1        x = u + 240 = celui de la ligne 4
    #   lignes 0,1,2 -> -80,u  ,u  80,u     lignes 3,4,5 -> -80,x  ,x  80,x
    # L'AXE DU BUFFER EST INVERSE. L'index de ligne du buffer croit VERS LE
    # HAUT de l'ecran (le blast descend, S decroissant) : ecrire la ligne 0 du
    # motif a l'offset le PLUS BAS la peint tout en bas. Les six lignes sont
    # donc emises a l'envers — et la sequence des rangees aussi, plus bas.
    # Mesure du 22/08 : sans ca le champ s'affiche en MIROIR vertical (99,70 %
    # de correspondance avec la carte retournee contre 95,78 % a l'endroit),
    # rangees ET lignes inversees. Le correctif est ici, pas au runtime : il ne
    # coute pas un cycle.
    DEST = [("x", 80), ("x", 0), ("x", -80), ("u", 80), ("u", 0), ("u", -80)]
    for i, combo in enumerate(ordre):
        tag = " (fond)" if vide(combo) else ""
        A(f"pscroll.row.{i:02d}{tag and '                   ; fond'}")
        A("        leax  240,u")
        groupes = {}
        for line in range(CELL_H):
            b = combo[line]
            base, off = DEST[line]
            groupes.setdefault((b[0] << 8) | b[1], []).append((base, off))
            groupes.setdefault((b[2] << 8) | b[3], []).append((base, off + 3))
        for val, dests in groupes.items():
            A(f"        ldd   #${val:04X}")
            for base, off in dests:
                A(f"        std   {off if off else ''},{base}")
        A("        rts")
        A("")
    # ------------------------------------------------------------------
    # LA TABLE EXHAUSTIVE, pour la MUTATION (cytron, et le creusement).
    # Le feed grave de la carte de build, donc les 33 combinaisons presentes
    # lui suffisent. Cytron, lui, fait pousser une gomme LA OU IL N'Y EN A
    # JAMAIS EU (arcade run_cytron etape 5 : il ecrit dans toute cellule qui
    # lit TILE_EMPTY) : un motif absent de la carte peut donc apparaitre en
    # cours de partie. La mutation lit ici, pas dans les combinaisons.
    #
    # Un chunk vu par un plan echantillonne 8 px (+0,+1,+4,+5,+8,+9,+12,+13),
    # couverts par 6 cellules au plus, et son contenu ne depend que de :
    #   - la classe d'alignement, (16m + phase + 2*plan) mod 3, soit 3 valeurs
    #   - l'etat des 6 cellules, soit 64 motifs
    # d'ou 3 x 64 entrees de 6 lignes x 4 octets.
    # La geometrie d'un chunk, par buffer. Le terme de pixel (phase + 2*plan)
    # vaut EXACTEMENT l'index de buffer, donc la table s'indexe par
    # (m*4 + buffer) : elle donne la premiere cellule couverte et la classe
    # d'alignement, evitant une division par 3 au runtime.
    # NOTE : la table de geometrie de chunk (pscroll.chunkbase.tbl) et la
    # table EXHAUSTIVE de mutation (pscroll.cell.tbl, 4 608 o) ont ete
    # supprimees le 23/08 : elles servaient un chemin generique que les 16
    # routines d'ecriture et d'effacement remplacent entierement, et elles
    # faisaient deborder l'unite des 16 Ko d'un direntry.
    # ------------------------------------------------------------------
    # LES ROUTINES D'ECRITURE D'UNE CELLULE (proposition auteur, 22/08).
    # Poser ou retirer UNE gomme ne touche que ses 3 px. En BM16 ils tombent
    # toujours de la meme facon : DEUX pixels forment un octet PLEIN dans un
    # plan, le TROISIEME est un quartet isole dans l'autre — donc lu, masque,
    # reecrit. Le cas ne depend que de (3c - phase) mod 16 : SEIZE cas, et on
    # n'en calcule aucun au runtime, on saute dans la bonne routine.
    #   plein  : lda #v / sta off,u
    #   masque : lda off,u / anda #masque / ora #v / sta off,u
    # L'octet d'un chunk-plan est a l'offset (0,1,3,4)[octet] de l'operande.
    OPOFF = (0, 1, 3, 4)
    # DEUX BASES, ZERO leau — le meme idiome que la gravure de colonne
    # (proposition auteur du 22/08, jamais appliquee ici). Six lignes espacees
    # de 80 octets se couvrent avec deux bases a 240 d'ecart et des offsets qui
    # ne depassent jamais +-88 : tous tiennent en 8 bits signes. On paie un
    # octet et un cycle par acces lointain, on economise CINQ leau par plan.
    #   u = la ligne 1 (l'appelant l'a deja decalee, cf. pscroll.geom)
    #   x = u - 240 = la ligne 4
    BASES = [("u", 80), ("u", 0), ("u", -80), ("x", 80), ("x", 0), ("x", -80)]
    # LE CHUNK VOISIN EST A -8, PAS +8. Les emplacements du ruban sont ranges
    # A L'ENVERS dans la ligne (le chunk c peint la colonne 9-c, cf. feedBand),
    # donc la bande SUIVANTE de la carte est 8 octets AVANT. Avec le signe +
    # les 96 cellules a cheval sur deux chunks posaient leur troisieme pixel
    # deux bandes plus loin — mesure du 22/08, cas 14 et 15 du banc.
    VOISIN = -8
    A("; --- les 16 routines d'ecriture d'une cellule ---------------------------")
    A("; cas = (3*colonne - phase) mod 16. Entree : les bases/pages des deux")
    A("; plans dans pscroll.wr.*, pointant la ligne du buffer qui porte la")
    A("; ligne 0 du motif — soit la ligne la PLUS HAUTE de la rangee, l'axe du")
    A("; buffer croissant vers le haut de l'ecran.")
    emettre_cellule(A, "wr", lambda l, i: BALL[l][i])
    A("; l'aiguillage : (3*colonne - phase) mod 16 -> la routine")
    A("pscroll.wr.tbl")
    for k in range(16):
        A(f"        fdb   pscroll.wr.{k:02d}")
    A("")
    # --- LES ROUTINES D'EFFACEMENT -------------------------------------------
    # Effacer une gomme, c'est ecrire le FOND sur ses 3 px : meme geometrie,
    # meme aiguillage, meme masques — seule la valeur change, et elle ne depend
    # plus de la ligne. Le pixel voisin est preserve par le masque, comme a
    # l'ecriture : c'est ce qui permet d'effacer une gomme collee a une autre.
    A("; --- les 16 routines d'EFFACEMENT d'une cellule -------------------------")
    A("; L'EFFACEMENT D'UNE CELLULE EST UN RUN DE UN. Les seize routines")
    A("; deroulees (er.NN, 1 456 octets) sont remplacees par la forme bouclee")
    A("; des runs : ~380 octets, au prix de ~120 cycles sur le chemin par")
    A("; cellule — qui est deja le repli, plus le chemin nominal (23/08).")
    A("; --- LES RUNS : les octets partages partent en entier -------------------")
    A("; Deux a sept : les longueurs sous le seuil de bande que les armes")
    A("; produisent reellement (gen_gum_cases.py les derive de leur empreinte,")
    A("; leur vitesse et le frame drop). Une n'a pas besoin de routine")
    A("; (clearCell) ; huit et plus passent par la bande deroulee.")
    for n in RUNS:
        emettre_run(A, n)
    A(f"; la table des runs, DENSE, indexee par (longueur - 1). Le trou du 3")
    A(f"; pointe la table du 2 : l'aiguillage decompose 3 avant d'arriver ici.")
    A("pscroll.run.tbl")
    for n in (1, 2, 2, 4, 5):
        A(f"        fdb   pscroll.r{n}.tbl")
    A("")

    return _suite_tables(A, L, path, ordre, colonnes)


# Les longueurs derivees des armes reelles (tools/gen_gum_cases.py) : le jeu
# produit 1..16 ; 8+ est la bande deroulee, reste 1..7. Seules 1, 2, 4 et 5
# sont GRAVEES — 3, 6 et 7 se DECOMPOSENT (2+1, 4+2, 4+3) sur ces routines :
# un octet de jointure masque deux fois au lieu d'ecrit plein, contre ~1,1 Ko
# de code genere en moins. Le 1 est aussi l'effacement d'UNE cellule (il a
# remplace les seize er.NN deroulees). La table est indexee longueur-1 ; le
# trou du 3 pointe la routine de 2 mais l'aiguillage ne l'atteint jamais.
RUNS = (1, 2, 4, 5)


def emettre_run(A, L):
    """Les 16 routines d'un RUN de L cellules voisines, sur une rangee.

    Une cellule fait 3 px larges, un octet en fait 2 : deux gommes voisines
    PARTAGENT toujours un octet. Traitees une par une, cet octet se fait
    masquer deux fois — une fois par chacune, chaque fois pour preserver la
    moitie de l'autre — alors que dans un run il part en entier. Pour L=4, les
    24 ecritures masquees d'un plan tombent a 4, et il ne reste qu'UN
    aiguillage au lieu de quatre.

    BOUCLE SUR LES SIX LIGNES, et non deroule. Le deroule pesait 992
    instructions (~2,4 Ko) et la page du banc etait deja pleine a 129 octets
    pres. La base avance de -80 par ligne, ce qui a deux vertus : le code
    n'existe qu'en un exemplaire, et les offsets retombent dans -8..+4 — donc
    en indexe 5 bits, un octet et un cycle de moins que les 8 bits du deroule.
    Le prix est de 10 cycles par ligne et par plan, soit ~240 sur un run qui en
    economise plusieurs milliers.

    B vaut 0 d'un bout a l'autre et sert toutes les ecritures pleines ; le
    masquage passe par A, qui ne le touche pas — d'ou le compteur de lignes en
    memoire et non dans un registre.
    """
    assert BG == 0, "le run ecrit le fond par stb : il doit valoir zero"
    OPOFF = (0, 1, 3, 4)
    VOISIN = -8
    for k in range(16):
        px = []
        for j in range(3 * L):
            n = k + j
            px.append(((n >> 1) & 1, n >> 4, (n % 16) >> 2, n & 1))
        for plane in (0, 1):
            octets = {}
            for d in px:
                if d[0] == plane:
                    octets.setdefault((d[1], d[2]), set()).add(d[3])
            if not octets:
                continue
            lbl = f"pscroll.r{L}.{k:02d}.p{plane}"
            A(lbl)
            cles = sorted(octets, key=lambda t: (-t[0], t[1]))
            # UN PLAN SANS MASQUE garde A a zero d'un tour a l'autre : ses
            # octets pleins voisins partent alors par PAIRES (std). Les offsets
            # 0-1 et 3-4 sont contigus, 1-3 ne l'est pas.
            propre = all(len(octets[c]) == 2 for c in cles)
            saute = None
            for idx, (voisin, bi) in enumerate(cles):
                if (voisin, bi) == saute:
                    continue
                quartets = octets[(voisin, bi)]
                off = OPOFF[bi] + (VOISIN if voisin else 0)
                o = f"{off if off else ''},u"
                if len(quartets) == 2:          # les deux px partent
                    suiv = cles[idx + 1] if idx + 1 < len(cles) else None
                    if (propre and suiv and suiv[0] == voisin
                            and OPOFF[suiv[1]] == OPOFF[bi] + 1):
                        A(f"        std   {o}")
                        saute = suiv
                    else:
                        A(f"        stb   {o}")
                else:                           # un seul : le voisin survit
                    garde = "$0F" if 0 in quartets else "$F0"
                    A(f"        lda   {o}")
                    A(f"        anda  #{garde}")
                    A(f"        sta   {o}")
            A("        leau  -80,u")
            A(f"        dec   pscroll.run.lines")
            A(f"        bne   {lbl}")
            A("        rts")
            A("")
    A(f"; l'aiguillage du run de {L} : DEUX entrees par cas, une par plan. Le")
    A("; montage de page et la mise en place de la base sont identiques pour les")
    A("; seize cas — les repeter ici pesait plus que les ecritures elles-memes,")
    A("; ils vivent donc dans pscroll.run.plans.")
    A(f"pscroll.r{L}.tbl")
    for k in range(16):
        A(f"        fdb   pscroll.r{L}.{k:02d}.p0,pscroll.r{L}.{k:02d}.p1")
    A("")


def emettre_cellule(A, prefixe, pen):
    """les 16 routines d'un chemin de mutation ; `pen(ligne, index)` donne le
    quartet a poser pour le pixel `index` de la gomme, a la ligne `ligne`."""
    OPOFF = (0, 1, 3, 4)
    # DEUX BASES, ZERO leau — le meme idiome que la gravure de colonne
    # (proposition auteur du 22/08, jamais appliquee ici). Six lignes espacees
    # de 80 octets se couvrent avec deux bases a 240 d'ecart et des offsets qui
    # ne depassent jamais +-88 : tous tiennent en 8 bits signes. On paie un
    # octet et un cycle par acces lointain, on economise CINQ leau par plan.
    #   u = la ligne 1 (l'appelant l'a deja decalee, cf. pscroll.geom)
    #   x = u - 240 = la ligne 4
    BASES = [("u", 80), ("u", 0), ("u", -80), ("x", 80), ("x", 0), ("x", -80)]
    VOISIN = -8
    for k in range(16):
        n0 = k                                  # (3c - p) mod 16, ramene a 0..15
        px = []
        for j in range(3):
            n = n0 + j
            px.append(((n >> 1) & 1, n >> 4, (n % 16) >> 2, n & 1))
        planes = [d[0] for d in px]
        full_plane = 0 if planes.count(0) == 2 else 1
        A(f"pscroll.{prefixe}.{k:02d}")
        dernier = [None]                    # la derniere valeur chargee dans A
        for phase_pass in ("full", "mask"):
            sel = [d for d in px if (d[0] == full_plane) == (phase_pass == "full")]
            pl = full_plane if phase_pass == "full" else 1 - full_plane
            A(f"        lda   pscroll.wr.page{pl}")
            A("        _SetCartPageA")
            A(f"        ldu   pscroll.wr.base{pl}")
            A("        leax  -240,u")
            dernier[0] = None                   # _SetCartPageA a passe par A
            for line in range(CELL_H):
                if phase_pass == "full":
                    # la valeur vient des SOUS-PIXELS reels de la paire (leur
                    # index dans la gomme), pas du quartet — le quartet ne dit
                    # que la place, pas quel pixel de la gomme s'y trouve.
                    pair = sorted(sel, key=lambda t: t[3])
                    hi, lo = (px.index(pair[0]), px.index(pair[1]))
                    v = (pen(line, hi) << 4) | pen(line, lo)
                    d = pair[0]
                    base, dl = BASES[line]
                    off = OPOFF[d[2]] + (VOISIN if d[1] else 0) + dl
                    if v != dernier[0]:
                        A(f"        lda   #${v:02X}")
                        dernier[0] = v
                    A(f"        sta   {off if off else ''},{base}")
                else:
                    d = sel[0]
                    sub = 0 if len(sel) == 1 and px.index(d) == 0 else 2
                    v = pen(line, px.index(d))
                    base, dl = BASES[line]
                    off = OPOFF[d[2]] + (VOISIN if d[1] else 0) + dl
                    if d[3] == 0:                # quartet haut
                        A(f"        lda   {off if off else ''},{base}")
                        A("        anda  #$0F")
                        if v:                    # le fond vaut 0 : rien a poser
                            A(f"        ora   #${v << 4:02X}")
                    else:                        # quartet bas
                        A(f"        lda   {off if off else ''},{base}")
                        A("        anda  #$F0")
                        if v:
                            A(f"        ora   #${v:02X}")
                    A(f"        sta   {off if off else ''},{base}")
        A("        rts")
        A("")


def _suite_tables(A, L, path, ordre, colonnes):
    # LA GEOMETRIE D'UNE BANDE, EN TABLE. pscroll.geom divisait par 10 en
    # retranchant 10 jusqu'a passer dessous : 12 cycles par dizaine, donc
    # jusqu'a 84 pour la bande 71 — et ca se paie a chaque mutation. Les deux
    # tables tiennent en 3 octets par bande et suppriment aussi le mul de
    # l'emplacement.
    # L'OFFSET D'UNE MUTATION, EN DEUX ADDITIONS. Il valait
    #   dst = ligne*80 + emplacement + 1,  ligne = BIAIS - couture + 6*(29-r) + 5
    # soit deux mul et une division par 10. Or ca se separe : le terme de
    # RANGEE ne depend pas de la bande, le terme de BANDE ne depend pas de la
    # rangee, et le biais est une constante d'instruction. Deux tables, deux
    # additions, plus un seul mul ni une seule division.
    # ------------------------------------------------------------------
    # LA SEQUENCE D'EFFACEMENT DEROULEE — une rangee entiere, zero re-base.
    #
    # Effacer, c'est ecrire le FOND, et le fond vaut 0 : un chunk dont toutes
    # les cellules sont parties ne contient que des zeros. Pas de table, pas de
    # relecture de la carte.
    #
    # TROIS BASES, SIX LIGNES. Un offset indexe 8 bits ne va que de -128 a
    # +127, et l'offset combine vaut « decalage de ligne » + « decalage de
    # colonne » (1 a 76 dans la ligne) : une base ne sert donc que DEUX lignes
    # (0 et -80). X, Y et U en couvrent six, soit exactement une rangee, et D
    # reste charge a zero — c'est la donnee.
    #
    #   X sur la ligne L+1 : offset 0 -> L+1, -80 -> L
    #   Y sur la ligne L+3 : offset 0 -> L+3, -80 -> L+2
    #   U sur la ligne L+5 : offset 0 -> L+5, -80 -> L+4
    #
    # Les emplacements du ruban sont ranges A L'ENVERS dans la ligne (la bande
    # c peint la colonne 9-c), donc deux bandes de carte consecutives sont a
    # des offsets DECROISSANTS de 8. La sequence est emise dans cet ordre : on
    # entre sur la premiere bande du run et on continue tout seul.
    #
    # L'ENTREE se choisit par le nombre de colonnes (table ci-dessous), LA
    # SORTIE se patche par un rts — le mecanisme de pscroll.do pour le blast.
    # La premiere cellule de chaque bande : sert a ramener un intervalle de
    # cellules dans la fenetre du ruban, sans division au runtime. Une entree de
    # plus que de bandes, pour que « derniere cellule de la bande m » se lise
    # tbl[m+1]-1.
    # Couper un run aux COUTURES : les bandes d'un meme groupe de dix partagent
    # le cisaillement, donc les memes lignes de buffer. seamof donne le groupe,
    # seamlast sa derniere bande — et l'emplacement de ruban s'en deduit sans
    # modulo : slot(m) = seamlast[seam(m)] - m.
    A("; --- le groupe de couture de chaque bande, et sa derniere bande ---------")
    A("pscroll.seamof.tbl")
    for m in range(0, CHUNKS, 12):
        A("        fcb   " + ",".join(str(x // CHUNKS_PER_LINE)
                                      for x in range(m, min(m + 12, CHUNKS))))
    A("")
    A("pscroll.seamlast.tbl")
    A("        fcb   " + ",".join(str((k + 1) * CHUNKS_PER_LINE - 1)
                                  for k in range(CHUNKS // CHUNKS_PER_LINE + 1)))
    A("")
    A("; --- la premiere cellule de chaque bande --------------------------------")
    A("pscroll.chunkfirst.tbl")
    for m in range(CHUNKS + 1):
        A(f"        fdb   {-(-CHUNK_PX * m // CELL_W)}"
          + (f"   ; bande {m}" if m % 10 == 0 else ""))
    A("")
    A("; LA DERNIERE CELLULE ENTIEREMENT DANS LA BANDE m. Une cellule occupe")
    A("; [3c, 3c+2] ; elle tient dans la bande m si 3c+2 <= 16m+15, soit")
    A("; c <= (16m+13)/3. NE PAS confondre avec chunkfirst[m+1]-1, qui est la")
    A("; cellule d'AVANT la premiere entierement dans la bande suivante : celle-la")
    A("; est le plus souvent A CHEVAL sur les deux bandes. Prendre l'une pour")
    A("; l'autre laissait la queue d'un effacement demarrer une cellule trop loin,")
    A("; et cette cellule gardait deux de ses trois pixels (23/08).")
    A("pscroll.bandlast.tbl")
    for m in range(CHUNKS + 1):
        A(f"        fdb   {(CHUNK_PX * m + CHUNK_PX - 1 - (CELL_W - 1)) // CELL_W}"
          + (f"   ; bande {m}" if m % 10 == 0 else ""))
    A("")
    A("; --- l'effacement deroule : une rangee, dix bandes ----------------------")
    A("; 12 std par bande, trois bases (X,Y,U) pour six lignes, offsets 8 bits.")
    A("; On entre par pscroll.zrow.entry[bande] et on sort en patchant un rts.")
    A("pscroll.zrow")
    for slot in range(CHUNKS_PER_LINE - 1, -1, -1):
        c = slot * CHUNK_SIZE
        A(f"pscroll.zrow.{slot:02d}")
        for base, dl in (("x", 0), ("x", -LINE_SIZE), ("y", 0), ("y", -LINE_SIZE),
                         ("u", 0), ("u", -LINE_SIZE)):
            for k in (1, 4):
                off = c + k + dl
                A(f"        std   {off},{base}")
    A("        rts                            ; sortie naturelle : le run va")
    A("                                       ; jusqu'au bord du ruban")
    A("")
    A("; l'entree, par emplacement de ruban de la PREMIERE bande du run")
    A("pscroll.zrow.entry")
    for slot in range(CHUNKS_PER_LINE):
        A(f"        fdb   pscroll.zrow.{slot:02d}")
    A("")
    A(f"pscroll.ZROW_STEP equ 6*2*3          ; octets par bande dans la sequence")
    A("")
    A("; --- l'offset d'une mutation, en deux termes ---------------------------")
    A("; dst = pscroll.ROW_BIAS*LINE_SIZE + rowbase[rangee] + bandoff[bande] + 1")
    A("; rowbase : le terme de rangee, axe du buffer inverse (rangee 0 en bas)")
    A("pscroll.rowbase.tbl")
    for r in range(ROWS):
        A(f"        fdb   {(CELL_H - 1 + CELL_H * (ROWS - 1 - r)) * LINE_SIZE}"
          + (f"   ; rangee {r}" if r % 10 == 0 else ""))
    A("")
    A("; bandoff : l'emplacement dans la ligne (INVERSE : la bande c peint la")
    A("; colonne 9-c) MOINS le cisaillement de ses coutures. Signe.")
    A("pscroll.bandoff.tbl")
    for m in range(CHUNKS):
        v = ((CHUNKS_PER_LINE - 1 - m % CHUNKS_PER_LINE) * CHUNK_SIZE
             - (m // CHUNKS_PER_LINE) * LINE_SIZE)
        A(f"        fdb   {v}" + (f"   ; bande {m}" if m % CHUNKS_PER_LINE == 0 else ""))
    A("")
    A(" ENDC                             ; --- fin de la part $4000")
    A("")
    A(" IFNE PSCROLL_CART                ; --- lu AVANT montage : reste en page")
    A("; --- les colonnes : 30 index de routine par (bande, plan, phase) -------")
    A("; Seules les colonnes NON VIDES portent une sequence ; les autres")
    A("; pointent 0 dans l'index, et le feed se contente alors d'y poser le")
    A("; fond (57 bandes sur 72 dans ce niveau).")
    for (m, plane, phase), seq in sorted(colonnes.items()):
        if all(vide(ordre[i]) for i in seq):
            continue
        A(f"pscroll.col.{m:02d}.{plane}.{phase}")
        # a l'envers : la premiere rangee gravee est celle du BAS de l'ecran
        A("        fcb   " + ",".join(str(i) for i in seq[::-1]))
    A("")
    A("; --- l'index : ((bande * 2 + plan) * 2 + phase) -> sequence, 0 si vide -")
    A("pscroll.col.tbl")
    for m in range(CHUNKS):
        for plane in (0, 1):
            for phase in (0, 1):
                seq = colonnes[(m, plane, phase)]
                if all(vide(ordre[i]) for i in seq):
                    A(f"        fdb   0                    ; bande {m:02d} "
                      f"plan {plane} phase {phase}")
                else:
                    A(f"        fdb   pscroll.col.{m:02d}.{plane}.{phase}")
    A(" ENDC                             ; --- fin de la part cartouche")
    A("")
    A(f"pscroll.CHUNKS    equ {CHUNKS}      ; bandes de 16 px dans le niveau")
    A(f"pscroll.ROWS      equ {ROWS}      ; rangees de cellules")
    A(f"pscroll.CELL_H    equ {CELL_H}       ; lignes par rangee")
    A(f"pscroll.CELLS     equ {CELLS}     ; cellules dans la largeur de carte")
    A(f"pscroll.MAP_STRIDE equ {W_BYTES}     ; octets par rangee du bitfield")
    open(path, "w").write("\n".join(L) + "\n")
    return len(L)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verifier-seulement", action="store_true")
    a = ap.parse_args()

    dat = charger()
    ordre, colonnes = recenser(dat)
    nv = [c for c in ordre if not vide(c)]
    print(f"combinaisons distinctes : {len(ordre)}  ({len(nv)} non vides)")
    bandes_nv = sum(1 for k, seq in colonnes.items()
                    if not all(vide(ordre[i]) for i in seq))
    print(f"colonnes (bande, plan, phase) non vides : {bandes_nv} / {len(colonnes)}")

    print("\npreuve : rejeu du placement du blast sur tout le niveau...")
    controles, div = verifier(dat, ordre, colonnes)
    print(f"  {controles} pixels controles, {div} divergence(s)")
    if div:
        sys.exit(1)
    print("  0 divergence — le buffer rend exactement la carte.")

    if not a.verifier_seulement:
        n = emettre(ordre, colonnes)
        print(f"\necrit {OUT} ({n} lignes)")


if __name__ == "__main__":
    main()
