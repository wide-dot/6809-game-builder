#!/usr/bin/env python3
"""Quels index de palette les objets COMMUNS consomment — donc lesquels un
stage peut encore s'approprier.

Le jeu tient une palette de 16 couleurs par stage (`Pal_stage`). Tout ce qui
est RÉSIDENT — chargé une fois par `scenes.boot` et jamais rechargé : joueur,
armes, HUD, explosions, bonus, messages… — se dessine avec la palette du stage
courant, quel qu'il soit. Un index que ces objets utilisent est donc GELÉ : il
doit porter la même couleur dans les huit palettes, sinon l'objet change de
couleur d'un stage à l'autre. Les autres index sont libres pour le décor.

C'est exactement le piège du relevé « STAGE CLEARED » (15/08/2026) : la fonte
peignait le fond de ses glyphes en index 15, noir sur la palette du titre et
saumon sur celles du jeu.

Le script lit `to8.config.xml` — jamais une liste écrite à la main — expanse
les images comme le builder le fait, et rend trois choses :

  * les index CONTRAINTS  : consommés par au moins un objet commun ;
  * les index LIBRES      : personne de commun ne les touche, un stage peut y
                            mettre ce qu'il veut ;
  * le RECOUPEMENT        : ce que les huit `Pal_stage` font vraiment
                            aujourd'hui, index par index — un index contraint
                            dont la couleur varie entre stages est un défaut.

Les LOTS d'ennemis (`lib.*`, chargés par combinaison de stage via
`scenes.lot.*`) sont hors du verdict : partiellement communs, ils ne
contraignent que les stages qui les chargent. Ils sont comptés à part, en
information — la demande est de connaître les index potentiellement
spécifiques stage, et un lot ne les gèle pas.

DEUX sources d'index, pas une — c'est ce qui fait la valeur du relevé :

  * les PNG passés à `gfxcomp` (la quasi-totalité des objets) ;
  * le DESSIN ÉCRIT À LA MAIN, du code qui pose ses nibbles lui-même
    (`LDA #$xy` suivi d'un `STA n,U`). La fonte du « STAGE CLEARED » est
    exactement ça, et c'est elle qui a saigné : un scan de PNG seul l'aurait
    déclarée innocente. Les sources balayées sont celles que le config
    déclare pour chaque unité commune, chaîne d'INCLUDE suivie — un fichier
    qui traîne sans être inclus reste donc hors du compte.

Conventions (docs/lang/en/sprites.md) : les PNG sont indexés 8 bits, l'index 0
est la TRANSPARENCE et 1..16 portent les couleurs ; le code dessine `pixel-1`,
donc l'index PNG N vaut l'index matériel N-1. `png2pal` applique le même
décalage (`offset` = 1) pour extraire une palette. Dans le code écrit à la
main, en revanche, les nibbles SONT déjà des index matériels et le 0 y est une
couleur (le noir), pas une transparence : le mode BM16 n'en a pas.

    usage : tools/palette_usage.py [--detail] [--config to8.config.xml]

      --detail   liste aussi, par index, les fichiers communs qui l'utilisent
                 (c'est ce qui sert à trouver le coupable d'un index gelé)

Le recoupement des palettes de stage a besoin des PNG produits sous `gen/`
(les tilesets des stages 2-8) : construire une fois avant, sinon cette
section s'annonce incomplète et le reste du rapport tient quand même.
"""
import argparse
import fnmatch
import os
import re
import sys
import xml.etree.ElementTree as ET

try:
    from PIL import Image
except ImportError:
    sys.exit("il faut Pillow : pip install pillow")

NB_INDEX = 16          # la palette matérielle du TO8 en mode BM16
TRANSPARENT = 0        # index PNG 0 : la transparence, jamais une couleur


