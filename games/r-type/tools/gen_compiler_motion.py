#!/usr/bin/env python3
"""Genere les scripts de combat du Compiler (boss du stage 4).

Passe l'intro, chaque piece du boss suit ses propres trajectoires. La borne
les tient dans NEUF scripts (trois par piece, nommes a/b/c) qu'un curseur
parcourt segment par segment ; une config de variante dit dans quel ORDRE la
piece les enchaine, et le tirage au sort du spawn choisit la config parmi
trois. Voir compiler_part_motion_step (0x40:AFE6).

Un segment fait six octets : {vx:word, vy:word, duree:word}, tous en 8.8 pour
les vitesses. La sentinelle est vx = 0x8000, et elle seule : chaque script
compte dix-sept segments puis elle. Attention, vx = 0 est un mouvement
VERTICAL PUR, tres frequent (le premier segment de chaque script en est un) —
le confondre avec une fin vide tous les scripts, verifie.
Le terminateur — celui qui declenche l'auto-destruction de la borne apres
~3,6 min — vit au bout de la CHAINE de scripts d'une config, pas dans un
script.

Conversion : vx x0,375 ; vy x0,75 ET CHANGEMENT DE SIGNE (l'axe y de la borne
monte, le notre descend). Les durees restent en trames — l'horloge de jeu est
calee sur la borne.

Sortie : src/enemies/compiler/motion.asm, inclus par compiler.unit.asm.
Rejeu : python3 tools/gen_compiler_motion.py (depuis games/r-type/).
"""
import os
import struct

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000

# Les neuf scripts, dans l'ordre piece x lettre. Les adresses viennent des
# configs de variante (0x1000:5AFA et suivantes).
SCRIPTS = (
    ('right_a',  0x5B5C), ('bottom_a', 0x5BC4), ('left_a', 0x5C2C),
    ('right_b',  0x5C94), ('bottom_b', 0x5CFC), ('left_b', 0x5D64),
    ('right_c',  0x5DCC), ('bottom_c', 0x5E34), ('left_c', 0x5E9C),
)
# Les trois configs par piece : {piece: [(lettre, adresse), ...]}. Chacune
# liste ses trois scripts dans l'ordre d'enchainement.
CONFIGS = {
    'right':  (0x5AFA, 0x5B04, 0x5B0E),
    'bottom': (0x5B18, 0x5B22, 0x5B2C),
    'left':   (0x5B36, 0x5B40, 0x5B4A),
}
FIN = 0x8000
MAXSEG = 24


def conv(v, k):
    """Une vitesse 8.8 arcade -> 8.8 v2, bornee au mot signe."""
    r = int(round(v * k))
    if not -32768 <= r <= 32767:
        raise SystemExit('vitesse hors bornes : %d' % r)
    return r & 0xFFFF


def lire(rom, off):
    out = []
    for i in range(MAXSEG):
        vx, vy, dur = struct.unpack_from('<Hhh', rom, SEG + off + i * 6)
        out.append((vx, vy, dur))
        if vx == FIN:
            break
    return out


def main():
    rom = open(ROM, 'rb').read()
    out = [
        '; ---------------------------------------------------------------------------',
        '; LES SCRIPTS DE COMBAT DU COMPILER — table GENEREE, ne pas editer',
        '; ---------------------------------------------------------------------------',
        '; Rejeu : python3 tools/gen_compiler_motion.py (depuis games/r-type/).',
        '; Un segment = {vx:word, vy:word, duree:word}, vitesses en 8.8 v2.',
        '; vx = $8000 : fin du script, passer au suivant de la config.',
        '; (vx = $0000 est un mouvement VERTICAL PUR, pas une fin.)',
        '',
    ]
    for nom, off in SCRIPTS:
        segs = lire(rom, off)
        out.append('cpl.mot.%s' % nom)
        for vx, vy, dur in segs:
            if vx == FIN:
                out.append('        fdb   $8000,0,0        ; fin : script suivant')
            else:
                sx = struct.unpack('<h', struct.pack('<H', vx))[0]
                out.append('        fdb   $%04X,$%04X,%-5d ; arcade %+5d,%+5d,%d'
                           % (conv(sx, 0.375), conv(vy, -0.75), dur, sx, vy, dur))
        out.append('')

    out.append('; Les trois configs de chaque piece : trois scripts, dans l\'ordre ou')
    out.append('; la piece les enchaine. Le tirage du spawn choisit la ligne.')
    for piece, adrs in CONFIGS.items():
        out.append('cpl.cfg.%s' % piece)
        for a in adrs:
            # les elements a/b/c d'une config sont ses mots 1, 2 et 3
            elems = struct.unpack_from('<3H', rom, SEG + a + 2)
            noms = []
            for e in elems:
                m = [n for n, o in SCRIPTS if o == e]
                noms.append('cpl.mot.%s' % m[0] if m else '0')
            out.append('        fdb   %s' % ','.join(noms))
        out.append('')

    # LA SORTIE VIT DANS src/, PAS DANS gen/ (29/08/2026, decision auteur).
    # C'est une donnee de PORTAGE d'un ennemi, comme part/boxes.asm ou
    # reactor/tables.asm : elle se commite, et le dump arcade ne sert qu'a la
    # REGENERER. Dans gen/ — gitignore — elle disparaissait a chaque nettoyage
    # et manquait a tout clone frais : la CI et une machine neuve ne pouvaient
    # pas builder le jeu, faute d'un fichier qu'aucune commande du depot ne
    # sait reproduire sans le dump et son chemin absolu.
    dst = 'src/enemies/compiler/motion.asm'
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'w').write('\n'.join(out) + '\n')
    print('ecrit %s (%d scripts, %d configs par piece)'
          % (dst, len(SCRIPTS), len(CONFIGS['right'])))


if __name__ == '__main__':
    main()
