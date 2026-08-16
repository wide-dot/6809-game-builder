#!/usr/bin/env python3
"""Migrer les images d'UNE ressource vers la nouvelle palette, sous validation.

Le protocole (docs/lang/fr/analyse-palette-migration-2026-08.md, §7) veut un
mapping PAR OBJET, une planche de prévisualisation, et la validation de
l'auteur avant que rien ne soit gravé. Cet outil sert ces trois temps :

    tools/palette_migrate.py --liste                        ce qu'il reste a faire
    tools/palette_migrate.py RES [RES…] --apercu out.png    la planche, rien d'ecrit
    tools/palette_migrate.py RES [RES…] --ecrire            applique, apres accord

Plusieurs ressources en une commande donnent **une seule planche**, une section
par ressource : un tour de validation = un fichier a regarder.

Outil SÉPARÉ de `palette_usage.py` — à dessein. Celui-là relève et ne touche à
rien ; celui-ci réécrit des assets. Les mêler, c'est risquer qu'une faute de
frappe sur une option d'analyse repeigne cent quatre-vingts fichiers. Les
primitives communes (expansion des <images>, lecture de palette, comptage par
index) sont importées de l'outil de relevé : une seule source de vérité pour
« quelles images appartiennent à quelle ressource ».

Deux choses que la migration doit faire, et pas une seule :

  * **renuméroter les pixels** selon la table de `palette-map.txt` ;
  * **réinstaller la table de couleurs** du PNG. Les png de sprites en portent
    une aujourd'hui, mais elle ne fait PAS foi — les couleurs réelles viennent
    de `png2pal` sur `pal.png`, et celles des sprites ont d'ailleurs dérivé
    (`CCB` au lieu de `CCA`, une entrée 16 en vrac qui vaut `F0F` ou `677`
    selon les fichiers). Écrire la nouvelle table remet tout le monde d'accord
    et rend le fichier lisible dans un éditeur.

Garde-fous, parce qu'un remap silencieux est pire qu'une erreur :

  * un index présent dans une image mais absent de la table **arrête tout**,
    avec la liste des coupables — jamais d'identité par défaut ;
  * **deux index employés qui tomberaient sur le même** arrêtent tout aussi :
    c'est un niveau de dégradé qui disparaît du sprite, et la priorité est de
    les conserver (décision auteur du 16/08). L'outil nomme les coupables et
    liste les emplacements encore libres dans la nouvelle palette pour qu'on
    puisse re-répartir. Une fusion réellement voulue se déclare, sur la ligne
    de la ressource, par le mot `fusion-ok` — jamais par omission ;
  * après écriture, chaque fichier est relu : la table doit être la nouvelle,
    et les index doivent être exactement ceux que la correspondance prévoyait ;
  * `--ecrire` refuse si la ressource a déjà été migrée (idempotence : on ne
    remappe pas deux fois, ça décalerait tout une seconde fois).

Toute conversion validée s'inscrit dans `tools/palette-replay.sh`, qui rejoue
la campagne entière depuis `origin/master`. Cet outil-ci n'a donc pas d'état :
la table est le paramètre, le script est la commande, les deux sont versionnés.
"""
import argparse
import importlib.util
import os
import sys
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
PROJET = os.path.dirname(ICI)
PAL_ANCIENNE = 'src/stages/01/palette/pal.png'
PAL_NOUVELLE = 'src/stages/01/palette/pal-next.png'
TRANSPARENT = 0
# Le TO8 affiche 160x200 : le pixel est DEUX FOIS PLUS LARGE QUE HAUT. Une
# planche en pixels carres ment sur les proportions et surtout sur les trames,
# qu'elle montre en grain neutre la ou l'ecran donnera des rayures diagonales.
RATIO = 2

# Les index MATERIELS 12 a 15 sont propres au stage : un commun n'a pas le
# droit de s'en servir, et un lot ne peut employer que celui que sa table lui
# accorde. La table de couleurs ecrite dans le PNG peint les autres en MAGENTA
# (decision auteur, 16/08) — un pixel egare y devient criard dans n'importe
# quel editeur, au lieu de passer pour une couleur plausible.
# Seule exception connue : le vert du scant, grave dans la palette
# stage-specifique des stages 1 et 7 (les deux seuls qui chargent ce lot).
STAGE_SPECIFIQUES = (12, 13, 14, 15)
MAGENTA = (255, 0, 255)


