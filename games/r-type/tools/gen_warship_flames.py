#!/usr/bin/env python3
"""Les gerbes des reacteurs de ventre : dedupliquer, trancher, emettre la chaine.

DEUX GESTES, tous deux dictes par l'arcade et par le moteur de sprites.

1. DEDUPLIQUER. La chaine d'animation arcade (1000:7ef2/7f38/7f7e) compte DIX
   entrees, mais ne designe que QUATRE recettes : elle les cycle
   (0,1,2,1,2,3,2,3,2,3 pour la gerbe basse). L'export les deroule toutes les
   dix ; on ne garde que les uniques et on emet la chaine en clair. C'est le
   geste des roues de tourelle, et il divise l'art par deux et demi — de 36 Ko
   a 15,5 Ko, ce qui fait tenir LES TROIS GERBES DANS UNE PAGE. C'est cette
   tenue qui rend possible le manager a un seul objet : BuildSprites ne monte
   qu'une page d'images par identifiant.

2. TRANCHER en quatre — SANS TOUCHER AU CANEVAS. BuildSprites REJETTE EN BLOC
   un sprite qui deborde de la bande, il ne clippe jamais. Une gerbe de 48
   lignes disparait donc des que son bas depasse, alors que sa buse est encore
   a l'ecran : 44 px de bande morte, pres d'une seconde de jet manquant quand
   le vaisseau descend. En quatre tranches de 12 la bande morte tombe a 8 px —
   le jet et sa buse s'en vont ensemble, ce que l'oeil lit comme une sortie de
   cadre et non comme un defaut.
   Le tranchage reste necessaire MALGRE le manager : un sprite compile ecrit un
   nombre de lignes fixe, on ne peut pas l'arreter en route.

   LA TRANCHE GARDE LES 48 LIGNES DU CANEVAS, dont douze seulement sont
   peintes. C'est ce qui rend le manager trivial. L'encodeur ROGNE les bords
   transparents mais rapporte les bornes au CENTRE DU CANEVAS
   (Image.java : `x1_offset = x_Min - (width-1)/2`) : les quatre tranches
   partagent donc EXACTEMENT la meme ancre, tout en portant chacune la boite
   de ses douze lignes a elle. Le manager les dessine aux memes coordonnees,
   sans un seul calcul de decalage, et le test de bande se fait par tranche
   puisque chacune declare sa propre hauteur. Rogner le canevas aurait donne
   quatre ancres differentes a rattraper a la main.
   Le poids ne bouge pas : l'encodeur n'emet que la region rognee.

Sortie : images/flame-wheel/ (48 images) et reactor/flames.asm (les chaines).

Usage : python3 tools/gen_warship_flames.py   (depuis games/r-type)
"""
import os
import re

