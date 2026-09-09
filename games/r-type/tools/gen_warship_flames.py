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

2. TRANCHER EN FENETRES DE 16 x 12 — SANS TOUCHER AU CANEVAS (depuis le
   09/09/2026 : quatre rangees de douze lignes ET deux colonnes, 16 + 8 px,
   la regle commune des gros sprites mobiles ; les fenetres vides ne sont
   pas emises — 76 tranches pour 12 poses). BuildSprites REJETTE EN BLOC
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

Sortie : images/flame-wheel-<d|r|l>/ (les tranches, un dossier par gerbe), reactor/flames.asm (les chaines
et, par pose, la LISTE de ses tranches au format du manager wsmgr :
fcb n / fdb sets) et reactor/flames.ext.asm (les EXTERNAL du cast).

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
TW, TH = 16, 12
# (chaine arcade, dossier source, prefixe des symboles, identifiant dont
#  Img_Page_Index donne la page du fichier d'images qui porte cette gerbe)
# LES TROIS GERBES NE TIENNENT PLUS DANS UNE PAGE une fois tranchees en
# 16x12 (16 778 octets, 09/09/2026) : la gerbe gauche loge dans la page des
# tourelles (imgTurret, 9 Ko libres). Le manager de tranches wsmgr monte la
# page par slot, donc la page peut differer par gerbe — le manager des gerbes
# la lit dans Img_Page_Index de l'identifiant note ici (flame.PageIds).
GERBES = ((0x7EF2, 'bottom-reactor-flame-straight-down', 'fl_d', 'ObjID_warship_flamemgr'),
          (0x7F38, 'bottom-reactor-flame-right', 'fl_r', 'ObjID_warship_flamemgr'),
          (0x7F7E, 'bottom-reactor-flame-left', 'fl_l', 'ObjID_warship_turret'))


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/warship-elements')
    rom = open(ROM, 'rb').read()

    def w(o):
        return rom[DATA + o] | (rom[DATA + o + 1] << 8)

    out = [
        "; Les gerbes des reacteurs de ventre — GENERE par",
        "; tools/gen_warship_flames.py depuis le dump arcade.",
        ";",
        "; Une chaine = les dix pas de l'animation, chacun donnant le rang de la",
        "; POSE UNIQUE a jouer (l'arcade cycle quatre recettes sur dix pas). Le",
        "; manager des gerbes (flamemgr.asm) y lit le rang, puis INSCRIT chez",
        "; wsmgr la liste des tranches 16x12 de cette pose (fcb n / fdb sets),",
        "; que wsmgr dessine tranche par tranche, chacune testee contre la bande.",
        ";",
        "; Les images sont rangees pose par pose, fenetre par fenetre (rangees",
        "; du haut vers le bas, colonnes de gauche a droite) : set_fl_<n>, n",
        "; courant sur tout le dossier. Toutes les tranches d'une pose gardent",
        "; le canevas de la gerbe, donc partagent son ancre.",
        "",
    ]
    n_img = 0
    externs = ['; GENERE par tools/gen_warship_flames.py — les tranches des gerbes, resolues au chargement.']
    for chaine, dossier, prefixe, hote in GERBES:
        # UN DOSSIER PAR GERBE (images/flame-wheel-<prefixe>/), parce que les
        # gerbes peuvent vivre dans des pages differentes ; <images> numerote
        # par nom de fichier, si bien que le rang du fichier EST le rang du
        # symbole set_<prefixe>_<n>.
        dst = os.path.join(base, 'images/flame-wheel-' + prefixe[3:])
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(dst):
            if f.endswith('.png'):
                os.remove(os.path.join(dst, f))
        rang = [0]
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
        listes = []
        for p, a in enumerate(uniques):
            im = Image.open(os.path.join(src, '%02d.png' % ordi[a]))
            assert im.mode == 'P', 'source non palettisee : ' + dossier
            iw, ih = im.size
            px = im.tobytes()
            mots = []
            for y0 in range(0, ih, TH):
                for x0 in range(0, iw, TW):
                    x1, y1 = min(x0 + TW, iw), min(y0 + TH, ih)
                    if not any(px[y * iw + x] for y in range(y0, y1) for x in range(x0, x1)):
                        continue           # fenetre vide : rien a dessiner
                    # LA DECOUPE RESTE EN MODE P, PALETTE ET INDEX INTACTS.
                    # gfxcomp lit l'octet brut du raster : pixel == 0 ->
                    # transparent, le RGB ne compte pas — et la palette du jeu
                    # met sa cle magenta a l'index 0. Un passage par RGBA puis
                    # convert('P') requantifie avec un ordre PAR IMAGE (vecu le
                    # 29/08/2026, gerbes fausses a l'ecran). On copie donc la
                    # source et on remplit d'index 0 tout ce qui est hors fenetre.
                    tr = im.copy()
                    tr.paste(0, (0, 0, iw, y0))
                    tr.paste(0, (0, y1, iw, ih))
                    tr.paste(0, (0, y0, x0, y1))
                    tr.paste(0, (x1, y0, iw, y1))
                    tr.save(os.path.join(dst, '%02d.png' % rang[0]))
                    mots.append('set_%s_%d' % (prefixe, rang[0]))
                    externs.append('set_%s_%d  EXTERNAL' % (prefixe, rang[0]))
                    rang[0] += 1
                    n_img += 1
            listes.append(mots)
        out.append('; %s : %d poses uniques sur dix pas (chaine %04X)'
                   % (dossier, len(uniques), chaine))
        out.append('flame.chain.%s' % prefixe)
        out.append('        fcb   ' + ','.join(str(uniques.index(a)) for a in pas))
        for p, mots in enumerate(listes):
            out.append('flame.sl.%s.%d' % (prefixe, p))
            out.append('        fcb   %d' % len(mots))
            out.append('        fdb   ' + ','.join(mots))
        out.append('flame.sets.%s' % prefixe)
        out.append('        fdb   ' + ','.join('flame.sl.%s.%d' % (prefixe, p) for p in range(len(listes))))
        out.append('')
        geo = os.path.join(src, 'geometrie.txt')
        if os.path.exists(geo):
            with open(os.path.join(dst, 'geometrie.txt'), 'w') as f:
                f.write(open(geo).read())
    out += ['flame.Chains',
            '        fdb   ' + ','.join('flame.chain.%s' % g[2] for g in GERBES),
            'flame.Sets',
            '        fdb   ' + ','.join('flame.sets.%s' % g[2] for g in GERBES),
            '; la page des tranches de chaque gerbe : Img_Page_Index de cet identifiant',
            'flame.PageIds',
            '        fcb   ' + ','.join(g[3] for g in GERBES),
            '']
    open(os.path.join(base, 'reactor/flames.asm'), 'w').write('\n'.join(out))
    open(os.path.join(base, 'reactor/flames.ext.asm'), 'w').write('\n'.join(externs) + '\n')
    print('%d images -> images/flame-wheel-*/, chaines et listes -> reactor/flames.asm, EXTERNAL -> flames.ext.asm' % n_img)


if __name__ == '__main__':
    main()
