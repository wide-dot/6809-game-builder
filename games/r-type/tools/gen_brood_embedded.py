#!/usr/bin/env python3
"""Ampute la base du brood de ses lignes ENFOUIES dans la paroi.

Pourquoi : le brood est fixe au decor, et la place regagnee paie les
variantes pre-decalees (shifts="0,1") qui le calent au pixel sur le scroll —
l'imageset double, il doit tenir dans les 16 Ko d'une page.

Ce qui est coupe a ete MESURE en jeu (sonde toje, 26/08/2026), pas estime :
  - sol (poses impaires) : le sprite pose s'etend sur les lignes ecran
    141..188, la surface de roche au montage est a ~174-176 -> tout ce qui
    est au-dela de la ligne 34 du sprite est enfoui. On coupe 36..47
    (12 lignes) : la base verte de la pose fermee (36..47) exactement,
    2 lignes de marge enfouie restent au raccord.
  - plafond (poses paires) : sprite sur 9..56, le plafond le moins profond
    releve autour du montage est a la ligne ecran ~22 -> lignes <= 13 du
    sprite enfouies. On coupe 0..11 (12 lignes), 2 lignes de marge.
La premiere coupe (9/10 lignes) laissait l'imageset double a 16796 octets,
412 de trop pour la page : la profondeur est reglee au plus juste DANS la
zone mesuree enfouie, jamais au-dela.
Pendant l'entree et le settle le sprite est PLUS enfoui encore (il emerge de
12 px) : la coupe y est d'autant plus invisible.

Le canevas garde sa taille (24x48) : l'ancre et le positionnement du code
objet ne bougent pas — seuls les pixels coupes passent a la couleur cle.

Entree : images/open/ (l'export arcade, reference intouchee).
Sortie : images/embedded/ (ce que le build consomme).
"""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / 'src/enemies/brood/images/open'
DST = HERE.parent / 'src/enemies/brood/images/embedded'

KEY = (204, 0, 255)        # la couleur cle de la chaine (relevee dans open/)
CUT_CEILING = 12           # poses paires : lignes 0..11 coupees
CUT_FLOOR = 12             # poses impaires : lignes 36..47 coupees

DST.mkdir(exist_ok=True)
for png in sorted(SRC.glob('*.png')):
    idx = int(png.stem)
    im = Image.open(png)
    assert im.mode == 'P', f'{png.name}: la chaine attend un PNG indexe 8 bits'
    w, h = im.size
    assert (w, h) == (24, 48), f'{png.name}: canevas inattendu {w}x{h}'
    pal = im.getpalette()
    key = next(i for i in range(len(pal) // 3)
               if tuple(pal[i * 3:i * 3 + 3]) == KEY)
    px = im.load()
    rows = range(CUT_CEILING) if idx % 2 == 0 else range(h - CUT_FLOOR, h)
    cleared = 0
    for y in rows:
        for x in range(w):
            if px[x, y] != key:
                px[x, y] = key
                cleared += 1
    im.save(DST / png.name)
    side = 'plafond' if idx % 2 == 0 else 'sol'
    print(f'{png.name} ({side}) : {cleared} px enfouis retires')

# la geometrie ne change pas : meme canevas, meme ancre
geo = SRC / 'geometrie.txt'
(DST / 'geometrie.txt').write_text(geo.read_text())
print('geometrie recopiee (inchangee : meme canevas, meme ancre)')