from PIL import Image

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
ARC = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/sprites/warship-elements')
DATA = 0x1000 * 16
TRANCHES = 4
GERBES = ((0x7EF2, 'bottom-reactor-flame-straight-down', 'fl_d'),
          (0x7F38, 'bottom-reactor-flame-right', 'fl_r'),
          (0x7F7E, 'bottom-reactor-flame-left', 'fl_l'))


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/warship-elements')
    rom = open(ROM, 'rb').read()

    def w(o):
        return rom[DATA + o] | (rom[DATA + o + 1] << 8)

    dst = os.path.join(base, 'images/flame-wheel')
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if f.endswith('.png'):
            os.remove(os.path.join(dst, f))

    out = [
        "; Les gerbes des reacteurs de ventre — GENERE par",
        "; tools/gen_warship_flames.py depuis le dump arcade.",
        ";",
        "; Une chaine = les dix pas de l'animation, chacun donnant le rang de la",
        "; POSE UNIQUE a jouer (l'arcade cycle quatre recettes sur dix pas). Le",
        "; manager y lit le rang, puis dessine les QUATRE TRANCHES de cette pose",
        "; qui tiennent dans la bande.",
        ";",
        "; Les images sont rangees pose par pose, tranche par tranche :",
        ";   set_fl_<n>, n courant sur tout le dossier, tranche 0 = la plus HAUTE.",
        "; Ce sont les IMAGESETS : le manager y lit la geometrie (bornes, taille,",
        "; centre) pour son test de bande, puis l'adresse de la routine compilee —",
        "; le meme chemin que outslay.RecPublish. Les quatre tranches d'une pose",
        "; se dessinent a la MEME ancre : elles gardent le canevas de la gerbe.",
        "",
    ]
    n_img = 0
    # LE NUMERO EST GLOBAL AU DOSSIER : <images> range par nom de fichier et
    # numerote dans cet ordre, si bien que le rang du fichier EST le rang du
    # symbole set_fl_<n>. Les trois gerbes se suivent donc, seize images
    # chacune (quatre poses uniques x quatre tranches).
    rang = [0]
    for chaine, dossier, prefixe in GERBES:
        ordi = {}
        for nom in os.listdir(os.path.join(ARC, dossier)):
            m = re.match(r'(\d+)_01([0-9a-f]{4})\.png$', nom)
            if m:
                ordi[int(m.group(2), 16)] = int(m.group(1))
        pas = [w(chaine + 2 * k) for k in range(10)]
        uniques = []
        for a in pas:
            if a not in uniques:
                uniques.append(a)
        src = os.path.join(base, 'images', dossier)
        for p, a in enumerate(uniques):
            im = Image.open(os.path.join(src, '%02d.png' % ordi[a]))
            h = im.height // TRANCHES
            for t in range(TRANCHES):
                # LA DECOUPE RESTE EN MODE P, PALETTE ET INDEX INTACTS.
                # gfxcomp lit l'octet brut du raster : pixel == 0 -> transparent,
                # le RGB ne compte pas — et la palette du jeu met sa cle magenta
                # a l'index 0. Un passage par RGBA puis convert('P') requantifie
                # avec un ordre PAR IMAGE : magenta opaque, teintes decalees
                # d'un cran, et trois ordres differents sur seize tranches
                # (vecu le 29/08/2026, gerbes fausses a l'ecran). On copie donc
                # la source et on remplit d'index 0 les lignes hors bande.
                assert im.mode == 'P', 'source non palettisee : ' + dossier
                tr = im.copy()
                tr.paste(0, (0, 0, im.width, t * h))
                tr.paste(0, (0, (t + 1) * h, im.width, im.height))
                if not tr.getbbox():
                    raise SystemExit('tranche vide : %s_%02d — l\'encodeur ne '
                                     'sait pas placer une image sans pixel'
                                     % (prefixe, p * TRANCHES + t))
                tr.save(os.path.join(dst, '%02d.png' % rang[0]))
                rang[0] += 1
                n_img += 1
        out.append('; %s : %d poses uniques sur dix pas (chaine %04X)'
                   % (dossier, len(uniques), chaine))
        out.append('flame.chain.%s' % prefixe)
        out.append('        fcb   ' + ','.join(str(uniques.index(a)) for a in pas))
        depart = rang[0] - TRANCHES * len(uniques)
        out.append('flame.sets.%s' % prefixe)
        for p in range(len(uniques)):
            out.append('        fdb   ' + ','.join(
                'set_fl_%d' % (depart + p * TRANCHES + t) for t in range(TRANCHES)))
        out.append('')
        geo = os.path.join(src, 'geometrie.txt')
        if os.path.exists(geo):
            with open(os.path.join(dst, 'geometrie.txt'), 'w') as f:
                f.write(open(geo).read())
    out += ['flame.Chains',
            '        fdb   ' + ','.join('flame.chain.%s' % g[2] for g in GERBES),
            'flame.Sets',
            '        fdb   ' + ','.join('flame.sets.%s' % g[2] for g in GERBES),
            '']
    open(os.path.join(base, 'reactor/flames.asm'), 'w').write('\n'.join(out))
    print('%d images -> images/flame-wheel/, chaines -> reactor/flames.asm' % n_img)


if __name__ == '__main__':
    main()
