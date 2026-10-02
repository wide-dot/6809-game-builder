#!/usr/bin/env python3
"""Tourelles de proue et tourelles multiples du vaisseau : tables depuis la ROM.

Rien n'est recopie a la main : on relit le dump arcade, on suit les pointeurs
des vignettes d'installation et on convertit par les formules de la table
(x et vx par 0,375 ; y et vy par 0,75 avec INVERSION — l'axe arcade monte).
La correspondance sprite arcade -> PNG converti se lit dans les NOMS des
exports de re.arcade, qui portent l'adresse de la recette (`NNN_01xxxx.png`).

Ce que ca produit :
  - front-turret-wheel/         les poses UNIQUES des cinq variantes, UN jeu
    partage (11 silhouettes pour 30 images, memes ancres — 11/09/2026)
  - warship-elements/frontturret/tables.asm  roues + tables de tir + boites
  - warship-elements/multiturret/tables.asm  cadences + boites
  - warship-elements/fireball/tables.asm     dissipations + eclat de bouche

Sources arcade (relevees sur les listings, 28/08/2026) :
  40:d596..d5dc  vignettes proue : (table de poses, table de tir) par variante
  1000:7b4e/6e/8e/ae/ce   les 5 tables de poses (c et e partagent la 3e)
  1000:7c30/50/70/90/b0/d0  les 6 tables de tir : word[16] -> record ou 0
      record = { vx 8.8, vy 8.8, ptr paire de sprites de la boule }
  1000:7db6  l'eclat de bouche, 8 recettes    1000:7de6/7e16  les dissipations
  1000:7e46  boite de la proue    1000:7e4e  boite de la boule
  40:db63..db8f  vignettes multi : (anim 4 poses, patron de tir) par montage
  1000:8066/7e/96/ae  patrons de tir : 5 x {vx,vy} + (dx,dy) de ponte
  1000:80c6  boite de la multi (partagee)

Usage : python3 tools/gen_warship_frontmulti.py   (depuis games/r-type)
"""
import os
import re
import shutil
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
EXPORTS = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
           '/out/sprites/warship-elements')
DATA = 0x1000 * 16

