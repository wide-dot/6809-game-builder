#!/usr/bin/env python3
"""Les images blanches du FLASH DE COUP du MANAGER, par taille de boite.
(gen_hit_flash.py, lui, fait les poses blanches du brood et du zoid.)

    python3 tools/gen_hitflash_manager.py        (depuis games/r-type)

Le manager (decision auteur, 11/09/2026) : le crochet Collision_OnLoose du
moteur — appele par la passe de collision quand un ennemi encaisse un coup
et survit — pose un objet explosion de sous-type $80 qui porte la boite
touchee ; l'unite explosion choisit l'image blanche PAR LA TAILLE DE LA
BOITE (rx, ry) et la dessine un rendu, centree sur la boite (relue au
dessin). Aucune ligne dans les ennemis. Ce script ecrit les images et la
table des tailles.

Pour chaque cle (rx, ry) l'image est calee sur le CENTRE DE LA BOITE : les
poses des familles qui portent cette cle sont alignees sur leur centre de
boite (ancre + excentrage CTR/cy) et l'ELLIPSE qui minimise l'ecart moyen
avec ces poses est cherchee exhaustivement (centre au demi-pixel). Les
familles a pose unique gardent leur SILHOUETTE (capsule, reacteur arriere).
Doc : doc/inventaire-flash-de-coup-2026-09.md.

SORTIES :
  src/common/fx/explosion/images/hitflash/NN.png   canevas impair, ancre =
                                                    centre de boite, index 4
  src/common/fx/explosion/hitflash.tables.asm       hitflash.Sizes
"""
import glob
import math
import os

from PIL import Image

B = 'src/enemies/warship-elements/images/'
WHITE = 4
# cle (rx, ry) -> (nom, [(dossier, (ecart cx, cy du centre de boite depuis l'ancre))], mode)
#   les excentrages : turret.cy +6 haut / -6 bas, big +3 ; fturret.CTR 0 ;
#   multi.CTR 0 ; breactor.CTR 0 ; cytron a l'ancre ; rreactor.BODYCTR (-2,0) ;
#   capsule.CTR 0 ; detach.CTR (0,-1)
KEYS = [
    ((4, 4), 'petites tourelles haut+bas', [(B + 'small-turret-top-wheel', (0, 6)), (B + 'small-turret-bottom-wheel', (0, -6))], 'ellipse'),
    ((4, 6), 'grosse tourelle', [(B + 'big-turret-wheel', (0, 3))], 'ellipse'),
    ((4, 8), 'tourelle frontale', [(B + 'front-turret-wheel', (0, 0))], 'ellipse'),
    ((4, 9), 'Cytron', [('src/enemies/cytron/images/default', (0, 0))], 'ellipse'),
    # (12/09/2026, decision auteur) les reacteurs, capsules, triangle et la
    # tourelle multiple ne passent PAS par le manager : ils dessinent leur pose
    # blanche EN REMPLACEMENT de leur sprite (tools/gen_warship_hit.py).
]
# TOUT EN ELLIPSES, RANGEES ALIGNEES SUR L'OCTET (11/09/2026) : la silhouette
# d'une pose se compile en une routine trois fois plus lourde (ses trous et
# ses bords irreguliers coutent des ecritures d'un octet), et un bord
# d'ellipse sur un pixel impair aussi. Chaque rangee est etendue aux paires
# de pixels de l'encodeur (le sprite est toujours dessine aligne sur l'octet,
# l'ancre impaire tombant a la colonne paire suivante) : la routine n'est
# plus que des pshu/leau. 4 117 -> ~1 500 octets pour les huit images.


def poses_alignees(familles):
    """Les masques des poses, en coordonnees relatives au CENTRE DE BOITE."""
    out = []
    for d, (ocx, ocy) in familles:
        for f in sorted(glob.glob(d + '/*.png')):
            im = Image.open(f)
            assert im.mode == 'P', f
            p = im.load()
            w, h = im.size
            ax, ay = (w - 1) // 2, (h - 1) // 2
            out.append({(x - ax - ocx, y - ay - ocy) for y in range(h) for x in range(w) if p[x, y]})
    return out