def expanse(gfx, base):
    """Les PNG que déclare un <gfxcomp>, comme le builder les voit.

    Deux formes coexistent : les <image filename> littéraux et les lignes
    <images dir> compactes. Pour ces dernières le builder liste le répertoire
    SANS descendre (listFiles + filtre glob sur le nom, défaut `[0-9]*.png`) —
    c'est ce qui met les sprites arcade de `images/original/` hors du build,
    et le script doit s'aligner exactement là-dessus.

    Les images `grid=` sont écartées : ce sont les tilesets, du décor de stage
    découpé en tuiles, pas des objets.
    """
    png = []
    for img in gfx.iter('image'):
        if img.get('grid'):
            continue
        f = img.get('filename')
        if f:
            png.append(os.path.join(base, f))
    for row in gfx.iter('images'):
        d = os.path.join(base, row.get('dir'))
        match = row.get('match', '[0-9]*.png')
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            p = os.path.join(d, name)
            if os.path.isfile(p) and fnmatch.fnmatch(name, match):
                png.append(p)
    return png


def pixels_par_index(path):
    """Le POIDS d'une image, index matériel par index matériel : combien de
    pixels chacun porte. Rend aussi le compte des pixels transparents, qui ne
    sont d'aucune couleur mais disent la part de vide du sprite."""
    im = Image.open(path)
    if im.mode != 'P':
        raise ValueError(f"{path} : attendu un PNG indexe 8 bits, trouve {im.mode}")
    poids, vide = {}, 0
    for n, v in (im.getcolors(1 << 20) or []):
        if v == TRANSPARENT:
            vide += n
        else:
            poids[v - 1] = poids.get(v - 1, 0) + n
    return poids, vide


def index_utilises(path):
    """Les index MATÉRIELS qu'une image consomme (transparence exclue)."""
    return set(pixels_par_index(path)[0])


LDA_IMM = re.compile(r'^\s*lda\s+#\$([0-9a-f]{1,2})\s*(;.*)?$', re.I)
# Le deplacement doit etre un NOMBRE (ou rien) : c'est ce qui separe un octet
# deverse a l'ecran d'une ecriture dans un OST, ou U pointe l'objet et le
# deplacement est un champ nomme. Sans cette exigence, `sta o_fade_idx,u` et
# `sta nb_cells,u` passaient pour des pixels — releve et corrige le 15/08.
# Le SIGNE compte : une police dessine au-dessus de son ancre (`STA -80,U`),
# et l'oublier coutait 171 appariements sur les 400 — vu parce que le compte
# avait bouge PLUS que les deux faux positifs ne l'expliquaient.
STA_U = re.compile(r'^\s*sta\s+(?:-?\$?[0-9a-f]+)?\s*,\s*u\b', re.I)
INCLUDE = re.compile(r'^\s*INCLUDE\s+"([^"]+)"', re.I)


def sources_de(fichier, base):
    """Les .asm qu'une unité assemble : ceux que le config déclare, plus tout
    ce qu'ils tirent par INCLUDE. Suivre la chaîne est ce qui fait tomber les
    fichiers morts — un .asm que plus personne n'inclut n'est pas du code."""
    vus, pile = set(), []
    for a in fichier.iter('asm'):
        f = a.get('filename')
        if f:
            pile.append(os.path.join(base, f))
    while pile:
        p = os.path.normpath(pile.pop())
        if p in vus or not os.path.isfile(p):
            continue
        vus.add(p)
        for l in open(p, errors='replace'):
            m = INCLUDE.match(l)
            if m:
                pile.append(os.path.join(base, m.group(1)))
    return vus


def pixels_ecrits_main(path):
    """Idem pour le dessin écrit à la main : chaque octet BM16 déversé à
    l'écran vaut DEUX pixels, un par nibble. Ce sont des pixels statiques —
    ceux que le code pose à chaque appel — donc comparables à ceux d'une
    image, à ceci près qu'un glyphe appelé dix fois les pose dix fois."""
    lignes = open(path, errors='replace').read().split('\n')
    poids = {}
    for i, l in enumerate(lignes):
        m = LDA_IMM.match(l)
        if not m:
            continue
        for j in range(i + 1, min(i + 4, len(lignes))):
            s = lignes[j].strip()
            if not s or s.startswith((';', '*')):
                continue
            if STA_U.match(lignes[j]):
                v = int(m.group(1), 16)
                for nib in (v >> 4, v & 0x0F):
                    poids[nib] = poids.get(nib, 0) + 1
            break
    return poids


