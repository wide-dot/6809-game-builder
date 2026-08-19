#!/usr/bin/env python3
"""Nommer les ObjID numeriques des waves depuis le depot arcade.

Les waves des stages 2-8 sont l'import des fichiers `object-wave-data.asm` du
depot `wide-dot/re.arcade.r-type`. L'import a laisse en COMMENTAIRE toute ligne
dont l'objet n'etait pas encore porte, et a ecrit son ObjID en clair —
`ObjID_23` au lieu de `ObjID_warship_core`. Un numero ne dit rien : il faut
ouvrir le depot arcade pour savoir de quel ennemi on parle.

La table est `tools/objid-arcade.csv`, tiree de `data/routines.yaml` du
depot arcade — une LISTE dont l'index EST l'ObjID. Elle porte aussi l'adresse
ROM de chaque routine, seule identite disponible pour les six objets que le
depot arcade ne nomme pas encore lui-meme (1, 2, 34, 39, 46, 47).

Le renommage ne touche QUE les lignes commentees, et seulement le token
`ObjID_<numero>` : une ligne vive designe un objet deja porte, elle n'a rien a
voir ici.

Idempotent : une wave deja nommee n'a plus de numero a substituer.

## Le controle, et pourquoi il vaut mieux qu'une relecture

`--verifier` compare CHAQUE ligne portant un ObjID a la ligne de meme rang du
fichier arcade correspondant. Les deux fichiers sont le meme document — l'un
est l'import de l'autre — donc le rang apparie sans ambiguite. Un appariement
plus lache (par instant de spawn) ne suffit pas : plusieurs objets partagent le
meme instant, et la comparaison rendait alors de faux ecarts.

Ecart tolere et declare : `Geld` cote arcade, `geld` chez nous — le dossier
`src/enemies/geld/` est en minuscules comme tous les autres.

    usage : tools/objid_rename.py [--verifier]
"""
import csv
import io
import os
import re
import sys

ARCADE = '/workspace/re.arcade.r-type/out/object-wave/%s/object-wave-data.asm'
TABLE = 'tools/objid-arcade.csv'
STAGES = ('02', '03', '04', '05', '06', '07', '08')
TOLERE = {('Geld', 'geld')}

# Corruption d'import, corrigee ici : deux lignes portaient `ObjID_33wave`, ou
# l'arcade ecrit `ObjID_starfield`. Le suffixe collait au numero, donc aucune
# substitution par numero ne pouvait l'atteindre.
LITTERAUX = {'ObjID_33wave': 'ObjID_starfield'}


def table():
    lignes = [l for l in open(TABLE, encoding='utf-8')
              if not l.startswith('#') and l.strip()]
    r = csv.DictReader(io.StringIO(''.join(lignes[1:])))
    return {int(d['id']): d['nom_arcade'].strip() for d in r
            if d['nom_arcade'].strip()}


def renommer():
    noms = table()
    total = 0
    for s in STAGES:
        p = 'src/stages/%s/wave.asm' % s
        t = avant = open(p).read()
        n = 0
        for litteral, cible in LITTERAUX.items():
            t, k = re.subn(re.escape(litteral), cible, t)
            n += k
        for i, nom in sorted(noms.items()):
            # uniquement en commentaire, et le numero ENTIER (pas un prefixe)
            t, k = re.subn(r'(?m)(^;.*ObjID_)%d(?=[,\s]|$)' % i,
                           lambda m: m.group(1) + nom.replace('-', '_'), t)
            n += k
        if t != avant:
            open(p, 'w').write(t)
        print('  stage %s : %3d references nommees' % (s, n))
        total += n
    print('%d references au total' % total)
    return 0


def verifier():
    tot = ok = 0
    ecarts = []
    for s in STAGES:
        src = ARCADE % s
        if not os.path.exists(src):
            print('  stage %s : depot arcade absent — non verifiable' % s)
            continue
        fa = [l.lstrip(' \t;') for l in open(src).read().splitlines() if 'ObjID_' in l]
        fb = [l.lstrip(' \t;') for l in open('src/stages/%s/wave.asm' % s).read().splitlines()
              if 'ObjID_' in l]
        if len(fa) != len(fb):
            print('  stage %s : %d lignes arcade vs %d ici — NON APPARIABLE'
                  % (s, len(fa), len(fb)))
            ecarts.append(s)
            continue
        d = 0
        for x, y in zip(fa, fb):
            na = re.search(r'ObjID_(\w+)', x).group(1)
            nb = re.search(r'ObjID_(\w+)', y).group(1)
            tot += 1
            if na == nb or (na, nb) in TOLERE:
                ok += 1
            else:
                d += 1
                ecarts.append('stage %s : arcade %s, ici %s' % (s, na, nb))
        print('  stage %s : %3d lignes, %d ecart(s) hors tolerance' % (s, len(fa), d))
    print('%d lignes comparees, %d conformes' % (tot, ok))
    if ecarts:
        for e in ecarts[:20]:
            print('   ECART', e)
        return 1
    print('CONFORME — chaque ObjID est celui du depot arcade.')
    return 0


if __name__ == '__main__':
    sys.exit(verifier() if '--verifier' in sys.argv else renommer())
