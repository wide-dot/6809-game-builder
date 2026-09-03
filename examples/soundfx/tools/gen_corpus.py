#!/usr/bin/env python3
"""Genere src/corpus.asm et src/corpus/*.asm depuis le corpus Master System de
games/r-type (reference/sms/sfx/soundfx/, sorti de tools/sms_sfx_to_soundfx.py).

L'exemple ne depend pas du jeu au build : les 54 blocs sont COPIES ici, et ce
script est la seule facon de les rafraichir. Il ecrit aussi, pour chaque son :
son identifiant Master System, son nom, sa duree en trames, s'il joue sur
l'instrument personnalise, et s'il fait partie des dix-neuf sons du jeu.

    tools/gen_corpus.py
"""
import glob, os, re, shutil

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.normpath(os.path.join(ICI, '../../games/r-type/reference/sms/sfx/soundfx'))
DST = os.path.join(ICI, 'src/corpus')
JEU = {18, 33, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51}

def main():
    os.makedirs(DST, exist_ok=True)
    for f in glob.glob(os.path.join(DST, '*.asm')):
        os.remove(f)
    sons = []
    for f in sorted(glob.glob(os.path.join(SRC, '*.asm')),
                    key=lambda x: int(re.match(r'(\d+)', os.path.basename(x)).group(1))):
        base = os.path.basename(f)[:-4]
        sid = int(re.match(r'(\d+)', base).group(1))
        txt = open(f).read()
        label = re.search(r'^(soundFX\.\w+\.data)$', txt, re.M).group(1)
        duree = sum(int(d) for d in re.findall(r'fcb\s+\$[0-9A-F]{2},\$[0-9A-F]{2},(\d+)', txt))
        custom = '; instrument perso' in txt
        nom = re.sub(r'^\d+-?', '', base).replace('-', ' ').upper() or 'SMS %d' % sid
        shutil.copy(f, os.path.join(DST, base + '.asm'))
        sons.append((sid, base, label, min(duree, 255), custom, nom))

    l = ['; GENERE par tools/gen_corpus.py — ne pas editer a la main.',
         '; Le corpus Master System de games/r-type, un bloc par son, au format du',
         '; pilote soundFX (en-tete nb commandes + voie, commandes registre/donnee/delai).',
         '',
         'corpus.count equ %d' % len(sons), '']
    for _, base, *_ in sons:
        l.append('        INCLUDE "src/corpus/%s.asm"' % base)
    l += ['', '; adresse du bloc de chaque son', 'corpus.table']
    l += ['        fdb   %s' % s[2] for s in sons]
    l += ['', '; identifiant Master System (index du test sonore)', 'corpus.id']
    l += ['        fcb   %d' % s[0] for s in sons]
    l += ['', '; duree en trames (somme des delais, plafonnee a 255)', 'corpus.duration']
    l += ['        fcb   %d' % s[3] for s in sons]
    l += ['', '; bit 0 : joue sur l instrument personnalise ; bit 1 : un des sons du jeu', 'corpus.flags']
    l += ['        fcb   %d' % ((1 if s[4] else 0) | (2 if s[0] in JEU else 0)) for s in sons]
    l += ['', '; nom affiche (dernier caractere avec le bit 7)', 'corpus.name']
    l += ['        fdb   corpus.name.%d' % s[0] for s in sons]
    l.append('')
    for s in sons:
        nom = s[5]
        l.append('corpus.name.%d fcc "%s"' % (s[0], nom[:-1]))
        l.append('        fcb   $%02X' % (ord(nom[-1]) | 0x80))
    open(os.path.join(ICI, 'src/corpus.asm'), 'w').write('\n'.join(l) + '\n')
    print('%d sons, %d du jeu, %d sur instrument personnalise' % (
        len(sons), sum(1 for s in sons if s[0] in JEU), sum(1 for s in sons if s[4])))

if __name__ == '__main__':
    main()