def index_ecrits_main(path):
    """Les index qu'un dessin ÉCRIT À LA MAIN pose : un `LDA #$xy` dont le
    STA qui suit vise l'écran (`,U`) est un octet BM16, soit deux pixels —
    les deux nibbles sont des index matériels, le 0 compris (le mode n'a pas
    de transparence). Un `lda #$..` qui ne se déverse pas à l'écran est une
    constante ordinaire et ne compte pas : c'est l'idiome, pas l'opcode, qui
    fait la couleur."""
    return set(pixels_ecrits_main(path))


def palette_de(path):
    """Les 16 couleurs d'un PNG de palette, comme png2pal les extrait
    (offset 1 : l'entrée PNG 1 devient la couleur matérielle 0)."""
    im = Image.open(path)
    if im.mode != 'P':
        raise ValueError(f"{path} : attendu un PNG indexe 8 bits, trouve {im.mode}")
    brut = im.getpalette() or []
    out = []
    for i in range(1, 1 + NB_INDEX):
        r, g, b = brut[i * 3:i * 3 + 3] if len(brut) >= (i + 1) * 3 else (0, 0, 0)
        out.append((r >> 4, g >> 4, b >> 4))   # le TO8 code 4 bits par canal
    return out


def planche(sortie, palettes, contraints, px_img, px_code, defauts):
    """La planche de pastilles : un index par ligne, une palette de stage par
    colonne. On y lit d'un coup ce qu'un tableau de chiffres fait deviner —
    une ligne d'une seule couleur est un index sur lequel les huit stages
    s'accordent, une ligne bariolee est un index qui bouge. Quand c'est un
    index GELE, la ligne bariolee EST le defaut."""
    from PIL import ImageDraw, ImageFont

    def police(taille, gras=False):
        chemin = ('/usr/share/fonts/truetype/dejavu/DejaVuSansMono'
                  + ('-Bold' if gras else '') + '.ttf')
        try:
            return ImageFont.truetype(chemin, taille)
        except OSError:
            return ImageFont.load_default()

    f, fb = police(13), police(14, True)
    noms = list(palettes)
    MARGE, LIG, PAST = 16, 30, 46      # marge, hauteur de ligne, largeur pastille
    GAUCHE, ENTETE = 250, 56           # colonne des libelles, bandeau du haut
    titre = ("Index de palette — objets communs contre les palettes de stage")
    legende = ("ligne d'une seule couleur = les 8 stages s'accordent",
               "ligne bariolee sur un index GELE = defaut")
    # la planche s'elargit pour son texte : une legende coupee ne se lit pas
    mesure = ImageDraw.Draw(Image.new('RGB', (1, 1)))
    besoin = max([mesure.textlength(titre, font=fb)]
                 + [mesure.textlength(t, font=f) for t in legende])
    L = max(GAUCHE + PAST * len(noms), int(besoin)) + 2 * MARGE
    H = ENTETE + LIG * NB_INDEX + MARGE + 20 * len(legende) + 8

    im = Image.new('RGB', (L, H), (18, 20, 24))
    d = ImageDraw.Draw(im)
    d.text((MARGE, 14), titre, font=fb, fill=(228, 232, 240))
    for k, n in enumerate(noms):
        d.text((GAUCHE + k * PAST + 10, 38), n.replace('stage', ''),
               font=f, fill=(150, 158, 172))

    total = sum(px_img.values()) + sum(px_code.values()) or 1
    for i in range(NB_INDEX):
        y = ENTETE + i * LIG
        gele = i in contraints
        px = px_img[i] + px_code[i]
        if i in defauts:                       # la ligne qui coute
            d.rectangle([MARGE - 6, y - 3, L - MARGE + 6, y + LIG - 7],
                        fill=(58, 26, 30))
        libelle = (200, 206, 216) if gele else (120, 128, 140)
        d.text((MARGE, y + 4), f"index {i:2}", font=fb, fill=libelle)
        etat = "GELE" if gele else "libre"
        d.text((MARGE + 86, y + 5), etat, font=f,
               fill=(232, 120, 130) if i in defauts else
                    (200, 206, 216) if gele else (110, 118, 130))
        d.text((MARGE + 140, y + 5), f"{px:5} px" if px else "    -",
               font=f, fill=(140, 148, 162))
        # la barre de poids, sous le libelle : le cout de l'index en un trait
        larg = round(78 * px / max(px_img[j] + px_code[j] for j in range(NB_INDEX)))
        if larg:
            d.rectangle([MARGE + 140, y + LIG - 9, MARGE + 140 + larg, y + LIG - 7],
                        fill=(90, 100, 118))
        for k, n in enumerate(noms):
            r, g, b = palettes[n][i]
            x = GAUCHE + k * PAST
            d.rectangle([x, y, x + PAST - 6, y + LIG - 8],
                        fill=(r * 17, g * 17, b * 17), outline=(60, 66, 78))

    bas = ENTETE + NB_INDEX * LIG + 8
    for k, t in enumerate(legende):
        d.text((MARGE, bas + 20 * k), t, font=f, fill=(150, 158, 172))
    im.save(sortie)


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('--detail', action='store_true')
    ap.add_argument('--histogramme', action='store_true')
    ap.add_argument('--planche', metavar='SORTIE.PNG',
                    help="ecrit une planche de pastilles : les 16 index en "
                         "lignes, les palettes de stage en colonnes")
    ap.add_argument('--config', default='to8.config.xml')
    args = ap.parse_args()

    base = os.path.dirname(os.path.abspath(args.config)) or '.'
    root = ET.parse(args.config).getroot()

    # --- ce que chaque <file> apporte comme images, et ce que chaque scène charge
    images = {}
    sources = {}
    palettes = {}
    for f in root.iter('file'):
        nom = f.get('name')
        if not nom:
            continue
        png = []
        for gfx in f.iter('gfxcomp'):
            png += expanse(gfx, base)
        if png:
            images[nom] = png
        sources[nom] = sources_de(f, base)
        for pal in f.iter('png2pal'):
            if pal.get('symbol') == 'Pal_stage':
                palettes[nom] = os.path.join(base, pal.get('filename'))

    scenes = {s.get('name'): [l.get('name') for l in s.iter('load')]
              for s in root.iter('scene')}

    # --- les trois familles. Le title est chargé au boot comme le reste, mais
    #     il se dessine sur SA palette (Pal_title) : il ne gèle rien du jeu.
    communs = [n for n in scenes.get('scenes.boot', [])
               if not n.startswith('title.')
               and (n in images or sources.get(n))]
    lots = sorted({n for s, l in scenes.items() if s.startswith('scenes.lot.')
                   for n in l if n in images})

    if not communs:
        sys.exit("aucun objet commun trouve : le config a-t-il change de forme ?")

    # --- relevé
    par_index = {i: [] for i in range(NB_INDEX)}
    px_img = {i: 0 for i in range(NB_INDEX)}       # pixels venus des png
    px_code = {i: 0 for i in range(NB_INDEX)}      # pixels venus du code
    px_vide = 0
    nb_png = 0
    for nom in communs:
        for p in images.get(nom, []):
            nb_png += 1
            poids, vide = pixels_par_index(p)
            px_vide += vide
            for i, n in poids.items():
                px_img[i] += n
                par_index[i].append((nom, os.path.relpath(p, base)))

    # le dessin ecrit a la main, deuxieme source d'index
    main_par_fichier = {}
    for nom in communs:
        for p in sorted(sources.get(nom, ())):
            poids = pixels_ecrits_main(p)
            if poids:
                main_par_fichier[os.path.relpath(p, base)] = (nom, set(poids))
                for i, n in poids.items():
                    px_code[i] += n
                    par_index[i].append((nom, os.path.relpath(p, base)))

    contraints = sorted(i for i in par_index if par_index[i])
    libres = [i for i in range(NB_INDEX) if i not in contraints]

    lots_index = set()
    nb_png_lots = 0
    for nom in lots:
        for p in images[nom]:
            nb_png_lots += 1
            lots_index |= index_utilises(p)

    # --- rapport
    print(f"OBJETS COMMUNS — {len(communs)} unites, {nb_png} png"
          + (f", {len(main_par_fichier)} source(s) de dessin ecrit a la main"
             if main_par_fichier else ", aucun dessin ecrit a la main"))
    for f, (nom, ix) in sorted(main_par_fichier.items()):
        print(f"    a la main : {f} ({nom}) -> "
              + ' '.join(str(i) for i in sorted(ix)))
    print(f"  index CONTRAINTS ({len(contraints)}/16) : "
          + ' '.join(str(i) for i in contraints))
    print(f"  index LIBRES     ({len(libres)}/16) : "
          + (' '.join(str(i) for i in libres) if libres else "aucun"))
    print()
    print(f"LOTS D'ENNEMIS (partiellement communs, hors verdict) — "
          f"{len(lots)} unites, {nb_png_lots} png")
    ajout = sorted(lots_index - set(contraints))
    print(f"  index utilises : " + ' '.join(str(i) for i in sorted(lots_index)))
    print(f"  dont pris SUR LES LIBRES : "
          + (' '.join(str(i) for i in ajout) if ajout else "aucun"))

    if args.histogramme:
        total = sum(px_img.values()) + sum(px_code.values())
        print()
        print(f"HISTOGRAMME — pixels par index sur les objets communs "
              f"({total} px poses, {px_vide} px transparents dans les png)")
        large = max(px_img[i] + px_code[i] for i in range(NB_INDEX)) or 1
        for i in range(NB_INDEX):
            n = px_img[i] + px_code[i]
            barre = '#' * round(40 * n / large)
            part = 100 * n / total if total else 0
            venu = f"  (dont {px_code[i]} en code)" if px_code[i] else ""
            etat = "libre" if not par_index[i] else "gele "
            print(f"  index {i:2} {etat} {n:7} px {part:5.1f} %  {barre}{venu}")
        print("  Un index gele mais leger se libere a peu de frais ; un index"
              " lourd, non — c'est ce que ce classement sert a trancher.")

    if args.detail:
        print()
        print("DETAIL — qui consomme quoi")
        for i in contraints:
            unites = sorted({n for n, _ in par_index[i]})
            print(f"  index {i:2} : {len(par_index[i]):4} png, {len(unites)} unites"
                  f"  [{', '.join(unites)}]")

    # --- recoupement : ce que les palettes de stage font vraiment
    print()
    stages = sorted(palettes)
    lues, manquantes = {}, []
    for nom in stages:
        p = palettes[nom]
        (lues.__setitem__(nom, palette_de(p)) if os.path.exists(p)
         else manquantes.append(os.path.relpath(p, base)))
    if manquantes:
        print(f"RECOUPEMENT DES PALETTES — INCOMPLET, {len(manquantes)} absente(s) "
              f"(construire une fois) : {', '.join(manquantes)}")
    if len(lues) < 2:
        return 0
    print(f"RECOUPEMENT DES PALETTES DE STAGE — {len(lues)} lues "
          f"({', '.join(lues)})")
    defauts = []
    for i in range(NB_INDEX):
        couleurs = {tuple(pal[i]) for pal in lues.values()}
        stable = len(couleurs) == 1
        gele = i in contraints
        if gele and not stable:
            defauts.append(i)
        etat = ("GELE, stable          " if gele and stable else
                "GELE, VARIE -> DEFAUT " if gele else
                "libre, stable         " if stable else
                "libre, varie          ")
        rgb = ' '.join('%X%X%X' % tuple(pal[i]) for pal in lues.values())
        print(f"  index {i:2} : {etat} {rgb}")
    if args.planche:
        planche(args.planche, lues, contraints, px_img, px_code, defauts)
        print(f"planche ecrite : {args.planche}")

    print()
    if defauts:
        print(f"DEFAUT : {len(defauts)} index geles par un objet commun changent "
              f"de couleur selon le stage : {' '.join(str(i) for i in defauts)}")
        print("  -> soit l'objet commun cesse d'utiliser cet index, soit les "
              "palettes de stage s'accordent dessus.")
    else:
        print("Aucun index gele ne varie entre les palettes de stage.")
    return 1 if defauts else 0


if __name__ == '__main__':
    sys.exit(main())
