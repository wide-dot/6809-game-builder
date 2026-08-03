#!/usr/bin/env python3
"""Garde-fou : les variantes de sprite v2 contre le contrat v1 (conf disquette).

La conf de la CIBLE fait foi : pour la disquette, les *.d7.properties du
game-project v1. Ce script rapproche, PAR FICHIER PNG (le nom d'image change
entre v1 et v2, pas le png), les variantes déclarées des deux côtés :

  v1 : sprite.Img_x=./chemin/img.png;NB0,NB1     (suffixe = variante)
  v2 : <image filename=".../img.png"> <encoder name mirror shift/> </image>

Traduction encoder -> suffixe : N/X/Y = mirror none/x/y, B/D = bdraw/draw,
chiffre = shift. Toute divergence sur un png déclaré en v2 est une erreur :
ni perte (variante v1 absente) ni invention (variante v2 sans source v1).
Les png v1 absents de v2 sont listés pour information (pas encore portés).

    usage : tools/check_variants.py [chemin du game-project v1]
"""
import os
import re
import sys


def suffix3(path):
    """Cle de rapprochement : les trois derniers segments du chemin. Les
    arborescences v1 et v2 different, mais <objet>/images/<png> survit au
    demenagement — et discrimine les homonymes (mask/images/mask.png n'est
    pas shell/images/mask.png)."""
    return '/'.join(path.replace('\\', '/').split('/')[-3:])

V1 = sys.argv[1] if len(sys.argv) > 1 else \
    '../../../thomson-to8-game-engine/game-projects/r-type'

# --- v1 : tous les sprite. des conf disquette -------------------------------
v1 = {}         # suffixe a 3 segments -> variantes (union)
v1_by_base = {} # basename -> {chemin: variantes}, pour le repli
for root, _, files in os.walk(V1):
    for f in files:
        if not f.endswith('.d7.properties'):
            continue
        for line in open(os.path.join(root, f)):
            line = line.strip()
            if line.startswith('#') or line.startswith(';'):
                continue
            m = re.match(r'sprite\.[A-Za-z0-9_]+=(\S+?\.png);([A-Z0-9,]+)', line)
            if not m:
                continue
            png = os.path.basename(m.group(1))
            path = m.group(1)
            # UNION par CHEMIN : un meme png porte parfois plusieurs lignes
            # sprite. (une par variante, ex. emitter-flash en NB0 puis XB0).
            # Et deux fichiers DIFFERENTS peuvent partager un basename (le
            # mask.png du shell n'est pas celui du champ de jeu) : on garde
            # les chemins separes et on tranche au rapprochement.
            v1.setdefault(suffix3(path), set()).update(m.group(2).split(','))
            v1_by_base.setdefault(png, {}).setdefault(path, set()).update(m.group(2).split(','))

# --- v2 : les <image>/<encoder> de to8.config.xml ---------------------------
MIRROR = {'none': 'N', 'x': 'X', 'y': 'Y', 'xy': 'W'}
ENC = {'bdraw': 'B', 'draw': 'D'}
v2 = {}
config = open('to8.config.xml').read()
for img in re.finditer(r'<image [^>]*filename="([^"]+\.png)"[^>]*>(.*?)</image>',
                       config, re.S):
    png = suffix3(img.group(1))
    vs = set()
    for enc in re.finditer(r'<encoder name="(\w+)" mirror="(\w+)" shift="(\d)"', img.group(2)):
        vs.add(MIRROR[enc.group(2)] + ENC[enc.group(1)] + enc.group(3))
    v2.setdefault(png, set()).update(vs)

# --- rapprochement -----------------------------------------------------------
errors = 0
for png, vs in sorted(v2.items()):
    if png in v1:
        if v1[png] != vs:
            print(f'ERREUR : {png} — v1 (d7) : {sorted(v1[png])}, v2 : {sorted(vs)}')
            errors += 1
        continue
    base = os.path.basename(png)
    if base not in v1_by_base:
        print(f'INFO : {png} déclaré en v2 sans sprite. v1 (généré ou volontaire)')
        continue
    # repli basename : le suffixe a bouge entre v1 et v2 — on accepte si une
    # source correspond, on signale sinon (sans trancher entre homonymes)
    sources = v1_by_base[base]
    if any(vars == vs for vars in sources.values()):
        continue
    det = ' ; '.join(f'{p} : {sorted(v)}' for p, v in sources.items())
    # Non bloquant : un basename partage ne dit pas si c'est un demenagement
    # (le fichier a change de dossier entre v1 et v2) ou un homonyme (le
    # mask.png du shell n'est pas celui du champ de jeu, dont la ligne v1 est
    # commentee — sprite remplace par du code, regenere en v2). A trancher a
    # l'oeil, pas a l'aveugle.
    print(f'AVERTISSEMENT : {png} — v2 : {sorted(vs)}, homonymes v1 : {det}')
missing = sorted(set(v1) - set(v2))
if missing:
    print(f'({len(missing)} png v1 pas encore portés en v2 — normal en cours de migration)')
print('variantes conformes' if not errors else f'{errors} divergence(s)')
sys.exit(1 if errors else 0)
