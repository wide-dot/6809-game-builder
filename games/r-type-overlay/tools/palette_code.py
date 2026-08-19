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

# Deuxieme forme de couleur en dur, trouvee le 16/08 en basculant la palette :
# une TABLE de masques XOR. Le champ d'etoiles ne charge pas ses couleurs, il
# les XOR-e sur un ciel de nibble uniforme — l'octet range est donc
# `ciel ^ couleur`, pas la couleur. Aucun `#$` la-dedans : ni cet outil ni le
# releve de `palette_usage.py` (qui cherche `LDA #$xy` suivi d'un `STA ,U`)
# ne pouvaient la voir. C'est le trou que la bascule a revele, d'ou cette forme.
MASQUE = re.compile(r'^(\s*)(\w+)(\s+)(\$[0-9A-Fa-f]{2}(?:\s*,\s*\$[0-9A-Fa-f]{2})*)'
                    r'(\s*(?:;.*)?)$', re.M)

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


class Fichier:
    """Un fichier declare : ce qui y porte une couleur, et sous quelle forme."""

    def __init__(self, chemin, ressource):
        self.chemin, self.ressource = chemin, ressource
        self.couleurs, self.exclus = set(), set()
        self.masque = None          # (opcode, ciel, nb de lignes attendu) ou None

    def masque_ici(self, op):
        return self.masque is not None and op == self.masque[0]


def declaration(chemin):
    """Les fichiers declares, dans l'ordre."""
    out, cour = [], None
    for ligne in open(chemin, encoding='utf-8'):
        ligne = ligne.split('#')[0].strip()
        if not ligne:
            continue
        mots = ligne.split()
        if mots[0] == 'fichier':
            cour = Fichier(mots[1], mots[2])
            out.append(cour)
        elif mots[0] == 'couleur':
            cour.couleurs.update(m.lower() for m in mots[1:])
        elif mots[0] == 'masque':
            # `masque <opcode> ciel=$F [cible=$0] lignes=N` : les octets de cette
            # directive sont `ciel ^ couleur`, cadres a gauche ($X0) ou a droite
            # ($0X). `cible` permet de RE-ENCODER sur un autre ciel que celui
            # qu'on decode — c'est ce qui a servi quand le ciel du niveau 1 est
            # passe de l'index 15 a l'index 0 : meme table, meme passe, un XOR
            # different en sortie. Par defaut la cible est le ciel d'entree.
            # `lignes=N` est le garde-fou du silence : une table qu'on cesse de
            # reconnaitre (un operande ecrit autrement) ferait 0 ligne et ne
            # dirait rien — ici elle ARRETE.
            opts = dict(m.split('=') for m in mots[2:])
            ciel = int(opts['ciel'].lstrip('$'), 16)
            cour.masque = (mots[1].lower(), ciel,
                           int(opts.get('cible', '$%X' % ciel).lstrip('$'), 16),
                           int(opts['lignes']))
        elif mots[0] == 'exclut':
            # `exclut <op>` exclut tout l'opcode ; `exclut <op> $val` une valeur
            cour.exclus.add((mots[1].lower(),
                             mots[2].lstrip('$').lower() if len(mots) > 2 else None))
    return out


def octets_masque(operande):
    return [int(t.strip().lstrip('$'), 16) for t in operande.split(',')]


def decode_masque(octet, ciel):
    """(quartet employe, cadrage) d'un octet de masque, ou None si indecodable.

    Cadre a gauche  ($X0) -> quartet haut  : couleur = (octet>>4) ^ ciel
    Cadre a droite  ($0X) -> quartet bas   : couleur = (octet&$F) ^ ciel
    $00 a les deux quartets nuls : ambigu, donc indecodable — c'est voulu, ca
    force le bourrage a se declarer au lieu d'etre devine.
    """
    haut, bas = octet >> 4, octet & 0x0F
    if haut and not bas:
        return haut ^ ciel, 'haut'
    if bas and not haut:
        return bas ^ ciel, 'bas'
    return None


