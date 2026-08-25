#!/usr/bin/env python3
"""La planche des candidats : les sprites du stage 5 rendus sous chaque palette.

    python3 tools/pal05_planche.py SORTIE.png [P7 P11 ...]

Rien n'est ecrit dans l'arbre : les sprites sont cadres et reduits par les
fonctions de `arcade_to_sprites` (donc au pixel pres ce que la conversion
produirait), puis chaque pixel passe par la palette du candidat — plus proche
voisin, sauf les couleurs forcees.

Une planche vaut mieux qu'une colonne d'ecarts moyens : un degrade rendu sur
deux niveaux au lieu de trois se voit, et ne se lit pas dans le chiffre.
"""
import sys, os, glob, importlib.util
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arcade_to_in as A
import pal05_candidats as C

_s = importlib.util.spec_from_file_location(
    'ats', os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        'arcade_to_sprites.py'))
ATS = importlib.util.module_from_spec(_s)
_s.loader.exec_module(ATS)

# (etiquette, dossier d'originaux, index de la frame a montrer)
SUJETS = [
    ('slither tete', 'src/enemies/slither/images/original/head', 0),
    ('slither corps', 'src/enemies/slither/images/original/body', 0),
    ('slither queue', 'src/enemies/slither/images/original/tail', 0),
    ('pursuer', 'src/enemies/pursuer/images/original/default', 0),
    ('cheetah', 'src/enemies/cheetah/images/original/animation', 0),
]
ZOOM = 4


def rendu(dossier, frame, pal, forces):
    """L'image reduite, chaque pixel ramene sur la palette candidate."""
    chemins = sorted(glob.glob(os.path.join(dossier, '*.png')))
    if not chemins:
        return None
    u = ATS.cadre(chemins, Image.open(chemins[0]).size)
    if u is None:
        return None
    im = Image.open(chemins[min(frame, len(chemins) - 1)])
    src_pal = im.getpalette()
    petit, (w, h) = ATS.reduire(im, u)
    out = Image.new('RGB', (w, h), (0, 0, 0))
    op, pp = out.load(), petit.load()
    cache = {}
    for y in range(h):
        for x in range(w):
            i = pp[x, y]
            if not i:                       # index 0 = transparent
                continue
            if i not in cache:
                c = tuple(src_pal[i * 3:i * 3 + 3])
                cache[i] = C.nearest(c, pal, forces)[1]
            op[x, y] = cache[i]
    return out.resize((w * ZOOM, h * ZOOM), Image.NEAREST)


def main():
    sortie = sys.argv[1]
    voulus = sys.argv[2:] or None
    base = C.commons()
    cands = [(n, l, f) for n, l, f in C.CANDIDATS
             if not voulus or n.split()[0] in voulus]

    rendus = []
    for nom, libres, forces in cands:
        pal = dict(base)
        pal.update(libres)
        rendus.append((nom, pal, forces,
                       [(e, rendu(d, i, pal, forces)) for e, d, i in SUJETS]))

    colw = [max(im.width for _, _, _, r in rendus for e, im in r if e == et and im)
            for et, _, _ in SUJETS]
    GAP, PADX, PADY, TETE = 18, 150, 26, 22
    W = PADX + sum(c + GAP for c in colw) + 20
    H = TETE + sum(max(im.height for _, im in r if im) + PADY for _, _, _, r in rendus)
    im = Image.new('RGB', (W, H), (16, 16, 20))
    d = ImageDraw.Draw(im)

    x = PADX
    for (et, _, _), c in zip(SUJETS, colw):
        d.text((x, 6), et, fill=(150, 158, 175))
        x += c + GAP

    y = TETE
    for nom, pal, forces, r in rendus:
        hmax = max(i.height for _, i in r if i)
        d.text((8, y + hmax // 2 - 6), nom[:22], fill=(232, 234, 240))
        # les trois cases propres, en pastilles
        for k, idx in enumerate((13, 14, 16)):
            d.rectangle([8 + k * 22, y + hmax // 2 + 10,
                         8 + k * 22 + 18, y + hmax // 2 + 28],
                        fill=pal[idx], outline=(70, 70, 78))
            d.text((8 + k * 22 + 3, y + hmax // 2 + 30), str(idx),
                   fill=(255, 200, 90))
        x = PADX
        for (et, _, _), c in zip(SUJETS, colw):
            img = dict(r)[et]
            if img:
                im.paste(img, (x, y))
            x += c + GAP
        y += hmax + PADY
    im.save(sortie)
    print('planche ecrite :', sortie, im.size)


if __name__ == '__main__':
    main()