def _releve():
    """Les primitives de l'outil de relevé — une seule définition de « quelles
    images appartiennent à quelle ressource »."""
    spec = importlib.util.spec_from_file_location(
        'palette_usage', os.path.join(ICI, 'palette_usage.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def ressources(pu, base):
    """{nom: [png…]} pour les communs et les lots du cast du stage 1 — le
    périmètre de la campagne, tel que le config le décrit."""
    root = ET.parse(os.path.join(base, 'to8.config.xml')).getroot()
    images = {}
    for f in root.iter('file'):
        nom = f.get('name')
        if not nom:
            continue
        png = [p for g in f.iter('gfxcomp') for p in pu.expanse(g, base)]
        if png:
            images[nom] = list(dict.fromkeys(png))   # une ligne miroir redéclare
    # Les CARTES de niveau (groupe F). Elles n'entrent pas par un <gfxcomp> :
    # `<leanscroll image=...>` est leur source, le build en derive les tuiles et
    # la carte, et le <gfxcomp> qui suit consomme du genere. La ressource est
    # donc l'image du niveau elle-meme, une par stage.
    for ls in root.iter('leanscroll'):
        img = ls.get('image')          # src/stages/NN/map/in.png
        if img:
            stage = int(img.split('/')[2])
            images['stage%d.map' % stage] = [os.path.join(base, img)]
    scenes = {s.get('name'): [l.get('name') for l in s.iter('load')]
              for s in root.iter('scene')}
    dedans = [n for n in scenes.get('scenes.boot', [])
              if not n.startswith('title.') and n in images]
    for lot in sorted(pu.lots_du_stage('stage1', base) or ()):
        for u in scenes.get(f'scenes.lot.{lot}', []):
            if u in images and u not in dedans:
                dedans.append(u)
    # les cartes s'ajoutent au perimetre commun : ce sont du contenu de STAGE,
    # elles ne passent pas par scenes.boot.
    dedans += [n for n in images if n.endswith('.map')]
    return {n: images[n] for n in dedans}


def _lignes(chemins):
    for chemin in chemins:
        for ligne in open(chemin, encoding='utf-8'):
            yield ligne


def table(chemins, ressource):
    """La correspondance applicable à CETTE ressource : le défaut, puis ce que
    sa ligne ajoute ou remplace. Rend (correspondance, fusion autorisée).

    `chemins` est une PILE : la table de base, puis d'éventuelles surcouches
    (`--variante`) lues par-dessus. C'est ce qui permet de comparer plusieurs
    candidats sans dupliquer la table de base — donc sans qu'elle dérive."""
    corr, fusion_ok = {}, False
    for ligne in _lignes(chemins):
        ligne = ligne.split('#')[0].strip()
        if not ligne:
            continue
        mots = ligne.split()
        cle, jetons = mots[0], mots[1:]
        # `*` = « la ressource en cours de traitement ». Sert aux SURCOUCHES de
        # comparaison : un candidat exprime une recette (quel neutre fusionne)
        # sans prejuger a quelle ressource elle convient. Une recette retenue
        # s'ecrit ensuite sous le NOM de la ressource — jamais en `defaut` :
        # ce qui va au vaisseau ne va pas forcement au pow (auteur, 16/08).
        if cle not in ('defaut', '*', ressource):
            continue
        for c in jetons:
            if c == 'fusion-ok':
                fusion_ok = cle != 'defaut'    # jamais autorisable en masse
                continue
            if c.startswith('marqueur='):
                continue                       # lu par marqueurs(), pas ici
            a, _, b = c.partition('>')
            # `b~c` = TRAME : l'ancien index ne devient pas une couleur mais un
            # damier de deux, une case sur deux. C'est le moyen de fabriquer un
            # barreau intermediaire quand la palette n'en a plus de libre.
            corr[int(a)] = (tuple(int(x) for x in b.split('~'))
                            if '~' in b else int(b))
    return corr, fusion_ok


def cible(v):
    """Les nouveaux index qu'une cible occupe — un seul, ou les deux d'une trame."""
    return v if isinstance(v, tuple) else (v,)


def _dit(v, x, y):
    """L'index effectif d'un pixel : la trame alterne sur (x+y), donc le motif
    est porte par l'IMAGE et suit le sprite quand il bouge."""
    return v[(x + y) & 1] if isinstance(v, tuple) else v


def luminance(rvb):
    r, v, b = rvb
    return 0.299 * r + 0.587 * v + 0.114 * b


def couleurs_changees(corr, employes, rvb_a, rvb_b):
    """[(ancien, nouveau)] pour les seuls index dont la COULEUR bouge. Le reste
    de la migration est une renumerotation pure : les pixels rendus sont les
    mêmes, au bit près. Distinction posée par l'auteur le 16/08 — une planche
    ne se justifie que là où l'œil a quelque chose à voir."""
    return [(a, corr[a]) for a in sorted(employes)
            if isinstance(corr[a], tuple)
            or rvb_a[a + 1] != rvb_b[corr[a] + 1]]


def fusions(corr, employes):
    """{nouvel index: [anciens index employés qui y tombent]} pour les seules
    collisions. Un dégradé de N valeurs qui en rend N-1 se voit ici."""
    vers = {}
    for a in sorted(employes):
        vers.setdefault(corr[a], []).append(a)   # cle = int OU couple trame
    return {b: anc for b, anc in vers.items() if len(anc) > 1}


def dire_fusions(nom, coll, employes, corr, pal_a, pal_b):
    """Nommer ce qui se perd, et montrer où le remettre."""
    h = lambda t: '#%02X%02X%02X' % t
    dis = lambda b: ('trame ' + '~'.join(h(pal_b[i + 1]) for i in b)
                     if isinstance(b, tuple) else h(pal_b[b + 1]))
    print(f"{nom} : ARRET — {len(coll)} niveau(x) de degrade disparaitrait(ent).")
    for b, anc in sorted(coll.items(), key=lambda kv: str(kv[0])):
        quoi = ', '.join(f"{a} {h(pal_a[a + 1])} (lum {luminance(pal_a[a + 1]):.0f})"
                         for a in anc)
        print(f"  anciens {quoi}")
        print(f"      tombent tous sur {dis(b)}")
    pris = {i for a in employes for i in cible(corr[a])}
    libres = [i for i in range(16) if i not in pris]
    print("  emplacements encore libres dans la nouvelle palette, par luminance :")
    for i in sorted(libres, key=lambda i: luminance(pal_b[i + 1])):
        print(f"      {i:2d} {h(pal_b[i + 1])}  lum {luminance(pal_b[i + 1]):5.0f}")
    print("  Re-repartir dans palette-map.txt, ou declarer `fusion-ok` si la")
    print("  perte est voulue et mesuree.")


def palette_brute(chemin):
    """Les 17 entrées RVB 8 bits d'un PNG de palette, telles quelles."""
    b = Image.open(chemin).getpalette()
    return b[:17 * 3]


def palette_ecrite(pal_b, cibles):
    """La table de couleurs a graver dans les PNG d'UNE ressource : la nouvelle
    palette, sauf les emplacements propres au stage qu'elle n'emploie pas —
    ceux-la passent en magenta."""
    out = list(pal_b)
    for i in STAGE_SPECIFIQUES:
        if i not in cibles:
            out[(i + 1) * 3:(i + 1) * 3 + 3] = list(MAGENTA)
    return out


def index_migres(chemin, pal_b):
    """Les index de CE fichier sont-ils deja ceux de la nouvelle palette ?
    On compare les treize premieres entrees — transparence plus les douze
    couleurs communes. Les quatre suivantes ne comptent pas : elles dependent
    de la ressource (magenta ou non), et la question posee ici est « faut-il
    encore renumeroter », pas « la table est-elle a jour »."""
    return palette_brute(chemin)[:13 * 3] == pal_b[:13 * 3]


def marqueurs(chemins, ressource):
    """Les anciens index qu'UNE ressource declare comme MARQUEURS.

    Un marqueur est un index dont la couleur, dans le fichier source, n'est pas
    celle de la palette de jeu : il sert a le reperer a l'oeil dans un editeur.
    Le cas fondateur est le ciel des cartes de niveau — `in.png` le peint en
    magenta #FF00FF la ou la palette machine rend du noir, pour qu'il saute aux
    yeux. Un marqueur n'a donc pas de couleur a preserver, et le controle de
    palette source doit le laisser passer. Il se declare, jamais il ne se
    devine : `marqueur=15` sur la ligne de la ressource.
    """
    out = set()
    for ligne in _lignes(chemins):
        mots = ligne.split('#')[0].split()
        if mots and mots[0] == ressource:
            out |= {int(m.split('=')[1]) for m in mots[1:]
                    if m.startswith('marqueur=')}
    return out


def desaccords(png, rvb_a, marques=()):
    """Les index EMPLOYES dont la couleur, dans ce fichier, n'est pas celle de
    l'ancienne palette de reference.

    La table de correspondance parle d'index ANCIENS ; l'appliquer a un fichier
    dont l'index 4 ne porte pas la meme couleur, c'est renumeroter contre la
    mauvaise table — et en silence, puisque rien d'autre ne le remarquerait.
    C'est le cas des cartes des stages 2-8 : elles reaffectent quelques
    emplacements a des teintes propres a leur niveau."""
    im = Image.open(png)
    if im.mode != 'P':
        return []
    pal = palette_brute(png)
    vus = {v for _, v in (im.getcolors(1 << 20) or [])}
    return sorted(v - 1 for v in vus if v != TRANSPARENT
                  and (v - 1) not in marques
                  and tuple(pal[v * 3:v * 3 + 3]) != rvb_a[v])


def migrer(png, corr, pal_neuve):
    """Rend (image migrée, index rencontrés, index sans correspondance)."""
    im = Image.open(png)
    if im.mode != 'P':
        raise ValueError(f"{png} : attendu un PNG indexe, trouve {im.mode}")
    w, h = im.size
    src = im.load()
    vus = {v for _, v in (im.getcolors(1 << 20) or [])}
    orphelins = sorted(v - 1 for v in vus
                       if v != TRANSPARENT and (v - 1) not in corr)
    if orphelins:
        return None, vus, orphelins
    out = Image.new('P', (w, h))
    out.putpalette(pal_neuve)
    dst = out.load()
    for y in range(h):
        for x in range(w):
            v = src[x, y]
            dst[x, y] = (TRANSPARENT if v == TRANSPARENT
                         else _dit(corr[v - 1], x, y) + 1)
    return out, vus, []


def _rendu_brut(source, pal):
    """Les octets RVB d'une image indexée, transparence comprise. Deux images
    qui rendent la même chose donnent la même chaîne — c'est la preuve qu'une
    renumérotation n'a rien changé pour l'œil."""
    im = source if isinstance(source, Image.Image) else Image.open(source)
    src = im.load()
    w, h = im.size
    return bytes(b for y in range(h) for x in range(w)
                 for b in ((255, 0, 255) if src[x, y] == TRANSPARENT
                           else pal[src[x, y]]))


def rendu(png, pal, Z, fond, ratio=RATIO):
    """Un aperçu couleur d'un PNG indexé, avec la palette donnée."""
    im = Image.open(png)
    w, h = im.size
    src = im.load()
    out = Image.new('RGB', (w, h), fond)
    dst = out.load()
    for y in range(h):
        for x in range(w):
            v = src[x, y]
            dst[x, y] = fond if v == TRANSPARENT else pal[v]
    return out.resize((w * Z * ratio, h * Z), Image.NEAREST)


def _police(t, gras=False):
    c = ('/usr/share/fonts/truetype/dejavu/DejaVuSansMono'
         + ('-Bold' if gras else '') + '.ttf')
    try:
        return ImageFont.truetype(c, t)
    except OSError:
        return ImageFont.load_default()


FOND, LARGEUR_DEFAUT = (18, 20, 24), 1360


def _geometrie(paires, nb_col, Zmax, largeur_max):
    """Géométrie d'un bloc : chaque ressource a sa propre échelle — un sprite
    de 12 px ne mérite pas la cellule d'un sprite de 48 — et le nombre de
    vignettes par ligne se déduit de la largeur disponible.

    Le zoom est RABATTU pour que la cellule tienne dans la page : sans ça, une
    bannière de 320 px de large au zoom 10 étale la planche sur six mille
    pixels et réduit les sprites voisins à des timbres."""
    mw = max(Image.open(p).size[0] for p, _ in paires)
    mh = max(Image.open(p).size[1] for p, _ in paires)
    Z = max(1, min(Zmax, (largeur_max - 54 - 14 * (nb_col - 1))
                   // (mw * RATIO * nb_col)))
    cw = mw * Z * RATIO * nb_col + 14 * (nb_col - 1) + 30
    par_ligne = max(1, min(len(paires), (largeur_max - 24) // cw))
    return (cw, mh * Z + 50, (len(paires) + par_ligne - 1) // par_ligne,
            mw, mh, par_ligne, Z)


def planche(sortie, blocs, colonnes, Z=6, largeur_max=LARGEUR_DEFAUT):
    """La planche de validation : chaque image telle quelle à gauche, puis une
    vignette par candidat. C'est ce que l'auteur regarde, et rien d'autre ne
    l'engage. Chaque vignette porte SA table de couleurs — une image déjà
    migrée par une autre ressource n'a plus d'original dans l'arbre, sa
    colonne « actuel » doit donc se rendre avec la nouvelle palette."""
    f, fp, fb, ft = _police(11), _police(10), _police(15, True), _police(13, True)
    nb = len(colonnes)
    geo = [_geometrie(p, nb, Z, largeur_max) for _, _, p in blocs]
    largeur = max([640] + [cw * pl for (cw, _, _, _, _, pl, _) in geo]) + 24
    hauteur = 62 + sum(34 + ch * li for (_, ch, li, _, _, _, _) in geo)
    im = Image.new('RGB', (largeur, hauteur), FOND)
    d = ImageDraw.Draw(im)
    d.text((14, 12), "migration de palette — planche de validation", font=fb,
           fill=(228, 232, 240))
    lettres = ['ref'] + [chr(ord('A') + i) for i in range(len(colonnes) - 1)]
    d.text((14, 36), "colonnes : " + "   ".join(
        f"{l} = {n}" for l, n in zip(lettres, colonnes)),
        font=f, fill=(150, 158, 172))
    y0 = 62
    for (nom, soustitre, paires), (cw, ch, li, mw, mh, par_ligne, Z) in zip(blocs, geo):
        d.text((14, y0 + 6), nom, font=ft, fill=(228, 232, 240))
        d.text((14 + len(nom) * 8 + 18, y0 + 8), soustitre, font=f,
               fill=(150, 158, 172))
        y0 += 34
        for k, (src, versions) in enumerate(paires):
            x, y = 12 + (k % par_ligne) * cw, y0 + (k // par_ligne) * ch
            for j, (etiquette, chemin, pal) in enumerate(versions):
                vue = rendu(chemin, pal, Z, FOND)
                # pas de colonne fixe (mw), pas la largeur de CETTE vignette :
                # sinon les colonnes se decalent d'une image a l'autre
                xj = x + j * (mw * Z * RATIO + 14)
                im.paste(vue, (xj, y + mh * Z - vue.size[1]))
                # une LETTRE, pas le nom du candidat : un nom de fichier de
                # surcouche est plus large qu'une vignette et les etiquettes
                # se chevauchaient d'une colonne a l'autre
                d.text((xj, y + mh * Z + 6), lettres[j], font=fp,
                       fill=(120, 128, 142))
            d.text((x, y + mh * Z + 22),
                   '/'.join(os.path.relpath(src, PROJET).split('/')[-2:]),
                   font=f, fill=(200, 206, 216))
        y0 += ch * li
    im.save(sortie)


def preparer(nom, images, corr, fusion_ok, pal_b, rvb_a, rvb_b, base, pris,
             pal_res, tables_map=()):
    """La passe à blanc d'UNE ressource. Rend (résultats, héritées, code) ; un
    code non nul veut dire qu'il ne faut rien écrire, ni pour elle ni pour les
    autres — un tour de validation se valide en entier."""
    # Une image peut appartenir a DEUX ressources — les impacts de `weapon`
    # sont aussi ceux de `simplefire`. La regle du plan est qu'elle se decide
    # une fois : la seconde ressource en HERITE, on ne la remappe pas (ce qui
    # decalerait ses index une seconde fois). Reste a le dire, pas a le subir.
    # `pris` porte les images qu'une ressource CITEE PLUS TOT dans la meme
    # commande revendique deja : sans ca, deux ressources partageant une image
    # la prepareraient chacune depuis l'original et la derniere ecriture
    # gagnerait en silence. La premiere nommee decide, les autres heritent.
    deja = [p for p in images if index_migres(p, pal_b) or p in pris]
    reste = [p for p in images if p not in deja]
    # une image deja renumerotee peut porter une table PERIMEE (la regle du
    # magenta est arrivee apres). Ce n'est pas une migration, c'est une
    # reecriture de table : les index n'y sont pas touches.
    tables = [p for p in deja if p not in pris
              and palette_brute(p) != pal_res]
    if not reste:
        if tables:
            print(f"{nom} : index deja migres, {len(tables)} table(s) de "
                  "couleurs a rafraichir.")
            return [], deja, set(), 0, tables
        print(f"{nom} : rien a faire, tout est deja migre.")
        return [], deja, set(), 0, []
    if deja:
        print(f"{nom} : {len(deja)} image(s) deja migree(s), heritee(s) d'une "
              "autre ressource — laissee(s) telle(s) quelle(s) :")
        for p in deja:
            print(f"    {os.path.relpath(p, base)}")

    # Controle de palette source, reserve aux CARTES DE NIVEAU. Mesure faite
    # (16/08) : 1195 fichiers du corpus ne portent pas pal.png — masques de
    # terrain a deux couleurs, sprites enregistres avec la palette du moment.
    # La campagne travaille donc par INDEX, et c'est valide : les planches sont
    # rendues contre la palette cible, pas contre celle du fichier.
    # Les cartes sont l'exception qui compte : elles REAFFECTENT des
    # emplacements a des teintes propres au niveau (mesure : stage 2 sur 4 et
    # 15, stage 3 sur 4, 6, 14 et 15…). Appliquer la table du stage 1 a l'une
    # d'elles renumeroterait contre la mauvaise table, en silence. D'ou ce
    # controle ici et nulle part ailleurs.
    marques = marqueurs(tables_map, nom)
    ecarts = ([(p, d) for p in reste
               for d in [desaccords(p, rvb_a, marques)] if d]
              if nom.endswith('.map') else [])
    if ecarts:
        print(f"{nom} : ARRET — la palette source n'est pas l'ancienne de"
              " reference sur des index employes.")
        for p, d in ecarts:
            print(f"  {os.path.relpath(p, base)} : index {d}")
        print("La table parle d'index ANCIENS : l'appliquer ici renumeroterait")
        print("contre la mauvaise table. Declarer l'ancienne palette de CE")
        print("fichier avant de le migrer.")
        return [], deja, set(), 1, tables

    resultats, refus, employes = [], [], set()
    for p in reste:
        img, vus, orphelins = migrer(p, corr, pal_res)
        if orphelins:
            refus.append((p, orphelins))
        else:
            resultats.append((p, img, vus))
            employes |= {v - 1 for v in vus if v != TRANSPARENT}
    if refus:
        print(f"{nom} : ARRET — des index n'ont pas de correspondance.")
        for p, o in refus:
            print(f"  {os.path.relpath(p, base)} : index {o}")
        print("Trancher leur sort dans palette-map.txt — une identite"
              " silencieuse serait pire.")
        return [], deja, employes, 1, tables

    # Priorite auteur (16/08) : conserver les niveaux de degrade. Deux index
    # employes qui tombent sur le meme, c'est une marche de rampe perdue.
    coll = fusions(corr, employes)
    if coll and not fusion_ok:
        dire_fusions(nom, coll, employes, corr, rvb_a, rvb_b)
        return [], deja, employes, 1, tables
    if coll:
        print(f"{nom} : fusion DECLAREE (fusion-ok) — "
              + ' ; '.join(f"anciens {anc} -> {b}" for b, anc in sorted(coll.items())))

    chg = couleurs_changees(corr, employes, rvb_a, rvb_b)
    h = lambda t: '#%02X%02X%02X' % t
    if chg:
        dis = lambda b: ('trame ' + '~'.join(h(rvb_b[i + 1]) for i in b)
                         if isinstance(b, tuple) else h(rvb_b[b + 1]))
        print(f"{nom} : {len(resultats)} images, {len(chg)} couleur(s) changent — "
              "une planche est utile : "
              + ', '.join(f"{a} {h(rvb_a[a + 1])}>{dis(b)}" for a, b in chg))
    else:
        # renumerotation pure : plutot que de demander a l'oeil de confirmer
        # que rien n'a bouge, on le PROUVE — pixel par pixel, rendu contre rendu.
        for p, img, _ in resultats:
            if _rendu_brut(p, rvb_a) != _rendu_brut(img, rvb_b):
                print(f"{nom} : ARRET — {os.path.relpath(p, base)} devait rendre "
                      "exactement les memes couleurs et n'y arrive pas.")
                return [], deja, employes, 1, tables
        print(f"{nom} : {len(resultats)} images, renumerotation PURE — rendu "
              "prouve identique pixel par pixel, pas de planche a faire.")
    return resultats, deja, employes, 0, tables


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ressource', nargs='*')
    ap.add_argument('--liste', action='store_true')
    ap.add_argument('--apercu', metavar='SORTIE.PNG')
    ap.add_argument('--ecrire', action='store_true')
    ap.add_argument('--map', default=os.path.join(ICI, 'palette-map.txt'))
    ap.add_argument('--impactees', action='store_true',
                    help='ne garder sur la planche que les images dont le RENDU '
                         'change. Le reste est une renumerotation pure : '
                         'montrer deux fois la meme chose noie la decision.')
    ap.add_argument('--largeur', type=int, default=LARGEUR_DEFAUT,
                    help='largeur maximale de la planche en pixels (defaut '
                         f'{LARGEUR_DEFAUT}). A elargir quand on compare '
                         'beaucoup de candidats : le zoom est rabattu pour '
                         'tenir dedans, et six colonnes etroites ne montrent '
                         'plus rien d\'une trame.')
    ap.add_argument('--zoom', type=int, default=6,
                    help='pixels par pixel sur la planche (defaut 6).')
    ap.add_argument('--sans-base', action='store_true',
                    help='ne pas montrer la colonne de la table de base. Utile '
                         'quand la decision en cours est justement ce qui lui '
                         'manque : la base ARRETE, et c\'est normal.')
    ap.add_argument('--variante', action='append', metavar='SURCOUCHE.TXT',
                    help='une colonne de plus sur la planche : une table lue '
                         'PAR-DESSUS la table de base. Repetable. Sert a '
                         'comparer des candidats a l\'oeil, pas a ecrire.')
    args = ap.parse_args()

    base = PROJET
    pu = _releve()
    res = ressources(pu, base)
    pal_a = palette_brute(os.path.join(base, PAL_ANCIENNE))
    pal_b = palette_brute(os.path.join(base, PAL_NOUVELLE))
    rgb = lambda p: [tuple(p[i * 3:i * 3 + 3]) for i in range(17)]
    rvb_a, rvb_b = rgb(pal_a), rgb(pal_b)

    if args.liste or not args.ressource:
        # la colonne qui compte n'est pas « combien d'images » mais « est-ce que
        # l'oeil a quelque chose a voir » : une renumerotation pure se prouve,
        # elle ne se regarde pas.
        h = lambda t: '#%02X%02X%02X' % t
        print(f"{len(res)} ressources dans le perimetre :")
        for n in sorted(res):
            if all(index_migres(p, pal_b) for p in res[n]):
                print(f"  [x] {n:26} {len(res[n]):3} img")
                continue
            corr, _ = table([args.map], n)
            employes = set()
            for p in res[n]:
                employes |= {v - 1 for _, v in (Image.open(p).getcolors(1 << 20)
                                                or []) if v != TRANSPARENT}
            sans = sorted(a for a in employes if a not in corr)
            chg = couleurs_changees(corr, employes - set(sans), rvb_a, rvb_b)
            dis = lambda b: ('trame ' + '~'.join(h(rvb_b[i + 1]) for i in b)
                             if isinstance(b, tuple) else h(rvb_b[b + 1]))
            quoi = ', '.join([f"{a} {h(rvb_a[a + 1])} A TRANCHER" for a in sans]
                             + [f"{a} {h(rvb_a[a + 1])}>{dis(b)}" for a, b in chg])
            print(f"  [ ] {n:26} {len(res[n]):3} img   "
                  + (quoi if quoi else "renumerotation pure, pas de planche"))
        return 0

    inconnues = [n for n in args.ressource if n not in res]
    if inconnues:
        sys.exit(f"ressource(s) inconnue(s) : {', '.join(inconnues)} (voir --liste)")
    if args.ecrire and args.variante:
        sys.exit("--variante ne sert qu'a REGARDER. Le candidat retenu se"
                 " recopie dans palette-map.txt, puis s'ecrit sans surcouche :"
                 " c'est la table de base qui fait foi pour le rejeu.")

    # Une colonne de planche par candidat : la table de base, puis chaque
    # surcouche lue par-dessus. La colonne 0 est toujours l'image actuelle.
    candidats = []
    if not (args.sans_base and args.variante):
        candidats.append(('migre' if not args.variante else 'table de base',
                          [args.map]))
    for v in (args.variante or []):
        candidats.append((os.path.basename(v).rsplit('.', 1)[0], [args.map, v]))

    # --- passe a blanc SUR TOUT LE TOUR : rien n'est ecrit tant qu'une seule
    # ressource bloque. Un lot de validation se prend ou se laisse en entier.
    tour, code = [], 0
    for etiquette, pile in candidats:
        pris = set()          # le partage d'images se rejoue dans CHAQUE colonne
        for nom in args.ressource:
            corr, fusion_ok = table(pile, nom)
            if not corr:
                sys.exit(f"aucune correspondance pour {nom} dans {pile}")
            # ce que CETTE ressource a le droit d'occuper dans les quatre
            # emplacements propres au stage : ce que sa table y envoie, rien de plus
            pal_res = palette_ecrite(pal_b, {i for v in corr.values()
                                             for i in cible(v)})
            if args.variante:
                print(f"[{etiquette}]", end=' ')
            resultats, deja, employes, c, tables = preparer(
                nom, res[nom], corr, fusion_ok, pal_b, rvb_a, rvb_b, base, pris,
                pal_res, pile)
            code |= c
            pris |= {p for p, _, _ in resultats}
            tour.append((etiquette, nom, corr, resultats, deja, employes,
                         pal_res, tables))
    if code:
        return 1

    if args.apercu:
        tmp = os.path.join('/tmp', f'.mig-{os.getpid()}')
        blocs, resumes = [], {}
        for nom in args.ressource:
            paires, ordre = {}, []
            for etiquette, n, corr, resultats, deja, employes, _, _ in tour:
                if n != nom:
                    continue
                # un sous-dossier PAR CANDIDAT ET PAR RESSOURCE : deux
                # ressources ont les memes noms de fichiers (00.png, 01.png…)
                # et s'ecraseraient l'une l'autre
                coin = os.path.join(tmp, etiquette, nom)
                os.makedirs(coin, exist_ok=True)
                for k, (p, img, _) in enumerate(resultats):
                    # index en tete : UNE ressource peut porter deux series aux
                    # memes noms (player/images/rship/00.png et une autre 00.png)
                    # et l'une ecraserait l'autre dans le dossier temporaire —
                    # la planche montrerait alors une image en reference et une
                    # AUTRE dans les colonnes de candidats.
                    t = os.path.join(coin, f'{k:02d}-{os.path.basename(p)}')
                    img.save(t)
                    paires.setdefault(p, []).append((etiquette, t, rvb_b))
                    if p not in ordre:
                        ordre.append(p)
                # les heritees figurent aussi : la planche montre la ressource
                # ENTIERE telle qu'elle sera, pas seulement ce qui reste a faire
                for p in deja:
                    paires.setdefault(p, []).append((etiquette, p, rvb_b))
                    if p not in ordre:
                        ordre.append(p)
                resumes.setdefault(nom, _resume(corr, employes))
            if args.impactees:
                # une image ne merite sa place que si l'oeil y voit quelque
                # chose : on compare le rendu, pas les index — c'est le seul
                # critere honnete quand plusieurs candidats sont en lice.
                garde = []
                for p in ordre:
                    ref = _rendu_brut(p, rvb_b if index_migres(p, pal_b)
                                      else rvb_a)
                    if any(_rendu_brut(c, rvb_b) != ref for _, c, _ in paires[p]):
                        garde.append(p)
                if len(garde) < len(ordre):
                    print(f"{nom} : {len(ordre) - len(garde)} image(s) au rendu "
                          f"inchange retiree(s) de la planche, {len(garde)} gardee(s)")
                ordre = garde
            if ordre:
                # une image heritee n'a plus d'original : sa colonne « actuel »
                # se rend avec la NOUVELLE palette, sinon on montrerait un
                # charabia et on croirait a un defaut de conversion
                blocs.append((nom, resumes[nom], [
                    (p, [('actuel', p,
                          rvb_b if index_migres(p, pal_b) else rvb_a)]
                     + paires[p]) for p in ordre]))
        if not blocs:
            print("rien a montrer : tout est deja migre.")
            return 0
        planche(args.apercu, blocs, ['actuel'] + [e for e, _ in candidats],
                Z=args.zoom, largeur_max=args.largeur)
        print(f"planche ecrite : {args.apercu}  (rien n'a ete modifie)")

    if args.ecrire:
        tour = [t[1:] for t in tour]        # une seule colonne quand on ecrit
        ecrites, rafraichies, mauvais = 0, 0, []
        for nom, corr, resultats, _, _, pal_res, tables in tour:
            for p, img, _ in resultats:
                img.save(p)
            for p in tables:                 # table perimee : les index restent
                im = Image.open(p)
                im.putpalette(pal_res)
                im.save(p)
                if palette_brute(p) != pal_res:
                    mauvais.append((p, 'table de couleurs non rafraichie'))
                rafraichies += 1
            # --- relecture : ce qui est sur le disque est-il ce qu'on voulait ?
            for (p, img, vus) in resultats:
                relu = Image.open(p)
                if palette_brute(p) != pal_res:
                    mauvais.append((p, 'table de couleurs non installee'))
                    continue
                attendu = {i + 1 for v in vus if v != TRANSPARENT
                           for i in cible(corr[v - 1])}
                attendu |= ({TRANSPARENT} if TRANSPARENT in vus else set())
                obtenu = {v for _, v in (relu.getcolors(1 << 20) or [])}
                if obtenu != attendu:
                    mauvais.append(
                        (p, f'index {sorted(obtenu)} au lieu de {sorted(attendu)}'))
            ecrites += len(resultats)
        if mauvais:
            print("ECRITURE VERIFIEE : DES ECARTS")
            for p, m in mauvais:
                print(f"  {os.path.relpath(p, base)} : {m}")
            return 1
        quoi = f"{ecrites} images reecrites"
        if rafraichies:
            quoi += f", {rafraichies} tables rafraichies"
        print(f"{quoi} et relues : conformes.")
    return 0


def _resume(corr, employes):
    """Le sous-titre d'une section : ce que la table fait bouger POUR CETTE
    ressource — pas la table entière, seulement les index qu'elle emploie."""
    bouge = [f"{a}>" + ('~'.join(str(i) for i in corr[a])
                        if isinstance(corr[a], tuple) else str(corr[a]))
             for a in sorted(employes) if corr[a] != a]
    return ' '.join(bouge) if bouge else 'renumerotation nulle'


if __name__ == '__main__':
    sys.exit(main())