def encode_masque(couleur, cadrage, ciel):
    v = couleur ^ ciel
    return v << 4 if cadrage == 'haut' else v


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

    for f in declaration(args.decl):
        fich, ressource, couleurs, exclus = f.chemin, f.ressource, f.couleurs, f.exclus
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

        # deuxieme forme : les tables de masques XOR
        lignes_masque, indecodables, compte_faux = 0, [], False
        if f.masque:
            _, ciel, cible, attendues = f.masque
            for m in MASQUE.finditer(src):
                if not f.masque_ici(m.group(2).lower()):
                    continue
                octets = octets_masque(m.group(4))
                if all((m.group(2).lower(), '%02x' % o) in exclus for o in octets):
                    continue
                lignes_masque += 1
                for o in octets:
                    if (m.group(2).lower(), '%02x' % o) in exclus:
                        continue
                    d = decode_masque(o, ciel)
                    if d is None:
                        indecodables.append(o)
                        continue
                    q = d[0]
                    if q not in corr:
                        orphelins.add(q)
                    vus[q] = vus.get(q, 0) + 1
            compte_faux = lignes_masque != attendues

        print(f"\n{fich}   (table : {ressource})")
        if f.masque:
            vers = '' if f.masque[1] == f.masque[2] else f" -> ciel ${f.masque[2]:X}"
            print(f"  {lignes_masque} ligne(s) de masques XOR sur un ciel"
                  f" ${f.masque[1]:X}{vers}")
        if indecodables or compte_faux:
            if compte_faux:
                print(f"  ARRET — {lignes_masque} ligne(s) de masques reconnue(s),"
                      f" {f.masque[3]} declaree(s) dans palette-code.txt.")
                print("  Une table cesse d'etre reconnue en silence : c'est le cas"
                      " que ce compte existe pour attraper.")
            for o in sorted(set(indecodables)):
                print(f"  ARRET — octet de masque indecodable : ${o:02X} (les deux"
                      " quartets porteurs, ou aucun). L'exclure s'il est du bourrage.")
            code = 1
            continue
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

            def sub_masque(m):
                op = m.group(2).lower()
                if not f.masque_ici(op):
                    return m.group(0)
                ciel, cible = f.masque[1], f.masque[2]
                neufs = []
                for o in octets_masque(m.group(4)):
                    d = None if (op, '%02x' % o) in exclus else decode_masque(o, ciel)
                    neufs.append(o if d is None
                                 else encode_masque(corr[d[0]], d[1], cible))
                return (m.group(1) + m.group(2) + m.group(3)
                        + ','.join('$%02X' % o for o in neufs) + m.group(5))

            neuf = IMM.sub(sub, src)
            if f.masque:
                neuf = MASQUE.sub(sub_masque, neuf)
            open(chemin, 'w', encoding='utf-8', errors='surrogateescape').write(
                MARQUE + '\n' + neuf)
            # relecture : les quartets porteurs doivent tous etre des cibles
            relu = open(chemin, encoding='utf-8', errors='surrogateescape').read()
            attendu = {corr[q] for q in vus}
            obtenu = set()
            for m in IMM.finditer(relu):
                op, val = m.group(2).lower(), m.group(4).lower()
                if porte_couleur(op, val, couleurs, exclus):
                    obtenu |= set(quartets(val))
            if f.masque:
                for m in MASQUE.finditer(relu):
                    op = m.group(2).lower()
                    if not f.masque_ici(op):
                        continue
                    for o in octets_masque(m.group(4)):
                        if (op, '%02x' % o) in exclus:
                            continue
                        # relire avec le ciel CIBLE : c'est celui de l'octet ecrit
                        d = decode_masque(o, f.masque[2])
                        if d is not None:
                            obtenu.add(d[0])
            if obtenu != attendu:
                print(f"  ECRITURE VERIFIEE : ECART — quartets {sorted(obtenu)}"
                      f" au lieu de {sorted(attendu)}")
                code = 1
            else:
                print("  reecrit et relu : conforme.")
    return code


if __name__ == '__main__':
    sys.exit(main())
