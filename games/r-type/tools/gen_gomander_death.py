#!/usr/bin/env python3
"""Genere la cascade d'explosions de la mort du Gomander (boss du stage 2).

La borne (tick_gomander_death_explosion_cascade, 0x40:A6A5) seme une
explosion par trame PAIRE pendant 352 trames, aux positions d'une liste de
288 pointeurs (0x1000:5602, terminee par 0x0000) vers 68 couples {x, y}
(0x1000:54EA.., le plan des cellules du corps). Elle n'en consomme que 176 :
la liste boucle mais la vie de l'acteur s'arrete avant.

Ce que le TO8 en garde (decision auteur, 08/09/2026) : on ne peut pas
afficher 176 explosions, on ECHANTILLONNE a 8 images par seconde — une
entree toutes les 8 trames arcade, soit un spawn arcade sur quatre, 44
entrees pour les 352 trames. Le marcheur v2 (src/common/fx/bosscascade/
obj.asm) pose une entree toutes les bosscascade.PERIOD trames video, ce qui
garde la duree arcade.

Le « une chance sur quatre de grosse explosion » de la borne (random & 6 ==
0 -> big_explosion_with_grey_brown_flash_disk, 0x40:E817) est PRE-TIRE ici,
graine fixe : la variete est deterministe, comme le compiler.

Conversion : x*0,375 ; y*0,75 EN CHANGEANT DE SIGNE (l'axe de la borne
monte) — les regles de gen_compiler_death.py. Le +4 vertical de l'ancrage
arcade (a4ef) est laisse au boss, qui pose l'enfant.

Sortie : src/enemies/gomander/explosions.asm (commise, comme celle du
compiler : le dump arcade ne sert qu'a la REGENERER).
Rejeu : python3 tools/gen_gomander_death.py (depuis games/r-type/).
"""
import os
import random
import struct

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000                      # le segment de donnees 0x1000
LISTE = 0x5602                     # les pointeurs proches vers les couples
VIE = 0x160                        # a4fa : 352 trames de cascade
PAS_ARCADE = 2                     # une explosion par trame paire
PERIODE = 8                        # notre pas : 8 trames -> 8 images/s
GRAINE = 0x5609                    # le pre-tirage de la grosse explosion :
                                   # choisie pour 11 grosses sur 44, le quart
                                   # de la borne au plus juste


def lire_pointeurs(rom):
    out = []
    off = LISTE
    while True:
        p = struct.unpack_from('<H', rom, SEG + off)[0]
        if p == 0:
            return out
        out.append(p)
        off += 2


def couple(rom, ptr):
    return struct.unpack_from('<hh', rom, SEG + ptr)


def borne(v, quoi):
    if not -128 <= v <= 127:
        raise SystemExit('offset %s hors d\'un octet signe : %d' % (quoi, v))
    return v & 0xFF


def main():
    rom = open(ROM, 'rb').read()
    ptrs = lire_pointeurs(rom)
    consommes = VIE // PAS_ARCADE           # 176 : ce que la borne joue
    if consommes > len(ptrs):
        raise SystemExit('la borne bouclerait (%d > %d) — pas prevu'
                         % (consommes, len(ptrs)))
    pas = PERIODE // PAS_ARCADE             # un spawn arcade sur quatre
    choisis = [ptrs[i] for i in range(0, consommes, pas)]
    tirage = random.Random(GRAINE)
    out = [
        '; ---------------------------------------------------------------------------',
        "; LA CASCADE DE MORT DU GOMANDER — table GENEREE, ne pas editer",
        '; ---------------------------------------------------------------------------',
        '; Rejeu : python3 tools/gen_gomander_death.py (depuis games/r-type/).',
        '; Une entree = {dx, dy, subtype} : deux octets signes a ajouter a la',
        "; position de l'enfant, puis le subtype d'explosion (animation + son).",
        '; Une entree toutes les bosscascade.PERIOD (%d) trames video ; la borne' % PERIODE,
        '; en jouait une par trame paire (0x1000:5602, 176 des 288 lues) — ici',
        "; un spawn sur %d, pour 8 images par seconde. Fin de table : $80." % pas,
        '',
        '; le pas du marcheur, en trames video : la table est echantillonnee dessus',
        'bosscascade.PERIOD equ %d' % PERIODE,
        'bosscascade.SMALL equ explosion.subtype.smallx3+explosion.sfx.cascade',
        'bosscascade.BIG   equ explosion.subtype.big.brown+explosion.sfx.cascade',
        '',
        'bosscascade.table',
    ]
    grosses = 0
    for i, p in enumerate(choisis):
        x, y = couple(rom, p)
        vx = borne(round(x * 0.375), 'x')
        vy = borne(round(-y * 0.75), 'y')   # l'axe y de la borne MONTE
        grosse = (tirage.randrange(8) & 6) == 0     # a6d7 : random & 6 == 0
        grosses += grosse
        out.append('        fcb   $%02X,$%02X,bosscascade.%s   ; t=%3d  arcade %+4d,%+4d (%04X)'
                   % (vx, vy, 'BIG  ' if grosse else 'SMALL', i * PERIODE,
                      x, y, p))
    out.append('        fcb   $80')
    dst = 'src/enemies/gomander/explosions.asm'
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'w').write('\n'.join(out) + '\n')
    print('ecrit %s : %d entrees (%d grosses) sur %d pointeurs, %d consommes'
          % (dst, len(choisis), grosses, len(ptrs), consommes))


if __name__ == '__main__':
    main()
