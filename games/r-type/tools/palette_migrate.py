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
    scenes = {s.get('name'): [l.get('name') for l in s.iter('load')]
              for s in root.iter('scene')}
    dedans = [n for n in scenes.get('scenes.boot', [])
              if not n.startswith('title.') and n in images]
    for lot in sorted(pu.lots_du_stage('stage1', base) or ()):
        for u in scenes.get(f'scenes.lot.{lot}', []):
            if u in images and u not in dedans:
                dedans.append(u)
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
        if cle not in ('defaut', ressource):
            continue
        for c in jetons:
            if c == 'fusion-ok':
                fusion_ok = cle == ressource   # jamais autorisable en masse
                continue
            a, _, b = c.partition('>')
            corr[int(a)] = int(b)
    return corr, fusion_ok


def luminance(rvb):
    r, v, b = rvb
    return 0.299 * r + 0.587 * v + 0.114 * b


def fusions(corr, employes):
    """{nouvel index: [anciens index employés qui y tombent]} pour les seules
    collisions. Un dégradé de N valeurs qui en rend N-1 se voit ici."""
    vers = {}
    for a in sorted(employes):
        vers.setdefault(corr[a], []).append(a)
    return {b: anc for b, anc in vers.items() if len(anc) > 1}


def dire_fusions(nom, coll, employes, corr, pal_a, pal_b):
    """Nommer ce qui se perd, et montrer où le remettre."""
    h = lambda t: '#%02X%02X%02X' % t
    print(f"{nom} : ARRET — {len(coll)} niveau(x) de degrade disparaitrait(ent).")
    for b, anc in sorted(coll.items()):
        quoi = ', '.join(f"{a} {h(pal_a[a + 1])} (lum {luminance(pal_a[a + 1]):.0f})"
                         for a in anc)
        print(f"  anciens {quoi}")
        print(f"      tombent tous sur le nouvel index {b} {h(pal_b[b + 1])}")
    pris = {corr[a] for a in employes}
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
            dst[x, y] = TRANSPARENT if v == TRANSPARENT else corr[v - 1] + 1
    return out, vus, []


def rendu(png, pal, Z, fond):
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
    return out.resize((w * Z, h * Z), Image.NEAREST)


def _police(t, gras=False):
    c = ('/usr/share/fonts/truetype/dejavu/DejaVuSansMono'
         + ('-Bold' if gras else '') + '.ttf')
    try:
        return ImageFont.truetype(c, t)
    except OSError:
        return ImageFont.load_default()


FOND, Z, LARGEUR_MAX = (18, 20, 24), 6, 1360


