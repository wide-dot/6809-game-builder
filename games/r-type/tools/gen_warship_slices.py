#!/usr/bin/env python3
"""Trancher les pieces mobiles du vaisseau en fenetres de 16 x 12 au plus.

    python3 tools/gen_warship_slices.py            (depuis games/r-type)

POURQUOI. BuildSprites rejette EN BLOC un sprite qui deborde de la bande
(plan : doc/plan-warship-sprites-2026-09.md). Le sol du stage 3 couvre les
12 px du bas dans 94 % des colonnes, jamais 24 : une tranche de 12 lignes
qui sort par le bas est deja sous le sol, une tranche de 24 laisserait un
trou. En largeur, la bordure a cheval tolere 8 px de l'autre cote : 16.
Decision auteur du 09/09/2026 : 16 x 12, uniforme.

LE GESTE est celui de gen_warship_flames.py : chaque tranche GARDE LE CANEVAS
de la pose et n'en peint que sa fenetre. L'encodeur rogne les bords
transparents mais rapporte l'ancre au centre du canevas : toutes les tranches
d'une pose partagent l'ancre, le manager (wsmgr.asm) les dessine aux memes
coordonnees, sans decalage a calculer, et teste la bande tranche par
tranche. Une fenetre entierement transparente n'est pas emise.

SORTIES, par jeu d'images <dir> :
  images/<dir>-slices/NN_pP_sS.png  les tranches, NN = leur rang (le prefixe
                                  d'ordre que <images> exige unique), P la
                                  pose, S la fenetre (rangees du haut vers le
                                  bas, colonnes de gauche a droite) : NN est
                                  l'ordinal des set_<sym>_NN ;
  <asm>                           les listes : pour chaque pose P,
                                    <prefixe>.<sym>.P   fcb n / fdb set_<sym>_k...
                                  et les EXTERNAL correspondants dans <ext>.
Le config pointe les dossiers -slices ; les pieces designent les listes
(reactor/obj.asm, reactor/children.asm, capsule/obj.asm).
"""
import os
import sys

from PIL import Image

TW, TH = 16, 12
TRANSPARENT = 0

# (dossier d'images, symbole <images names=...>) par jeu, et par jeu :
# (prefixe des listes, fichier asm, fichier externals).
# LE PERIMETRE (decision auteur, 09/09/2026) : les GROS sprites mobiles du
# vaisseau — reacteur arriere, son allumage et ses flammes geantes, capsule
# de survie, petite capsule, triangle. Les tourelles et autres petites pieces
# accrochees a la coque restent des sprites entiers ; les gerbes des
# reacteurs de ventre sont tranchees par gen_warship_flames.py.
JEUX = [
    (('rear-reactor', 'rear_reactor'), ('reactor-startup', 'reactor_startup'),
     ('reactor-flame-0', 'reactor_flame_0'), ('reactor-flame-1', 'reactor_flame_1'),
     ('escape-capsule', 'escape_capsule'), ('small-escape-capsule', 'small_escape_capsule'),
     ('falling-triangle', 'falling_triangle')),
    # le NOYAU (le boss, 09/09/2026) : 24x24 comme la petite capsule et le
    # triangle, il glisse de 13 px en s'ouvrant et suit la coque — chez wsmgr
    (('core_anim', 'core_anim'), ('core_opening', 'core_opening'), ('core_open', 'core_open'),
     # et le cache de coque qui le recouvre (gen_core_cover.py)
     ('core-cover', 'core_cover')),
]
TABLES = [('react.sl', 'reactor/slices.asm', 'reactor/slices.ext.asm'),
          ('core.sl', 'core/slices.asm', 'core/slices.ext.asm')]


def slices_of(im):
    """Les fenetres non vides de l'image, en (x0, y0, x1, y1), rangees puis colonnes."""
    w, h = im.size
    px = im.tobytes()
    out = []
    for y0 in range(0, h, TH):
        for x0 in range(0, w, TW):
            x1, y1 = min(x0 + TW, w), min(y0 + TH, h)
            if any(px[y * w + x] != TRANSPARENT for y in range(y0, y1) for x in range(x0, x1)):
                out.append((x0, y0, x1, y1))
    return out


def cut(im, win):
    w, h = im.size
    x0, y0, x1, y1 = win
    px = bytearray(im.tobytes())
    for y in range(h):
        for x in range(w):
            if not (x0 <= x < x1 and y0 <= y < y1):
                px[y * w + x] = TRANSPARENT
    out = Image.frombytes('P', im.size, bytes(px))
    out.putpalette(im.getpalette())
    return out


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/warship-elements')
    for jeux, (prefixe, asm, ext) in zip(JEUX, TABLES):
        lignes = ['; GENERE par tools/gen_warship_slices.py — les tranches 16x12 de chaque',
                  '; pose : fcb n, puis n imagesets, dans l\'ordre de peinture (rangees du',
                  '; haut vers le bas). Voir wsmgr.asm.', '']
        externs = ['; GENERE par tools/gen_warship_slices.py — les tranches, resolues au chargement.']
        total = 0
        for dossier, sym in jeux:
            src = os.path.join(base, 'images', dossier)
            dst = os.path.join(base, 'images', dossier + '-slices')
            os.makedirs(dst, exist_ok=True)
            for f in os.listdir(dst):
                if f.endswith('.png'):
                    os.remove(os.path.join(dst, f))
            poses = sorted(f for f in os.listdir(src) if f.endswith('.png'))
            k = 0
            for p, f in enumerate(poses):
                im = Image.open(os.path.join(src, f))
                if im.mode != 'P':
                    sys.exit('%s n\'est pas une image indexee' % f)
                wins = slices_of(im)
                mots = []
                for s, win in enumerate(wins):
                    cut(im, win).save(os.path.join(dst, '%02d_p%d_s%d.png' % (k, p, s)))
                    mots.append('set_%s_%d' % (sym, k))
                    externs.append('set_%s_%d  EXTERNAL' % (sym, k))
                    k += 1
                lignes.append('%s.%s.%d' % (prefixe, sym, p))
                lignes.append('        fcb   %d' % len(mots))
                lignes.append('        fdb   ' + ','.join(mots))
            geo = os.path.join(src, 'geometrie.txt')
            if os.path.exists(geo):
                open(os.path.join(dst, 'geometrie.txt'), 'w').write(open(geo).read())
            total += k
            print('%-28s %d poses -> %d tranches' % (dossier, len(poses), k))
        open(os.path.join(base, asm), 'w').write('\n'.join(lignes) + '\n')
        open(os.path.join(base, ext), 'w').write('\n'.join(externs) + '\n')
        print('%s : %d tranches ; %s' % (asm, total, ext))


if __name__ == '__main__':
    main()
