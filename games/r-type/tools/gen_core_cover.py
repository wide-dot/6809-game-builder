#!/usr/bin/env python3
"""Le CACHE DE COQUE du noyau (boss du stage 3).

L'arcade dessine le noyau DERRIERE le plan de tuiles du vaisseau : au repos il
est dans une cavite de la coque, POSE sur sa plaque, et sa glissade de 13 px
le fait passer sous la masse de coque de DROITE. Seule cette masse le cache :
le cache est donc la fenetre de coque a droite de la cavite, rien en bas
(releve auteur sur la capture arcade, 09/09/2026).
Chez nous la couche mscroll est un tampon peint AVANT les sprites : rien ne
peut passer derriere. Le geste (decision auteur, 09/09/2026) : repeindre,
apres le noyau, le morceau de coque qui le recouvre, comme un SPRITE a
transparence — la cavite en index 0 laisse voir le noyau, la coque opaque
le cache. Le noyau l'inscrit chez wsmgr juste apres lui-meme : le manager
peint dans l'ordre d'inscription.

Ce script decoupe la fenetre dans src/stages/03/map/battleship.png a droite
de la position de REPOS du noyau (colonne 352, ligne 91 de la carte, voir
REST), et rend transparent le noir de la cavite — les
pixels d'index 1 (le noir de cette carte) CONNEXES au centre de la cavite,
pas les traits noirs de la coque, qui restent opaques. Sortie :
images/core-cover/00.png (canevas 48x36, meme palette), et core/cover.equ :
l'ecart du centre du canevas a l'ancre de repos du noyau, que le code
ajoute a l'inscription.

Rejeu : python3 tools/gen_core_cover.py (depuis games/r-type/), puis
gen_warship_slices.py (les tranches 16x12).
"""
import os
from PIL import Image

MAP = 'src/stages/03/map/battleship.png'
REST = (352, 91)                   # l'ancre de repos du noyau EN PIXELS DE CARTE : toje donne
                                   # mapX 352 et y_pos 102 a camera.y 0, et la couche est peinte
                                   # 11 lignes sous le haut de l'ecran (le cadre du champ) —
                                   # ligne de carte = y ecran + camera.y - 11. Verifie : pose sur
                                   # la plaque (ligne 103) comme sur la borne.
WIN = (364, 73, 396, 109)          # la fenetre : la masse de coque de DROITE seule (le
                                   # noyau y glisse) ; la cavite n'est pas cachee
NOIR = 1                           # l'index du noir dans cette carte
DST = 'src/enemies/warship-elements/images/core-cover'
EQU = 'src/enemies/warship-elements/core/cover.equ'


def main():
    im = Image.open(MAP)
    assert im.mode == 'P', 'carte non indexee'
    x0, y0, x1, y1 = WIN
    crop = im.crop(WIN)
    w, h = crop.size
    px = crop.load()
    # le noir de la cavite : flood fill sur l'index 1 depuis le bord gauche de
    # la fenetre, a la hauteur du noyau (la cavite est a gauche de la fenetre)
    ry = REST[1] - y0
    seeds = [(x, ry) for x in range(w) if px[x, ry] == NOIR]
    pile = seeds[:1]
    vus = set()
    while pile:
        x, y = pile.pop()
        if (x, y) in vus or not (0 <= x < w and 0 <= y < h) or px[x, y] != NOIR:
            continue
        vus.add((x, y))
        pile += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for x, y in vus:
        px[x, y] = 0
    os.makedirs(DST, exist_ok=True)
    for f in os.listdir(DST):
        if f.endswith('.png'):
            os.remove(os.path.join(DST, f))
    crop.save(os.path.join(DST, '00.png'))
    cx, cy = x0 + w // 2, y0 + h // 2
    open(os.path.join(DST, 'geometrie.txt'), 'w').write(
        '# fenetre de battleship.png %d %d %d %d, cavite (index 1 connexe a %d,%d) -> 0\n'
        '# centre du canevas en couche %d %d ; repos du noyau %d %d\n'
        % (x0, y0, x1, y1, REST[0], REST[1], cx, cy, REST[0], REST[1]))
    open(EQU, 'w').write(
        '; GENERE par tools/gen_core_cover.py — le cache de coque du noyau :\n'
        '; l\'ecart du centre de son canevas (%dx%d) a l\'ancre de REPOS du noyau.\n'
        'core.COVERDX equ %d\n'
        'core.COVERDY equ %d\n' % (w, h, cx - REST[0], cy - REST[1]))
    print('%s : %dx%d, %d pixels de cavite rendus transparents ; centre (%d,%d), ecart (%d,%d)'
          % (DST, w, h, len(vus), cx, cy, cx - REST[0], cy - REST[1]))


if __name__ == '__main__':
    main()
