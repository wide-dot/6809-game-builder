#!/usr/bin/env python3
"""Convertir les sprites arcade d'un objet en sprites TO8.

L'export arcade pose chaque frame sur un canevas de 256x256, index 0
transparent, le sprite centré sur le point chaud de l'arcade. Le portage veut
des PNG serrés, réduits au format TO8 et ramenés sur la palette du jeu.

## La géométrie — mesurée, pas supposée

Le cadre d'un jeu de frames est l'**union des boîtes englobantes** de ses
frames, réduite de **3/8 en X et 3/4 en Y** au plus proche voisin. Prouvé
exactement sur la seule paire complète du dépôt : les treize frames arcade du
`pow` ont pour union 32x32, et les six PNG TO8 du `pow` font 12x24 —
32x3/8 = 12 et 32x3/4 = 24, au pixel. C'est aussi le ratio de la carte
(`arcade_to_in.py`), ce qui est attendu : il ne dépend que de la géométrie du
pixel TO8, deux fois plus large que haut.

Un cadre par jeu de frames, et non un cadre par frame : c'est ce qui fait qu'un
sprite ne se déplace pas d'une frame à l'autre. L'**ancre** — l'écart entre le
centre du canevas arcade et le coin haut-gauche du cadre — est écrite dans un
fichier `geometrie.txt` à côté des PNG. Le code objet en aura besoin pour placer le
sprite, et cette information ne se retrouve plus une fois le PNG rogné.

## La palette

Deux modes, et le choix n'est pas une préférence :

* `--palette communs` — les 12 index communs seuls, cases 13-16 en magenta.
  C'est le **défaut**, et c'est ce qu'il faut pour tout objet qu'au moins deux
  stages chargent : sa couleur ne peut pas dépendre d'un stage. C'est déjà la
  convention des sprites communs du dépôt (mesurée sur pata-pata : 13, 14 et 16
  en `FF00FF`, seule la case 15 employée, l'olive propre au stage).
* `--palette NN` — la palette dédiée du stage NN, ses quatre cases comprises.
  Réservé aux objets **exclusifs** à un stage. Un objet converti ainsi devra
  être reconverti le jour où un autre stage le convoque.

La quantification se fait en **CIE Lab ΔE76**, la même métrique que la carte
(voir l'en-tête de `arcade_to_in.py` : la distance RGB confond « teinte un peu
fausse » et « teinte détruite »). L'index 0 arcade est la transparence et
ressort en index 0, jamais quantifié.

    usage : tools/arcade_to_sprites.py <objet> [options]

    <objet>          nom sous src/enemies/ (ex. gouger) ou chemin d'un
                     répertoire contenant images/original/
    --palette P      `communs` (défaut), un numéro de stage (ex. 02), ou un
                     chemin de PNG — utile pour une palette dédiée à un boss.
    --ecrire-palette CHEMIN
                     calcule d'abord une palette DÉDIÉE à cet objet (12 communs
                     + les cases propres du stage attribuées à lui seul, olive
                     gelée comprise), l'écrit là, et convertit dessus. Voir
                     `palette_dediee()`.
    --dry-run        n'écrit rien, affiche la géométrie et les couleurs
    --out-suffixe S  suffixe de sortie (défaut : aucun, écrit dans images/)
"""
import argparse
import os
import sys
import glob
import importlib.util
from collections import Counter

from PIL import Image

RACINE = os.path.dirname(os.path.abspath(__file__))
SCALE_X = 3 / 8
SCALE_Y = 3 / 4
MAGENTA_LIBRE = (0xFF, 0x00, 0xFF)   # une case de stage non employee
MARQUEUR_TRANSP = (0xCC, 0x00, 0xFF)  # l'index 0 des PNG du portage


