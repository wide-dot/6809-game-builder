#!/usr/bin/env python3
"""Les poses du noyau ROGNEES par la coque — plus de cache par-dessus.

    python3 tools/gen_core_clip.py            (depuis games/r-type), puis
    python3 tools/gen_warship_slices.py       (les tranches 16x12)

ETUDE : doc/etude-noyau-sans-cache-2026-09.md (decision auteur, 11/09/2026).
Au repos le noyau remplit exactement la cavite (H0 = 0 colonne cachee,
mesure sur la machine) ; il glisse de SLIDEPX px sous la masse de coque de
droite pour s'ouvrir, et n'y montre plus que 24 - SLIDEPX colonnes. La coque
etant peinte AVANT les sprites, on repeignait par-dessus lui un morceau de
coque (core-cover, 6 tranches, ~3 100 cycles par rendu). Ici la coque est
retiree DES POSES : les colonnes cachees sont mises a l'index 0.

LES CONTRAINTES v2, qui fixent la coupe :
  - les positions x sont PAIRES (layer.evenX, un seul decalage compile) :
    la glissade n'a que SLIDEPX/2 positions distinctes, d = 2, 4, ... ; une
    ancre impaire (derive 1, 3, ...) est rendue a la colonne paire suivante,
    le choix de la variante suit la meme regle (core/obj.asm, core.Slide) ;
  - le rognage tombe sur une colonne PAIRE du canevas (paires de pixels de
    l'encodeur) : H0 et SLIDEPX sont pairs — mesures, pas supposes ;
  - les tranches wsmgr sont des fenetres de 16 x 12 du canevas : une pose
    dont les colonnes visibles tiennent dans 0..15 n'a que deux tranches ;
  - la glissade montre UNE pose fixe (la pose fermee 0) : ses variantes
    d = 2, 4, 6 ne different que par la colonne de droite des tranches, la
    variante d = 8 EST la colonne de gauche de la pose, et
    gen_warship_slices.py dedoublonne les tranches identiques.
  - le flash de coup (palette 0x55, un rendu sur deux) est rogne comme la
    pose ouverte : les deux alternent au meme endroit.

SORTIES (canevas 24x24 conserve, meme ancre) :
  images/core_closed/00..03  les 4 poses fermees, rognees de H0 (repos, pompe)
  images/core_closed/04..    la pose fermee 0 rognee de H0+d, d = 2..SLIDEPX
  images/core_opening-rogne/, core_open-rogne/, core_open_flash-rogne/
                             les poses glissees, rognees de H0+SLIDEPX
"""
import os
import sys

from PIL import Image

# MESURE SUR LA MACHINE (captures toje du 11/09/2026, doc/etude-noyau-sans-cache
# § 6) : au repos les 24 colonnes remplissent exactement la cavite (H0 = 0), et
# le moteur dessine une ancre impaire a la colonne paire SUIVANTE — la glissade
# de 13 px etait deja rendue a 14, dix colonnes visibles. La grille paire est
# donc 14, l'arcade fait 13,5.
H0 = 0        # colonnes cachees au repos
SLIDEPX = 14  # core.SLIDEPX
BASE = 'src/enemies/warship-elements/images'
TRANSPARENT = 0


def rogne(im, hidden):
    """La pose sans ses `hidden` colonnes de droite (index 0)."""
    w, h = im.size
    px = bytearray(im.tobytes())
    for y in range(h):
        for x in range(w - hidden, w):
            px[y * w + x] = TRANSPARENT
    out = Image.frombytes('P', im.size, bytes(px))
    out.putpalette(im.getpalette())
    return out


def vide(dst):
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if f.endswith('.png'):
            os.remove(os.path.join(dst, f))


def poses(src):
    return [Image.open(os.path.join(BASE, src, f))
            for f in sorted(os.listdir(os.path.join(BASE, src))) if f.endswith('.png')]


def main():
    assert H0 % 2 == 0 and SLIDEPX % 2 == 0, 'la coupe tombe sur une colonne paire'
    for im in poses('core_anim'):
        assert im.mode == 'P' and im.size == (24, 24), 'pose fermee inattendue'
    # le repos et la glissade, dans UN jeu (les tranches de gauche se partagent)
    dst = os.path.join(BASE, 'core_closed')
    vide(dst)
    k = 0
    for im in poses('core_anim'):
        rogne(im, H0).save(os.path.join(dst, '%02d.png' % k))
        k += 1
    ferme0 = poses('core_anim')[0]
    for d in range(2, SLIDEPX + 1, 2):
        rogne(ferme0, H0 + d).save(os.path.join(dst, '%02d.png' % k))
        k += 1
    print('core_closed : 4 poses de repos (-%d colonnes) + %d de glissade' % (H0, k - 4))
    # les poses glissees
    for src in ('core_opening', 'core_open', 'core_open_flash'):
        dst = os.path.join(BASE, src + '-rogne')
        vide(dst)
        n = 0
        for im in poses(src):
            rogne(im, H0 + SLIDEPX).save(os.path.join(dst, '%02d.png' % n))
            n += 1
        print('%s-rogne : %d poses, %d colonnes visibles' % (src, n, 24 - H0 - SLIDEPX))
    open(os.path.join(BASE, 'core_closed', 'geometrie.txt'), 'w').write(
        '# poses fermees rognees de %d colonnes ; 04.. : glissade, rognee de %d+d, d = 2..%d\n'
        % (H0, H0, SLIDEPX))
    open('src/enemies/warship-elements/core/clip.equ', 'w').write(
        '; GENERE par tools/gen_core_clip.py — la coupe du noyau par la coque\n'
        'core.H0      equ %d                 ; colonnes cachees au repos\n'
        'core.SLIDEPX equ %d                ; la glissade, paire (arcade 13,5)\n' % (H0, SLIDEPX))


if __name__ == '__main__':
    main()
