#!/usr/bin/env python3
"""Mesure l'enveloppe des poses de tir et la confronte aux constantes cuites.

    python3 tools/bullet_envelope.py          # apres un build

Le manager de tirs blitte des poses compilees fixes, sans imageset : la
geometrie que CheckSpritesRefresh irait lire dans image_subset_y1_offset et
image_y_size est cuite dans bullets.equ, ce qui epargne deux lectures indexees
par balle et par trame. Le prix de ce raccourci est qu'une constante peut
mentir le jour ou l'art change. Ce script est ce qui l'empeche : il relit les
poses generees, en deduit l'enveloppe reelle, et sort en erreur si elle ne
tient pas dans ce que bullets.equ declare.
"""
import glob, re, sys

LINE = 40                       # octets par ligne et par plan


def envelope(pattern='gen/weapons/foefire/foefire_*_ND0.asm'):
    lo, hi, columns = 0, 0, set()
    poses = sorted(glob.glob(pattern))
    if not poses:
        sys.exit('aucune pose sous %s — construire le jeu d\'abord' % pattern)
    for f in poses:
        for m in re.finditer(r'^\s*ST([ABD])\s+(-?\d+)?,U\s*$', open(f).read(), re.M):
            off = int(m.group(2) or 0)
            width = 2 if m.group(1) == 'D' else 1
            lo, hi = min(lo, off), max(hi, off + width - 1)
            for b in range(width):
                columns.add((off + b) % LINE)
    return poses, lo, hi, columns


def baked(path='src/enemies/_shared/bullets/bullets.equ'):
    out = {}
    for l in open(path):
        m = re.match(r'(bullet\.DRAW_[A-Z]+)\s+equ\s+(\d+)', l.strip())
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


poses, lo, hi, columns = envelope()
up = (-lo + LINE - 1) // LINE
down = (hi + LINE - 1) // LINE
right = len(columns) - 1
print('%d poses lues' % len(poses))
print('  enveloppe    : %d .. %+d octets depuis U' % (lo, hi))
print('  lignes       : %d au-dessus de l\'ancre, %d au-dessous' % (up, down))
print('  colonnes     : %s (soit %d octet(s) a droite de l\'ancre)'
      % (sorted(columns), right))

b = baked()
errors = []
for name, measured in (('bullet.DRAW_UP', up), ('bullet.DRAW_DOWN', down)):
    if b.get(name) is None:
        errors.append('%s absente de bullets.equ' % name)
    elif b[name] < measured:
        errors.append('%s vaut %d, mesure %d — le sprite deborde de ce que la '
                      'borne protege' % (name, b[name], measured))
# DRAW_RIGHT couvre le decalage d'un octet du second plan (DRS_XYToAddress,
# branche RAM2First), pas la largeur propre du sprite : il doit valoir AU MOINS
# les colonnes que les poses touchent.
if b.get('bullet.DRAW_RIGHT', 0) < max(right, 1):
    errors.append('bullet.DRAW_RIGHT vaut %s, il en faut %d'
                  % (b.get('bullet.DRAW_RIGHT'), max(right, 1)))

if errors:
    print('\nLES CONSTANTES CUITES NE PROTEGENT PLUS L\'ART :')
    for e in errors:
        print('  - ' + e)
    sys.exit(1)
print('\nles constantes cuites couvrent l\'art mesure')
