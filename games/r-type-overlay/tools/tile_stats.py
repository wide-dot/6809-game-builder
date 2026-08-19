#!/usr/bin/env python3
"""Ce que coutent les tuiles compilees d'un stage — en OCTETS et en CYCLES.

    python3 tools/tile_stats.py 01            les deux plans du stage 01
    python3 tools/tile_stats.py 01 --classes  le detail par classe de tuile

Trois sources, croisees :

  * `gen/stages/NN/map/{even,odd}.png`  — le tileset : ce que CHAQUE tuile
    contient, donc sa CLASSE (voir plus bas) ;
  * `gen/stages/NN/map/{even,odd}.bin`  — la carte : combien de fois chaque
    tuile est POSEE. Une tuile employee 50 fois ne pese pas comme une tuile
    employee une fois — ni en octets (elle n'est stockee qu'une fois) ni en
    cycles (elle est jouee 50 fois). Les deux colonnes ne se lisent donc pas
    de la meme facon, et c'est tout l'interet de les mettre cote a cote ;
  * `gen/stages/NN/tiles-{even,odd}/*_ND0.asm` — le code compile par gfxcomp,
    d'ou sortent les octets et les cycles.

LES CLASSES. La question posee (auteur, 17/08) : que pesent les tuiles qui
n'emploient QUE du transparent et du noir ? Depuis que le ciel a rejoint
l'index 0 materiel, le noir est de tres loin la valeur la plus posee de la
carte, et une tuile qui ne fait que poser du noir sur du noir deja efface est
un candidat evident a un traitement moins cher qu'une routine compilee.

  VIDE     aucun pixel opaque — la carte l'adresse par l'id 0, elle n'est
           jamais jouee et ne coute rien. Comptee pour memoire.
  NOIR     que du transparent et du noir (index PNG 1 = materiel 0).
  MIXTE    du noir ET de la couleur.
  COULEUR  pas de noir du tout.

LE MODELE DE CYCLES. Comptage 6809 standard, sur les seules instructions que
gfxcomp emet ici. Il est exact pour ce jeu d'instructions ; il ne pretend pas
l'etre pour un autre encodeur. La table est ecrite en clair pour qu'on puisse
la contredire.
"""
import argparse
import os
import re
import sys
from collections import Counter

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
PROJET = os.path.dirname(ICI)

# (octets, cycles) par instruction, 6809.
#   LEAU n,U   : 4 + le cout du mode indexe (offset 5/8 bits = 1, 16 bits = 4)
#   PSHU liste : 5 + 1 par octet empile
#   LDA/LDB #  : 2 octets, 2 cycles ; LDX/LDD # : 3 octets, 3 cycles
#   STD n,U    : 5 + mode indexe ; LDU <dp : 2 octets, 5 cycles ; RTS : 5
def indexe(arg):
    """(octets, cycles) EN PLUS pour un mode indexe `n,R`.
    Pas d'offset = 0/0 ; offset 5 bits = 0 octet 1 cycle ; 8 bits = 1/1 ;
    16 bits = 2/4. Ce sont les surcouts standard du postbyte 6809."""
    t = arg.split(',')[0].strip()
    if t == '':
        return 0, 0
    n = int(t)
    if -16 <= n < 16:
        return 0, 1
    if -128 <= n < 128:
        return 1, 1
    return 2, 4


def cout(op, arg):
    o = op.upper()
    if o == 'RTS':
        return 1, 5
    if o == 'LDU':
        return 2, 5                      # LDU <glb_screen_location_1 (direct)
    if o in ('LDA', 'LDB'):
        return 2, 2                      # immediat
    if o in ('LDX', 'LDY', 'LDD'):
        return 3, 3                      # immediat 16 bits
    if o in ('ANDA', 'ANDB', 'ORA', 'ORB', 'EORA', 'EORB',
             'ADDA', 'ADDB', 'SUBA', 'SUBB'):
        return 2, 2                      # immediat 8 bits
    if o in ('ADDD', 'SUBD', 'CMPX', 'CMPD'):
        return 3, 4                      # immediat 16 bits
    if o in ('PSHU', 'PSHS'):
        regs = arg.replace(' ', '').split(',')
        n = sum(2 if r.upper() in ('X', 'Y', 'U', 'S', 'D', 'PC') else 1
                for r in regs)
        return 2, 5 + n                  # 5 + 1 par octet empile
    do, dc = indexe(arg)
    if o in ('LEAU', 'LEAX', 'LEAY', 'LEAS'):
        return 2 + do, 4 + dc
    if o in ('STA', 'STB'):
        return 2 + do, 4 + dc
    if o in ('STD', 'STX', 'STY', 'STU'):
        return 2 + do, 5 + dc
    raise ValueError("instruction non modelisee : %s %s" % (op, arg))