FRONT = (  # variante -> (table de poses, table de tir, dossier d'export)
    (0x7B4E, 0x7C30, 'front-turret-a'),
    (0x7B6E, 0x7C50, 'front-turret-b'),
    (0x7B8E, 0x7C70, 'front-turret-c'),
    (0x7BAE, 0x7C90, 'front-turret-d'),
    (0x7B8E, 0x7CB0, 'front-turret-c'),   # e REUTILISE les poses de c
    (0x7BCE, 0x7CD0, 'front-turret-e'),
)
MULTI = (  # montage -> (anim, patron de tir, dossier)
    (0x8006, 0x8066, 'multi-turret-top-left'),
    (0x801E, 0x807E, 'multi-turret-bottom-left'),
    (0x8036, 0x8096, 'multi-turret-top-right'),
    (0x804E, 0x80AE, 'multi-turret-bottom-right'),
)
MULTI_SYM = ('multi_tl', 'multi_bl', 'multi_tr', 'multi_br')
MUZZLE, DISS_A, DISS_B = 0x7DB6, 0x7DE6, 0x7E16
AABB_FRONT, AABB_BALL, AABB_MULTI = 0x7E46, 0x7E4E, 0x80C6


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/warship-elements')
    rom = open(ROM, 'rb').read()

    def w(off):
        return rom[DATA + off] | (rom[DATA + off + 1] << 8)

    def sw(off):
        v = w(off)
        return v - 0x10000 if v >= 0x8000 else v

    def ordinaux(dossier):
        """adresse de recette -> ordinal du PNG, lue dans les noms d'export."""
        m = {}
        for nom in os.listdir(os.path.join(EXPORTS, dossier)):
            r = re.match(r'(\d+)_01([0-9a-f]{4})\.png$', nom)
            if r:
                m[int(r.group(2), 16)] = int(r.group(1))
        return m

    def vconv(vx, vy):
        """vitesse 8.8 arcade -> v2 : x par 0,375, y par 0,75 inverse."""
        return round(vx * 0.375), round(-vy * 0.75)

    def boite(off):
        x0, x1, y0, y1 = sw(off), sw(off + 2), sw(off + 4), sw(off + 6)
        return (round((x1 - x0) * 0.375 / 2), round((y1 - y0) * 0.75 / 2),
                round((x0 + x1) / 2 * 0.375), round(-(y0 + y1) / 2 * 0.75))

    # ------------------------------------------------------------- la proue
    lignes = [
        "; Tourelles de PROUE — GENERE par tools/gen_warship_frontmulti.py",
        "; depuis le dump arcade. Six variantes : cinq jeux de poses (c et e",
        "; partagent le 3e) et six tables de tir.",
        "",
    ]
    # UNE SEULE ROUE POUR LES CINQ VARIANTES (decision auteur, 11/09/2026) :
    # les cinq jeux de poses arcade se recoupent — 30 images, 11 silhouettes
    # distinctes, chacune A LA MEME PLACE par rapport a l'ancre d'une variante
    # a l'autre (seule la hauteur du canevas differait, 24/30/36 : l'encodeur
    # rogne et ancre au centre, l'image compilee est la meme). Les poses sont
    # dedoublonnees par (pixels rognes, position relative a l'ancre) et posees
    # sur un canevas uniforme ; les roues des variantes ne sont plus que des
    # tables d'index dans ce jeu partage. imgFront : 9 677 -> ~3 550 octets.
    from PIL import Image
    CANVAS = (18, 36)
    dst = os.path.join(base, 'images', 'front-turret-wheel')
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if f.endswith('.png'):
            os.remove(os.path.join(dst, f))
    partagees = {}

    def pose_partagee(png):
        im = Image.open(png)
        assert im.mode == 'P' and im.size[0] == CANVAS[0], png
        px = im.load()
        w, h = im.size
        xs = [x for y in range(h) for x in range(w) if px[x, y]]
        ys = [y for y in range(h) for x in range(w) if px[x, y]]
        x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
        rel = (x0 - (w - 1) // 2, y0 - (h - 1) // 2)
        cle = (bytes(px[x, y] for y in range(y0, y1) for x in range(x0, x1)), rel)
        if cle in partagees:
            return partagees[cle]
        k = len(partagees)
        out = Image.new('P', CANVAS, 0)
        out.putpalette(im.getpalette())
        out.paste(im.crop((x0, y0, x1, y1)),
                  (rel[0] + (CANVAS[0] - 1) // 2, rel[1] + (CANVAS[1] - 1) // 2))
        out.save(os.path.join(dst, '%02d.png' % k))
        partagees[cle] = k
        return k

    wheels_emises = {}
    for v, (ptbl, ftbl, dossier) in enumerate(FRONT):
        ordi = ordinaux(dossier)
        sym = dossier.replace('-', '_')
        src = os.path.join(base, 'images', dossier)
        if ptbl not in wheels_emises:
            rang = [pose_partagee(os.path.join(src, '%02d.png' % ordi[w(ptbl + 2 * i)]))
                    for i in range(16)]
            lignes.append('; roue %s (table %04X) : les poses du jeu partage'
                          % (dossier, ptbl))
            lignes.append('fturret.wheel.%s' % sym)
            for bloc in range(4):
                mots = ['set_front_turret_%d' % rang[i] for i in range(bloc * 4, bloc * 4 + 4)]
                lignes.append('        fdb   ' + ','.join(mots))
            lignes.append('')
            wheels_emises[ptbl] = sym
            geo = os.path.join(src, 'geometrie.txt')
            if os.path.exists(geo) and not os.path.exists(os.path.join(dst, 'geometrie.txt')):
                shutil.copyfile(geo, os.path.join(dst, 'geometrie.txt'))
        # la table de tir : 16 directions, 6 octets par entree
        ball = ordinaux('fire-ball')
        lignes.append('; tir variante %d (table %04X) : fdb vx,vy puis fcb pose,alt'
                      % (v, ftbl))
        lignes.append('; de la boule ($FF = direction sans tir, la porte d arc)')
        lignes.append('fturret.fire.%d' % v)
        for i in range(16):
            ptr = w(ftbl + 2 * i)
            if ptr == 0:
                lignes.append('        fdb   0,0')
                lignes.append('        fcb   $FF,$FF ; dir %d : pas de tir' % i)
            else:
                vx, vy = vconv(sw(ptr), sw(ptr + 2))
                paire = w(ptr + 4)
                lignes.append('        fdb   %d,%d' % (vx, vy))
                lignes.append('        fcb   %d,%d ; dir %d (record %04X)'
                              % (ball[paire], ball[paire + 6], i, ptr))
        lignes.append('')
    lignes.append('; %d poses partagees : set_front_turret_0..%d' % (len(partagees), len(partagees) - 1))
    lignes.append('fturret.Wheels')
    for ptbl, _f, _d in FRONT:
        lignes.append('        fdb   fturret.wheel.%s' % wheels_emises[ptbl])
    lignes.append('fturret.Fires')
    for v in range(len(FRONT)):
        lignes.append('        fdb   fturret.fire.%d' % v)
    rx, ry, cx, cy = boite(AABB_FRONT)
    lignes += ['', '; la boite (1000:%04X), rayons et excentrage v2' % AABB_FRONT,
               'fturret.BOX equ $%02X%02X ; rx,ry' % (rx, ry),
               'fturret.CTR equ $%02X%02X ; cx,cy (signes)' % (cx & 255, cy & 255), '']
    os.makedirs(os.path.join(base, 'frontturret'), exist_ok=True)
    open(os.path.join(base, 'frontturret/tables.asm'), 'w').write('\n'.join(lignes))

    # ----------------------------------------------------------- la boule
    flash = ordinaux('fireball-flash')
    lignes = [
        "; La boule de feu de la proue — GENERE par tools/gen_warship_frontmulti.py",
        "",
        "; l'eclat de bouche (1000:%04X), 8 recettes, index (vie & $0E)/2" % MUZZLE,
        "muzzle.Sets",
    ]
    for i in range(8):
        lignes.append('        fdb   set_fireball_flash_%d' % flash[MUZZLE + 6 * i])
    # ECART ASSUME (28/08/2026) : PAS de tables de dissipation. Les recettes
    # arcade (1000:7de6/7e16) deplacent la bouffee le long de la paroi pendant
    # ses 8 poses : l'union des boites fait 64-80 px arcade de haut, soit un
    # canevas v2 de 48-60 lignes — un sprite pareil joue au ras du sol ou du
    # plafond et le moteur le rejette EN BLOC (culling par sprite entier).
    # La boule meurt donc en explosion standard. L'export amont existe
    # (catalog fireball-dissipate-a/b) pour le jour ou le convertisseur saura
    # les ancres par pose.
    lignes += ['', "; (pas de dissipation dediee — voir l'en-tete du generateur)"]
    rx, ry, cx, cy = boite(AABB_BALL)
    lignes += ['', '; la boite (1000:%04X)' % AABB_BALL,
               'fireball.BOX equ $%02X%02X' % (rx, ry),
               'fireball.CTR equ $%02X%02X' % (cx & 255, cy & 255), '']
    os.makedirs(os.path.join(base, 'fireball'), exist_ok=True)
    open(os.path.join(base, 'fireball/tables.asm'), 'w').write('\n'.join(lignes))

    # ------------------------------------------------------------ la multi
    lignes = [
        "; Tourelles MULTIPLES — GENERE par tools/gen_warship_frontmulti.py",
        "; Quatre montages : 4 poses d'anim chacun (cycle temporel), un patron",
        "; de tir de 5 vecteurs + le point de ponte, une boite partagee.",
        "",
    ]
    for m, (atbl, ftbl, dossier) in enumerate(MULTI):
        ordi = ordinaux(dossier)
        sym = MULTI_SYM[m]
        lignes.append('; %s : anim %04X, tir %04X' % (dossier, atbl, ftbl))
        lignes.append('multi.anim.%s' % sym)
        mots = ['set_%s_%d' % (sym, ordi[atbl + 6 * i]) for i in range(4)]
        lignes.append('        fdb   ' + ','.join(mots))
        lignes.append('multi.fire.%s' % sym)
        for i in range(5):
            vx, vy = vconv(sw(ftbl + 4 * i), sw(ftbl + 4 * i + 2))
            lignes.append('        fdb   %d,%d ; vecteur %d' % (vx, vy, i))
        dx = round(sw(ftbl + 0x14) * 0.375)
        dy = round(-sw(ftbl + 0x16) * 0.75)
        lignes.append('        fcb   %d,%d ; le point de ponte, ecart signe' % (dx & 255, dy & 255))
        lignes.append('')
    lignes.append('multi.Anims')
    for sym in MULTI_SYM:
        lignes.append('        fdb   multi.anim.%s' % sym)
    lignes.append('multi.Fires')
    for sym in MULTI_SYM:
        lignes.append('        fdb   multi.fire.%s' % sym)
    # la pose blanche de coup par montage (gen_warship_hit.py), dessinee a la
    # place du barillet un rendu (decision auteur, 12/09/2026)
    lignes.append('multi.Hits')
    for sym in MULTI_SYM:
        lignes.append('        fdb   set_%s_hit_0' % sym)
    rx, ry, cx, cy = boite(AABB_MULTI)
    lignes += ['', '; la boite (1000:%04X), partagee par les quatre montages' % AABB_MULTI,
               'multi.BOX equ $%02X%02X' % (rx, ry),
               'multi.CTR equ $%02X%02X' % (cx & 255, cy & 255), '']
    os.makedirs(os.path.join(base, 'multiturret'), exist_ok=True)
    open(os.path.join(base, 'multiturret/tables.asm'), 'w').write('\n'.join(lignes))
    print('tables ecrites : frontturret/, fireball/, multiturret/')


if __name__ == '__main__':
    main()
