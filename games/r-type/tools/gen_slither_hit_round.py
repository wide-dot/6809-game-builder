#!/usr/bin/env python3
"""Le flash de coup du CORPS : UNE image ronde pour les seize orientations.

Les seize poses du corps sont des rotations d'un meme segment. Leur
INTERSECTION — ce que toutes couvrent — est deja un noyau rond de 9x15
centre. Une seule image blanche a cette forme suffit donc pour n'importe
quelle orientation, ce qui vaut mieux qu'un jeu de seize blanches :

- elle tient sur la page du cast (quelques centaines d'octets contre ~6 700),
  donc le renderer NORMAL peut la dessiner ;
- et c'est justement ce qui retablit l'ORDRE DE DESSIN. Avec un second
  renderer, le blanc passait sous les segments voisins et l'effet d'ecailles
  tuilees se perdait (constat auteur).

Ce script mesure l'intersection sur les vraies poses, en tire l'image, et
produit une PLANCHE de simulation pour juger avant d'integrer.

Usage : python3 tools/gen_slither_hit_round.py   (depuis games/r-type)
"""
import glob, os, sys
from PIL import Image, ImageDraw

BLANC = 4          # index PNG du blanc de la palette du stage 5
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPS = os.path.join(RACINE, 'src/enemies/slither/images/body')

# le pixel TO8 est plus large que haut : 704/160 contre 624/200 a l'ecran
PW, PH = 7, 5

def poses():
    out = []
    for f in sorted(glob.glob(os.path.join(CORPS, '*.png'))):
        im = Image.open(f)
        out.append((im.size, bytearray(im.tobytes()), im.getpalette()))
    return out

# Le noyau brut est l'INTERSECTION des poses ; on le dilate ensuite d'un
# pixel en largeur et de deux en hauteur (donc +2 et +4 sur les cotes), avec
# un element de dilatation ELLIPTIQUE pour ne pas carrer les coins. Le disque
# deborde alors legerement de certaines poses — c'est voulu : un flash qui
# mord sur le contour se voit mieux qu'un flash inscrit (choix auteur).
DILX, DILY = 1, 2

def noyau(ps):
    (W, H), _, _ = ps[0]
    inter = [[1] * W for _ in range(H)]
    for (_, px, _) in ps:
        for y in range(H):
            for x in range(W):
                if not px[y * W + x]:
                    inter[y][x] = 0
    el = [(dx, dy) for dx in range(-DILX, DILX + 1)
                   for dy in range(-DILY, DILY + 1)
          if (dx / float(DILX)) ** 2 + (dy / float(DILY)) ** 2 <= 1.0]
    gros = [[0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if inter[y][x]:
                for dx, dy in el:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H:
                        gros[ny][nx] = 1
    return W, H, gros

def rendu(px, W, H, pal, masque=None):
    """Une pose agrandie au ratio de l'ecran ; masque = le blanc par-dessus."""
    im = Image.new('RGB', (W * PW, H * PH), (0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(H):
        for x in range(W):
            v = px[y * W + x]
            if masque is not None and masque[y][x]:
                c = tuple(pal[BLANC * 3:BLANC * 3 + 3])
            elif v:
                c = tuple(pal[v * 3:v * 3 + 3])
            else:
                continue
            d.rectangle([x * PW, y * PH, x * PW + PW - 1, y * PH + PH - 1], fill=c)
    return im

def main():
    ps = poses()
    W, H, inter = noyau(ps)
    aire = sum(sum(r) for r in inter)
    xs = [x for x in range(W) if any(inter[y][x] for y in range(H))]
    ys = [y for y in range(H) if any(inter[y])]
    print('corps %dx%d, %d poses' % (W, H, len(ps)))
    print('noyau rond : %d..%d x %d..%d  (%dx%d), %d pixels'
          % (min(xs), max(xs), min(ys), max(ys),
             max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, aire))

    # --- l'image du flash, au format des autres poses
    pal = ps[0][2]
    out = bytearray(W * H)
    for y in range(H):
        for x in range(W):
            if inter[y][x]:
                out[y * W + x] = BLANC
    img = Image.frombytes('P', (W, H), bytes(out))
    img.putpalette(pal)
    dst = os.path.join(RACINE, 'src/enemies/slither/images/body_hit_round')
    os.makedirs(dst, exist_ok=True)
    img.save(os.path.join(dst, '00.png'))
    print('image ecrite : body_hit_round/00.png')

    # --- la planche : chaque pose, nue puis flashee
    marge, col = 10, 2
    cw, ch = W * PW, H * PH
    L = Image.new('RGB', (4 * (2 * cw + 3 * marge), 4 * (ch + marge) + marge), (24, 24, 24))
    for i, ((w, h), px, p) in enumerate(ps):
        cx = (i % 4) * (2 * cw + 3 * marge) + marge
        cy = (i // 4) * (ch + marge) + marge
        L.paste(rendu(px, W, H, p), (cx, cy))
        L.paste(rendu(px, W, H, p, inter), (cx + cw + marge, cy))
    L.save('/tmp/rond_planche.png')
    print('planche : /tmp/rond_planche.png')

    # --- la chaine tuilee : dix segments, le quatrieme flashe
    # Les seize poses ne sont PAS des rotations — toutes ont la meme
    # orientation (~85 deg, verticale) : ce sont les frames d'animation des
    # ecailles. La courbure du serpent vient donc des POSITIONS, pas des
    # sprites. On les tuile le long d'une courbe, a l'ecart reel de la chaine.
    import math
    px0 = ps[0][1]
    n, ecart = 10, 7           # ecart releve sous toje : 6.4 a 13.9, ~7 median
    CW, CH = 190, 90
    C = Image.new('RGB', (CW * PW // 2, CH * PH // 2), (0, 0, 0))
    for k in range(n - 1, -1, -1):        # a rebours : le plus ancien recouvre
        sx = 12 + k * ecart
        sy = int(30 + math.sin(0.35 + k * 0.30) * 18)
        (_, px, p2) = ps[k % len(ps)]
        seg = rendu(px, W, H, p2, inter if k == 3 else None)
        seg = seg.resize((W * PW // 2, H * PH // 2), Image.NEAREST)
        C.paste(seg, (sx * PW // 2, sy * PH // 2),
                seg.convert('L').point(lambda v: 255 if v else 0))
    C.save('/tmp/rond_chaine.png')
    print('chaine  : /tmp/rond_chaine.png')

    # --- la meme, mais avec le flash PLEINE SILHOUETTE, pour comparer
    plein = [[1 if px0[y * W + x] else 0 for x in range(W)] for y in range(H)]
    C2 = Image.new('RGB', (CW * PW // 2, CH * PH // 2), (0, 0, 0))
    for k in range(n - 1, -1, -1):
        sx = 12 + k * ecart
        sy = int(30 + math.sin(0.35 + k * 0.30) * 18)
        (_, px, p2) = ps[k % len(ps)]
        m = [[1 if px[y * W + x] else 0 for x in range(W)] for y in range(H)] if k == 3 else None
        seg = rendu(px, W, H, p2, m)
        seg = seg.resize((W * PW // 2, H * PH // 2), Image.NEAREST)
        C2.paste(seg, (sx * PW // 2, sy * PH // 2),
                 seg.convert('L').point(lambda v: 255 if v else 0))
    C2.save('/tmp/plein_chaine.png')
    print('comparaison pleine silhouette : /tmp/plein_chaine.png')

if __name__ == '__main__':
    main()