def _outil_carte():
    """arcade_to_in.py — une seule source pour la reduction et la metrique."""
    spec = importlib.util.spec_from_file_location(
        'arcade_to_in', os.path.join(RACINE, 'arcade_to_in.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


A = _outil_carte()


def verifie_transparence(p, im):
    """L'index 0 est-il bien la transparence de ce PNG arcade ?

    Mesure sur les 605 PNG de l'export : 590 declarent `transparency=0`, les
    15 autres (blaster, foefire) ne declarent rien mais ont un index 0 noir qui
    couvre plus de 99 % du canevas. Meme convention, donc — mais elle se
    verifie, elle ne se suppose pas : un export ou l'index 0 serait une couleur
    du sprite donnerait un sprite entierement troue, sans rien dire.
    """
    t = im.info.get('transparency')
    if t not in (None, 0):
        sys.exit('%s : transparence a l\'index %s, pas 0 — non gere' % (p, t))
    pal = im.getpalette()
    if tuple(pal[0:3]) != (0, 0, 0):
        sys.exit('%s : index 0 n\'est pas noir (%s) — transparence douteuse'
                 % (p, tuple(pal[0:3])))
    n0, total = im.histogram()[0], im.size[0] * im.size[1]
    if n0 < 0.5 * total:
        sys.exit('%s : index 0 ne couvre que %.1f %% — transparence douteuse'
                 % (p, 100 * n0 / total))


def boite(im):
    """Boite englobante des pixels non transparents (index 0 = transparence)."""
    px, (w, h) = im.load(), im.size
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if px[x, y]:
                x0, y0 = min(x0, x), min(y0, y)
                x1, y1 = max(x1, x), max(y1, y)
    return None if x1 < 0 else (x0, y0, x1, y1)


def cadre(chemins, canevas):
    """L'union des boites du jeu de frames, collee a la grille de reduction.

    Deux quantites doivent tomber juste, pas une : la TAILLE reduite et
    l'ANCRE. Le cadre etant symetrique autour du centre du canevas — le point
    chaud de l'arcade — l'ancre vaut la demi-etendue, et c'est donc la
    DEMI-etendue qui doit etre multiple de 8 en X et de 4 en Y (soit un cadre
    multiple de 16 et de 8). Caler sur la taille seule ne suffit pas : une union
    de 32x28 donne bien 12x21 entiers, mais une ancre a -10,5 — un placement au
    demi-pixel que le code objet ne peut pas exprimer. Mesure du premier jet :
    `outslay/body` sortait exactement comme ca.

    L'extension ne prend que de la transparence, elle ne peut rien couper.
    """
    u = None
    for p in chemins:
        im = Image.open(p)
        verifie_transparence(p, im)
        b = boite(im)
        if b is None:
            continue
        u = b if u is None else (min(u[0], b[0]), min(u[1], b[1]),
                                 max(u[2], b[2]), max(u[3], b[3]))
    if u is None:
        return None
    cx, cy = canevas[0] / 2, canevas[1] / 2

    def cale(a, b, centre, pas):
        """Demi-etendue max autour du centre, arrondie au pas superieur."""
        demi = max(centre - a, b + 1 - centre)
        demi = pas * ((demi + pas - 1) // pas)
        return int(centre - demi), int(centre + demi) - 1
    x0, x1 = cale(u[0], u[2], cx, 8)   # demi-largeur multiple de 8 -> ancre entiere
    y0, y1 = cale(u[1], u[3], cy, 4)   # demi-hauteur multiple de 4 -> ancre entiere
    return (x0, y0, x1, y1)


def palette_cible(spec):
    """(liste rgb 0..16, index attribuables) de la palette de sortie."""
    if spec == 'communs':
        src = 'tools/palette-reference/nouvelle.png'
        libres = []
    elif spec.endswith('.png'):
        src = spec
        libres = [13, 14, 15, 16]
    else:
        src = 'src/stages/%s/palette/pal.png' % spec
        libres = [13, 14, 15, 16]
    p = Image.open(src).getpalette()
    pal = [tuple(p[i * 3:i * 3 + 3]) for i in range(17)]
    pal[0] = MARQUEUR_TRANSP
    # Les 12 communs sont les index PNG 1..12. Les quatre suivants ne sont
    # ouverts qu'en mode stage ; sinon ils sortent en magenta, comme le veut la
    # convention des sprites communs (leur couleur viendra de Pal_stage).
    dispo = list(range(1, 13)) + libres
    for i in range(13, 17):
        if i not in libres:
            pal[i] = MAGENTA_LIBRE
    return pal, dispo


def reduire(im, u):
    """Rogne au cadre puis reduit 3/8 x 3/4, plus proche voisin.

    Meme echantillonnage que la carte (A.downscale), mais sur les INDEX et non
    sur du RGB : un pixel transparent doit rester transparent, et une moyenne
    inventerait des couleurs qui ne sont pas dans la palette.
    """
    x0, y0, x1, y1 = u
    aw, ah = x1 - x0 + 1, y1 - y0 + 1
    w, h = max(1, round(aw * SCALE_X)), max(1, round(ah * SCALE_Y))
    src, out = im.load(), Image.new('P', (w, h))
    op = out.load()
    for y in range(h):
        ay = y0 + y * ah // h
        for x in range(w):
            op[x, y] = src[x0 + x * aw // w, ay]
    return out, (w, h)


def correspondance(im_src, pal, dispo, forcer=None):
    """{index arcade -> index TO8}, en Lab — SAUF les couleurs forcees.

    `forcer` : {rgb arcade: index materiel OU (a, b) trame}. Regle de l'auteur
    (18/08) : en pixel art le NOMBRE DE NIVEAUX d'un degrade compte plus que
    la proximite Lab. Le plus proche voisin ecrase volontiers une rampe de
    4 verts sur une seule case ; le forcage pose chaque marche sur SA case,
    par rang — la bijection par rang de la regle 1 du protocole, appliquee
    aux sprites. Le cas fondateur est le mikun : 4 verts et 3 bleus arcade,
    que Lab reduisait a 2 et 2.

    Une TRAME (a, b) est un damier des deux index, alterne sur (x+y) — meme
    notation `A~B` et meme sens que dans palette-map.txt : elle compte comme
    UNE valeur percue, et c'est le moyen de fabriquer un barreau intermediaire
    quand la palette n'a plus de case libre. Attention au rendu reel : le TO8
    est en 160x200, le pixel est deux fois plus large que haut, donc un damier
    se lit en fines rayures diagonales.
    """
    ps = im_src.getpalette()
    m = {0: 0}
    for i, n in enumerate(im_src.histogram()):
        if not n or i == 0:
            continue
        c = tuple(ps[i * 3:i * 3 + 3])
        if forcer and c in forcer:
            v = forcer[c]
            m[i] = (v[0] + 1, v[1] + 1) if isinstance(v, tuple) else v + 1
        else:
            m[i] = min(dispo, key=lambda j: A.dist_lab(c, pal[j]))
    return m


def convertir(objet, spec_pal, dry, suffixe, forcer=None, dedup=False, marge=0):
    base = objet if os.path.isdir(objet) else 'src/enemies/%s' % objet
    orig = os.path.join(base, 'images/original')
    if not os.path.isdir(orig):
        sys.exit('%s : pas de images/original/' % base)
    pal, dispo = palette_cible(spec_pal)
    plat = [v for i in range(256) for v in (pal[i] if i < 17 else (0, 0, 0))]

    jeux = {}
    for p in sorted(glob.glob(os.path.join(orig, '*/*.png'))):
        jeux.setdefault(os.path.basename(os.path.dirname(p)), []).append(p)
    for p in sorted(glob.glob(os.path.join(orig, '*.png'))):
        jeux.setdefault('', []).append(p)
    if not jeux:
        sys.exit('%s : aucun PNG' % orig)

    print('%s  palette %s  (%d index attribuables)'
          % (base, spec_pal, len(dispo)))
    total = 0
    for nom, chemins in sorted(jeux.items()):
        u = cadre(chemins, Image.open(chemins[0]).size)
        if u is None:
            print('  %-16s VIDE (que de la transparence) — passe' % (nom or '.'))
            continue
        aw, ah = u[2] - u[0] + 1, u[3] - u[1] + 1
        w, h = max(1, round(aw * SCALE_X)), max(1, round(ah * SCALE_Y))
        # L'ancre : ou tombe le coin haut-gauche du cadre par rapport au centre
        # du canevas arcade, exprime en pixels TO8.
        cx, cy = Image.open(chemins[0]).size
        ax, ay = (u[0] - cx / 2) * SCALE_X, (u[1] - cy / 2) * SCALE_Y
        print('  %-16s %2d frames  cadre %dx%d -> %dx%d  ancre %+.1f %+.1f'
              % (nom or '.', len(chemins), aw, ah, w, h, ax, ay))
        dst = os.path.join(base, 'images' + suffixe, nom)
        # --dedup : un cycle d'animation arcade repasse souvent par les memes
        # poses (le gouger fait un aller-retour 0 1 2 3 2 1 0 puis une huitieme
        # distincte). Importer huit fichiers quand cinq suffisent double le
        # cout sprite pour rien. Sous ce drapeau on n'ecrit que les images
        # DISTINCTES, renumerotees a la suite, et on note la correspondance
        # slot -> pose dans cycle.txt : c'est elle que le code objet indexe.
        # Opt-in, parce que renumeroter changerait l'art deja embarque des
        # ennemis existants.
        vus = {}
        cycle = []
        for n, p in enumerate(chemins):
            im = Image.open(p)
            petit, _ = reduire(im, u)
            m = correspondance(im, pal, dispo, forcer)
            px = petit.load()
            for y in range(h):
                for x in range(w):
                    v = m[px[x, y]]
                    px[x, y] = v[(x + y) & 1] if isinstance(v, tuple) else v
            petit.putpalette(plat)
            if dedup:
                cle = petit.tobytes()
                if cle in vus:
                    cycle.append(vus[cle])
                    continue
                pose = len(vus)
                vus[cle] = pose
                cycle.append(pose)
            else:
                pose = n
            if marge:
                large = Image.new('P', (w + marge, h), 0)
                large.putpalette(plat)
                large.paste(petit, (0, 0))
                petit = large
            if not dry:
                os.makedirs(dst, exist_ok=True)
                petit.save(os.path.join(dst, '%02d.png' % pose))
            total += 1
        if dedup and not dry:
            os.makedirs(dst, exist_ok=True)
            with open(os.path.join(dst, 'cycle.txt'), 'w') as f:
                f.write('# slot d animation arcade -> pose importee, ecrit par\n'
                        '# arcade_to_sprites.py --dedup. Le code objet indexe\n'
                        '# cette table, pas le slot brut.\n')
                f.write(' '.join(str(c) for c in cycle) + '\n')
        if not dry:
            os.makedirs(dst, exist_ok=True)
            with open(os.path.join(dst, 'geometrie.txt'), 'w') as f:
                f.write('# cadre arcade et ancre, ecrits par arcade_to_sprites.py\n'
                        '# ancre = coin haut-gauche du cadre vs centre du canevas,\n'
                        '#         en pixels TO8 — le code objet en a besoin.\n'
                        'cadre_arcade %d %d %d %d\n'
                        'taille_to8 %d %d\n'
                        'ancre_to8 %.1f %.1f\n' % (u[0], u[1], u[2], u[3],
                                                    w + marge, h, ax, ay))
                if marge:
                    f.write('marge_droite %d\n' % marge)
    print('  %d frames%s' % (total, ' (dry-run, rien ecrit)' if dry else ' ecrites'))
    return 0


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('objet')
    ap.add_argument('--palette', default='communs')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--out-suffixe', default='')
    ap.add_argument('--ecrire-palette', default=None)
    ap.add_argument('--stage', default=None)
    ap.add_argument('--garder-olive', action='store_true')
    ap.add_argument('--dedup', action='store_true',
                    help="n'importer que les poses distinctes, et ecrire la "
                         "table slot -> pose dans cycle.txt")
    ap.add_argument('--forcer', action='append', default=[],
                    help='R,G,B:MAT ou R,G,B:A~B (trame) — couleur arcade '
                         'posee sur un index (ou un damier de deux), hors '
                         'Lab. Repetable. Preserve les niveaux d\'un degrade.')
    ap.add_argument('--marge-droite', type=int, default=0,
                    help="pixels TO8 transparents ajoutes A DROITE du cadre. "
                         "Le centre d'un sprite compile est width/2 : une "
                         "marge de N decale le dessin de N/2 px vers la "
                         "GAUCHE a l'affichage, sans toucher x_pos. Sert a "
                         "recentrer un sprite sur sa mecanique (cytron : la "
                         "gomme sort desormais une cellule plus a gauche, le "
                         "corps doit suivre de 2 px — pixels larges obligent, "
                         "c'est l'echelon exact).")
    ap.add_argument('--ajuster', default=None,
                    help='index materiels COMMUNS re-regles pour ce combat, ex. 7,8')
    ap.add_argument('--poser', default=None,
                    help='R,G,B:MATERIEL;... — valeurs POSEES PAR L\'AUTEUR, '
                         'communs compris. Ne pas confondre avec --ajuster '
                         '(choix automatique parmi les couleurs rattachees) ni '
                         '--reserver (case d\'effet runtime, hors calcul). Ne le '
                         'commettre que sur decision auteur : la planche A du '
                         'compiler (29/08) pose ses six cases chaudes a la main '
                         'pour MAXIMISER LES RAMPES — deux rampes de 4 marches a '
                         'sommets partages (blanc et rouge nuit servent chacun '
                         'deux rampes).')
    ap.add_argument('--reserver', default=None,
                    help='R,G,B:MATERIEL — couleur posee a un index precis, hors '
                         'calcul. Plusieurs reservations separees par des '
                         'points-virgules (le dome du compiler en prend trois : '
                         'ombre, corps et halo oscillent chacun sur sa case).')
    ap.add_argument('-h', '--help', action='store_true')
    a = ap.parse_args()
    if a.help:
        print(__doc__)
        return 0
    forcer = {}
    for f in a.forcer:
        rgb, mat = f.rsplit(':', 1)
        cle = tuple(int(x) for x in rgb.split(','))
        if '~' in mat:
            va, vb = mat.split('~')
            forcer[cle] = (int(va), int(vb))
        else:
            forcer[cle] = int(mat)
    if a.ecrire_palette:
        if not a.stage:
            sys.exit('--ecrire-palette demande --stage NN (le gel olive en depend)')
        res = []
        if a.reserver:
            for spec in a.reserver.split(';'):
                v = [int(x) for x in spec.replace(':', ',').split(',')]
                res.append(tuple(v))
        pos = []
        if a.poser:
            for spec in a.poser.split(';'):
                v = [int(x) for x in spec.replace(':', ',').split(',')]
                pos.append(tuple(v))
        aj = [int(x) for x in a.ajuster.split(',') if x] if a.ajuster else []
        palette_dediee(a.objet, a.stage, a.ecrire_palette, a.garder_olive, res, aj,
                       pos)
        return convertir(a.objet, a.ecrire_palette, a.dry_run, a.out_suffixe,
                         forcer, a.dedup)
    return convertir(a.objet, a.palette, a.dry_run, a.out_suffixe, forcer,
                     a.dedup, a.marge_droite)




def recensement(objet):
    """Counter {rgb: nb_px} des pixels OPAQUES d'un objet, apres cadrage et
    reduction — exactement les pixels que la conversion produira.

    Sert a `arcade_to_in.py --plan sprites:<objet>` : faire peser les sprites
    d'un stage dans le choix de ses quatre cases propres. Le besoin est venu du
    brood, dont les SIX verts arcade tombaient tous sur l'unique vert du stage 2
    parce que ces cases avaient ete choisies sur la carte seule.

    Le comptage se fait sur les pixels REDUITS, pas sur le canevas arcade : un
    sprite de 64x64 ne pese pas 4096 px a l'ecran mais 24x48. Compter la source
    surestimerait les sprites d'un facteur 3,6 face a la carte.
    """
    base = objet if os.path.isdir(objet) else 'src/enemies/%s' % objet
    orig = os.path.join(base, 'images/original')
    jeux = {}
    for p in sorted(glob.glob(os.path.join(orig, '*/*.png'))):
        jeux.setdefault(os.path.dirname(p), []).append(p)
    for p in sorted(glob.glob(os.path.join(orig, '*.png'))):
        jeux.setdefault(orig, []).append(p)
    cnt = Counter()
    for chemins in jeux.values():
        u = cadre(chemins, Image.open(chemins[0]).size)
        if u is None:
            continue
        for p in chemins:
            im = Image.open(p)
            pal = im.getpalette()
            petit, _ = reduire(im, u)
            for i, n in enumerate(petit.histogram()):
                if n and i:
                    cnt[tuple(pal[i * 3:i * 3 + 3])] += n
    return cnt


def palette_dediee(objet, stage, sortie, garder_olive=False, reserver=None,
                   ajuster=(), poser=()):
    """Calculer et ecrire une palette dediee a UN objet, puis la rendre.

    Cas d'emploi (auteur, 17/08) : un boss de fin de stage combat dans une zone
    ou la TILEMAP N'EXISTE PLUS — mesure sur le stage 4, ses 144 derniers pixels
    (12 colonnes, presque un ecran) sont entierement noirs. Les quatre cases
    propres au stage n'y sont donc disputees par personne : elles peuvent servir
    le boss seul, chargees par un echange de palette a l'entree de l'arene.

Les QUATRE cases vont au boss par defaut (decision auteur) : les 12 index
    communs ne bougent pas, mais l'olive du stage n'est plus gelee ici. Le gain
    moyen est faible — dE 13,5 en gardant l'olive, 13,1 en la liberant — mais la
    moyenne ne dit pas ce qu'on regarde : la quatrieme case porte le DOME du
    compiler, son oeil, 396 px de vert que rien d'autre ne peut rendre. C'est la
    lecon du boss du stage 8, la meme a l'echelle d'un sprite.

    Ce que ca coute, et il faut le savoir : un sprite d'un LOT affiche pendant le
    combat perd son olive. Mesure sur la wave du stage 4 — le compiler apparait
    au dernier spawn ($14,$F8), et le dernier ennemi de lot avant lui est un
    cancer a $12,$34 : il peut encore etre a l'ecran. `garder_olive=True` rend
    l'ancien comportement si ca se voit.
    """
    cnt = recensement(objet)
    palette, free = A.palette_pal_next(stage)
    if not garder_olive and 15 not in free:
        free = sorted(free + [15])
    # `reserver` = liste de (r, g, b, index_materiel) : des couleurs POSEES a
    # des index precis, retirees du calcul. Sert quand un effet de palette du
    # runtime doit savoir OU taper — une oscillation de boss fait varier des
    # index connus d'avance et que personne d'autre ne partage. Le compiler en
    # prend TROIS (decision auteur, 29/08) : l'ombre, le corps et le halo de
    # son dome oscillent chacun sur sa case — la rampe 4 etapes est etablie
    # dans la simulation TO8 (voir le commit qui a introduit ce mode).
    for r, v, b, mat in (reserver or []):
        png = mat + 1
        if png not in free:
            sys.exit('reserver : le materiel %d n\'est pas attribuable ici' % mat)
        palette[png] = (r, v, b)
        free = [i for i in free if i != png]
        print('reserve : materiel %d = %02X%02X%02X (effet de palette du runtime)'
              % (mat, r, v, b))
    # `ajuster` : des index COMMUNS re-regles pour CE combat (auteur, 17/08 —
    # « en phase de boss on utilise une palette ajustee »). Chaque index garde
    # son ROLE : sa nouvelle valeur est choisie parmi les couleurs de l'objet
    # qui tombaient deja sur lui, celle qui minimise leur erreur ponderee. Un
    # sprite commun affiche pendant le combat voit donc un rouge un peu
    # different, jamais une autre teinte a la place du rouge.
    for mat in ajuster:
        png = mat + 1
        if not 1 <= png <= 12:
            sys.exit('ajuster : %d n\'est pas un index commun' % mat)
        rat = [c for c in cnt
               if min(range(1, 13), key=lambda j: A.dist_lab(c, palette[j])) == png]
        if not rat:
            print('ajuste : materiel %d — aucune couleur de l\'objet ne s\'y '
                  'rattache, valeur commune conservee' % mat)
            continue
        avant = palette[png]
        palette[png] = min(rat, key=lambda cand:
                           sum(cnt[c] * A.dist_lab(c, cand) for c in rat))
        print('ajuste : materiel %d  %02X%02X%02X -> %02X%02X%02X '
              '(%d px de l\'objet s\'y rattachent)'
              % (mat, *avant, *palette[png], sum(cnt[c] for c in rat)))
    # `poser` = valeurs d'AUTEUR, communs compris — voir l'aide de --poser.
    # Une case propre posee sort du calcul d'attribution, comme une reservee.
    for r, v, b, mat in (poser or ()):
        png = mat + 1
        palette[png] = (r, v, b)
        if png in free:
            free = [i for i in free if i != png]
        print('pose : materiel %d = %02X%02X%02X (decision auteur)' % (mat, r, v, b))
    palette[0] = MARQUEUR_TRANSP
    _, chosen = A.assign(cnt, palette, free, A.dist_lab, 0.001)
    os.makedirs(os.path.dirname(sortie), exist_ok=True)
    im = Image.new('P', (1, 1))
    im.putpalette([v for i in range(256)
                   for v in (palette[i] if i < 17 else (0, 0, 0))])
    im.save(sortie)
    print('palette dediee a %s : %s' % (objet, sortie))
    print('  cases propres : %s'
          % ' '.join('PNG %d = %02X%02X%02X' % (s, *chosen[s]) for s in sorted(chosen)))
    return palette, free


if __name__ == '__main__':
    sys.exit(main())
