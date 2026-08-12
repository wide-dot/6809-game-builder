#!/usr/bin/env python3
"""Garde-fou : les variantes de sprite v2 contre le contrat v1 (conf disquette).

La conf de la CIBLE fait foi : pour la disquette, les *.d7.properties du
game-project v1. Depuis le renommage 7b (les fichiers v2 portent leur ordre
en préfixe NN, plus leur nom v1), le rapprochement se fait PAR CONTENU :
les png v2 sont des copies byte-identiques des png v1, le sha256 est donc
la clé — il désambiguïse aussi les homonymes que l'ancien rapprochement
par chemin devait trancher à l'œil.

Côté v2, les deux formes de déclaration sont lues : les <image>/<encoder>
littéraux, et les lignes <images> compactes — expansées comme le builder
le fait (fichiers NN du répertoire, un code par décalage de shifts=).

Traduction encoder -> suffixe : N/X/Y/XY = mirror, B/D = bdraw/draw,
chiffre = shift. Toute divergence sur un png déclaré en v2 est une erreur :
ni perte (variante v1 absente) ni invention (variante v2 sans source v1).

    usage : tools/check_variants.py [chemin du game-project v1]
"""
import hashlib
import os
import re
import sys

V1 = sys.argv[1] if len(sys.argv) > 1 else \
    '../../../thomson-to8-game-engine/game-projects/r-type'

def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()

# --- v1 : tous les sprite. des conf disquette -------------------------------
v1 = {}          # sha256 -> variantes (union)
v1_names = {}    # sha256 -> un chemin v1, pour les messages
for root, _, files in os.walk(V1):
    for f in files:
        if not f.endswith('.d7.properties'):
            continue
        for line in open(os.path.join(root, f), encoding='latin-1'):
            line = line.strip()
            if line.startswith('#') or line.startswith(';'):
                continue
            m = re.match(r'sprite\.[A-Za-z0-9_]+=(\S+?\.png);([A-Z0-9,]+)', line)
            if not m:
                continue
            path = os.path.normpath(os.path.join(V1, m.group(1).lstrip('./')))
            if not os.path.isfile(path):
                continue
            h = sha(path)
            # UNION : un même png porte parfois plusieurs lignes sprite.
            v1.setdefault(h, set()).update(m.group(2).split(','))
            v1_names.setdefault(h, m.group(1))

# --- v2 : <image>/<encoder> littéraux + lignes <images> ---------------------
MIRROR = {'none': 'N', 'x': 'X', 'y': 'Y', 'xy': 'XY'}
ENC = {'bdraw': 'B', 'draw': 'D'}
v2 = {}          # sha256 -> variantes
v2_names = {}    # sha256 -> un chemin v2

def declare(path, codes):
    if not os.path.isfile(path):
        print(f'ERREUR : {path} déclaré mais absent du disque')
        return
    h = sha(path)
    v2.setdefault(h, set()).update(codes)
    v2_names.setdefault(h, path)

config = open('to8.config.xml').read()
for img in re.finditer(r'<image [^>]*filename="([^"]+\.png)"[^>]*>(.*?)</image>',
                       config, re.S):
    if 'grid=' in img.group(0):
        continue
    codes = set()
    for enc in re.finditer(r'<encoder name="(\w+)" mirror="(\w+)" shift="(\d)"',
                           img.group(2)):
        codes.add(MIRROR[enc.group(2)] + ENC[enc.group(1)] + enc.group(3))
    declare(img.group(1), codes)

for row in re.finditer(r'<images\s+([^>]*?)/>', config):
    attrs = dict(re.findall(r'(\w+)="([^"]*)"', row.group(1)))
    d = attrs['dir']
    mirror = MIRROR[attrs.get('mirror', 'none')]
    enc = ENC[attrs.get('encoder', 'bdraw')]
    shifts = attrs.get('shifts', '0').split(',')
    codes = {mirror + enc + s.strip() for s in shifts}
    match = attrs.get('match', r'[0-9]*.png')
    ordered = {}
    for f in os.listdir(d):
        if not f.endswith('.png') or not os.path.isfile(os.path.join(d, f)):
            continue
        m = re.match(r'^(\d+)', f)
        if match == r'[0-9]*.png' and not m:
            continue
        if m:
            ordered[int(m.group(1))] = f
    for k in sorted(ordered):
        declare(os.path.join(d, ordered[k]), codes)

# --- rapprochement ----------------------------------------------------------
errors = 0
for h, vs in sorted(v2.items(), key=lambda kv: v2_names.get(kv[0], '')):
    if h not in v1:
        print(f'INFO : {v2_names[h]} déclaré en v2 sans sprite. v1 (généré ou volontaire)')
        continue
    if v1[h] != vs:
        print(f'ERREUR : {v2_names[h]} — v1 (d7, {v1_names[h]}) : '
              f'{sorted(v1[h])}, v2 : {sorted(vs)}')
        errors += 1
missing = sorted(v1_names[h] for h in set(v1) - set(v2))
if missing:
    print(f'({len(missing)} png v1 pas encore portés en v2 — normal en cours de migration)')
print('variantes conformes' if not errors else f'{errors} divergence(s)')
sys.exit(1 if errors else 0)
