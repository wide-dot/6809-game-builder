#!/usr/bin/env python3
"""Comparer des candidats pour les trois cases propres du stage 5.

    python3 tools/pal05_candidats.py [--planche SORTIE.png]

Le stage 5 dispose de trois emplacements attribuables (13, 14, 16 ; le 15 est
l'olive gelee) et son cast EXCLUSIF est slither / pursuer / cheetah — mid et
cancer sont partages avec d'autres stages et se convertissent sur les communs,
le boss bellmite prendra sa palette dediee.

Ce script mesure, pour chaque candidat : l'ecart moyen pondere par ennemi et
sur la carte, et surtout le nombre de NIVEAUX DISTINCTS qu'une rampe source
conserve apres quantification — c'est ce que « maximiser les degrades » veut
dire ici, et l'ecart moyen seul ne le dit pas (la doc de --force le rappelle :
retablir un niveau fait MONTER l'ecart moyen et ameliore l'image).

Le gamut TO8 est l'acteur principal : ses niveaux de DAC sont
[0, 97, 122, ...] — il n'y a RIEN entre 0 et 97, donc aucun ton sombre. Quatre
bruns sources du stage 5 (886800 de la carte, 583810 du slither, 705810 et
887030 du cheetah) tombent tous sur le meme 7A6100. C'est ce qui a rendu la
case 16 muette au dernier calcul : le vote lui a donne une couleur que l'ecran
ne distingue pas de celle du 13.
"""
import sys, os, argparse
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import to8disp
import arcade_to_in as A
from PIL import Image

CAST = ('slither', 'pursuer', 'cheetah')

# Les rampes que l'on veut voir survivre : (nom, [couleurs source, du sombre
# au clair]). Relevees dans le recensement, ce sont les familles qui portent
# le volume de pixels.
RAMPES = [
    ('slither corps', [(0x58, 0x38, 0x10), (0xA8, 0x80, 0x58), (0xF8, 0xC8, 0x98)]),
    ('slither oeil',  [(0x00, 0x80, 0x90), (0x00, 0xB0, 0x90), (0x00, 0xE8, 0xB0)]),
    ('pursuer',       [(0x90, 0x48, 0x20), (0xC8, 0x80, 0x30), (0xF8, 0xB0, 0x88)]),
    ('cheetah vert',  [(0x08, 0x48, 0x20), (0x10, 0x90, 0x38), (0x80, 0xC8, 0x70)]),
]


def commons():
    """Les douze communs + l'olive gelee, lus dans la palette du stage."""
    p = Image.open('src/stages/05/palette/pal.png').getpalette()[:17 * 3]
    return {i: tuple(p[i * 3:i * 3 + 3]) for i in list(range(1, 13)) + [15]}


def census():
    """{ressource: Counter(couleur -> pixels)} — cast + carte."""
    out = {}
    for obj in CAST:
        cnt, _, _, _ = A.plan_supplementaire('sprites:' + obj)
        out[obj] = cnt
    plan = 'src/stages/05/map/images/original/level5_f.png'
    cnt, _, _, _ = A.plan_supplementaire(plan)
    out['carte'] = cnt
    return out


def nearest(c, pal, forces=None):
    """L'emplacement vu par une couleur — `forces` court-circuite la distance.

    C'est `--force R,G,B=IDX` : le plus proche voisin ne voit que des couleurs
    isolees, jamais un degrade, et il ecrase donc deux niveaux voisins sur un
    seul emplacement alors qu'un autre, un peu plus loin, etait libre.
    """
    if forces and c in forces:
        i = forces[c]
        return i, pal[i]
    return min(pal.items(), key=lambda kv: A.dist_lab(c, kv[1]))


def evalue(pal, cens, forces=None):
    """(ecart moyen par ressource, niveaux conserves par rampe)."""
    ecarts = {}
    for nom, cnt in cens.items():
        tot = sum(cnt.values())
        if not tot:
            continue
        s = sum(n * A.dist_lab(c, nearest(c, pal, forces)[1]) for c, n in cnt.items())
        ecarts[nom] = s / tot
    niveaux = {}
    for nom, rampe in RAMPES:
        vus = [nearest(c, pal, forces)[0] for c in rampe]
        niveaux[nom] = (len(set(vus)), len(rampe))
    return ecarts, niveaux


