#!/usr/bin/env python3
"""Migrer les COULEURS ECRITES EN DUR dans le code 6809 (groupe D du plan).

    tools/palette_code.py --liste      ce que chaque fichier emploie
    tools/palette_code.py --ecrire     applique, apres accord

Un sprite compile ou un glyphe dessine a la main n'a pas de PNG : ses couleurs
sont des quartets dans des immediats (`LDA #$0d` puis `STA 40,U`). En BM16 un
octet porte deux pixels, un par quartet, et **le quartet EST l'index materiel** —
pas d'offset de transparence comme dans les PNG, ou le 0 est le transparent.
Ici le 0 est une couleur : le noir.

La table de correspondance est la MEME que pour les images
(`palette-map.txt`), lue sous le nom de ressource que `palette-code.txt`
associe au fichier. Une couleur ne doit pas migrer differemment selon qu'elle
est dans un PNG ou dans du code.

Deux garde-fous, les memes que pour les PNG :

  * un immediat qui n'est ni declare porteur de couleur ni exclu **arrete**
    l'outil. Le meme opcode ne dit pas la meme chose d'un fichier a l'autre
    (`anda #$55` = une couleur dans hud.asm, `anda #$f0` = un masque dans
    tailmgr_blits.asm) : aucune regle globale ne peut trancher, donc rien
    n'est devine ;
  * apres ecriture, chaque fichier est relu et chaque immediat re-verifie.

Et une propriete que l'outil MESURE au lieu de la supposer : si tous les
quartets employes se reportent sur une entree de MEME couleur, la reecriture
ne change pas un pixel a l'ecran. C'est le cas des deux fichiers du groupe D,
et ca vaut preuve — pas besoin de planche, comme pour les PNG.
"""
import argparse
import importlib.util
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
PROJET = os.path.dirname(ICI)
IMM = re.compile(r'(^[^\n;]*?\b)(\w+)(\s+#\$)([0-9A-Fa-f]{1,4})\b', re.M)

# Un ASM migre ne porte AUCUNE trace de son etat — contrairement a un PNG, dont
# la table de couleurs dit tout de suite si les index sont les neufs. Sans
# marqueur, un second `--ecrire` renumeroterait une seconde fois, en silence.
# (Verifie : ca n'a tenu qu'a un hasard, le quartet 3 absent de la table. Les
# autres, eux, auraient ete remappes.) D'ou cette ligne, ecrite en tete du
# fichier et relue avant toute ecriture.
MARQUE = '; PALETTE-MIGREE — voir games/r-type/tools/palette-code.txt'


def _mig():
    spec = importlib.util.spec_from_file_location(
        'palette_migrate', os.path.join(ICI, 'palette_migrate.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def declaration(chemin):
    """[(fichier, ressource, {opcodes porteurs}, {exclusions})] dans l'ordre."""
    out, cour = [], None
    for ligne in open(chemin, encoding='utf-8'):
        ligne = ligne.split('#')[0].strip()
        if not ligne:
            continue
        mots = ligne.split()
        if mots[0] == 'fichier':
            cour = (mots[1], mots[2], set(), set())
            out.append(cour)
        elif mots[0] == 'couleur':
            cour[2].update(m.lower() for m in mots[1:])
        elif mots[0] == 'exclut':
            # `exclut <op>` exclut tout l'opcode ; `exclut <op> $val` une valeur
            cour[3].add((mots[1].lower(),
                         mots[2].lstrip('$').lower() if len(mots) > 2 else None))
    return out


def porte_couleur(op, val, couleurs, exclus):
    if (op, val) in exclus or (op, None) in exclus:
        return False
    return op in couleurs


def quartets(val):
    return [int(c, 16) for c in val]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--liste', action='store_true')
    ap.add_argument('--ecrire', action='store_true')
    ap.add_argument('--decl', default=os.path.join(ICI, 'palette-code.txt'))
    ap.add_argument('--map', default=os.path.join(ICI, 'palette-map.txt'))
    args = ap.parse_args()

    pm = _mig()
    pal_a = pm.palette_brute(os.path.join(PROJET, pm.PAL_ANCIENNE))
    pal_b = pm.palette_brute(os.path.join(PROJET, pm.PAL_NOUVELLE))
    rgb = lambda p: [tuple(p[i * 3:i * 3 + 3]) for i in range(17)]
    A, B = rgb(pal_a), rgb(pal_b)
    h = lambda t: '#%02X%02X%02X' % t
    code = 0

    for fich, ressource, couleurs, exclus in declaration(args.decl):
        chemin = os.path.join(PROJET, fich)
        src = open(chemin, encoding='utf-8', errors='surrogateescape').read()
        if MARQUE in src:
            print(f"\n{fich} : deja migre (marqueur present), rien a faire.")
            continue
        corr, _ = pm.table([args.map], ressource)
        vus, inconnus, orphelins = {}, [], set()

        for m in IMM.finditer(src):
            op, val = m.group(2).lower(), m.group(4).lower()
            if (op, val) in exclus or (op, None) in exclus:
                continue
            if op not in couleurs:
                inconnus.append((op, val))
                continue
            for q in quartets(val):
                if q not in corr:
                    orphelins.add(q)
                vus[q] = vus.get(q, 0) + 1

        print(f"\n{fich}   (table : {ressource})")
        if inconnus:
            print("  ARRET — des immediats ne sont ni porteurs ni exclus :")
            for op, val in sorted(set(inconnus)):
                print(f"      {op} #${val}")
            print("  Les classer dans palette-code.txt — un opcode ne veut pas")
            print("  dire la meme chose d'un fichier a l'autre.")
            code = 1
            continue
        if orphelins:
            print(f"  ARRET — quartets sans correspondance : {sorted(orphelins)}")
            code = 1
            continue

        chg = [(q, corr[q]) for q in sorted(vus) if A[q + 1] != B[corr[q] + 1]]
        for q in sorted(vus, key=lambda q: -vus[q]):
            d = corr[q]
            marque = '  <<< LA COULEUR CHANGE' if A[q + 1] != B[d + 1] else ''
            print(f"   ${q:x} {h(A[q + 1])} x{vus[q]:4}  ->  ${d:x} {h(B[d + 1])}{marque}")
        if not chg:
            print("  renumerotation PURE : aucun pixel ne change de couleur.")

        if args.ecrire:
            def sub(m):
                op, val = m.group(2).lower(), m.group(4).lower()
                if (op, val) in exclus or (op, None) in exclus or op not in couleurs:
                    return m.group(0)
                neuf = ''.join('%x' % corr[q] for q in quartets(val))
                return m.group(1) + m.group(2) + m.group(3) + neuf
            open(chemin, 'w', encoding='utf-8', errors='surrogateescape').write(
                MARQUE + '\n' + IMM.sub(sub, src))
            # relecture : les quartets porteurs doivent tous etre des cibles
            relu = open(chemin, encoding='utf-8', errors='surrogateescape').read()
            attendu = {corr[q] for q in vus}
            obtenu = set()
            for m in IMM.finditer(relu):
                op, val = m.group(2).lower(), m.group(4).lower()
                if porte_couleur(op, val, couleurs, exclus):
                    obtenu |= set(quartets(val))
            if obtenu != attendu:
                print(f"  ECRITURE VERIFIEE : ECART — quartets {sorted(obtenu)}"
                      f" au lieu de {sorted(attendu)}")
                code = 1
            else:
                print("  reecrit et relu : conforme.")
    return code


if __name__ == '__main__':
    sys.exit(main())