INSTR = re.compile(r'^\s+([A-Za-z]{2,4})\s+(\S.*?)\s*$')


def mesure(chemin):
    """(octets, cycles) d'une tuile compilee."""
    o = c = 0
    for ligne in open(chemin, encoding='utf-8'):
        if ligne.lstrip().startswith(('*', ';', 'INCLUDE', 'OPT')) or not ligne.strip():
            continue
        m = INSTR.match(ligne.rstrip())
        if not m:
            continue                      # une etiquette seule
        op, arg = m.group(1), m.group(2)
        if op.upper() in ('INCLUDE', 'OPT', 'EXPORT', 'SECTION', 'ENDSECTION'):
            continue
        if op.upper() == 'RTS':
            do, dc = cout('RTS', '')
        else:
            do, dc = cout(op, arg)
        o += do
        c += dc
    return o, c


def classe(tuile_px):
    """VIDE / NOIR / MIXTE / COULEUR — sur les index PNG (0 = transparent,
    1 = noir materiel 0)."""
    vus = set(tuile_px)
    opaques = vus - {0}
    if not opaques:
        return 'VIDE'
    if opaques == {1}:
        return 'NOIR'
    if 1 in opaques:
        return 'MIXTE'
    return 'COULEUR'


def plan(stage, nom, detail):
    base = os.path.join(PROJET, 'gen/stages/%s' % stage)
    im = Image.open(os.path.join(base, 'map/%s.png' % nom))
    px = im.load()
    w, h = im.size
    n = h // 12

    # la carte : combien de fois chaque id est pose
    d = open(os.path.join(base, 'map/%s.bin' % nom), 'rb').read()
    usage = Counter(d[i] << 8 | d[i + 1] for i in range(0, len(d), 2))
    cellules = len(d) // 2

    rep = 'tiles-%s' % nom
    stats = {}
    manquants = 0
    for t in range(n):
        cl = classe([px[x, t * 12 + y] for y in range(12) for x in range(w)])
        f = os.path.join(base, rep,
                         'stage1.tiles.%s_%d_ND0.asm' % (nom, t))
        if os.path.exists(f):
            o, c = mesure(f)
        elif cl == 'VIDE':
            o = c = 0                     # l'id 0 n'a pas de routine
        else:
            manquants += 1
            continue
        s = stats.setdefault(cl, [0, 0, 0, 0])
        s[0] += 1                         # tuiles distinctes
        s[1] += o                         # octets STOCKES (une fois)
        s[2] += 0 if cl == 'VIDE' else usage[t] * c   # cycles JOUES
        s[3] += usage[t]                  # poses
        if detail and cl == 'NOIR':
            print("    tuile %3d : %4d o, %4d cy, posee %3d fois"
                  % (t, o, c, usage[t]))
    return stats, cellules, n, manquants


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stage', nargs='?', default='01')
    ap.add_argument('--classes', action='store_true')
    args = ap.parse_args()

    total = {}
    for nom in ('even', 'odd'):
        st, cellules, n, manquants = plan(args.stage, nom, args.classes)
        print("\n=== plan %s : %d tuiles, %d cellules de carte%s"
              % (nom, n, cellules,
                 " (%d routines introuvables)" % manquants if manquants else ""))
        print("    %-8s %6s %9s %9s %14s %7s"
              % ('classe', 'tuiles', 'poses', 'octets', 'cycles/passe', '% cy'))
        cy = sum(s[2] for s in st.values()) or 1
        for cl in ('VIDE', 'NOIR', 'MIXTE', 'COULEUR'):
            if cl not in st:
                continue
            t, o, c, p = st[cl]
            print("    %-8s %6d %9d %9d %14d %6.1f%%"
                  % (cl, t, p, o, c, 100.0 * c / cy))
            g = total.setdefault(cl, [0, 0, 0, 0])
            for i, v in enumerate((t, o, c, p)):
                g[i] += v

    print("\n=== les deux plans")
    cy = sum(s[2] for s in total.values()) or 1
    oc = sum(s[1] for s in total.values()) or 1
    print("    %-8s %6s %9s %9s %6s %14s %7s"
          % ('classe', 'tuiles', 'poses', 'octets', '% o', 'cycles/passe', '% cy'))
    for cl in ('VIDE', 'NOIR', 'MIXTE', 'COULEUR'):
        if cl not in total:
            continue
        t, o, c, p = total[cl]
        print("    %-8s %6d %9d %9d %5.1f%% %14d %6.1f%%"
              % (cl, t, p, o, 100.0 * o / oc, c, 100.0 * c / cy))
    print("    %-8s %6d %9d %9d %5s  %14d"
          % ('TOTAL', sum(s[0] for s in total.values()),
             sum(s[3] for s in total.values()), oc, '', cy))
    return 0


if __name__ == '__main__':
    sys.exit(main())