def ajuste_ellipse(masques):
    n = len(masques)
    xs = [x for m in masques for x, _ in m]
    ys = [y for m in masques for _, y in m]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    cnt = {}
    for m in masques:
        for q in m:
            cnt[q] = cnt.get(q, 0) + 1
    total = sum(cnt.values())
    # prefixes par ligne du poids (n - 2c), sur la fenetre [x0..x1] x [y0..y1]
    W, H = x1 - x0 + 1, y1 - y0 + 1
    pre = []
    for y in range(y0, y1 + 1):
        acc = [0]
        for x in range(x0, x1 + 1):
            acc.append(acc[-1] + n - 2 * cnt.get((x, y), 0))
        pre.append(acc)

    def cost(cx, cy, rx, ry):
        c = total
        for j in range(H):
            y = y0 + j
            t = 1 - ((y - cy) / ry) ** 2
            if t < 0:
                continue
            hw = rx * math.sqrt(t)
            a, b = max(x0, math.ceil(cx - hw)), min(x1, math.floor(cx + hw))
            if b >= a:
                c += pre[j][b - x0 + 1] - pre[j][a - x0]
        return c
    best = None
    for cx2 in range(2 * x0, 2 * x1 + 1):
        for cy2 in range(2 * y0, 2 * y1 + 1):
            for rx2 in range(3, W + 1):
                for ry2 in range(3, H + 1):
                    c = cost(cx2 / 2, cy2 / 2, rx2 / 2, ry2 / 2)
                    if best is None or c < best[0]:
                        best = (c, cx2 / 2, cy2 / 2, rx2 / 2, ry2 / 2)
    c, cx, cy, rx, ry = best
    pix = {(x, y) for y in range(y0 - 1, y1 + 2) for x in range(x0 - 1, x1 + 2)
           if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0}
    pix = aligne_octets(pix)
    cov = sum(len(pix & m) / len(m) for m in masques) / n
    return pix, (cx, cy, 2 * rx, 2 * ry, c / n, cov)


def aligne_octets(pix):
    """Chaque rangee etendue aux paires de pixels de l'encodeur. Le canevas a une
    largeur IMPAIRE et son ancre est la colonne (W-1)//2 : la colonne x du
    repere de boite est la colonne canevas x + hw, et hw est pair (voir ecrit) —
    une paire commence donc sur un x PAIR du repere de boite."""
    rangees = {}
    for x, y in pix:
        a, b = rangees.get(y, (x, x))
        rangees[y] = (min(a, x), max(b, x))
    out = set()
    for y, (a, b) in rangees.items():
        a -= a % 2                       # debut de paire
        b += (b + 1) % 2                 # fin de paire
        out.update((x, y) for x in range(a, b + 1))
    return out


def ecrit(pix, chemin, palette):
    xs = [x for x, _ in pix]
    ys = [y for _, y in pix]
    hw, hh = max(abs(min(xs)), abs(max(xs))), max(abs(min(ys)), abs(max(ys)))
    hw += hw % 2                           # hw PAIR : les paires de pixels du repere
    W, H = 2 * hw + 1, 2 * hh + 1          # de boite tombent sur celles du canevas ;
                                           # impair : l'ancre (W-1)//2 EST le centre de boite
    im = Image.new('P', (W, H), 0)
    im.putpalette(palette)
    p = im.load()
    for x, y in pix:
        p[x + hw, y + hh] = WHITE
    im.save(chemin)
    return W, H


def main():
    dst = 'src/common/fx/explosion/images/hitflash'
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if f.endswith('.png'):
            os.remove(os.path.join(dst, f))
    palette = Image.open(B + 'small-turret-top-wheel/00.png').getpalette()
    lignes = ['; GENERE par tools/gen_hitflash_manager.py — le flash de coup : par taille de',
              '; boite (rx, ry), l\'image blanche calee sur le centre de la boite.',
              '; fcb rx,ry / fdb set ; fin : rx = 0. Voir explosion.asm (hitflash.*).',
              'hitflash.Sizes']
    for k, ((rx, ry), nom, familles, mode) in enumerate(KEYS):
        masques = poses_alignees(familles)
        if mode == 'ellipse':
            pix, (cx, cy, dx, dy, xor, cov) = ajuste_ellipse(masques)
            info = 'ellipse %.0fx%.0f, centre (%+.1f,%+.1f) depuis la boite, couvre %.0f %% des poses' % (dx, dy, cx, cy, 100 * cov)
        else:
            pix = masques[0]
            info = 'silhouette de la pose'
        W, H = ecrit(pix, os.path.join(dst, '%02d.png' % k), palette)
        lignes.append('        fcb   %d,%d' % (rx, ry))
        lignes.append('        fdb   set_expHit_%d ; %s : %s (%dx%d)' % (k, nom, info, W, H))
        print('%02d (%2d,%2d) %-40s %s' % (k, rx, ry, nom, info), flush=True)
    lignes.append('        fcb   0,0')
    open('src/common/fx/explosion/hitflash.tables.asm', 'w').write('\n'.join(lignes) + '\n')


if __name__ == '__main__':
    main()