def candidat(nom, treize, quatorze, seize, forces=None):
    return (nom, {13: to8disp.displayed(treize),
                  14: to8disp.displayed(quatorze),
                  16: to8disp.displayed(seize)}, forces or {})


BRUN, TAN, CREME = (0x58, 0x38, 0x10), (0xA8, 0x80, 0x58), (0xF8, 0xC8, 0x98)
VERT_M, VERT_S, VERT_C = (0x10, 0x90, 0x38), (0x08, 0x48, 0x20), (0x80, 0xC8, 0x70)

CANDIDATS = [
    candidat('actuel (16 morte)',      (0x7A, 0x61, 0x00), (0xFA, 0xC2, 0x7A), (0x7A, 0x61, 0x00)),
    candidat('P1 brun+tan, vert 14',   BRUN, VERT_M, TAN),
    candidat('P2 brun+creme, vert 14', BRUN, VERT_M, CREME),
    candidat('P3 tan+creme, vert 14',  TAN,  VERT_M, CREME),
    candidat('P4 vert sombre en 14',   BRUN, VERT_S, TAN),
    candidat('P5 sans vert (temoin)',  BRUN, CREME,  TAN),
    # Avec --force : la rampe du slither reclame trois niveaux mais n'a que
    # deux cases. Le troisieme existe DEJA dans les communs (11 = FA9E61, un
    # peche) ; le plus proche voisin ne l'y envoie pas parce que le tan du 16
    # est plus pres. On l'y envoie de force : l'ecart moyen monte un peu,
    # l'image gagne un niveau.
    candidat('P6 = P1 + creme force en 11', BRUN, VERT_M, TAN,
             forces={CREME: 11}),
    candidat('P7 = P6 + vert clair force en 15', BRUN, VERT_M, TAN,
             forces={CREME: 11, VERT_C: 15}),
    candidat('P8 = P6, vert sombre en 14', BRUN, VERT_S, TAN,
             forces={CREME: 11, VERT_C: 15}),
    # Le clair du pursuer tombe sur le tan du 16 avec son medium : meme
    # collision, meme remede. Le peche du 11 sert alors deux rampes de deux
    # objets differents — sans consequence, ils ne partagent aucun pixel.
    candidat('P9 = P7 + clair pursuer en 11', BRUN, VERT_M, TAN,
             forces={CREME: 11, VERT_C: 15, (0xF8, 0xB0, 0x88): 11}),
    # L'oeil du slither (1 024 px) : trois turquoises qui s'ecrasent alors que
    # les communs 5-6-7 sont une rampe bleu-cyan de trois niveaux, libre.
    candidat('P10 = P9 + oeil sur 5-6-7', BRUN, VERT_M, TAN,
             forces={CREME: 11, VERT_C: 15, (0xF8, 0xB0, 0x88): 11,
                     (0x00, 0x80, 0x90): 5, (0x00, 0xB0, 0x90): 6,
                     (0x00, 0xE8, 0xB0): 7}),
    # Le pursuer laisse par defaut son brun sombre partir sur le ROUGE sombre
    # du 8 et empile ses deux clairs sur le 11. On le range sur la rampe brune
    # du slither, qui est exactement sa famille : 13 -> 16 -> 11.
    candidat('P11 = P10 + pursuer range', BRUN, VERT_M, TAN,
             forces={CREME: 11, VERT_C: 15,
                     (0x90, 0x48, 0x20): 13, (0xC8, 0x80, 0x30): 16,
                     (0xF8, 0xB0, 0x88): 11,
                     (0x00, 0x80, 0x90): 5, (0x00, 0xB0, 0x90): 6,
                     (0x00, 0xE8, 0xB0): 7}),
    # LE RETENU (choix auteur 24/08/2026, « P12+P11 ») : le vert SOMBRE de P12
    # en 14 — le vert sombre du cheetah cesse de tomber sur le gris du 2 — ET
    # les quatre rampes completes de P11. Le vert moyen prend l'olive gelee du
    # 15, le clair monte sur le jaune du 12 : la rampe verte garde ses trois
    # niveaux SANS case supplementaire, en empruntant deux communs.
    candidat('P13 = P12 + rampe verte rangee', BRUN, VERT_S, TAN,
             forces={CREME: 11, VERT_M: 15, VERT_C: 12,
                     (0x90, 0x48, 0x20): 13, (0xC8, 0x80, 0x30): 16,
                     (0xF8, 0xB0, 0x88): 11,
                     (0x00, 0x80, 0x90): 5, (0x00, 0xB0, 0x90): 6,
                     (0x00, 0xE8, 0xB0): 7}),
    # Variante du vert : sombre en 14 plutot que moyen. Le vert sombre du
    # cheetah cesse de tomber sur le GRIS du 2, mais le moyen et le clair se
    # partagent alors l'olive du 15.
    candidat('P12 = P11, vert sombre en 14', BRUN, VERT_S, TAN,
             forces={CREME: 11, VERT_C: 15,
                     (0x90, 0x48, 0x20): 13, (0xC8, 0x80, 0x30): 16,
                     (0xF8, 0xB0, 0x88): 11,
                     (0x00, 0x80, 0x90): 5, (0x00, 0xB0, 0x90): 6,
                     (0x00, 0xE8, 0xB0): 7}),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--planche', default=None)
    a = ap.parse_args()

    base = commons()
    cens = census()
    print('recensement : ' + ', '.join('%s %d px' % (k, sum(v.values()))
                                       for k, v in cens.items()))
    print()
    largeur = max(len(n) for n, _, _ in CANDIDATS)
    entete = ('%-*s | %s | %s' % (largeur, 'candidat',
              '  '.join('%-8s' % k for k in ('slither', 'pursuer', 'cheetah', 'carte')),
              ' '.join('%-14s' % n for n, _ in RAMPES)))
    print(entete)
    print('-' * len(entete))
    resultats = []
    for nom, libres, forces in CANDIDATS:
        pal = dict(base)
        pal.update(libres)
        ecarts, niveaux = evalue(pal, cens, forces)
        resultats.append((nom, pal, ecarts, niveaux, forces))
        print('%-*s | %s | %s' % (
            largeur, nom,
            '  '.join('%8.1f' % ecarts[k] for k in ('slither', 'pursuer', 'cheetah', 'carte')),
            ' '.join('%-14s' % ('%d/%d' % niveaux[n]) for n, _ in RAMPES)))
    print()
    print('valeurs ecrites (deja ramenees sur le gamut TO8) :')
    for nom, pal, _, _, _ in resultats:
        print('  %-*s 13=%02X%02X%02X  14=%02X%02X%02X  16=%02X%02X%02X' % (
            largeur, nom, *pal[13], *pal[14], *pal[16]))

    if a.planche:
        planche(resultats, cens, a.planche)


def planche(resultats, cens, sortie):
    """Une bande par candidat : la palette, puis les rampes rendues."""
    from PIL import ImageDraw
    CASE, MARGE, LIGNE = 34, 12, 116
    W = MARGE * 2 + 17 * CASE + 360
    H = MARGE + LIGNE * len(resultats) + 30
    im = Image.new('RGB', (W, H), (18, 18, 22))
    d = ImageDraw.Draw(im)
    for k, (nom, pal, ecarts, niveaux, forces) in enumerate(resultats):
        y = MARGE + k * LIGNE
        d.text((MARGE, y), nom, fill=(232, 234, 240))
        for i in range(1, 17):
            x = MARGE + (i - 1) * CASE
            c = pal.get(i, (0, 0, 0))
            d.rectangle([x, y + 18, x + CASE - 3, y + 18 + CASE], fill=c,
                        outline=(70, 70, 78))
            if i in (13, 14, 16):
                d.text((x + 2, y + 20 + CASE), str(i), fill=(255, 200, 90))
        # les rampes, source au-dessus / rendu en dessous
        x0 = MARGE + 17 * CASE + 16
        for nomr, rampe in RAMPES:
            for j, c in enumerate(rampe):
                x = x0 + j * 22
                d.rectangle([x, y + 18, x + 20, y + 34], fill=c)
                v = nearest(c, pal, forces)[1]
                d.rectangle([x, y + 36, x + 20, y + 52], fill=v)
            n, t = niveaux[nomr]
            d.text((x0, y + 56), '%s %d/%d' % (nomr, n, t),
                   fill=(232, 234, 240) if n == t else (240, 120, 110))
            x0 += 3 * 22 + 26
    im.save(sortie)
    print('planche ecrite :', sortie)


if __name__ == '__main__':
    main()
