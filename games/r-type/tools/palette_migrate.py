#!/usr/bin/env python3
"""Migrer les images d'UNE ressource vers la nouvelle palette, sous validation.

Le protocole (docs/lang/fr/analyse-palette-migration-2026-08.md, §7) veut un
mapping PAR OBJET, une planche de prévisualisation, et la validation de
l'auteur avant que rien ne soit gravé. Cet outil sert ces trois temps :

    tools/palette_migrate.py --liste                      ce qu'il reste a faire
    tools/palette_migrate.py RESSOURCE --apercu out.png    la planche, rien d'ecrit
    tools/palette_migrate.py RESSOURCE --ecrire            applique, apres accord

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
  * après écriture, chaque fichier est relu : la table doit être la nouvelle,
    et les index doivent être exactement ceux que la correspondance prévoyait ;
  * `--ecrire` refuse si la ressource a déjà été migrée (idempotence : on ne
    remappe pas deux fois, ça décalerait tout une seconde fois).
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


def table(chemin, ressource):
    """La correspondance applicable à CETTE ressource : le défaut, puis ce que
    sa ligne ajoute ou remplace."""
    corr = {}
    for ligne in open(chemin, encoding='utf-8'):
        ligne = ligne.split('#')[0].strip()
        if not ligne:
            continue
        mots = ligne.split()
        cle, couples = mots[0], mots[1:]
        if cle not in ('defaut', ressource):
            continue
        for c in couples:
            a, _, b = c.partition('>')
            corr[int(a)] = int(b)
    return corr


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


def planche(sortie, nom, paires, avant, apres):
    """La planche de validation : chaque image telle quelle à gauche, migrée à
    droite. C'est ce que l'auteur regarde, et rien d'autre ne l'engage."""
    def police(t, gras=False):
        c = ('/usr/share/fonts/truetype/dejavu/DejaVuSansMono'
             + ('-Bold' if gras else '') + '.ttf')
        try:
            return ImageFont.truetype(c, t)
        except OSError:
            return ImageFont.load_default()

    f, fb = police(11), police(15, True)
    FOND, Z, COLS = (18, 20, 24), 6, 4
    mw = max(Image.open(p).size[0] for p, _ in paires)
    mh = max(Image.open(p).size[1] for p, _ in paires)
    CW, CH = mw * Z * 2 + 30, mh * Z + 34
    lignes = (len(paires) + COLS - 1) // COLS
    im = Image.new('RGB', (COLS * CW + 24, 76 + lignes * CH), FOND)
    d = ImageDraw.Draw(im)
    d.text((14, 14), f"{nom} — {len(paires)} images", font=fb,
           fill=(228, 232, 240))
    d.text((14, 40), "a gauche l'image actuelle, a droite la migration proposee",
           font=f, fill=(150, 158, 172))
    for k, (src, tmp) in enumerate(paires):
        x, y = 12 + (k % COLS) * CW, 76 + (k // COLS) * CH
        a, b = rendu(src, avant, Z, FOND), rendu(tmp, apres, Z, FOND)
        base = y + mh * Z - a.size[1]          # les sprites reposent sur la même ligne
        im.paste(a, (x, base))
        im.paste(b, (x + a.size[0] + 14, base))
        d.text((x, y + mh * Z + 6), os.path.relpath(src, PROJET).split('/')[-1],
               font=f, fill=(200, 206, 216))
    im.save(sortie)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ressource', nargs='?')
    ap.add_argument('--liste', action='store_true')
    ap.add_argument('--apercu', metavar='SORTIE.PNG')
    ap.add_argument('--ecrire', action='store_true')
    ap.add_argument('--map', default=os.path.join(ICI, 'palette-map.txt'))
    args = ap.parse_args()

    base = PROJET
    pu = _releve()
    res = ressources(pu, base)
    pal_a = palette_brute(os.path.join(base, PAL_ANCIENNE))
    pal_b = palette_brute(os.path.join(base, PAL_NOUVELLE))
    rgb = lambda p: [tuple(p[i * 3:i * 3 + 3]) for i in range(17)]

    if args.liste or not args.ressource:
        print(f"{len(res)} ressources dans le perimetre :")
        for n in sorted(res):
            fait = all(palette_brute(p) == pal_b for p in res[n])
            print(f"  [{'x' if fait else ' '}] {n:26} {len(res[n]):3} images")
        return 0

    nom = args.ressource
    if nom not in res:
        sys.exit(f"ressource inconnue : {nom} (voir --liste)")
    corr = table(args.map, nom)
    if not corr:
        sys.exit(f"aucune correspondance pour {nom} dans {args.map}")

    deja = [p for p in res[nom] if palette_brute(p) == pal_b]
    if deja and args.ecrire:
        sys.exit(f"{nom} : {len(deja)} image(s) portent deja la nouvelle "
                 "palette — migration deja faite, on ne remappe pas deux fois")

    # --- passe a blanc : tout doit passer avant que rien ne soit ecrit
    resultats, refus = [], []
    for p in res[nom]:
        img, vus, orphelins = migrer(p, corr, pal_b)
        if orphelins:
            refus.append((p, orphelins))
        else:
            resultats.append((p, img, vus))
    if refus:
        print(f"{nom} : ARRET — des index n'ont pas de correspondance.")
        for p, o in refus:
            print(f"  {os.path.relpath(p, base)} : index {o}")
        print("Trancher leur sort dans", os.path.relpath(args.map, base),
              "— une identite silencieuse serait pire.")
        return 1

    bouge = sum(1 for _, _, vus in resultats
                if any(corr[v - 1] != v - 1 for v in vus if v != TRANSPARENT))
    print(f"{nom} : {len(resultats)} images, {bouge} dont au moins un index change")

    if args.apercu:
        tmp = os.path.join('/tmp', f'.mig-{os.getpid()}')
        os.makedirs(tmp, exist_ok=True)
        paires = []
        for p, img, _ in resultats:
            t = os.path.join(tmp, os.path.basename(p))
            img.save(t)
            paires.append((p, t))
        planche(args.apercu, nom, paires, rgb(pal_a), rgb(pal_b))
        print(f"planche ecrite : {args.apercu}  (rien n'a ete modifie)")

    if args.ecrire:
        for p, img, _ in resultats:
            img.save(p)
        # --- relecture : ce qui est sur le disque est-il ce qu'on voulait ?
        mauvais = []
        for (p, img, vus) in resultats:
            relu = Image.open(p)
            if palette_brute(p) != pal_b:
                mauvais.append((p, 'table de couleurs non installee'))
                continue
            attendu = {corr[v - 1] + 1 for v in vus if v != TRANSPARENT}
            attendu |= ({TRANSPARENT} if TRANSPARENT in vus else set())
            obtenu = {v for _, v in (relu.getcolors(1 << 20) or [])}
            if obtenu != attendu:
                mauvais.append((p, f'index {sorted(obtenu)} au lieu de {sorted(attendu)}'))
        if mauvais:
            print("ECRITURE VERIFIEE : DES ECARTS")
            for p, m in mauvais:
                print(f"  {os.path.relpath(p, base)} : {m}")
            return 1
        print(f"{len(resultats)} images reecrites et relues : conformes.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
