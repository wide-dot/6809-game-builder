#!/usr/bin/env python3
"""Genere la table d'oscillation du dome du Compiler (boss du stage 4).

La borne fait pulser TROIS entrees de sa palette — l'ombre, le corps et le halo
de la bulle — de la palette 0x41 vers la 0x52, en ping-pong triangulaire de
periode 128 ticks a 55 Hz, interpolation lineaire par canal. C'est etabli dans
la ROM et dans la simulation PalettePulse de re.arcade.r-type.

Ce que ce script en tire, et pourquoi il existe : le TO8 n'a pas 16 niveaux
lineaires mais une courbe DAC (0, 97, 122, 143, ... 250, 255) — un gouffre sous
97, des pas fins en haut. Projeter la rampe arcade dessus donne des paliers
INEGAUX, qu'il vaut mieux calculer que transcrire. La descente est COUPEE A
60 % (decision auteur, 29/08 : « 4 etapes, pas de noir, pas de vert sombre
uni ») : au-dela, les trois verts tombent dans les memes bacs DAC et la bulle
devient un aplat.

Sortie : src/enemies/compiler/dome-pulse.asm, inclus par compiler.unit.asm.
Rejeu : python3 tools/gen_dome_pulse.py (depuis games/r-type/).
"""
import os

# La courbe DAC du TO8 — la meme table que toolbox/graphics/png2pal (to.txt).
DAC = [0, 97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255]

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
PAL_BASE, PAL_TARGET = 0x41, 0x52
# Les trois entrees arcade qui pulsent, RANGEES DANS L'ORDRE DE NOS CASES
# MATERIELLES 12, 13, 14 — soit halo, ombre, corps. L'arcade les numerote
# autrement (2 = ombre, 3 = corps, 4 = halo) : la permutation est ici, une
# fois, plutot que dans le runtime.
DOME = (4, 2, 3)
COUPE = 0.6               # la descente s'arrete la (voir le docstring)
ETAPES = 4

# Le cycle, en trames de JEU (l'horloge est calee sur la borne). Une demi-
# descente arcade dure 128/2 ticks a 55 Hz, soit 58 trames a 50 Hz ; les
# etapes se repartissent dessus au prorata de la rampe, et la 4e absorbe le
# reste — c'est le creux profond de l'arcade, replie en TENUE puisqu'on a
# coupe la couleur a 60 %. Le boss respire donc lentement dans le sombre.
DUREES = [12, 12, 11, 58, 11, 12]      # e0 e1 e2 e3 e2 e1 -> 116 trames
ORDRE = [0, 1, 2, 3, 2, 1]


def niveau(v):
    """L'index DAC le plus proche d'une composante 0-255."""
    return min(range(16), key=lambda i: abs(DAC[i] - v))


def lire_palette(rom, idx):
    base = 0x3B000 + 0x30 * idx
    return [tuple((rom[base + i * 3 + c] & 0x1F) << 3 for c in range(3))
            for i in range(16)]


def main():
    rom = open(ROM, 'rb').read()
    base, cible = lire_palette(rom, PAL_BASE), lire_palette(rom, PAL_TARGET)

    lignes = []
    for e in range(ETAPES):
        t = COUPE * e / (ETAPES - 1)
        mots, desc = [], []
        for v in DOME:
            rgb = tuple(round(base[v][c] + (cible[v][c] - base[v][c]) * t)
                        for c in range(3))
            r, g, b = (niveau(x) for x in rgb)
            mots.append('$%X%X0%X' % (g, r, b))       # le format de png2pal
            desc.append('%d,%d,%d' % (DAC[r], DAC[g], DAC[b]))
        # (les trois desc suivent DOME : halo, ombre, corps)
        lignes.append('        fdb   %s ; e%d : halo %s / ombre %s / corps %s'
                      % (','.join(mots), e, *desc))

    out = ['; ---------------------------------------------------------------------------',
           '; L\'OSCILLATION DU DOME DU COMPILER — table GENEREE, ne pas editer',
           '; ---------------------------------------------------------------------------',
           '; Rejeu : python3 tools/gen_dome_pulse.py (depuis games/r-type/).',
           '; Le pourquoi de chaque valeur est dans le script ; en deux mots : la borne',
           '; pulse trois entrees de palette vers un vert sombre, et la courbe DAC du TO8',
           '; n\'a pas les niveaux intermediaires pour la suivre — on garde 4 paliers, sans',
           '; noir ni aplat uni (decision auteur).',
           ';',
           '; Trois mots par etape, dans l\'ordre des cases MATERIELLES 12, 13, 14 :',
           '; halo, ombre, corps. Format $GR0B, celui de png2pal — le runtime les recopie',
           '; tels quels dans Pal_buffer.',
           'cpl.dome.pal']
    out += lignes
    out += ['',
            '; Le cycle, en trames de jeu : l\'etape a jouer puis sa duree. La 4e est une',
            '; TENUE longue — le creux profond de l\'arcade, dont on a coupe la couleur.',
            '; Total %d trames, la periode de la borne (128 ticks a 55 Hz).' % sum(DUREES),
            'cpl.dome.CYCLE equ %d' % len(ORDRE),
            'cpl.dome.seq']
    for i, (e, d) in enumerate(zip(ORDRE, DUREES)):
        out.append('        fcb   %d,%-3d ; etape %d, %d trames' % (e, d, e, d))

    # LA SORTIE VIT DANS src/, PAS DANS gen/ (29/08/2026, decision auteur).
    # C'est une donnee de PORTAGE d'un ennemi, comme part/boxes.asm ou
    # reactor/tables.asm : elle se commite, et le dump arcade ne sert qu'a la
    # REGENERER. Dans gen/ — gitignore — elle disparaissait a chaque nettoyage
    # et manquait a tout clone frais : la CI et une machine neuve ne pouvaient
    # pas builder le jeu, faute d'un fichier qu'aucune commande du depot ne
    # sait reproduire sans le dump et son chemin absolu.
    dst = 'src/enemies/compiler/dome-pulse.asm'
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'w').write('\n'.join(out) + '\n')
    print('ecrit %s (%d etapes, cycle %d trames)' % (dst, ETAPES, sum(DUREES)))


if __name__ == '__main__':
    main()
