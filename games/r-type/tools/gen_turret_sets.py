#!/usr/bin/env python3
"""Les tourelles du vaisseau : dedupliquer les 16 poses, emettre la roue.

L'arcade range ses poses de tourelle dans une table de SEIZE pointeurs qui ne
designent que NEUF sprites : la roue de visee est palindromique (la pose vue
en montant a 30 degres est celle vue en descendant a 30 degres). L'export de
re.arcade deroule les seize et repete donc sept images.

Ici on fait comme l'arcade : neuf images, et une table de seize entrees qui
les designe. On economise 44 % de la page — et la correspondance n'est pas
devinee, elle se LIT dans les noms de l'export, qui portent l'adresse arcade
du sprite (`005_0182aa.png` est le meme sprite que `003_0182aa.png`).

Entree  : re.arcade.r-type/out/sprites/warship-elements/<jeu>/ (noms adresses)
          + src/enemies/warship-elements/images/<jeu>/ (les PNG convertis)
Sortie  : src/enemies/warship-elements/images/<jeu>-wheel/  (les 9 uniques)
          + gen'... non : la table est ECRITE ici, dans un .asm commite a cote
          des images, parce que le code objet la cite.

Usage : python3 tools/gen_turret_sets.py   (depuis games/r-type)
"""
import os
import re
import shutil
import sys

ARCADE = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
          '/out/sprites/warship-elements')
JEUX = ('small-turret-top', 'small-turret-bottom', 'big-turret')


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = os.path.join(racine, 'src/enemies/warship-elements/images')
    lignes = [
        "; La roue de visee des tourelles — GENERE par tools/gen_turret_sets.py.",
        "; Seize directions, neuf poses : la roue est palindromique et l'arcade",
        "; fait exactement cela (table de 16 pointeurs vers 9 sprites, 1000:8258",
        "; pour la petite HAUT, 8278 pour la BAS, 81fa pour la grosse).",
        "; L'index vaut la direction de setDirectionTo divisee par quatre.",
        "",
    ]
    for jeu in JEUX:
        src_arc = os.path.join(ARCADE, jeu)
        src_png = os.path.join(base, jeu)
        dst = os.path.join(base, jeu + '-wheel')
        if not os.path.isdir(src_arc):
            sys.exit('export arcade absent : ' + src_arc)
        # la correspondance : l'ordinal -> l'adresse arcade du sprite
        adr = {}
        for nom in sorted(os.listdir(src_arc)):
            m = re.match(r'(\d+)_([0-9a-f]+)\.png$', nom)
            if m:
                adr[int(m.group(1))] = m.group(2)
        if len(adr) != 16:
            sys.exit('%s : %d poses, 16 attendues' % (jeu, len(adr)))
        # les uniques, dans l'ordre de premiere apparition
        uniques, rang = [], {}
        for i in range(16):
            a = adr[i]
            if a not in rang:
                rang[a] = len(uniques)
                uniques.append(i)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(dst):
            if f.endswith('.png'):
                os.remove(os.path.join(dst, f))
        for k, i in enumerate(uniques):
            shutil.copyfile(os.path.join(src_png, '%02d.png' % i),
                            os.path.join(dst, '%02d.png' % k))
        geo = os.path.join(src_png, 'geometrie.txt')
        if os.path.exists(geo):
            shutil.copyfile(geo, os.path.join(dst, 'geometrie.txt'))
        sym = jeu.replace('-', '_')
        lignes.append('; %s : %d poses pour 16 directions' % (jeu, len(uniques)))
        lignes.append('turret.wheel.%s' % sym)
        for bloc in range(4):
            morceau = []
            for i in range(bloc * 4, bloc * 4 + 4):
                morceau.append('set_%s_%d' % (sym, rang[adr[i]]))
            lignes.append('        fdb   ' + ','.join(morceau))
        lignes.append('')
        print('%s : 16 poses -> %d uniques' % (jeu, len(uniques)))
    out = os.path.join(racine, 'src/enemies/warship-elements/turret/wheel.asm')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w') as f:
        f.write('\n'.join(lignes))
    print('roue ecrite : src/enemies/warship-elements/turret/wheel.asm')


if __name__ == '__main__':
    main()