def _geometrie(paires, nb_col):
    """Géométrie d'un bloc : chaque ressource a sa propre échelle — un sprite
    de 12 px ne mérite pas la cellule d'un sprite de 48 — et le nombre de
    vignettes par ligne se déduit de la largeur disponible."""
    mw = max(Image.open(p).size[0] for p, _ in paires)
    mh = max(Image.open(p).size[1] for p, _ in paires)
    cw = mw * Z * nb_col + 14 * (nb_col - 1) + 30
    par_ligne = max(1, min(len(paires), (LARGEUR_MAX - 24) // cw))
    return (cw, mh * Z + 50, (len(paires) + par_ligne - 1) // par_ligne,
            mw, mh, par_ligne)


def planche(sortie, blocs, colonnes):
    """La planche de validation : chaque image telle quelle à gauche, puis une
    vignette par candidat. C'est ce que l'auteur regarde, et rien d'autre ne
    l'engage. Chaque vignette porte SA table de couleurs — une image déjà
    migrée par une autre ressource n'a plus d'original dans l'arbre, sa
    colonne « actuel » doit donc se rendre avec la nouvelle palette."""
    f, fp, fb, ft = _police(11), _police(10), _police(15, True), _police(13, True)
    nb = len(colonnes)
    geo = [_geometrie(p, nb) for _, _, p in blocs]
    largeur = max([640] + [cw * pl for (cw, _, _, _, _, pl) in geo]) + 24
    hauteur = 62 + sum(34 + ch * li for (_, ch, li, _, _, _) in geo)
    im = Image.new('RGB', (largeur, hauteur), FOND)
    d = ImageDraw.Draw(im)
    d.text((14, 12), "migration de palette — planche de validation", font=fb,
           fill=(228, 232, 240))
    d.text((14, 36), "colonnes, de gauche a droite : " + "  |  ".join(colonnes),
           font=f, fill=(150, 158, 172))
    y0 = 62
    for (nom, soustitre, paires), (cw, ch, li, mw, mh, par_ligne) in zip(blocs, geo):
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
                xj = x + j * (mw * Z + 14)
                im.paste(vue, (xj, y + mh * Z - vue.size[1]))
                d.text((xj, y + mh * Z + 6), etiquette, font=fp,
                       fill=(120, 128, 142))
            d.text((x, y + mh * Z + 22),
                   os.path.relpath(src, PROJET).split('/')[-1], font=f,
                   fill=(200, 206, 216))
        y0 += ch * li
    im.save(sortie)


def preparer(nom, images, corr, fusion_ok, pal_b, rvb_a, rvb_b, base, pris):
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
    deja = [p for p in images if palette_brute(p) == pal_b or p in pris]
    reste = [p for p in images if p not in deja]
    if not reste:
        # tout est fait : c'est un rejeu, pas un heritage. Ne pas dresser une
        # liste qui donnerait a croire qu'une autre ressource a tranche.
        print(f"{nom} : rien a faire, tout est deja migre.")
        return [], deja, set(), 0
    if deja:
        print(f"{nom} : {len(deja)} image(s) deja migree(s), heritee(s) d'une "
              "autre ressource — laissee(s) telle(s) quelle(s) :")
        for p in deja:
            print(f"    {os.path.relpath(p, base)}")

    resultats, refus, employes = [], [], set()
    for p in reste:
        img, vus, orphelins = migrer(p, corr, pal_b)
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
        return [], deja, employes, 1

    # Priorite auteur (16/08) : conserver les niveaux de degrade. Deux index
    # employes qui tombent sur le meme, c'est une marche de rampe perdue.
    coll = fusions(corr, employes)
    if coll and not fusion_ok:
        dire_fusions(nom, coll, employes, corr, rvb_a, rvb_b)
        return [], deja, employes, 1
    if coll:
        print(f"{nom} : fusion DECLAREE (fusion-ok) — "
              + ' ; '.join(f"anciens {anc} -> {b}" for b, anc in sorted(coll.items())))

    bouge = sum(1 for _, _, vus in resultats
                if any(corr[v - 1] != v - 1 for v in vus if v != TRANSPARENT))
    print(f"{nom} : {len(resultats)} images, {bouge} dont au moins un index change")
    return resultats, deja, employes, 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ressource', nargs='*')
    ap.add_argument('--liste', action='store_true')
    ap.add_argument('--apercu', metavar='SORTIE.PNG')
    ap.add_argument('--ecrire', action='store_true')
    ap.add_argument('--map', default=os.path.join(ICI, 'palette-map.txt'))
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
        print(f"{len(res)} ressources dans le perimetre :")
        for n in sorted(res):
            fait = all(palette_brute(p) == pal_b for p in res[n])
            print(f"  [{'x' if fait else ' '}] {n:26} {len(res[n]):3} images")
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
    candidats = [('migre' if not args.variante else 'table de base', [args.map])]
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
            if args.variante:
                print(f"[{etiquette}]", end=' ')
            resultats, deja, employes, c = preparer(nom, res[nom], corr, fusion_ok,
                                                    pal_b, rvb_a, rvb_b, base, pris)
            code |= c
            pris |= {p for p, _, _ in resultats}
            tour.append((etiquette, nom, corr, resultats, deja, employes))
    if code:
        return 1

    if args.apercu:
        tmp = os.path.join('/tmp', f'.mig-{os.getpid()}')
        blocs, resumes = [], {}
        for nom in args.ressource:
            paires, ordre = {}, []
            for etiquette, n, corr, resultats, deja, employes in tour:
                if n != nom:
                    continue
                # un sous-dossier PAR CANDIDAT ET PAR RESSOURCE : deux
                # ressources ont les memes noms de fichiers (00.png, 01.png…)
                # et s'ecraseraient l'une l'autre
                coin = os.path.join(tmp, etiquette, nom)
                os.makedirs(coin, exist_ok=True)
                for p, img, _ in resultats:
                    t = os.path.join(coin, os.path.basename(p))
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
            if ordre:
                # une image heritee n'a plus d'original : sa colonne « actuel »
                # se rend avec la NOUVELLE palette, sinon on montrerait un
                # charabia et on croirait a un defaut de conversion
                blocs.append((nom, resumes[nom], [
                    (p, [('actuel', p,
                          rvb_b if palette_brute(p) == pal_b else rvb_a)]
                     + paires[p]) for p in ordre]))
        if not blocs:
            print("rien a montrer : tout est deja migre.")
            return 0
        planche(args.apercu, blocs, ['actuel'] + [e for e, _ in candidats])
        print(f"planche ecrite : {args.apercu}  (rien n'a ete modifie)")

    if args.ecrire:
        tour = [t[1:] for t in tour]        # une seule colonne quand on ecrit
        ecrites, mauvais = 0, []
        for nom, corr, resultats, _, _ in tour:
            for p, img, _ in resultats:
                img.save(p)
            # --- relecture : ce qui est sur le disque est-il ce qu'on voulait ?
            for (p, img, vus) in resultats:
                relu = Image.open(p)
                if palette_brute(p) != pal_b:
                    mauvais.append((p, 'table de couleurs non installee'))
                    continue
                attendu = {corr[v - 1] + 1 for v in vus if v != TRANSPARENT}
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
        print(f"{ecrites} images reecrites et relues : conformes.")
    return 0


def _resume(corr, employes):
    """Le sous-titre d'une section : ce que la table fait bouger POUR CETTE
    ressource — pas la table entière, seulement les index qu'elle emploie."""
    bouge = [f"{a}>{corr[a]}" for a in sorted(employes) if corr[a] != a]
    return ' '.join(bouge) if bouge else 'renumerotation nulle'


if __name__ == '__main__':
    sys.exit(main())
