#!/usr/bin/env python3
"""Confronte l'enveloppe reelle des sprites blittes en direct aux bornes cuites.

    python3 tools/sprite_envelope.py            # apres un build
    python3 tools/sprite_envelope.py --list     # l'inventaire, sans mesurer

QUATRE MANAGERS blittent des poses compilees sans passer par le dessin d'objet
du moteur. Ils le font parce que leur boite-proxy est garee au centre de
l'ecran expres, pour que BuildSprites les appelle toujours : le containment que
CheckSpritesRefresh fait pour un objet ordinaire ne les protege donc PAS, et
chacun doit le refaire lui-meme, sprite par sprite.

Deux facons de connaitre la geometrie a tester, et les deux ont cours ici :

  - LA LIRE DANS L'IMAGESET a chaque trame (flamemgr) : toujours juste, ne peut
    pas deriver, coute deux lectures indexees par sprite ;
  - LA CUIRE en constantes (bullets) : gratuit a l'execution, mais une constante
    peut mentir le jour ou l'art change.

Ce script est ce qui rend la seconde sure. Il relit les poses GENEREES, en
deduit l'enveloppe reellement ecrite autour de U, et sort en erreur si une
constante cuite ne la couvre plus. Il liste aussi les managers qui ne font ni
l'un ni l'autre — ce sont des trous connus, pas des oublis du script.

Ce que l'enveloppe veut dire, et pourquoi le haut n'est pas comme le reste :
un plan fait 200 lignes de 40 octets dans une demi-page de 8192, donc 192
octets libres le suivent. Deborder par le BAS ou par les cotes tombe dans cette
queue ou dans la bordure ; deborder par le HAUT du plan couleur tombe sous
$A000, sur la queue de la page directe, ou vivent les globales de camera. C'est
le seul bord dont l'omission corrompt de la memoire.
"""
import glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
ENGINE = os.path.join(GAME, '..', '..', 'engine', 'constants.asm')

# Les managers qui blittent en direct. 'equates'/'prefix' absents = le manager
# ne cuit rien : il lit sa geometrie ailleurs, ou ne teste pas encore.
MANAGERS = [
    {'name': 'bullets (tirs ennemis)',
     'draw': 'src/enemies/_shared/bullets/mgr.asm',
     'poses': 'gen/weapons/foefire/foefire_*_ND0.asm',
     'equates': 'src/enemies/_shared/bullets/bullets.equ',
     'prefix': 'bullet'},
    {'name': 'flamemgr (reacteur du warship)',
     'draw': 'src/enemies/warship-elements/reactor/flamemgr.asm',
     'note': "lit sa geometrie dans l'imageset a chaque trame : rien a cuire,"
             " donc rien qui puisse deriver"},
    {'name': 'eyepieces (dobkeratops)',
     'draw': 'src/enemies/dobkeratops/eyepieces.asm',
     'note': "ne teste pas le containment — trou connu"},
    {'name': 'eyebands (dobkeratops)',
     'draw': 'src/enemies/dobkeratops/eyebands-draw.asm',
     'note': "teste la bande en x, rien en y — trou connu"},
]


def geometry():
    """La geometrie de l'ecran, lue dans l'engine et jamais recopiee ici."""
    src = open(ENGINE).read()
    def equ(name):
        m = re.search(r'^%s\s+equ\s+([0-9]+)' % re.escape(name), src, re.M)
        if not m:
            sys.exit('%s absente de %s' % (name, ENGINE))
        return int(m.group(1))
    width, height = equ('screen_width'), equ('screen_height')
    # 4 pixels par octet, les deux plans entrelaces : DRS_XYToAddress fait
    # deux lsra avant de multiplier par la largeur de ligne
    return width // 4, height


def envelope(pattern):
    """Ce que les poses ecrivent vraiment autour de U : (min, max, colonnes)."""
    lo, hi, columns, files = 0, 0, set(), sorted(glob.glob(pattern))
    for f in files:
        for m in re.finditer(r'^\s*ST([ABD])\s+(-?\d+)?,U\s*$', open(f).read(), re.M):
            off, width = int(m.group(2) or 0), 2 if m.group(1) == 'D' else 1
            lo, hi = min(lo, off), max(hi, off + width - 1)
            columns.update((off + b) % LINE for b in range(width))
    return files, lo, hi, columns


def baked(path, prefix):
    out = {}
    for l in open(path):
        m = re.match(r'(%s\.[A-Z_]+)\s+equ\s+(\d+)' % re.escape(prefix), l.strip())
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


LINE, HEIGHT = geometry()
os.chdir(GAME)
listing = '--list' in sys.argv
print("geometrie lue dans l'engine : %d octets par ligne, %d lignes par plan\n"
      % (LINE, HEIGHT))

failed = []
for m in MANAGERS:
    print("* %s" % m['name'])
    print("    dessin   : %s" % m['draw'])
    if 'poses' not in m:
        print("    strategie: %s\n" % m['note'])
        continue
    if listing:
        print("    strategie: bornes cuites, verifiees ici\n")
        continue
    files, lo, hi, columns = envelope(m['poses'])
    if not files:
        print("    AUCUNE POSE sous %s — construire le jeu d'abord\n" % m['poses'])
        failed.append(m['name'])
        continue
    up, down = (-lo + LINE - 1) // LINE, (hi + LINE - 1) // LINE
    right = max(len(columns) - 1, 1)   # le plan decale de DRS_XYToAddress vaut 1
    print("    %d poses  : enveloppe %d..%+d octets depuis U" % (len(files), lo, hi))
    print("    mesure   : %d ligne(s) au-dessus, %d au-dessous, %d octet(s) a droite"
          % (up, down, right))
    b = baked(m['equates'], m['prefix'])
    for name, measured in (('DRAW_UP', up), ('DRAW_DOWN', down), ('DRAW_RIGHT', right)):
        key = '%s.%s' % (m['prefix'], name)
        if key not in b:
            print("    MANQUE   : %s n'est pas declaree" % key)
            failed.append(m['name'])
        elif b[key] < measured:
            print("    DERIVE   : %s vaut %d, il en faut %d — l'art a grandi"
                  % (key, b[key], measured))
            failed.append(m['name'])
    if m['name'] not in failed:
        print("    verdict  : les bornes cuites couvrent l'art")
    print()

if failed:
    print("ECHEC : %s" % ', '.join(sorted(set(failed))))
    sys.exit(1)
print("Tous les managers a bornes cuites couvrent leur art.")
